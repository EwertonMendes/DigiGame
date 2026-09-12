#!/usr/bin/env python3
"""Rebuild MetalGreymon's normalized field-walk sheet.

The source is the legacy Digimon World DS MetalGreymon sheet mirrored by The
Spriters Resource. It is copyrighted commercial game artwork; this script does
not claim a free-content license and exists only to make the fan/prototype asset
preparation reproducible.

Runtime layout (12 x 32x40 cells):
  0..2   down_left
  3..5   down_right
  6..8   up_left
  9..11  up_right

The original sheet exposes one three-frame isometric field-walk cycle and its
horizontal mirror, but no distinct rear-facing walk cycle. We therefore preserve
the original bottom-left cycle pixel-for-pixel, mirror it for right-facing
movement, and intentionally reuse those horizontal orientations for the two
"up" runtime groups. That is preferable to inventing non-source rear artwork and
keeps MetalGreymon compatible with DigiGame's existing directional_12 runtime.
"""
from __future__ import annotations

import hashlib
import io
import subprocess
from pathlib import Path

from PIL import Image, ImageOps

SOURCE_URL = "https://www.spriters-resource.com/media/assets/45/48322.png"
SOURCE_PAGE = "https://www.spriters-resource.com/ds_dsi/dgmnworldds/asset/48322/"
EXPECTED_SOURCE_SHA256 = "2f370926a0585787dfbae2b575509f8698a80539c8a68c87d3586b1d99a05665"
USER_AGENT = (
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
    "AppleWebKit/537.36 Chrome/140 Safari/537.36"
)

CELL_SIZE = (32, 40)
DIRECTION_ORDER = ("down_left", "down_right", "up_left", "up_right")
# Exact alpha-component bounds of the three clean field frames in asset 48322.
# These crops contain no logos, labels, portraits, or watermark pixels.
SOURCE_FRAMES = (
    (23, 306, 53, 338),
    (24, 350, 55, 384),
    (23, 391, 54, 427),
)


def fetch(url: str) -> bytes:
    result = subprocess.run(
        ["curl", "-fsSL", "--retry", "3", "-A", USER_AGENT, url],
        capture_output=True,
        timeout=90,
        check=False,
    )
    if result.returncode != 0:
        raise RuntimeError(
            f"Failed to fetch {url}: {result.stderr.decode('utf-8', 'replace').strip()}"
        )
    return result.stdout


def normalize(frame: Image.Image) -> Image.Image:
    rgba = frame.convert("RGBA")
    bbox = rgba.getbbox()
    if bbox is None:
        raise RuntimeError("MetalGreymon extraction produced an empty frame")
    rgba = rgba.crop(bbox)
    if rgba.width > CELL_SIZE[0] or rgba.height > CELL_SIZE[1]:
        raise RuntimeError(f"Source frame {rgba.size} does not fit runtime cell {CELL_SIZE}")

    output = Image.new("RGBA", CELL_SIZE, (0, 0, 0, 0))
    output.alpha_composite(
        rgba,
        ((CELL_SIZE[0] - rgba.width) // 2, CELL_SIZE[1] - rgba.height),
    )
    return output


def validate_source_crop(frame: Image.Image, index: int) -> None:
    # The useful field sprites in this sheet already have true alpha. Refuse to
    # accept a future source revision that silently replaces that with a flat
    # background, because color-key cleanup risks eating legitimate sprite pixels.
    alpha = frame.convert("RGBA").getchannel("A")
    if alpha.getbbox() is None:
        raise RuntimeError(f"MetalGreymon source frame {index} is empty")
    transparent = sum(1 for value in alpha.getdata() if value == 0)
    if transparent == 0:
        raise RuntimeError(
            f"MetalGreymon source frame {index} has no transparency; source layout changed"
        )


def compose(frames: list[Image.Image]) -> Image.Image:
    right = [ImageOps.mirror(frame) for frame in frames]
    prepared = {
        "down_left": frames,
        "down_right": right,
        "up_left": [frame.copy() for frame in frames],
        "up_right": [frame.copy() for frame in right],
    }

    output = Image.new(
        "RGBA",
        (CELL_SIZE[0] * 12, CELL_SIZE[1]),
        (0, 0, 0, 0),
    )
    for direction_index, direction in enumerate(DIRECTION_ORDER):
        direction_frames = prepared[direction]
        for frame_index, frame in enumerate(direction_frames):
            output.alpha_composite(
                frame,
                ((direction_index * 3 + frame_index) * CELL_SIZE[0], 0),
            )
    return output


def validate_runtime_sheet(sheet: Image.Image) -> None:
    expected_size = (CELL_SIZE[0] * 12, CELL_SIZE[1])
    if sheet.size != expected_size:
        raise RuntimeError(f"Unexpected runtime sheet size {sheet.size}, expected {expected_size}")

    for index in range(12):
        x = index * CELL_SIZE[0]
        frame = sheet.crop((x, 0, x + CELL_SIZE[0], CELL_SIZE[1]))
        if frame.getbbox() is None:
            raise RuntimeError(f"Runtime frame {index} is empty")
        corners = (
            frame.getpixel((0, 0))[3],
            frame.getpixel((CELL_SIZE[0] - 1, 0))[3],
            frame.getpixel((0, CELL_SIZE[1] - 1))[3],
            frame.getpixel((CELL_SIZE[0] - 1, CELL_SIZE[1] - 1))[3],
        )
        if any(corners):
            raise RuntimeError(f"Runtime frame {index} touches a cell corner")


def main() -> None:
    payload = fetch(SOURCE_URL)
    source_sha = hashlib.sha256(payload).hexdigest()
    if source_sha != EXPECTED_SOURCE_SHA256:
        raise RuntimeError(
            "MetalGreymon source integrity check failed: "
            f"expected {EXPECTED_SOURCE_SHA256}, got {source_sha}"
        )

    source = Image.open(io.BytesIO(payload)).convert("RGBA")
    if source.size != (395, 432):
        raise RuntimeError(f"Unexpected MetalGreymon source dimensions: {source.size}")

    frames: list[Image.Image] = []
    for index, box in enumerate(SOURCE_FRAMES):
        crop = source.crop(box)
        validate_source_crop(crop, index)
        frames.append(normalize(crop))

    sheet = compose(frames)
    validate_runtime_sheet(sheet)

    output_path = Path("assets/characters/metalgreymon/field.png")
    output_path.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(output_path, format="PNG", optimize=True)
    print(
        f"MetalGreymon: prepared {output_path} ({sheet.width}x{sheet.height}) "
        f"from {SOURCE_PAGE}"
    )


if __name__ == "__main__":
    main()
