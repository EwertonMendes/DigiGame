#!/usr/bin/env python3
from __future__ import annotations

import math
import os
import sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(sys.argv[1] if len(sys.argv) > 1 else "assets/external/central_city")
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
