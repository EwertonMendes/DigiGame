#!/usr/bin/env python3
from __future__ import annotations

import math
import os
import sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(sys.argv[1] if len(sys.argv) > 1 else ".cache/external-city-assets/sources")
OUT = Path(sys.argv[2] if len(sys.argv) > 2 else "build/city-asset-probe")
OUT.mkdir(parents=True, exist_ok=True)

THUMB_W = 220
THUMB_H = 220
LABEL_H = 56
COLS = 4
MARGIN = 12

font = ImageFont.load_default()

def pngs(folder: Path):
    return sorted(
        p for p in folder.rglob("*")
        if p.is_file() and p.suffix.lower() in {".png", ".jpg", ".jpeg", ".webp"}
    )

def build(pack: str):
    folder = ROOT / pack
    files = pngs(folder)
    if not files:
        raise SystemExit(f"No images found for {pack} under {folder}")

    inventory = OUT / f"{pack}-inventory.txt"
    with inventory.open("w", encoding="utf-8") as fh:
        for p in files:
            try:
                with Image.open(p) as im:
                    fh.write(f"{p.relative_to(folder)}\t{im.width}x{im.height}\n")
            except Exception as exc:
                fh.write(f"{p.relative_to(folder)}\tERROR {exc}\n")

    rows = math.ceil(len(files) / COLS)
    canvas = Image.new(
        "RGBA",
        (
            MARGIN + COLS * (THUMB_W + MARGIN),
            MARGIN + rows * (THUMB_H + LABEL_H + MARGIN),
        ),
        (18, 22, 28, 255),
    )
    draw = ImageDraw.Draw(canvas)

    for index, path in enumerate(files):
        col = index % COLS
        row = index // COLS
        x = MARGIN + col * (THUMB_W + MARGIN)
        y = MARGIN + row * (THUMB_H + LABEL_H + MARGIN)

        try:
            with Image.open(path) as original:
                image = original.convert("RGBA")
                image.thumbnail((THUMB_W - 12, THUMB_H - 12), Image.Resampling.NEAREST)
                px = x + (THUMB_W - image.width) // 2
                py = y + (THUMB_H - image.height) // 2
                canvas.alpha_composite(image, (px, py))
        except Exception:
            pass

        draw.rectangle((x, y, x + THUMB_W, y + THUMB_H), outline=(70, 82, 96, 255), width=1)
        label = str(path.relative_to(folder)).replace(os.sep, "/")
        if len(label) > 48:
            label = "…" + label[-47:]
        draw.text((x + 4, y + THUMB_H + 5), label, fill=(220, 230, 240, 255), font=font)

    canvas.save(OUT / f"{pack}-contact.png")
    print(f"[CityAssetsProbe] {pack}: {len(files)} images")

for pack_name in ("dystopian", "future"):
    build(pack_name)

print("[CityAssetsProbe] PASS")


def dystopian_components():
    sheet_path = ROOT / "dystopian" / "Dystopian City Starter Pack" / "Dystopian City Starter Pack.png"
    if not sheet_path.exists():
        raise SystemExit(f"Dystopian sheet not found: {sheet_path}")

    with Image.open(sheet_path) as src:
        image = src.convert("RGBA")
    alpha = image.getchannel("A")

    # Merge pixels that belong to the same authored sprite but have a few
    # transparent pixels between outline/shadow/glow parts.
    mask = alpha.point(lambda a: 255 if a > 8 else 0)
    from PIL import ImageFilter
    expanded = mask.filter(ImageFilter.MaxFilter(9))

    width, height = expanded.size
    pix = expanded.load()
    seen = bytearray(width * height)
    components = []

    def visit(sx, sy):
        stack = [(sx, sy)]
        seen[sy * width + sx] = 1
        min_x = max_x = sx
        min_y = max_y = sy
        count = 0
        while stack:
            x, y = stack.pop()
            count += 1
            min_x = min(min_x, x)
            max_x = max(max_x, x)
            min_y = min(min_y, y)
            max_y = max(max_y, y)
            for nx, ny in ((x-1,y),(x+1,y),(x,y-1),(x,y+1)):
                if nx < 0 or ny < 0 or nx >= width or ny >= height:
                    continue
                idx = ny * width + nx
                if seen[idx] or pix[nx, ny] == 0:
                    continue
                seen[idx] = 1
                stack.append((nx, ny))
        return min_x, min_y, max_x + 1, max_y + 1, count

    for y in range(height):
        for x in range(width):
            idx = y * width + x
            if seen[idx] or pix[x, y] == 0:
                continue
            box = visit(x, y)
            if box[4] < 40:
                continue
            pad = 6
            x0 = max(0, box[0] - pad)
            y0 = max(0, box[1] - pad)
            x1 = min(width, box[2] + pad)
            y1 = min(height, box[3] + pad)
            components.append((x0, y0, x1, y1))

    components.sort(key=lambda b: (b[1], b[0]))

    inv = OUT / "dystopian-components.txt"
    cols = 5
    thumb_w = 180
    thumb_h = 180
    label_h = 48
    rows = math.ceil(len(components) / cols)
    canvas = Image.new(
        "RGBA",
        (
            MARGIN + cols * (thumb_w + MARGIN),
            MARGIN + rows * (thumb_h + label_h + MARGIN),
        ),
        (18, 22, 28, 255),
    )
    draw = ImageDraw.Draw(canvas)

    with inv.open("w", encoding="utf-8") as fh:
        for index, box in enumerate(components):
            crop = image.crop(box)
            bbox = crop.getbbox()
            if bbox:
                crop = crop.crop(bbox)
            fh.write(
                f"{index:03d}\tbox={box[0]},{box[1]},{box[2]},{box[3]}"
                f"\tsize={crop.width}x{crop.height}\n"
            )

            col = index % cols
            row = index // cols
            x = MARGIN + col * (thumb_w + MARGIN)
            y = MARGIN + row * (thumb_h + label_h + MARGIN)
            preview = crop.copy()
            preview.thumbnail((thumb_w - 12, thumb_h - 12), Image.Resampling.NEAREST)
            px = x + (thumb_w - preview.width) // 2
            py = y + (thumb_h - preview.height) // 2
            canvas.alpha_composite(preview, (px, py))
            draw.rectangle((x, y, x + thumb_w, y + thumb_h), outline=(70, 82, 96, 255), width=1)
            draw.text(
                (x + 5, y + thumb_h + 5),
                f"#{index:03d}  {crop.width}x{crop.height}",
                fill=(220, 230, 240, 255),
                font=font,
            )

    canvas.save(OUT / "dystopian-components.png")
    print(f"[CityAssetsProbe] dystopian components: {len(components)}")


dystopian_components()
