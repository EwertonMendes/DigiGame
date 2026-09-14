#!/usr/bin/env python3
from __future__ import annotations

import base64
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
PARTS_ROOT = ROOT / "tools/bootstrap-assets"
GRASS_ROOT = ROOT / "assets/characters/grassagumon"
FIELD_SOURCE = GRASS_ROOT / "source/field.png"
PORTRAIT_SOURCE = GRASS_ROOT / "source/portrait_frames.png"
PORTRAIT_INPUT = PARTS_ROOT / "portrait-input.png"

FIELD_CELL = 66
SOURCE_CELL = 48
FIELD_ORDER = [0, 1, 2, 5, 4, 3, 11, 10, 9, 6, 7, 8]
PORTRAIT_CELL_WIDTH = 160
PORTRAIT_CELL_HEIGHT = 180
PORTRAIT_COUNT = 3


def decode_parts(prefix: str) -> bytes:
    parts = sorted(PARTS_ROOT.glob(f"{prefix}.part*"))
    if not parts:
        raise RuntimeError(f"missing bootstrap parts for {prefix}")
    encoded = "".join(part.read_text(encoding="ascii").strip() for part in parts)
    return base64.b64decode(encoded, validate=True)


def crop_visible(frame: Image.Image) -> Image.Image:
    bbox = frame.getbbox()
    if bbox is None:
        raise RuntimeError("source contains an empty authored frame")
    return frame.crop(bbox)


def normalized_frames(source: Image.Image, boxes: list[tuple[int, int, int, int]], max_width: int, max_height: int) -> list[Image.Image]:
    frames = [crop_visible(source.crop(box)) for box in boxes]
    source_width = max(frame.width for frame in frames)
    source_height = max(frame.height for frame in frames)
    scale = min(max_width / float(source_width), max_height / float(source_height))
    if abs(scale - 1.0) < 1e-9:
        return frames
    return [
        frame.resize(
            (max(1, round(frame.width * scale)), max(1, round(frame.height * scale))),
            Image.Resampling.NEAREST,
        )
        for frame in frames
    ]


def assert_alpha(strip: Image.Image, label: str) -> None:
    lo, hi = strip.getchannel("A").getextrema()
    if lo != 0 or hi != 255:
        raise RuntimeError(f"{label} alpha range is invalid: {(lo, hi)}")


def build_field_source() -> None:
    compact_path = ROOT / ".grass-agumon-field-input.png"
    compact_path.write_bytes(decode_parts("field.b64"))
    try:
        source = Image.open(compact_path).convert("RGBA")
        if source.size != (288, 96):
            raise RuntimeError(f"unexpected compact field source size: {source.size}")

        boxes = []
        for row in range(2):
            for column in range(6):
                left = column * SOURCE_CELL
                top = row * SOURCE_CELL
                boxes.append((left, top, left + SOURCE_CELL, top + SOURCE_CELL))
        authored = normalized_frames(source, boxes, 46, 46)
        runtime = [authored[index] for index in FIELD_ORDER]

        strip = Image.new("RGBA", (FIELD_CELL * 12, FIELD_CELL), (0, 0, 0, 0))
        for index, frame in enumerate(runtime):
            x = index * FIELD_CELL + (FIELD_CELL - frame.width) // 2
            y = FIELD_CELL - frame.height - 1
            strip.alpha_composite(frame, (x, y))
        assert_alpha(strip, "Grass Agumon field")
        FIELD_SOURCE.parent.mkdir(parents=True, exist_ok=True)
        strip.save(FIELD_SOURCE, "PNG", optimize=True)
    finally:
        compact_path.unlink(missing_ok=True)


def build_portrait_source() -> None:
    if not PORTRAIT_INPUT.is_file():
        raise RuntimeError(f"missing portrait bootstrap input: {PORTRAIT_INPUT.relative_to(ROOT)}")
    source = Image.open(PORTRAIT_INPUT).convert("RGBA")
    if source.size != (PORTRAIT_CELL_WIDTH * PORTRAIT_COUNT, PORTRAIT_CELL_HEIGHT):
        raise RuntimeError(f"unexpected Grass Agumon portrait input size: {source.size}")

    boxes = [
        (index * PORTRAIT_CELL_WIDTH, 0, (index + 1) * PORTRAIT_CELL_WIDTH, PORTRAIT_CELL_HEIGHT)
        for index in range(PORTRAIT_COUNT)
    ]
    frames = normalized_frames(source, boxes, 150, 170)
    strip = Image.new(
        "RGBA",
        (PORTRAIT_CELL_WIDTH * PORTRAIT_COUNT, PORTRAIT_CELL_HEIGHT),
        (0, 0, 0, 0),
    )
    for index, frame in enumerate(frames):
        x = index * PORTRAIT_CELL_WIDTH + (PORTRAIT_CELL_WIDTH - frame.width) // 2
        y = PORTRAIT_CELL_HEIGHT - frame.height - 1
        strip.alpha_composite(frame, (x, y))
    assert_alpha(strip, "Grass Agumon portrait")
    PORTRAIT_SOURCE.parent.mkdir(parents=True, exist_ok=True)
    strip.save(PORTRAIT_SOURCE, "PNG", optimize=True)


build_field_source()
build_portrait_source()
print("materialized transparent Grass Agumon field and profile portrait sources")
