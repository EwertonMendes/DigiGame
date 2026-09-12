#!/usr/bin/env python3
"""Validate Fresh, In-Training and Rookie database/portrait/DS-field wiring."""
from __future__ import annotations

import hashlib
import json
import re
import sys
from pathlib import Path, PurePosixPath
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
DATABASE_PATH = ROOT / "database/base-digimon-list.json"
MANIFEST_PATH = ROOT / "database/early-rank-playables.json"
EARLY_RANKS = ("Fresh", "In-Training", "Rookie")


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


def main() -> int:
    database = json.loads(DATABASE_PATH.read_text(encoding="utf-8"))
    manifest = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
    early = [entry for entry in database if entry.get("rank") in EARLY_RANKS]
    rows = manifest.get("species", [])
    if len(early) != 87 or int(manifest.get("count", -1)) != 87 or len(rows) != 87:
        fail(f"Expected exactly 87 early-rank species; database={len(early)} manifest={len(rows)}")
    expected_counts = {rank: sum(1 for entry in early if entry.get("rank") == rank) for rank in EARLY_RANKS}
    if manifest.get("counts_by_rank") != expected_counts:
        fail(f"Unexpected rank counts: {manifest.get('counts_by_rank')} != {expected_counts}")

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
            fail(f"{name}: canonical WebP mapping mismatch")

        char_dir = ROOT / "assets/characters" / key
        source_path = char_dir / "source/portrait.webp"
        portrait_strip = char_dir / "portrait_frames.png"
        portrait_meta = char_dir / "portrait_frames.json"
        field_path = char_dir / "field.png"
        field_meta_path = char_dir / "field.json"
        for path in (source_path, portrait_strip, portrait_meta, field_path, field_meta_path):
            if not path.is_file() or path.stat().st_size <= 0:
                fail(f"{name}: missing asset {path.relative_to(ROOT)}")

        pmeta = json.loads(portrait_meta.read_text(encoding="utf-8"))
        if pmeta.get("source") != PurePosixPath(str(entry.get("img", ""))).name:
            fail(f"{name}: portrait metadata source does not match database WebP")
        if pmeta.get("source_sha256") != hashlib.sha256(source_path.read_bytes()).hexdigest():
            fail(f"{name}: portrait source SHA-256 mismatch")

        fmeta = json.loads(field_meta_path.read_text(encoding="utf-8"))
        if int(fmeta.get("frame_count", 0)) != 12 or int(fmeta.get("frames_per_direction", 0)) != 3:
            fail(f"{name}: field metadata must describe 4 directions x 3 frames")
        if fmeta.get("directions") != ["down_left", "down_right", "up_left", "up_right"]:
            fail(f"{name}: invalid field direction order")
        source_kind = str(fmeta.get("source_kind", ""))
        if source_kind not in {"official_ds", "community_ds_style_exception"}:
            fail(f"{name}: unsupported field source kind {source_kind!r}")
        source_counts[source_kind] = source_counts.get(source_kind, 0) + 1
        with Image.open(field_path) as image:
            if image.width <= 0 or image.height <= 0 or image.width % 12 != 0:
                fail(f"{name}: field.png must be one horizontal 12-frame strip, got {image.size}")
            if image.mode not in {"RGBA", "LA", "P"}:
                fail(f"{name}: field.png must preserve transparency-capable pixel art")

        resource_path = ROOT / resource_relpath(name)
        if not resource_path.is_file():
            fail(f"{name}: missing runtime resource")
        text = resource_path.read_text(encoding="utf-8")
        if parse_assignment(text, "display_name") != json.dumps(name):
            fail(f"{name}: resource display_name is not canonical")
        if parse_assignment(text, "sprite_layout") != '"directional_12"':
            fail(f"{name}: resource must use directional_12; WebP portrait fallback is forbidden")
        if parse_assignment(text, "sprite_hframes") != "12" or parse_assignment(text, "sprite_vframes") != "1":
            fail(f"{name}: resource must use a 12x1 field strip")
        expected_field = f"res://assets/characters/{key}/field.png"
        if expected_field not in text or row.get("field_sprite") != expected_field:
            fail(f"{name}: resource/manifest is not linked to its DS field strip")
        if row.get("visual_mode") != "directional_12":
            fail(f"{name}: manifest still exposes a non-directional fallback")

    if source_counts.get("official_ds", 0) < 80:
        fail(f"Expected the WtW/DS roster to provide the overwhelming majority of fields, got {source_counts}")
    print(f"early-rank playable validation passed: 87 species, DS field sources={source_counts}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(f"early-rank playable validation failed: {exc}", file=sys.stderr)
        raise
