#!/usr/bin/env python3
"""Fetch and prepare explicitly requested legacy Digimon prototype sprites.

The original game sprites are copyrighted Bandai/Namco assets. They are not
claimed to be open-source or redistributable under a free license. This script
exists because DigiGame currently uses legacy Digimon World DS prototype art
and the project owner explicitly requested Gabumon from that same game/style.
"""

from __future__ import annotations

import hashlib
import io
import re
import subprocess
from pathlib import Path

from PIL import Image

GALLERY_URL = "https://www.spriters-resource.com/ds_dsi/dgmnworldds/"
BASE_URL = "https://www.spriters-resource.com"
USER_AGENT = (
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
    "(KHTML, like Gecko) Chrome/120.0 Safari/537.36"
)
GABUMON_SHEET_ID = "41249"
GABUMON_EXPECTED_SIZE = (412, 203)
GABUMON_EXPECTED_SOURCE_SHA256 = ""
OUTPUT_PATH = Path("assets/characters/gabumon.png")
BACKGROUND = (0, 128, 128)
BACKGROUND_TOLERANCE = 40

# Cell mapping is taken from DigimonWorldSpriteManager's pinned Gabumon
# extraction spec (021.extract.json). The output stays compatible with the
# existing shared Player Sprite2D, which expects exactly nine horizontal frames.
FRAME_BOXES = (
    (310, 140, 32, 32),  # idle
    (344, 140, 32, 32),  # idle alternate (reserved)
    (378, 140, 32, 32),  # idle alternate (reserved)
    (310, 70, 32, 32),   # up-left walk 1
    (344, 70, 32, 32),   # up-left walk 2
    (378, 70, 32, 32),   # up-left walk 3
    (310, 2, 32, 32),    # down-left walk 1
    (344, 2, 32, 32),    # down-left walk 2
    (378, 2, 32, 32),    # down-left walk 3
)


def _curl(url: str) -> bytes:
    result = subprocess.run(
        ["curl", "-sS", "-L", "-A", USER_AGENT, "--fail", url],
        capture_output=True,
        timeout=60,
        check=False,
    )
    if result.returncode != 0:
        raise RuntimeError(
            f"Failed to fetch {url}: {result.stderr.decode('utf-8', 'replace').strip()}"
        )
    return result.stdout


def _discover_sheet_url() -> str:
    gallery = _curl(GALLERY_URL).decode("utf-8", "replace")
    match = re.search(rf"asset_icons/(\d+)/{GABUMON_SHEET_ID}\.png", gallery)
    if match is None:
        raise RuntimeError("Could not locate Gabumon's asset bucket in the DWDS gallery")
    return f"{BASE_URL}/media/assets/{match.group(1)}/{GABUMON_SHEET_ID}.png"


def _is_background(pixel: tuple[int, int, int, int]) -> bool:
    r, g, b, _a = pixel
    return max(
        abs(r - BACKGROUND[0]),
        abs(g - BACKGROUND[1]),
        abs(b - BACKGROUND[2]),
    ) <= BACKGROUND_TOLERANCE


def _make_transparent(frame: Image.Image) -> Image.Image:
    rgba = frame.convert("RGBA")
    pixels = list(rgba.getdata())
    cleaned = [
        (r, g, b, 0) if _is_background((r, g, b, a)) else (r, g, b, a)
        for r, g, b, a in pixels
    ]
    rgba.putdata(cleaned)
    return rgba


def main() -> None:
    sheet_url = _discover_sheet_url()
    source = _curl(sheet_url)
    source_sha = hashlib.sha256(source).hexdigest()
    print(f"Gabumon source: {sheet_url}")
    print(f"Gabumon source SHA-256: {source_sha}")

    if GABUMON_EXPECTED_SOURCE_SHA256 and source_sha != GABUMON_EXPECTED_SOURCE_SHA256:
        raise RuntimeError(
            "Gabumon source integrity check failed: "
            f"expected {GABUMON_EXPECTED_SOURCE_SHA256}, got {source_sha}"
        )

    sheet = Image.open(io.BytesIO(source)).convert("RGBA")
    if sheet.size != GABUMON_EXPECTED_SIZE:
        raise RuntimeError(
            f"Unexpected Gabumon sheet size: expected {GABUMON_EXPECTED_SIZE}, got {sheet.size}"
        )

    output = Image.new("RGBA", (32 * len(FRAME_BOXES), 32), (0, 0, 0, 0))
    for index, (x, y, width, height) in enumerate(FRAME_BOXES):
        frame = _make_transparent(sheet.crop((x, y, x + width, y + height)))
        if frame.getbbox() is None:
            raise RuntimeError(f"Gabumon frame {index} became empty after background removal")
        output.alpha_composite(frame, (index * 32, 0))

    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    output.save(OUTPUT_PATH, format="PNG", optimize=True)
    print(f"Prepared {OUTPUT_PATH} ({output.size[0]}x{output.size[1]})")


if __name__ == "__main__":
    main()
