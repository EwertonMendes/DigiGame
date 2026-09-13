#!/usr/bin/env python3
"""Render all final DS runtime strips as human-review contact sheets.

Each row is one Digimon. Frames are shown in exact runtime order and labelled
DL / DR / UL / UR, three frames per group. Every frame in a Digimon row uses
the same nearest-neighbour scale so the audit preserves real relative sizes.
Semantic truth lives in database/ds-direction-registry.json.
"""
from __future__ import annotations

import json
import tempfile
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "database/ds-full-rebuild-manifest.json"
OUT = Path(tempfile.gettempdir()) / "ds-generated-direction-audit"
DIRECTIONS = (("DL", 0), ("DR", 3), ("UL", 6), ("UR", 9))
FRAME_BOX = 70
NAME_W = 190
HEADER_H = 28
ROW_H = 92
PAGE_ROWS = 9
SCALE_LIMIT = 4
WALK_PHASES = (0, 1, 0, 2)


def _row_scale(frames: list[Image.Image]) -> int:
    max_dimension = 1
    for frame in frames:
        bbox = frame.getbbox()
        if bbox is None:
            continue
        crop = frame.crop(bbox)
        max_dimension = max(max_dimension, crop.width, crop.height)
    return max(1, min(SCALE_LIMIT, (FRAME_BOX - 8) // max_dimension))


def _fit_nearest(frame: Image.Image, scale: int) -> Image.Image:
    if frame.getbbox() is None:
        return Image.new("RGBA", (FRAME_BOX, FRAME_BOX), (0, 0, 0, 0))
    scaled = frame.resize((frame.width * scale, frame.height * scale), Image.Resampling.NEAREST)
    canvas = Image.new("RGBA", (FRAME_BOX, FRAME_BOX), (0, 0, 0, 0))
    x = (FRAME_BOX - scaled.width) // 2
    y = FRAME_BOX - scaled.height - 4
    canvas.alpha_composite(scaled, (x, y))
    return canvas


def _animated_page(page_entries: list[dict], phase_index: int, font: ImageFont.ImageFont) -> Image.Image:
    page_w = NAME_W + FRAME_BOX * len(DIRECTIONS) + 24
    page_h = HEADER_H + ROW_H * len(page_entries)
    page = _checker((page_w, page_h))
    draw = ImageDraw.Draw(page)
    draw.rectangle((0, 0, page_w, HEADER_H), fill=(250, 250, 250, 255))
    draw.text(
        (8, 8),
        f"Animated runtime phase {WALK_PHASES[phase_index]}: DL / DR / UL / UR — red line is the shared anchor",
        fill=(0, 0, 0, 255),
        font=font,
    )
    for row_index, entry in enumerate(page_entries):
        y = HEADER_H + row_index * ROW_H
        draw.rectangle((0, y, page_w, y + ROW_H - 1), outline=(90, 90, 90, 255), width=1)
        draw.rectangle((0, y, NAME_W, y + ROW_H - 1), fill=(248, 248, 248, 255))
        frames = _load_frames(ROOT / entry["output"])
        scale = _row_scale(frames)
        draw.text((8, y + 8), f"{entry['name']}  x{scale}", fill=(0, 0, 0, 255), font=font)
        for column, (direction, start) in enumerate(DIRECTIONS):
            x = NAME_W + column * FRAME_BOX
            if column:
                draw.line((x, y, x, y + ROW_H - 1), fill=(70, 70, 70, 255), width=2)
            draw.text((x + 3, y + 3), direction, fill=(0, 0, 0, 255), font=font)
            anchor_y = y + 18 + FRAME_BOX - 4
            draw.line((x + 4, anchor_y, x + FRAME_BOX - 5, anchor_y), fill=(220, 45, 45, 255), width=1)
            frame = frames[start + WALK_PHASES[phase_index]]
            page.alpha_composite(_fit_nearest(frame, scale), (x, y + 18))
    return page


def _checker(size: tuple[int, int]) -> Image.Image:
    image = Image.new("RGBA", size, (235, 235, 235, 255))
    draw = ImageDraw.Draw(image)
    cell = 8
    for y in range(0, size[1], cell):
        for x in range(0, size[0], cell):
            if (x // cell + y // cell) % 2:
                draw.rectangle((x, y, x + cell - 1, y + cell - 1), fill=(210, 210, 210, 255))
    return image


def _read_entries() -> list[dict]:
    data = json.loads(MANIFEST.read_text(encoding="utf-8"))
    entries = [
        {"name": item["name"], "output": item["field"]}
        for item in data["preserved"]
    ]
    entries.extend(data["rebuilt"])
    if len(entries) != 89:
        raise RuntimeError(f"Expected 89 DS runtime strips, found {len(entries)}")
    return sorted(entries, key=lambda item: item["name"].casefold())


def _load_frames(path: Path) -> list[Image.Image]:
    strip = Image.open(path).convert("RGBA")
    if strip.width % 12 != 0:
        raise RuntimeError(f"{path}: width {strip.width} is not divisible by 12")
    cell_w = strip.width // 12
    cell_h = strip.height
    frames = [strip.crop((index * cell_w, 0, (index + 1) * cell_w, cell_h)) for index in range(12)]
    if any(frame.getbbox() is None for frame in frames):
        raise RuntimeError(f"{path}: one or more runtime frames are empty")
    return frames


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    entries = _read_entries()
    font = ImageFont.load_default()
    page_w = NAME_W + FRAME_BOX * 12 + 24

    manifest = []
    for page_index in range(0, len(entries), PAGE_ROWS):
        page_entries = entries[page_index : page_index + PAGE_ROWS]
        page_h = HEADER_H + ROW_H * len(page_entries)
        page = _checker((page_w, page_h))
        draw = ImageDraw.Draw(page)
        draw.rectangle((0, 0, page_w, HEADER_H), fill=(250, 250, 250, 255))
        draw.text(
            (8, 8),
            "Runtime contract: DL[0-2]  DR[3-5]  UL[6-8]  UR[9-11] — fixed scale per Digimon",
            fill=(0, 0, 0, 255),
            font=font,
        )

        for row_index, entry in enumerate(page_entries):
            y = HEADER_H + row_index * ROW_H
            draw.rectangle((0, y, page_w, y + ROW_H - 1), outline=(90, 90, 90, 255), width=1)
            draw.rectangle((0, y, NAME_W, y + ROW_H - 1), fill=(248, 248, 248, 255))
            output = ROOT / entry["output"]
            frames = _load_frames(output)
            scale = _row_scale(frames)
            draw.text((8, y + 8), f"{entry['name']}  x{scale}", fill=(0, 0, 0, 255), font=font)

            for direction, start in DIRECTIONS:
                group_x = NAME_W + start * FRAME_BOX
                draw.text((group_x + 3, y + 3), direction, fill=(0, 0, 0, 255), font=font)
                if start:
                    draw.line((group_x, y, group_x, y + ROW_H - 1), fill=(70, 70, 70, 255), width=2)
                for local_index in range(3):
                    frame_index = start + local_index
                    rendered = _fit_nearest(frames[frame_index], scale)
                    x = NAME_W + frame_index * FRAME_BOX
                    page.alpha_composite(rendered, (x, y + 18))
                    draw.text((x + 2, y + ROW_H - 12), str(frame_index), fill=(50, 50, 50, 255), font=font)

        filename = f"page-{page_index // PAGE_ROWS + 1:02d}.png"
        page.save(OUT / filename)
        animated_filename = f"animated-page-{page_index // PAGE_ROWS + 1:02d}.gif"
        animated_frames = [_animated_page(page_entries, phase, font).convert("RGB") for phase in range(len(WALK_PHASES))]
        animated_frames[0].save(
            OUT / animated_filename,
            save_all=True,
            append_images=animated_frames[1:],
            duration=120,
            loop=0,
            optimize=False,
        )
        manifest.append(
            {
                "page": filename,
                "animated_page": animated_filename,
                "names": [entry["name"] for entry in page_entries],
            }
        )

    (OUT / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(f"rendered {len(entries)} runtime strips across {len(manifest)} static and animated review pages")


if __name__ == "__main__":
    main()

