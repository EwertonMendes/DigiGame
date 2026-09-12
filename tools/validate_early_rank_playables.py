#!/usr/bin/env python3
"""Validate Fresh, In-Training, and Rookie playable visual wiring."""
from __future__ import annotations

import hashlib
import json
import re
import sys
from pathlib import Path, PurePosixPath

ROOT = Path(__file__).resolve().parents[1]
DATABASE_PATH = ROOT / "database/base-digimon-list.json"
MANIFEST_PATH = ROOT / "database/early-rank-playables.json"
EARLY_RANKS = ("Fresh", "In-Training", "Rookie")
ALLOWED_LAYOUTS = {"directional_12", "spaced_9_32", "portrait_strip"}


def fail(message: str) -> None:
    raise AssertionError(message)


def portrait_key(entry: dict) -> str:
    stem = PurePosixPath(str(entry.get("img", ""))).stem
    return re.sub(r"[^a-z0-9]+", "", stem.lower())


def resource_relpath(name: str) -> str:
    lowered = name.strip().lower()
    if not lowered or "/" in lowered or "\\" in lowered:
        fail(f"Unsafe canonical species name for resource path: {name!r}")
    return f"assets/resources/{lowered}.tres"


def parse_assignment(text: str, key: str) -> str | None:
    match = re.search(rf'^{re.escape(key)}\s*=\s*(.+)$', text, re.MULTILINE)
    return match.group(1).strip() if match else None


def main() -> int:
    database = json.loads(DATABASE_PATH.read_text(encoding="utf-8"))
    manifest = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
    early = [entry for entry in database if entry.get("rank") in EARLY_RANKS]
    manifest_rows = manifest.get("species", [])

    if manifest.get("ranks") != list(EARLY_RANKS):
        fail(f"Unexpected manifest ranks: {manifest.get('ranks')!r}")
    if int(manifest.get("count", -1)) != len(early):
        fail(f"Manifest count {manifest.get('count')} != database early-rank count {len(early)}")
    if len(manifest_rows) != len(early):
        fail(f"Manifest species rows {len(manifest_rows)} != database early-rank count {len(early)}")

    expected_counts = {rank: sum(1 for entry in early if entry.get("rank") == rank) for rank in EARLY_RANKS}
    if manifest.get("counts_by_rank") != expected_counts:
        fail(f"Manifest rank counts {manifest.get('counts_by_rank')} != {expected_counts}")

    database_by_name = {str(entry.get("name", "")): entry for entry in early}
    manifest_by_name = {str(row.get("name", "")): row for row in manifest_rows}
    if set(database_by_name) != set(manifest_by_name):
        missing = sorted(set(database_by_name) - set(manifest_by_name))
        extra = sorted(set(manifest_by_name) - set(database_by_name))
        fail(f"Manifest/database species mismatch; missing={missing}, extra={extra}")

    portrait_fallback_count = 0
    bespoke_count = 0
    for name, entry in sorted(database_by_name.items()):
        row = manifest_by_name[name]
        key = portrait_key(entry)
        if not key:
            fail(f"{name}: empty portrait key")
        if row.get("rank") != entry.get("rank") or row.get("seed") != entry.get("seed"):
            fail(f"{name}: manifest identity does not match database")
        if row.get("database_image") != entry.get("img"):
            fail(f"{name}: manifest WebP path does not match database img")
        if row.get("portrait_key") != key:
            fail(f"{name}: manifest portrait key {row.get('portrait_key')!r} != {key!r}")

        character_dir = ROOT / "assets/characters" / key
        source_path = character_dir / "source/portrait.webp"
        strip_path = character_dir / "portrait_frames.png"
        metadata_path = character_dir / "portrait_frames.json"
        for path in (source_path, strip_path, metadata_path):
            if not path.is_file() or path.stat().st_size <= 0:
                fail(f"{name}: missing generated portrait asset {path.relative_to(ROOT)}")

        metadata = json.loads(metadata_path.read_text(encoding="utf-8"))
        expected_source_name = PurePosixPath(str(entry.get("img", ""))).name
        if metadata.get("source") != expected_source_name:
            fail(f"{name}: portrait source {metadata.get('source')!r} != {expected_source_name!r}")
        source_sha = hashlib.sha256(source_path.read_bytes()).hexdigest()
        if metadata.get("source_sha256") != source_sha:
            fail(f"{name}: source WebP SHA-256 mismatch")
        frame_count = int(metadata.get("frame_count", 0))
        if frame_count <= 0:
            fail(f"{name}: portrait frame_count must be positive")
        durations = metadata.get("durations_ms", [])
        if not isinstance(durations, list) or len(durations) != frame_count:
            fail(f"{name}: portrait durations must match frame_count")
        if int(metadata.get("frame_width", 0)) <= 0 or int(metadata.get("frame_height", 0)) <= 0:
            fail(f"{name}: invalid portrait frame dimensions")

        resource_path = ROOT / resource_relpath(name)
        if not resource_path.is_file():
            fail(f"{name}: missing battle resource {resource_path.relative_to(ROOT)}")
        expected_manifest_resource = f"res://{resource_path.relative_to(ROOT).as_posix()}"
        if row.get("resource") != expected_manifest_resource:
            fail(f"{name}: manifest resource path is wrong")

        resource_text = resource_path.read_text(encoding="utf-8")
        if parse_assignment(resource_text, "display_name") != json.dumps(name):
            fail(f"{name}: resource display_name is not canonical")
        raw_layout = parse_assignment(resource_text, "sprite_layout")
        layout = raw_layout.strip('"') if raw_layout else "directional_12"
        if layout not in ALLOWED_LAYOUTS:
            fail(f"{name}: unsupported sprite layout {layout!r}")
        if row.get("visual_mode") != layout:
            fail(f"{name}: manifest visual_mode {row.get('visual_mode')!r} != resource layout {layout!r}")

        if layout == "portrait_strip":
            portrait_fallback_count += 1
            expected_texture = f"res://assets/characters/{key}/portrait_frames.png"
            if expected_texture not in resource_text:
                fail(f"{name}: portrait-strip resource is not linked to its generated WebP strip")
            hframes = parse_assignment(resource_text, "sprite_hframes")
            if hframes is None or int(hframes) != frame_count:
                fail(f"{name}: portrait-strip hframes must equal frame_count {frame_count}")
            if parse_assignment(resource_text, "sprite_scale") is None:
                fail(f"{name}: portrait-strip fallback must define a battle scale")
        else:
            bespoke_count += 1

    print(
        "early-rank playable validation passed: "
        f"{len(early)} species ({expected_counts}), "
        f"{bespoke_count} bespoke field resources, {portrait_fallback_count} WebP fallbacks"
    )
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:  # keep CI output concise and actionable
        print(f"early-rank playable validation failed: {exc}", file=sys.stderr)
        raise
