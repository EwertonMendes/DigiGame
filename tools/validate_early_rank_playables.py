#!/usr/bin/env python3
"""Validate Fresh, In-Training and Rookie database/portrait/field wiring."""
from __future__ import annotations

import hashlib
import json
import re
import struct
import sys
from pathlib import Path, PurePosixPath

ROOT = Path(__file__).resolve().parents[1]
DATABASE_PATH = ROOT / "database/base-digimon-list.json"
MANIFEST_PATH = ROOT / "database/early-rank-playables.json"
EARLY_RANKS = ("Fresh", "In-Training", "Rookie")
EXPECTED_EARLY_COUNT = 88
EXPECTED_COUNTS = {"Fresh": 3, "In-Training": 24, "Rookie": 61}


def fail(message: str) -> None:
    raise AssertionError(message)


def portrait_key(entry: dict) -> str:
    stem = PurePosixPath(str(entry.get("img", ""))).stem
    return re.sub(r"[^a-z0-9]+", "", stem.lower())


def resource_relpath(name: str) -> str:
    return f"assets/resources/{name.strip().lower()}.tres"


def parse_assignment(text: str, key: str) -> str | None:
    match = re.search(rf'^{re.escape(key)}\s*=\s*(.+)$', text, re.MULTILINE)
    return match.group(1).strip() if match else None


def read_png_ihdr(path: Path) -> tuple[int, int, int]:
    """Return width, height and PNG color type without third-party dependencies."""
    data = path.read_bytes()
    if len(data) < 33 or data[:8] != b"\x89PNG\r\n\x1a\n":
        fail(f"{path.relative_to(ROOT)}: invalid PNG signature/header")
    if data[12:16] != b"IHDR":
        fail(f"{path.relative_to(ROOT)}: PNG does not start with IHDR")
    width, height = struct.unpack(">II", data[16:24])
    color_type = data[25]
    return width, height, color_type


def _validate_portrait_source(name: str, entry: dict, row: dict, char_dir: Path, pmeta: dict) -> None:
    field_source_kind = str(row.get("field_source_kind", ""))
    if field_source_kind == "project_original":
        source_value = str(row.get("portrait_source", ""))
        if not source_value.startswith("res://"):
            fail(f"{name}: project-original portrait source must be a res:// path")
        source_path = ROOT / source_value.removeprefix("res://")
        if not source_path.is_file() or source_path.stat().st_size <= 0:
            fail(f"{name}: missing project-original source sheet {source_path.relative_to(ROOT)}")
        if pmeta.get("source_kind") != "project_original":
            fail(f"{name}: portrait metadata must identify project_original source")
        if pmeta.get("source_sha256") != hashlib.sha256(source_path.read_bytes()).hexdigest():
            fail(f"{name}: project-original portrait source SHA-256 mismatch")
        return

    if field_source_kind == "project_owner_supplied":
        if pmeta.get("source_kind") != "project_owner_supplied":
            fail(f"{name}: portrait metadata must identify project_owner_supplied source")
        if str(row.get("portrait_source", "")) != str(pmeta.get("source_path", "")):
            fail(f"{name}: manifest/project-owner portrait source mismatch")
        source_sha = str(pmeta.get("source_sha256", ""))
        if not re.fullmatch(r"[0-9a-f]{64}", source_sha):
            fail(f"{name}: project-owner portrait must pin the original source SHA-256")
        return

    source_path = char_dir / "source/portrait.webp"
    if not source_path.is_file() or source_path.stat().st_size <= 0:
        fail(f"{name}: missing canonical portrait source {source_path.relative_to(ROOT)}")
    if pmeta.get("source") != PurePosixPath(str(entry.get("img", ""))).name:
        fail(f"{name}: portrait metadata source does not match database WebP")
    if pmeta.get("source_sha256") != hashlib.sha256(source_path.read_bytes()).hexdigest():
        fail(f"{name}: portrait source SHA-256 mismatch")


def main() -> int:
    database = json.loads(DATABASE_PATH.read_text(encoding="utf-8"))
    manifest = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
    early = [entry for entry in database if entry.get("rank") in EARLY_RANKS]
    rows = manifest.get("species", [])
    if (
        len(early) != EXPECTED_EARLY_COUNT
        or int(manifest.get("count", -1)) != EXPECTED_EARLY_COUNT
        or len(rows) != EXPECTED_EARLY_COUNT
    ):
        fail(
            f"Expected exactly {EXPECTED_EARLY_COUNT} early-rank species; "
            f"database={len(early)} manifest={len(rows)}"
        )
    expected_counts = {
        rank: sum(1 for entry in early if entry.get("rank") == rank)
        for rank in EARLY_RANKS
    }
    if expected_counts != EXPECTED_COUNTS:
        fail(f"Unexpected database rank counts: {expected_counts} != {EXPECTED_COUNTS}")
    if manifest.get("counts_by_rank") != expected_counts:
        fail(f"Unexpected manifest rank counts: {manifest.get('counts_by_rank')} != {expected_counts}")

    db = {str(entry["name"]): entry for entry in early}
    mf = {str(row["name"]): row for row in rows}
    if set(db) != set(mf):
        fail(f"Manifest/database species mismatch: missing={sorted(set(db)-set(mf))}, extra={sorted(set(mf)-set(db))}")

    source_counts: dict[str, int] = {}
    for name, entry in sorted(db.items()):
        row = mf[name]
        key = portrait_key(entry)
        if row.get("seed") != entry.get("seed") or row.get("rank") != entry.get("rank"):
            fail(f"{name}: canonical database identity mismatch")
        if row.get("database_image") != entry.get("img") or row.get("portrait_key") != key:
            fail(f"{name}: database image / portrait key mismatch")

        char_dir = ROOT / "assets/characters" / key
        portrait_strip = char_dir / "portrait_frames.png"
        portrait_meta = char_dir / "portrait_frames.json"
        field_path = char_dir / "field.png"
        field_meta_path = char_dir / "field.json"
        for path in (portrait_strip, portrait_meta, field_path, field_meta_path):
            if not path.is_file() or path.stat().st_size <= 0:
                fail(f"{name}: missing asset {path.relative_to(ROOT)}")

        pmeta = json.loads(portrait_meta.read_text(encoding="utf-8"))
        _validate_portrait_source(name, entry, row, char_dir, pmeta)

        frame_count = int(pmeta.get("frame_count", 0))
        if frame_count < 1 or int(row.get("frame_count", -1)) != frame_count:
            fail(f"{name}: portrait frame count mismatch")

        portrait_width, portrait_height, portrait_color_type = read_png_ihdr(portrait_strip)
        frame_width = int(pmeta.get("frame_width", 0))
        frame_height = int(pmeta.get("frame_height", 0))
        if (portrait_width, portrait_height) != (frame_width * frame_count, frame_height):
            fail(f"{name}: portrait strip geometry does not match metadata")
        if portrait_color_type not in {3, 4, 6}:
            fail(f"{name}: portrait strip must preserve transparency-capable pixel art")

        fmeta = json.loads(field_meta_path.read_text(encoding="utf-8"))
        if int(fmeta.get("frame_count", 0)) != 12 or int(fmeta.get("frames_per_direction", 0)) != 3:
            fail(f"{name}: field metadata must describe 4 directions x 3 frames")
        if fmeta.get("directions") != ["down_left", "down_right", "up_left", "up_right"]:
            fail(f"{name}: invalid field direction order")
        source_kind = str(fmeta.get("source_kind", ""))
        if source_kind not in {"official_ds", "community_ds_style_exception", "project_owner_supplied", "project_original"}:
            fail(f"{name}: unsupported field source kind {source_kind!r}")
        if str(row.get("field_source_kind", "")) != source_kind:
            fail(f"{name}: manifest/field source kind mismatch")
        source_counts[source_kind] = source_counts.get(source_kind, 0) + 1

        width, height, color_type = read_png_ihdr(field_path)
        if width <= 0 or height <= 0 or width % 12 != 0:
            fail(f"{name}: field.png must be one horizontal 12-frame strip, got {(width, height)}")
        if color_type not in {3, 4, 6}:
            fail(f"{name}: field.png must preserve transparency-capable pixel art (PNG color type {color_type})")
        if source_kind == "project_owner_supplied":
            actual_sha = hashlib.sha256(field_path.read_bytes()).hexdigest()
            if fmeta.get("normalized_field_sha256") != actual_sha:
                fail(f"{name}: project-owner normalized field SHA-256 mismatch")
            if pmeta.get("source_sha256") != fmeta.get("original_source_sha256"):
                fail(f"{name}: project-owner field and portrait must come from the same source sheet")
            portrait_sha = hashlib.sha256(portrait_strip.read_bytes()).hexdigest()
            if pmeta.get("normalized_portrait_sha256") != portrait_sha:
                fail(f"{name}: project-owner normalized portrait SHA-256 mismatch")
            if (int(fmeta.get("cell_width", 0)), int(fmeta.get("cell_height", 0))) != (width // 12, height):
                fail(f"{name}: project-owner field metadata cell geometry mismatch")
            if float(fmeta.get("runtime_scale", 0.0)) != 1.0:
                fail(f"{name}: normalized project-owner field must render at native scale")
            if name == "Mochimon":
                if (width, height) != (384, 32):
                    fail(f"Mochimon: expected canonical 12x32x32 strip, got {(width, height)}")
                normalization = fmeta.get("normalization", {})
                if normalization.get("target_cell") != [32, 32]:
                    fail(f"Mochimon: normalization target must stay 32x32")
                if normalization.get("max_sprite_bounds") != [18, 16]:
                    fail(f"Mochimon: visible bounds must stay capped at 18x16")
                expected_mirror_policy = {
                    "down_right": "build_time_horizontal_mirror_of_down_left",
                    "up_right": "build_time_horizontal_mirror_of_up_left",
                }
                if fmeta.get("mirror_policy") != expected_mirror_policy:
                    fail(f"Mochimon: reviewed left/right facing policy changed")
                source_boxes = fmeta.get("source_frame_boxes", {})
                if set(source_boxes) != {"down_left", "up_left"}:
                    fail(f"Mochimon: only the reviewed authored left-facing groups may be direct source inputs")
                if (frame_width, frame_height, frame_count) != (192, 192, 3):
                    fail(f"Mochimon: owner portrait must remain a 3-frame 192x192 animation")
                if (portrait_width, portrait_height) != (576, 192):
                    fail(f"Mochimon: owner portrait strip must remain 576x192")
                if pmeta.get("source_frame_boxes") != [
                    [24, 51, 312, 257],
                    [373, 55, 307, 253],
                    [720, 55, 310, 253],
                ]:
                    fail(f"Mochimon: owner portrait must use the reviewed large animation frames")

        resource_path = ROOT / resource_relpath(name)
        if not resource_path.is_file():
            fail(f"{name}: missing runtime resource")
        text = resource_path.read_text(encoding="utf-8")
        if parse_assignment(text, "display_name") != json.dumps(name):
            fail(f"{name}: resource display_name is not canonical")
        if parse_assignment(text, "sprite_layout") != '"directional_12"':
            fail(f"{name}: resource must use directional_12")
        if parse_assignment(text, "sprite_hframes") != "12" or parse_assignment(text, "sprite_vframes") != "1":
            fail(f"{name}: resource must use a 12x1 field strip")
        expected_field = f"res://assets/characters/{key}/field.png"
        if expected_field not in text or row.get("field_sprite") != expected_field:
            fail(f"{name}: resource/manifest is not linked to its field strip")
        if row.get("visual_mode") != "directional_12":
            fail(f"{name}: manifest exposes a non-directional fallback")

    if source_counts.get("official_ds", 0) < 80:
        fail(f"Expected the WtW/DS roster to provide the overwhelming majority of fields, got {source_counts}")
    if source_counts.get("project_owner_supplied", 0) != 1:
        fail(f"Expected exactly one project-owner supplied early-rank field, got {source_counts}")
    if source_counts.get("project_original", 0) != 1:
        fail(f"Expected exactly one project-original early-rank playable, got {source_counts}")

    print(
        f"early-rank playable validation passed: {EXPECTED_EARLY_COUNT} species, "
        f"field sources={source_counts}"
    )
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(f"early-rank playable validation failed: {exc}", file=sys.stderr)
        raise
