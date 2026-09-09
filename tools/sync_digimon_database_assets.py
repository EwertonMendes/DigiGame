#!/usr/bin/env python3
"""Sync the canonical Digimon database and animated portraits used by DigiGame.

The source data/portraits currently live in EwertonMendes/digimon-ng. DigiGame
keeps the original animated WebP plus a deterministic PNG frame strip/metadata
because Godot imports WebP as a Texture2D instead of playing animated WebP
frames directly.
"""
from __future__ import annotations

import hashlib
import io
import json
import shutil
import subprocess
from pathlib import Path

from PIL import Image, ImageSequence

SOURCE_ROOT = "https://raw.githubusercontent.com/EwertonMendes/digimon-ng/master/public"
DATABASE_URL = f"{SOURCE_ROOT}/database/base-digimon-list.json"
EXPECTED_DATABASE_SHA256 = "edefcfa2275267760498b65971038beb4e35227e123e69c8a189a220612e9f15"

CURRENT_DIGIMONS = {
    "agumon": "Agumon.webp",
    "gabumon": "Gabumon.webp",
    "greymon": "Greymon.webp",
    "koromon": "Koromon.webp",
    "tanemon": "Tanemon.webp",
    "veemon": "Veemon.webp",
}


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


def sync_database() -> None:
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

    database_dir = Path("database")
    database_dir.mkdir(parents=True, exist_ok=True)
    (database_dir / "base-digimon-list.json").write_bytes(payload)
    print(f"database: synced {len(parsed)} Digimon ({digest})")


def move_existing_field_sheet(key: str) -> None:
    old_path = Path("assets/characters") / f"{key}.png"
    new_path = Path("assets/characters") / key / "field.png"
    new_path.parent.mkdir(parents=True, exist_ok=True)
    if old_path.exists():
        shutil.move(str(old_path), str(new_path))
        old_import = Path(f"{old_path}.import")
        if old_import.exists():
            old_import.unlink()


def build_portrait_assets(key: str, source_name: str) -> None:
    directory = Path("assets/characters") / key
    directory.mkdir(parents=True, exist_ok=True)

    payload = fetch(f"{SOURCE_ROOT}/assets/digimons/{source_name}")
    webp_path = directory / "portrait.webp"
    webp_path.write_bytes(payload)

    with Image.open(io.BytesIO(payload)) as image:
        frame_count = getattr(image, "n_frames", 1)
        if frame_count <= 1:
            raise RuntimeError(f"{source_name} is not animated (frames={frame_count})")

        frames: list[Image.Image] = []
        durations_ms: list[int] = []
        for frame in ImageSequence.Iterator(image):
            rgba = frame.convert("RGBA")
            frames.append(rgba.copy())
            durations_ms.append(max(20, int(frame.info.get("duration", image.info.get("duration", 100)))))

    width, height = frames[0].size
    if any(frame.size != (width, height) for frame in frames):
        raise RuntimeError(f"{source_name}: animated frames do not share one canvas size")

    strip = Image.new("RGBA", (width * len(frames), height), (0, 0, 0, 0))
    for index, frame in enumerate(frames):
        strip.alpha_composite(frame, (index * width, 0))

    strip_path = directory / "portrait_frames.png"
    strip.save(strip_path, format="PNG", optimize=True)
    metadata = {
        "source": source_name,
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
    print(f"{key}: {len(frames)} animated portrait frames ({width}x{height})")


def main() -> None:
    sync_database()
    for key, source_name in CURRENT_DIGIMONS.items():
        move_existing_field_sheet(key)
        build_portrait_assets(key, source_name)


if __name__ == "__main__":
    main()
