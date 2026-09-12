#!/usr/bin/env python3
"""Sync canonical early-rank Digimon visuals and battle resources.

The canonical catalogue and animated WebPs live in EwertonMendes/digimon-ng.
For every Fresh, In-Training (the project's Baby tier), and Rookie entry this
script keeps the original WebP under a Godot-ignored source directory, builds a
deterministic PNG frame strip/metadata for runtime playback, and creates a
battle-compatible Digimon resource when a bespoke field resource does not
already exist.

Existing authored field resources are never overwritten. Missing early-rank
field sheets intentionally fall back to their canonical WebP animation until a
proper directional field sprite is added later.
"""
from __future__ import annotations

import hashlib
import io
import json
import re
import subprocess
from pathlib import Path, PurePosixPath
from typing import Any
from urllib.parse import quote

from PIL import Image, ImageSequence

SOURCE_ROOT = "https://raw.githubusercontent.com/EwertonMendes/digimon-ng/master/public"
DATABASE_URL = f"{SOURCE_ROOT}/database/base-digimon-list.json"
EXPECTED_DATABASE_SHA256 = "edefcfa2275267760498b65971038beb4e35227e123e69c8a189a220612e9f15"
EARLY_RANKS = ("Fresh", "In-Training", "Rookie")
MANIFEST_PATH = Path("database/early-rank-playables.json")
PORTRAIT_FALLBACK_SCALE = 0.32
DEFAULT_FRAME_DURATION_MS = 120


def fetch(url: str) -> bytes:
    result = subprocess.run(
        ["curl", "-fsSL", "--retry", "3", url],
        capture_output=True,
        check=False,
        timeout=90,
    )
    if result.returncode != 0:
        raise RuntimeError(
            f"Failed to fetch {url}: {result.stderr.decode('utf-8', 'replace').strip()}"
        )
    return result.stdout


def load_database_payload() -> tuple[bytes, list[dict[str, Any]]]:
    payload = fetch(DATABASE_URL)
    digest = hashlib.sha256(payload).hexdigest()
    if digest != EXPECTED_DATABASE_SHA256:
        raise RuntimeError(
            "Canonical database differs from the JSON supplied for this feature: "
            f"expected {EXPECTED_DATABASE_SHA256}, got {digest}"
        )

    parsed = json.loads(payload.decode("utf-8"))
    if not isinstance(parsed, list) or len(parsed) != 408:
        raise RuntimeError(f"Unexpected Digimon database shape/count: {len(parsed)}")
    return payload, parsed


def sync_database(payload: bytes) -> None:
    database_dir = Path("database")
    database_dir.mkdir(parents=True, exist_ok=True)
    (database_dir / "base-digimon-list.json").write_bytes(payload)
    print(
        "database: synced canonical catalogue "
        f"({hashlib.sha256(payload).hexdigest()})"
    )


def early_rank_entries(database: list[dict[str, Any]]) -> list[dict[str, Any]]:
    entries = [entry for entry in database if str(entry.get("rank", "")) in EARLY_RANKS]
    entries.sort(key=lambda entry: (EARLY_RANKS.index(str(entry.get("rank"))), str(entry.get("name", ""))))
    if not entries:
        raise RuntimeError("Canonical catalogue contains no early-rank Digimon")
    return entries


def portrait_key(entry: dict[str, Any]) -> str:
    img = str(entry.get("img", "")).strip()
    stem = PurePosixPath(img).stem if img else str(entry.get("name", ""))
    key = re.sub(r"[^a-z0-9]+", "", stem.lower())
    if not key:
        raise RuntimeError(f"Could not derive portrait key for {entry.get('name')!r}")
    return key


def source_filename(entry: dict[str, Any]) -> str:
    img = str(entry.get("img", "")).strip()
    filename = PurePosixPath(img).name
    if not filename.lower().endswith(".webp"):
        raise RuntimeError(f"{entry.get('name')}: expected WebP database image, got {img!r}")
    return filename


def resource_filename(entry: dict[str, Any]) -> str:
    name = str(entry.get("name", "")).strip().lower()
    if not name or "/" in name or "\\" in name:
        raise RuntimeError(f"Unsafe Digimon resource filename: {name!r}")
    return f"{name}.tres"


def build_portrait_assets(entry: dict[str, Any]) -> dict[str, Any]:
    key = portrait_key(entry)
    source_name = source_filename(entry)
    directory = Path("assets/characters") / key
    source_directory = directory / "source"
    source_directory.mkdir(parents=True, exist_ok=True)
    (source_directory / ".gdignore").write_text(
        "# Preserve source assets without importing them in Godot.\n",
        encoding="utf-8",
    )

    encoded_source_name = quote(source_name, safe="")
    payload = fetch(f"{SOURCE_ROOT}/assets/digimons/{encoded_source_name}")
    source_webp_path = source_directory / "portrait.webp"
    source_webp_path.write_bytes(payload)

    with Image.open(io.BytesIO(payload)) as image:
        frame_count = max(1, int(getattr(image, "n_frames", 1)))
        frames: list[Image.Image] = []
        durations_ms: list[int] = []
        for frame in ImageSequence.Iterator(image):
            rgba = frame.convert("RGBA")
            frames.append(rgba.copy())
            durations_ms.append(
                max(
                    20,
                    int(frame.info.get("duration", image.info.get("duration", DEFAULT_FRAME_DURATION_MS))),
                )
            )
        if not frames:
            frames.append(image.convert("RGBA").copy())
            durations_ms.append(DEFAULT_FRAME_DURATION_MS)
        if len(frames) != frame_count:
            frame_count = len(frames)

    width, height = frames[0].size
    if width <= 0 or height <= 0:
        raise RuntimeError(f"{source_name}: invalid frame size {width}x{height}")
    if any(frame.size != (width, height) for frame in frames):
        raise RuntimeError(f"{source_name}: animated frames do not share one canvas size")

    strip = Image.new("RGBA", (width * len(frames), height), (0, 0, 0, 0))
    for index, frame in enumerate(frames):
        strip.alpha_composite(frame, (index * width, 0))

    strip_path = directory / "portrait_frames.png"
    strip.save(strip_path, format="PNG", optimize=True)
    metadata = {
        "source": source_name,
        "source_path": "source/portrait.webp",
        "frame_width": width,
        "frame_height": height,
        "frame_count": len(frames),
        "durations_ms": durations_ms,
        "source_sha256": hashlib.sha256(payload).hexdigest(),
    }
    (directory / "portrait_frames.json").write_text(
        json.dumps(metadata, indent=2) + "\n",
        encoding="utf-8",
    )
    print(
        f"{entry.get('name')}: {len(frames)} portrait frame(s) "
        f"({width}x{height}) from {source_name}"
    )
    return metadata


def existing_resource_visual_mode(resource_path: Path) -> str:
    text = resource_path.read_text(encoding="utf-8")
    match = re.search(r'^sprite_layout\s*=\s*"([^"]+)"', text, re.MULTILINE)
    return match.group(1) if match else "directional_12"


def create_visual_resource(entry: dict[str, Any], metadata: dict[str, Any]) -> tuple[Path, str]:
    resource_path = Path("assets/resources") / resource_filename(entry)
    resource_path.parent.mkdir(parents=True, exist_ok=True)
    if resource_path.exists():
        return resource_path, existing_resource_visual_mode(resource_path)

    key = portrait_key(entry)
    frame_count = max(1, int(metadata["frame_count"]))
    durations = [max(20, int(value)) for value in metadata.get("durations_ms", [])]
    avg_duration_ms = round(sum(durations) / len(durations)) if durations else DEFAULT_FRAME_DURATION_MS
    resource_text = f'''[gd_resource type="Resource" script_class="Digimon" load_steps=3 format=3]\n\n[ext_resource type="Script" path="res://src/resources/Digimon.gd" id="1_script"]\n[ext_resource type="Texture2D" path="res://assets/characters/{key}/portrait_frames.png" id="2_texture"]\n\n[resource]\nscript = ExtResource("1_script")\ntexture = ExtResource("2_texture")\ninitial_frame = 0\ninitial_facing = "down_right"\nsprite_hframes = {frame_count}\nsprite_vframes = 1\nsprite_layout = "portrait_strip"\nsprite_scale = Vector2({PORTRAIT_FALLBACK_SCALE:.2f}, {PORTRAIT_FALLBACK_SCALE:.2f})\nsprite_frame_duration = {avg_duration_ms / 1000.0:.3f}\nsprite_deviation = Vector2(0, 20)\nparticle_deviation = Vector2(0, 10)\ninitial_position = Vector2i(0, 0)\ntype = {json.dumps(str(entry.get("attribute", "Free")))}\ndisplay_name = {json.dumps(str(entry.get("name", "")))}\nlevel = 1\nhp = {max(1, int(entry.get("hp", 1)))}\nmp = {max(0, int(entry.get("sp", entry.get("mp", 0))))}\nattack = {max(1, int(entry.get("atk", entry.get("attack", 1))))}\ndefense = {max(1, int(entry.get("def", entry.get("defense", 1))))}\nage = 1\nbattles = 0\nvictories = 0\ndefeats = 0\n'''
    resource_path.write_text(resource_text, encoding="utf-8")
    return resource_path, "portrait_strip"


def write_manifest(entries: list[dict[str, Any]], manifest_rows: list[dict[str, Any]]) -> None:
    counts = {rank: 0 for rank in EARLY_RANKS}
    for entry in entries:
        counts[str(entry.get("rank"))] += 1
    payload = {
        "ranks": list(EARLY_RANKS),
        "count": len(entries),
        "counts_by_rank": counts,
        "species": manifest_rows,
    }
    MANIFEST_PATH.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
    print(f"manifest: {len(entries)} early-rank playable Digimon -> {MANIFEST_PATH}")


def main() -> None:
    payload, database = load_database_payload()
    sync_database(payload)
    entries = early_rank_entries(database)
    manifest_rows: list[dict[str, Any]] = []

    for entry in entries:
        metadata = build_portrait_assets(entry)
        resource_path, visual_mode = create_visual_resource(entry, metadata)
        manifest_rows.append(
            {
                "name": str(entry.get("name", "")),
                "seed": str(entry.get("seed", "")),
                "rank": str(entry.get("rank", "")),
                "attribute": str(entry.get("attribute", "")),
                "database_image": str(entry.get("img", "")),
                "portrait_key": portrait_key(entry),
                "portrait_source": f"res://assets/characters/{portrait_key(entry)}/source/portrait.webp",
                "portrait_strip": f"res://assets/characters/{portrait_key(entry)}/portrait_frames.png",
                "resource": f"res://{resource_path.as_posix()}",
                "visual_mode": visual_mode,
                "frame_count": int(metadata["frame_count"]),
            }
        )

    write_manifest(entries, manifest_rows)


if __name__ == "__main__":
    main()
