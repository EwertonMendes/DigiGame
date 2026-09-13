#!/usr/bin/env python3
"""Render all final DS runtime strips as human-review contact sheets.

Each row is one Digimon. Frames are shown in the exact runtime order and are
explicitly labelled DL / DR / UL / UR, three frames per group. This tool is a
review aid: semantic truth still lives in ds-source-direction-registry.json.
"""
from __future__ import annotations

import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "database/ds-full-rebuild-manifest.json"
OUT = Path("/tmp/ds-generated-direction-audit")
DIRECTIONS = (("DL", 0), ("DR", 3), ("UL", 6), ("UR", 9))
FRAME_BOX = 70
NAME_W = 190
HEADER_H = 28
ROW_H = 92
PAGE_ROWS = 9
SCALE_LIMIT = 4


def _fit_nearest(frame: Image.Image) -> Image.Image:
    bbox = frame.getbbox()
    if bbox is None:
        return Image.new("RGBA", (FRAME_BOX, FRAME_BOX), (0, 0, 0, 0))
    crop = frame.crop(bbox)
    max_scale = max(1, min(SCALE_LIMIT, (FRAME_BOX - 8) // max(crop.width, crop.height)))
    crop = crop.resize((crop.width * max_scale, crop.height * max_scale), Image.Resampling.NEAREST)
    canvas = Image.new("RGBA", (FRAME_BOX, FRAME_BOX), (0, 0, 0, 0))
    x = (FRAME_BOX - crop.width) // 2
    y = FRAME_BOX - crop.height - 4
    canvas.alpha_composite(crop, (x, y))
    return canvas


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
    entries = [{"name": "Agumon", "output": "assets/characters/agumon/field.png"}]
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
    return [strip.crop((index * cell_w, 0, (index + 1) * cell_w, cell_h)) for index in range(12)]


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
        draw.text((8, 8), "Runtime contract: DL[0-2]  DR[3-5]  UL[6-8]  UR[9-11]", fill=(0, 0, 0, 255), font=font)

        for row_index, entry in enumerate(page_entries):
            y = HEADER_H + row_index * ROW_H
            draw.rectangle((0, y, page_w, y + ROW_H - 1), outline=(90, 90, 90, 255), width=1)
            draw.rectangle((0, y, NAME_W, y + ROW_H - 1), fill=(248, 248, 248, 255))
            draw.text((8, y + 8), entry["name"], fill=(0, 0, 0, 255), font=font)
            output = ROOT / entry["output"]
            frames = _load_frames(output)
            for direction, start in DIRECTIONS:
                group_x = NAME_W + start * FRAME_BOX
                draw.text((group_x + 3, y + 3), direction, fill=(0, 0, 0, 255), font=font)
                if start:
                    draw.line((group_x, y, group_x, y + ROW_H - 1), fill=(70, 70, 70, 255), width=2)
                for local_index in range(3):
                    frame_index = start + local_index
                    rendered = _fit_nearest(frames[frame_index])
                    x = NAME_W + frame_index * FRAME_BOX
                    page.alpha_composite(rendered, (x, y + 18))
                    draw.text((x + 2, y + ROW_H - 12), str(frame_index), fill=(50, 50, 50, 255), font=font)

        filename = f"page-{page_index // PAGE_ROWS + 1:02d}.png"
        page.save(OUT / filename)
        manifest.append({"page": filename, "names": [entry["name"] for entry in page_entries]})

    (OUT / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(f"rendered {len(entries)} runtime strips across {len(manifest)} review pages")


if __name__ == "__main__":
    main()
