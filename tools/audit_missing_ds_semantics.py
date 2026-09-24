#!/usr/bin/env python3
"""Cross-check missing WtW movement groups against reviewed DWDS semantic specs.

This is audit-only tooling. It never writes runtime assets. The normal DigiGame
build remains reproducible from pinned WtW sources and committed extraction
metadata; this script only helps reviewers assign source groups to the canonical
DL/DR/UL/UR contract without guessing from sheet position.
"""
from __future__ import annotations

import argparse
import hashlib
import io
import itertools
import json
import math
import os
import re
from difflib import SequenceMatcher
from pathlib import Path
from typing import Any

import numpy as np
from PIL import Image, ImageOps

from audit_missing_ds_sources import (
    OUT as STRUCTURAL_OUT,
    SOURCE_ID_OVERRIDES,
    archive_member_for_id,
    compact,
    extract_candidates,
    missing_database_rows,
    resolve_unnumbered_member,
    topic_alias_index,
)
from build_additional_ds_fields import CONFIG_PATH, movement_groups
from build_early_rank_ds_fields import _components, load_wtw_archive

ROOT = Path(__file__).resolve().parents[1]
OUT = Path(os.environ.get("DIGIGAME_SEMANTIC_AUDIT_OUT", "/tmp/ds-semantic-audit"))
MANAGER_ROOT = Path(os.environ.get("DIGIMON_SPRITE_MANAGER_ROOT", "/tmp/DigimonWorldSpriteManager"))
MANAGER_SPECS = MANAGER_ROOT / "specs" / "digimon"
MANAGER_RAW = MANAGER_ROOT / "raw_sheets"
DIRECTIONS = ("down_left", "down_right", "up_left", "up_right")
PATTERNS = {
    "canonical_rows": [0, 1, 2, 3],
    "canonical_rows_rear_reversed": [0, 1, 3, 2],
    "rear_rows_first": [2, 3, 0, 1],
    "compact_interleaved": [0, 2, 1, 3],
    "compact_interleaved_horizontal_reversed": [2, 0, 3, 1],
    "canonical_rows_front_reversed": [1, 0, 3, 2],
    "rear_rows_first_horizontal_reversed": [3, 2, 1, 0],
}


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def parse_hex_color(value: Any) -> tuple[int, int, int] | None:
    if value is None:
        return None
    text = str(value).lower().replace("0x", "").replace("#", "")
    if len(text) != 6:
        return None
    return tuple(int(text[i:i + 2], 16) for i in (0, 2, 4))


def keyed_crop(image: Image.Image, box: dict[str, Any], background: tuple[int, int, int] | None = None, tolerance: int = 8) -> Image.Image:
    x, y, w, h = (int(box[key]) for key in ("x", "y", "w", "h"))
    crop = image.crop((x, y, x + w, y + h)).convert("RGBA")
    rgba = np.array(crop, dtype=np.uint8, copy=True)
    alpha = rgba[:, :, 3]
    if background is None:
        if np.any(alpha == 0):
            mask = alpha > 0
        else:
            corners = np.array([rgba[0, 0, :3], rgba[0, -1, :3], rgba[-1, 0, :3], rgba[-1, -1, :3]])
            colors, counts = np.unique(corners, axis=0, return_counts=True)
            background = tuple(int(v) for v in colors[int(np.argmax(counts))])
            delta = np.abs(rgba[:, :, :3].astype(np.int16) - np.array(background, dtype=np.int16))
            mask = np.max(delta, axis=2) > tolerance
    else:
        delta = np.abs(rgba[:, :, :3].astype(np.int16) - np.array(background, dtype=np.int16))
        mask = (np.max(delta, axis=2) > tolerance) & (alpha > 0)
    rgba[:, :, 3] = np.where(mask, 255, 0).astype(np.uint8)
    rgba[rgba[:, :, 3] == 0, :3] = 0
    out = Image.fromarray(rgba, "RGBA")
    bbox = out.getbbox()
    return out.crop(bbox) if bbox else out


def normalize_canvas(image: Image.Image, width: int, height: int) -> np.ndarray:
    rgba = np.array(image.convert("RGBA"), dtype=np.int16)
    canvas = np.zeros((height, width, 4), dtype=np.int16)
    x = max(0, (width - image.width) // 2)
    y = max(0, height - image.height)
    canvas[y:y + image.height, x:x + image.width] = rgba
    return canvas


def frame_cost(a: Image.Image, b: Image.Image) -> float:
    width = max(a.width, b.width)
    height = max(a.height, b.height)
    aa = normalize_canvas(a, width, height)
    bb = normalize_canvas(b, width, height)
    alpha_union = (aa[:, :, 3] > 0) | (bb[:, :, 3] > 0)
    if not np.any(alpha_union):
        return 1e9
    alpha_mismatch = np.mean(np.abs(aa[:, :, 3] - bb[:, :, 3])[alpha_union]) / 255.0
    rgb = np.abs(aa[:, :, :3] - bb[:, :, :3])
    rgb_error = np.mean(rgb[alpha_union]) / 255.0
    size_penalty = (abs(a.width - b.width) + abs(a.height - b.height)) / max(1.0, width + height)
    return float(alpha_mismatch * 2.0 + rgb_error + size_penalty * 0.5)


def triplet_cost(source_frames: list[Image.Image], reference_frames: list[Image.Image]) -> tuple[float, list[int]]:
    if len(source_frames) != 3 or len(reference_frames) != 3:
        return 1e9, [0, 1, 2]
    scored: list[tuple[float, tuple[int, int, int]]] = []
    for order in itertools.permutations(range(3)):
        cost = sum(frame_cost(source_frames[order[i]], reference_frames[i]) for i in range(3))
        scored.append((cost, order))
    scored.sort(key=lambda item: item[0])
    return scored[0][0], list(scored[0][1])


def source_stem_alias(member: str) -> str:
    stem = Path(member).stem
    return re.sub(r"^\d{3}_", "", stem)


def manager_index() -> tuple[dict[str, dict[str, Any]], list[dict[str, Any]]]:
    by_name: dict[str, dict[str, Any]] = {}
    specs: list[dict[str, Any]] = []
    for path in sorted(MANAGER_SPECS.glob("*.extract.json")):
        try:
            spec = json.loads(path.read_text(encoding="utf-8"))
        except Exception:
            continue
        name = str(spec.get("creature_name") or "").strip()
        if not name:
            continue
        spec["_path"] = str(path)
        specs.append(spec)
        by_name.setdefault(compact(name), spec)
    return by_name, specs


def best_manager_spec(candidates: list[str], by_name: dict[str, dict[str, Any]], specs: list[dict[str, Any]]) -> tuple[dict[str, Any] | None, float]:
    keys = [compact(value) for value in candidates if compact(value)]
    for key in keys:
        if key in by_name:
            return by_name[key], 1.0
    best: tuple[float, dict[str, Any] | None] = (0.0, None)
    for spec in specs:
        target = compact(str(spec.get("creature_name", "")))
        for key in keys:
            score = SequenceMatcher(None, key, target).ratio()
            if score > best[0]:
                best = (score, spec)
    return (best[1], best[0]) if best[0] >= 0.84 else (None, best[0])


def sheet_url_index() -> dict[str, str]:
    path = MANAGER_RAW / "sheet_urls.txt"
    if not path.is_file():
        return {}
    result: dict[str, str] = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        sheet_id, _, url = line.partition(" ")
        if sheet_id and url:
            result[sheet_id] = url.strip()
    return result


def load_manager_sheet(spec: dict[str, Any], urls: dict[str, str]) -> Image.Image | None:
    sheet_id = str(spec.get("sheet_id") or "")
    path = MANAGER_RAW / f"{sheet_id}.png"
    if not path.is_file():
        url = urls.get(sheet_id)
        if not url:
            bucket = sheet_id[:2]
            url = f"https://www.spriters-resource.com/resources/sheets/{bucket}/{sheet_id}.png"
        import subprocess
        path.parent.mkdir(parents=True, exist_ok=True)
        result = subprocess.run(
            ["curl", "-fsSL", "--retry", "3", "-A", "Mozilla/5.0", url, "-o", str(path)],
            check=False,
            capture_output=True,
            timeout=90,
        )
        if result.returncode != 0 or not path.is_file():
            return None
    return Image.open(path).convert("RGBA")


def manager_walk_frames(spec: dict[str, Any], sheet: Image.Image) -> dict[str, list[Image.Image]]:
    box_index = {str(box["id"]): box for box in spec.get("boxes", [])}
    walk = spec.get("clips", {}).get("walk", {})
    background = parse_hex_color(spec.get("background"))
    tolerance = int(spec.get("background_tolerance") or 8)
    result: dict[str, list[Image.Image]] = {}
    for direction in DIRECTIONS:
        ids = walk.get(direction) or []
        if not ids:
            continue
        frames = []
        for frame_id in ids[:3]:
            box = box_index.get(str(frame_id))
            if box is None:
                frames = []
                break
            frames.append(keyed_crop(sheet, box, background, tolerance))
        if len(frames) == 3:
            result[direction] = frames
    for target, source_direction in dict(spec.get("mirror") or {}).items():
        if target in DIRECTIONS and source_direction in result and target not in result:
            result[target] = [ImageOps.mirror(frame) for frame in result[source_direction]]
    return result


def wtw_group_frames(image: Image.Image, groups: list[list[dict[str, int]]]) -> list[list[Image.Image]]:
    background, _ = _components(image)
    return [[keyed_crop(image, box, background, 0) for box in group] for group in groups]


def pattern_from_assignment(assignment: dict[str, int]) -> str | None:
    if not all(direction in assignment for direction in DIRECTIONS):
        return None
    permutation = [assignment[direction] for direction in DIRECTIONS]
    for name, values in PATTERNS.items():
        if values == permutation:
            return name
    return "explicit:" + ",".join(str(value) for value in permutation)


def classify(groups: list[list[Image.Image]], refs: dict[str, list[Image.Image]]) -> dict[str, Any]:
    directions = [direction for direction in DIRECTIONS if direction in refs]
    if len(groups) != 4 or len(directions) < 3:
        return {"status": "insufficient_semantics", "directions": directions}
    matrix: dict[str, list[dict[str, Any]]] = {}
    for direction in directions:
        scores = []
        for group_index, group in enumerate(groups):
            cost, phase_order = triplet_cost(group, refs[direction])
            scores.append({"group": group_index, "cost": cost, "phase_order": phase_order})
        matrix[direction] = sorted(scores, key=lambda item: item["cost"])

    best: tuple[float, dict[str, int], dict[str, list[int]]] | None = None
    for group_perm in itertools.permutations(range(4), len(directions)):
        assignment = dict(zip(directions, group_perm))
        if len(set(assignment.values())) != len(assignment):
            continue
        total = 0.0
        phases: dict[str, list[int]] = {}
        for direction, group_index in assignment.items():
            candidate = next(item for item in matrix[direction] if item["group"] == group_index)
            total += float(candidate["cost"])
            phases[direction] = list(candidate["phase_order"])
        if best is None or total < best[0]:
            best = (total, assignment, phases)
    if best is None:
        return {"status": "no_assignment"}

    total, assignment, phases = best
    runner_up = math.inf
    for group_perm in itertools.permutations(range(4), len(directions)):
        candidate_assignment = dict(zip(directions, group_perm))
        if candidate_assignment == assignment or len(set(candidate_assignment.values())) != len(candidate_assignment):
            continue
        candidate_total = 0.0
        for direction, group_index in candidate_assignment.items():
            candidate_total += float(next(item for item in matrix[direction] if item["group"] == group_index)["cost"])
        runner_up = min(runner_up, candidate_total)

    return {
        "status": "matched",
        "directions": directions,
        "assignment": assignment,
        "source_phase_order": phases,
        "pattern": pattern_from_assignment(assignment),
        "cost": round(total, 6),
        "confidence_margin": round(runner_up - total, 6) if math.isfinite(runner_up) else None,
        "matrix": matrix,
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--include-existing", action="store_true")
    args = parser.parse_args()
    OUT.mkdir(parents=True, exist_ok=True)

    config = json.loads(CONFIG_PATH.read_text(encoding="utf-8"))
    archive = load_wtw_archive()
    alias_index = topic_alias_index()
    manager_by_name, manager_specs = manager_index()
    urls = sheet_url_index()
    if not manager_specs:
        raise RuntimeError(f"No DigimonWorldSpriteManager specs found under {MANAGER_SPECS}")
    rows: list[dict[str, Any]] = []
    unresolved: list[dict[str, Any]] = []

    targets = missing_database_rows()
    if args.include_existing:
        database = json.loads((ROOT / "database/base-digimon-list.json").read_text(encoding="utf-8"))
        by_name = {str(entry["name"]): entry for entry in database}
        for name in config.get("species", {}):
            if name in by_name:
                targets.append(by_name[name])

    seen: set[str] = set()
    for entry in targets:
        name = str(entry["name"])
        if name in seen:
            continue
        seen.add(name)

        existing = config.get("species", {}).get(name)
        member = str(existing.get("source_member")) if existing and existing.get("source_member") else None
        source_id = int(existing["source_id"]) if existing and existing.get("source_id") is not None else SOURCE_ID_OVERRIDES.get(name)
        if member is None and source_id is None:
            source_id = alias_index.get(compact(name))
        if member is None and source_id is not None:
            try:
                member = archive_member_for_id(archive, source_id)
            except RuntimeError:
                member = None
        if member is None:
            member = resolve_unnumbered_member(archive, name)
        if member is None:
            unresolved.append({"name": name, "reason": "wtw_source_not_resolved"})
            continue

        payload = archive.read(member)
        source = Image.open(io.BytesIO(payload)).convert("RGBA")
        profile_name = str(existing.get("profile")) if existing else ""
        candidates: dict[str, Any] = {}
        if profile_name and profile_name in config.get("profiles", {}):
            try:
                candidates[profile_name] = movement_groups(source, config["profiles"][profile_name])
            except Exception:
                pass
        if not candidates:
            candidates = extract_candidates(source, config)
        if not candidates:
            unresolved.append({"name": name, "source": member, "reason": "no_4x3_profile"})
            continue

        manager_spec, name_score = best_manager_spec(
            [name, source_stem_alias(member)],
            manager_by_name,
            manager_specs,
        )
        if manager_spec is None:
            unresolved.append({"name": name, "source": member, "reason": "manager_name_not_resolved", "name_score": round(name_score, 4)})
            continue
        manager_sheet = load_manager_sheet(manager_spec, urls)
        if manager_sheet is None:
            unresolved.append({"name": name, "source": member, "reason": "manager_sheet_download_failed", "manager": manager_spec.get("creature_name")})
            continue
        refs = manager_walk_frames(manager_spec, manager_sheet)
        best_result: dict[str, Any] | None = None
        best_profile = ""
        for candidate_profile, boxes in candidates.items():
            result = classify(wtw_group_frames(source, boxes), refs)
            if result.get("status") != "matched":
                continue
            if best_result is None or float(result.get("cost", 1e9)) < float(best_result.get("cost", 1e9)):
                best_result = result
                best_profile = candidate_profile
        if best_result is None:
            unresolved.append({
                "name": name,
                "source": member,
                "reason": "semantic_match_failed",
                "manager": manager_spec.get("creature_name"),
                "manager_directions": sorted(refs),
            })
            continue

        rows.append({
            "name": name,
            "rank": str(entry.get("rank", "")),
            "source_id": source_id,
            "source_member": member,
            "source_sha256": sha256(payload),
            "profile": best_profile,
            "suggested_pattern": best_result.get("pattern"),
            "existing_pattern": existing.get("pattern") if existing else None,
            "manager_name": manager_spec.get("creature_name"),
            "manager_spec_id": manager_spec.get("id"),
            "manager_sheet_id": manager_spec.get("sheet_id"),
            "manager_name_score": round(name_score, 4),
            "semantic": best_result,
        })
        print(f"{name}: {best_profile} -> {best_result.get('pattern')} cost={best_result.get('cost')} margin={best_result.get('confidence_margin')}")

    cross = [row for row in rows if row.get("existing_pattern")]
    mismatches = [
        row for row in cross
        if row.get("suggested_pattern") != row.get("existing_pattern")
    ]
    payload = {
        "schema_version": 1,
        "review_only": True,
        "matched": len(rows),
        "unresolved": len(unresolved),
        "existing_crosscheck_count": len(cross),
        "existing_crosscheck_mismatches": len(mismatches),
        "rows": rows,
        "unresolved_rows": unresolved,
        "mismatches": mismatches,
    }
    (OUT / "semantic-audit.json").write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
    (OUT / "semantic-audit-summary.txt").write_text(
        "\n".join([
            f"matched={len(rows)}",
            f"unresolved={len(unresolved)}",
            f"existing_crosscheck_count={len(cross)}",
            f"existing_crosscheck_mismatches={len(mismatches)}",
        ]) + "\n",
        encoding="utf-8",
    )
    print(json.dumps({key: payload[key] for key in ("matched", "unresolved", "existing_crosscheck_count", "existing_crosscheck_mismatches")}, indent=2))


if __name__ == "__main__":
    main()
