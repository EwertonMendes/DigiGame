#!/usr/bin/env python3
"""Normalize risky early-rank DS facings from reviewed SpriteManager specs.

The WtW archive contains both explicit four-facing sheets and sheets whose right
facings are mirrors of left-facing artwork. The base roster builder handles the
former directly; this pass replaces every risky/non-explicit layout for which a
reviewed DigimonWorldSpriteManager spec can resolve all four diagonals.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Any

from PIL import Image

DIRECTION_ORDER = ("down_left", "down_right", "up_left", "up_right")
FRAMES_PER_DIRECTION = 3
EARLY_RANKS = ("Fresh", "In-Training", "Rookie")
NAME_ALIASES: dict[str, tuple[str, ...]] = {
    "Aruraumon": ("Aruraumon", "Alraumon"),
    "Biyomon": ("Biyomon", "Piyomon"),
    "Crabmon": ("Crabmon", "Ganimon"),
    "DemiDevimon": ("DemiDevimon", "PicoDevimon"),
    "DoKunemon": ("DoKunemon", "Dokunemon"),
    "Goburimon": ("Goburimon", "Goblimon"),
    "Lalamon": ("Lalamon", "Raramon"),
    "Mushroomon": ("Mushroomon", "Mushmon"),
    "PawnChessmon (Black)": ("PawnChessmonBlack", "PawnChessmon (Black)"),
    "PawnChessmon (White)": ("PawnChessmonWhite", "PawnChessmon (White)"),
    "Penguinmon": ("Penguinmon", "Penmon"),
    "Salamon": ("Salamon", "Plotmon"),
    "SnowAgumon": ("SnowAgumon", "YukiAgumon"),
    "SnowGoburimon": ("SnowGoburimon", "SnowGoblimon"),
    "Syakomon": ("Syakomon", "Shakomon"),
    "Tapirmon": ("Tapirmon", "Bakumon"),
    "ToyAgumon (Black)": ("ShadowToyAgumon", "ToyAgumonBlack", "ToyAgumon (Black)"),
    "Veemon": ("Veemon", "Vmon", "V-mon"),
}


def normalize(value: str) -> str:
    return re.sub(r"[^a-z0-9]+", "", value.lower())


def portrait_key(entry: dict[str, Any]) -> str:
    image_path = str(entry.get("img", ""))
    stem = Path(image_path).stem if image_path else str(entry.get("name", ""))
    return normalize(stem)


def _direct_walk(spec: dict[str, Any], direction: str) -> list[str]:
    walk = spec.get("clips", {}).get("walk", {})
    frames = walk.get(direction, [])
    return list(frames) if isinstance(frames, list) else []


def _resolved_source_direction(spec: dict[str, Any], direction: str) -> str | None:
    if _direct_walk(spec, direction):
        return direction
    source = spec.get("mirror", {}).get(direction)
    if isinstance(source, str) and _direct_walk(spec, source):
        return source
    return None


def _is_complete_diagonal_spec(spec: dict[str, Any]) -> bool:
    if not bool(spec.get("diagonals", False)):
        return False
    return all(_resolved_source_direction(spec, direction) is not None for direction in DIRECTION_ORDER)


def _load_specs(manager_root: Path) -> dict[str, list[tuple[Path, dict[str, Any]]]]:
    grouped: dict[str, list[tuple[Path, dict[str, Any]]]] = {}
    for path in sorted((manager_root / "specs/digimon").glob("*.extract.json")):
        spec = json.loads(path.read_text(encoding="utf-8"))
        name = str(spec.get("creature_name", "")).strip()
        if not name or not _is_complete_diagonal_spec(spec):
            continue
        grouped.setdefault(normalize(name), []).append((path, spec))
    return grouped


def _resolve_spec(name: str, grouped: dict[str, list[tuple[Path, dict[str, Any]]]]) -> tuple[Path, dict[str, Any]] | None:
    candidates: list[tuple[Path, dict[str, Any]]] = []
    for alias in NAME_ALIASES.get(name, (name,)):
        candidates.extend(grouped.get(normalize(alias), []))
    if not candidates:
        return None
    # Prefer a spec with more authored facings over one that relies on mirrors.
    candidates.sort(key=lambda item: (-sum(bool(_direct_walk(item[1], d)) for d in DIRECTION_ORDER), item[0].name))
    return candidates[0]


def _ensure_three(cells: list[dict[str, int]]) -> list[dict[str, int]]:
    if not cells:
        raise RuntimeError("directional walk clip is empty")
    chosen = list(cells[:FRAMES_PER_DIRECTION])
    while len(chosen) < FRAMES_PER_DIRECTION:
        chosen.append(chosen[-1])
    return chosen


def _build_from_manager(manager_root: Path, spec_path: Path, spec: dict[str, Any], temp_out: Path) -> tuple[Image.Image, dict[str, Any]]:
    sys.path.insert(0, str(manager_root))
    sys.path.insert(0, str(manager_root / "src"))
    from core import baker  # type: ignore

    temp_out.mkdir(parents=True, exist_ok=True)
    result = baker.bake(str(spec_path), out_dir=str(temp_out), log=lambda *_: None)
    baked = Image.open(result["png"]).convert("RGBA")
    layout = json.loads(Path(result["layout"]).read_text(encoding="utf-8"))
    cols = int(layout["cols"])
    rows = int(layout["rows"])
    if cols <= 0 or rows <= 0 or baked.width % cols or baked.height % rows:
        raise RuntimeError(f"invalid baked grid {baked.size}, cols={cols}, rows={rows}")
    cell_w = baked.width // cols
    cell_h = baked.height // rows
    frames: list[Image.Image] = []
    for direction in DIRECTION_ORDER:
        cells = _ensure_three(list(layout.get("walk", {}).get(direction, [])))
        for cell in cells:
            col = int(cell["col"])
            row = int(cell["row"])
            frames.append(baked.crop((col * cell_w, row * cell_h, (col + 1) * cell_w, (row + 1) * cell_h)))
    if len(frames) != 12:
        raise RuntimeError(f"expected 12 normalized frames, got {len(frames)}")
    strip = Image.new("RGBA", (cell_w * 12, cell_h), (0, 0, 0, 0))
    for index, frame in enumerate(frames):
        strip.alpha_composite(frame, (index * cell_w, 0))
    metadata = {
        "source_kind": "official_ds",
        "source_variant": "digimon_world_sprite_manager",
        "direction_source": "reviewed_walk_and_mirror_spec",
        "source_name": str(spec.get("creature_name", "")),
        "manager_spec": spec_path.name,
        "manager_sheet_id": str(spec.get("sheet_id", "")),
        "cell_width": cell_w,
        "cell_height": cell_h,
        "frame_count": 12,
        "frames_per_direction": 3,
        "directions": list(DIRECTION_ORDER),
        "runtime_scale": 0.5,
    }
    return strip, metadata


def _patch_resource_scale(resource_path: Path, scale: float) -> None:
    text = resource_path.read_text(encoding="utf-8")
    replacement = f"sprite_scale = Vector2({scale:.4f}, {scale:.4f})"
    if re.search(r"^sprite_scale\s*=", text, re.MULTILINE):
        text = re.sub(r"^sprite_scale\s*=.*$", replacement, text, count=1, flags=re.MULTILINE)
    else:
        marker = 'sprite_layout = "directional_12"\n'
        if marker not in text:
            raise RuntimeError(f"{resource_path}: directional_12 marker not found")
        text = text.replace(marker, marker + replacement + "\n", 1)
    resource_path.write_text(text, encoding="utf-8")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--manager", required=True, type=Path)
    parser.add_argument("--database", default=Path("database/base-digimon-list.json"), type=Path)
    parser.add_argument("--tmp", default=Path("/tmp/digigame-direction-audit"), type=Path)
    parser.add_argument("--report", default=Path("database/ds-facing-audit.json"), type=Path)
    args = parser.parse_args()

    database = json.loads(args.database.read_text(encoding="utf-8"))
    entries = [entry for entry in database if str(entry.get("rank", "")) in EARLY_RANKS]
    grouped = _load_specs(args.manager)
    corrected: list[dict[str, str]] = []
    trusted_explicit: list[str] = []
    community: list[str] = []
    unresolved: list[str] = []

    for entry in entries:
        name = str(entry["name"])
        key = portrait_key(entry)
        directory = Path("assets/characters") / key
        metadata_path = directory / "field.json"
        metadata = json.loads(metadata_path.read_text(encoding="utf-8"))
        if metadata.get("source_kind") == "community_ds_style_exception":
            community.append(name)
            continue

        resolved = _resolve_spec(name, grouped)
        if resolved is None:
            # Two explicit rows of six are already four authored WtW facings.
            # Everything else must be backed by reviewed directional metadata.
            if metadata.get("extraction_layout") == "two_rows_of_six":
                trusted_explicit.append(name)
            else:
                unresolved.append(name)
            continue

        spec_path, spec = resolved
        try:
            strip, new_meta = _build_from_manager(args.manager, spec_path, spec, args.tmp / key)
        except Exception as exc:
            unresolved.append(f"{name} ({exc})")
            continue
        strip.save(directory / "field.png", "PNG", optimize=True)
        new_meta["field_path"] = f"res://assets/characters/{key}/field.png"
        metadata_path.write_text(json.dumps(new_meta, indent=2) + "\n", encoding="utf-8")
        resource_path = Path("assets/resources") / f"{name.strip().lower()}.tres"
        _patch_resource_scale(resource_path, float(new_meta["runtime_scale"]))
        corrected.append({"name": name, "manager_spec": spec_path.name})
        print(f"normalized facing: {name} <- {spec_path.name}")

    report = {
        "direction_order": list(DIRECTION_ORDER),
        "corrected_from_reviewed_specs": corrected,
        "trusted_explicit_wtw_four_facing": trusted_explicit,
        "community_synthetic_four_facing": community,
        "already_reviewed_outside_early_rank": ["Greymon", "Metal Greymon"],
        "unresolved": unresolved,
    }
    args.report.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(f"facing audit: corrected={len(corrected)} explicit={len(trusted_explicit)} community={len(community)} unresolved={len(unresolved)}")
    if unresolved:
        raise RuntimeError("Unresolved risky DS facings: " + ", ".join(unresolved))
    if not corrected:
        raise RuntimeError("Facing audit corrected no reviewed directional sprites")


if __name__ == "__main__":
    main()
