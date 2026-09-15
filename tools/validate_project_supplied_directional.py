#!/usr/bin/env python3
"""Validate project-supplied directional Digimon assets and the generic normalization contract."""
from __future__ import annotations

import hashlib
import json
import re
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
CONFIG = ROOT / "database/project-supplied-sources.json"
MANIFEST = ROOT / "database/project-supplied-playables.json"
DATABASE = ROOT / "database/base-digimon-list.json"
DIRECTIONS = ["down_left", "down_right", "up_left", "up_right"]
PHASES = ["idle", "step_a", "step_b"]


def compact_key(value: str) -> str:
    return re.sub(r"[^a-z0-9]+", "", value.lower())


def local_res(value: str) -> Path:
    if not value.startswith("res://"):
        raise RuntimeError(f"Expected res:// path, got {value!r}")
    return ROOT / value.removeprefix("res://")


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def git_blob_sha(path: Path) -> str:
    payload = path.read_bytes()
    return hashlib.sha1(f"blob {len(payload)}\0".encode("ascii") + payload).hexdigest()


def assignment(text: str, key: str) -> str | None:
    match = re.search(rf'^\s*{re.escape(key)}\s*=\s*(.+)$', text, re.MULTILINE)
    return match.group(1).strip() if match else None


def main() -> None:
    config = json.loads(CONFIG.read_text(encoding="utf-8"))
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    database = json.loads(DATABASE.read_text(encoding="utf-8"))
    if config.get("source_kind") != "project_supplied_directional" or int(config.get("schema_version", 0)) != 1:
        raise RuntimeError("Project-supplied source config schema/source kind is invalid")
    if config.get("canonical_runtime_order") != DIRECTIONS or config.get("canonical_runtime_phases") != PHASES:
        raise RuntimeError("Project-supplied source config runtime contract is not canonical")
    if manifest.get("source_kind") != "project_supplied_directional" or manifest.get("canonical_runtime_order") != DIRECTIONS:
        raise RuntimeError("Project-supplied generated manifest contract is invalid")
    specs = config.get("species", [])
    rows = manifest.get("species", [])
    if not isinstance(specs, list) or not specs or len(rows) != len(specs) or int(manifest.get("count", -1)) != len(specs):
        raise RuntimeError("Project-supplied source/generated manifest counts are invalid")
    row_by_name = {str(row["name"]): row for row in rows}
    db_by_name = {str(row.get("name", "")): row for row in database}

    for spec in specs:
        name = str(spec["name"])
        key = compact_key(name)
        row = row_by_name.get(name)
        if row is None:
            raise RuntimeError(f"{name}: missing generated manifest row")
        db = db_by_name.get(name)
        if db is None or str(db.get("seed")) != str(spec["seed"]):
            raise RuntimeError(f"{name}: canonical database identity mismatch")
        source = local_res(str(spec["source_sheet"]))
        if not source.is_file() or sha256(source) != str(spec["source_sha256"]):
            raise RuntimeError(f"{name}: supplied source is missing or changed")

        field = ROOT / "assets/characters" / key / "field.png"
        field_meta_path = ROOT / "assets/characters" / key / "field.json"
        portrait = ROOT / "assets/characters" / key / "portrait_frames.png"
        portrait_meta_path = ROOT / "assets/characters" / key / "portrait_frames.json"
        resource = ROOT / "assets/resources" / f"{name.lower()}.tres"
        for path in (field, field_meta_path, portrait, portrait_meta_path, resource):
            if not path.is_file() or path.stat().st_size <= 0:
                raise RuntimeError(f"{name}: missing generated asset {path.relative_to(ROOT)}")

        meta = json.loads(field_meta_path.read_text(encoding="utf-8"))
        if meta.get("source_kind") != "project_supplied_directional" or meta.get("source_sha256") != str(spec["source_sha256"]):
            raise RuntimeError(f"{name}: field provenance mismatch")
        if meta.get("canonical_runtime_order") != DIRECTIONS or meta.get("canonical_runtime_phases") != PHASES:
            raise RuntimeError(f"{name}: field contract mismatch")
        if meta.get("runtime_group_indices") != spec["movement"]["direction_group_pattern"]:
            raise RuntimeError(f"{name}: direction normalization mapping drifted")
        if any(meta.get("source_frame_order", {}).get(direction) != spec["movement"]["phase_order"] for direction in DIRECTIONS):
            raise RuntimeError(f"{name}: authored phase order drifted")
        if meta.get("anchor_policy") != "bottom_center_in_uniform_species_cell":
            raise RuntimeError(f"{name}: field anchor policy is not canonical")

        cell_w = int(meta["cell_width"])
        cell_h = int(meta["cell_height"])
        image = Image.open(field).convert("RGBA")
        if image.size != (cell_w * 12, cell_h):
            raise RuntimeError(f"{name}: field strip dimensions are invalid: {image.size}")
        for index in range(12):
            frame = image.crop((index * cell_w, 0, (index + 1) * cell_w, cell_h))
            if frame.getbbox() is None:
                raise RuntimeError(f"{name}: empty runtime frame {index}")
            if frame.getpixel((0, 0))[3] != 0 or frame.getpixel((cell_w - 1, 0))[3] != 0:
                raise RuntimeError(f"{name}: keyed background leaked into runtime frame {index}")

        portrait_cfg = spec.get("portrait", {})
        if not isinstance(portrait_cfg, dict):
            raise RuntimeError(f"{name}: portrait config must be a dictionary")
        portrait_mode = str(portrait_cfg.get("mode", "sheet_frame"))
        pmeta = json.loads(portrait_meta_path.read_text(encoding="utf-8"))
        pimage = Image.open(portrait).convert("RGBA")
        frame_count = int(pmeta.get("frame_count", 0))
        frame_width = int(pmeta.get("frame_width", 0))
        frame_height = int(pmeta.get("frame_height", 0))
        durations = pmeta.get("durations_ms", [])
        if frame_count <= 0 or frame_width <= 0 or frame_height <= 0:
            raise RuntimeError(f"{name}: portrait metadata dimensions/count are invalid")
        if pimage.size != (frame_width * frame_count, frame_height):
            raise RuntimeError(f"{name}: portrait strip/metadata mismatch")
        if not isinstance(durations, list) or len(durations) != frame_count or any(int(value) < 20 for value in durations):
            raise RuntimeError(f"{name}: portrait frame durations are invalid")

        if portrait_mode == "animated_webp":
            portrait_source = local_res(str(portrait_cfg.get("source_webp", "")))
            if not portrait_source.is_file():
                raise RuntimeError(f"{name}: animated WebP portrait source is missing")
            expected_blob_sha = str(portrait_cfg.get("source_git_blob_sha", ""))
            if not expected_blob_sha or git_blob_sha(portrait_source) != expected_blob_sha:
                raise RuntimeError(f"{name}: animated WebP source does not match its pinned Git blob")
            minimum_frames = max(2, int(portrait_cfg.get("minimum_frames", 2)))
            if frame_count < minimum_frames:
                raise RuntimeError(f"{name}: animated portrait collapsed to {frame_count} frame(s)")
            if pmeta.get("source_kind") != "project_supplied_animated_webp":
                raise RuntimeError(f"{name}: animated portrait provenance kind mismatch")
            if pmeta.get("source_path") != str(portrait_cfg.get("source_webp", "")):
                raise RuntimeError(f"{name}: animated portrait source path mismatch")
            if pmeta.get("source_git_blob_sha") != expected_blob_sha or pmeta.get("source_sha256") != sha256(portrait_source):
                raise RuntimeError(f"{name}: animated portrait provenance hash mismatch")
        elif portrait_mode == "sheet_frame":
            if frame_count != 1 or pmeta.get("source_sha256") != str(spec["source_sha256"]):
                raise RuntimeError(f"{name}: sheet portrait provenance mismatch")
        else:
            raise RuntimeError(f"{name}: unsupported portrait mode {portrait_mode}")

        text = resource.read_text(encoding="utf-8")
        required = {
            "display_name": json.dumps(name),
            "sprite_layout": '"directional_12"',
            "sprite_hframes": "12",
            "sprite_vframes": "1",
        }
        for field_name, expected in required.items():
            if assignment(text, field_name) != expected:
                raise RuntimeError(f"{name}: resource {field_name} is not {expected}")
        if "flip_h" in text or "horizontal_facing_inverted" in text:
            raise RuntimeError(f"{name}: resource contains a species-specific facing workaround")
        if row.get("resource") != f"res://assets/resources/{name.lower()}.tres" or row.get("field_cell") != [cell_w, cell_h]:
            raise RuntimeError(f"{name}: generated playable manifest drifted")
        if int(row.get("portrait_frames", 0)) != frame_count or row.get("portrait_source") != pmeta.get("source_path"):
            raise RuntimeError(f"{name}: generated portrait manifest drifted")
        print(f"validated {name}: directional_12 field + {frame_count}-frame {portrait_mode} portrait")

    print(f"project-supplied directional validation passed: {len(specs)} species")


if __name__ == "__main__":
    main()
