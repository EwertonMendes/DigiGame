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

FIELD_CELL = 66
SOURCE_CELL = 48
FIELD_ORDER = [0, 1, 2, 5, 4, 3, 11, 10, 9, 6, 7, 8]


def decode_parts(prefix: str) -> bytes:
    parts = sorted(PARTS_ROOT.glob(f"{prefix}.part*"))
    if not parts:
        raise RuntimeError(f"missing bootstrap parts for {prefix}")
    encoded = "".join(part.read_text(encoding="ascii").strip() for part in parts)
    return base64.b64decode(encoded, validate=True)


def crop_visible(frame: Image.Image) -> Image.Image:
    bbox = frame.getbbox()
    if bbox is None:
        raise RuntimeError("field source contains an empty authored frame")
    return frame.crop(bbox)


def build_field_source() -> None:
    compact_path = ROOT / ".grass-agumon-field-input.png"
    compact_path.write_bytes(decode_parts("field.b64"))
    try:
        source = Image.open(compact_path).convert("RGBA")
        if source.size != (288, 96):
            raise RuntimeError(f"unexpected compact field source size: {source.size}")

        authored: list[Image.Image] = []
        for row in range(2):
            for column in range(6):
                left = column * SOURCE_CELL
                top = row * SOURCE_CELL
                authored.append(crop_visible(source.crop((left, top, left + SOURCE_CELL, top + SOURCE_CELL))))

        runtime = [authored[index] for index in FIELD_ORDER]
        max_width = max(frame.width for frame in runtime)
        max_height = max(frame.height for frame in runtime)
        scale = min(46.0 / max_width, 46.0 / max_height)
        runtime = [
            frame.resize(
                (max(1, round(frame.width * scale)), max(1, round(frame.height * scale))),
                Image.Resampling.NEAREST,
            )
            for frame in runtime
        ]

        strip = Image.new("RGBA", (FIELD_CELL * 12, FIELD_CELL), (0, 0, 0, 0))
        for index, frame in enumerate(runtime):
            x = index * FIELD_CELL + (FIELD_CELL - frame.width) // 2
            y = FIELD_CELL - frame.height - 1
            strip.alpha_composite(frame, (x, y))

        alpha = strip.getchannel("A")
        lo, hi = alpha.getextrema()
        if lo != 0 or hi != 255:
            raise RuntimeError(f"normalized field alpha range is invalid: {(lo, hi)}")
        FIELD_SOURCE.parent.mkdir(parents=True, exist_ok=True)
        strip.save(FIELD_SOURCE, "PNG", optimize=True)
    finally:
        compact_path.unlink(missing_ok=True)


def validate_portrait_source() -> None:
    portrait = Image.open(PORTRAIT_SOURCE).convert("RGBA")
    if portrait.size != (480, 180):
        raise RuntimeError(f"unexpected Grass Agumon portrait source size: {portrait.size}")
    alpha = portrait.getchannel("A")
    lo, hi = alpha.getextrema()
    if lo != 0 or hi != 255:
        raise RuntimeError(f"Grass Agumon portrait alpha range is invalid: {(lo, hi)}")


build_field_source()
validate_portrait_source()
print("materialized transparent Grass Agumon field strip and validated profile portrait source")
