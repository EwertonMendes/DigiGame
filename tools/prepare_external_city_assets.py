#!/usr/bin/env python3
from __future__ import annotations

import json
import shutil
import sys
from pathlib import Path
from typing import Iterable

from PIL import Image

ROOT = Path(sys.argv[1] if len(sys.argv) > 1 else "assets/external/central_city")
PROCESSED = ROOT / "processed"
FUTURE_OUT = PROCESSED / "future"
DYSTOPIAN_OUT = PROCESSED / "dystopian"
MAX_FUTURE_DIMENSION = 480

DYSTOPIAN_COMPONENTS = {
    "diner_a": (730, 478, 942, 672),
    "diner_b": (497, 479, 709, 673),
    "shop_a": (499, 702, 711, 896),
    "shop_b": (738, 702, 950, 896),
    "apartment_a": (25, 456, 237, 776),
    "apartment_b": (249, 458, 461, 778),
    "apartment_c": (29, 774, 241, 1094),
    "apartment_d": (257, 776, 469, 1096),
    "road_a": (492, 918, 642, 1003),
    "sidewalk_a": (823, 919, 940, 998),
    "road_curve_a": (645, 928, 795, 1006),
    "sidewalk_b": (817, 1028, 934, 1107),
    "road_b": (485, 1031, 635, 1116),
    "road_curve_b": (645, 1041, 795, 1119),
    "street_lamp_a": (89, 1111, 144, 1243),
    "street_lamp_b": (256, 1111, 311, 1242),
    "street_lamp_c": (12, 1121, 69, 1241),
    "street_lamp_d": (171, 1121, 228, 1241),
    "sidewalk_curve_a": (785, 1149, 960, 1218),
    "sidewalk_curve_b": (588, 1164, 774, 1236),
    "terminal_a": (337, 1171, 385, 1242),
    "terminal_b": (415, 1171, 463, 1242),
    "terminal_c": (337, 1283, 385, 1350),
    "terminal_d": (415, 1283, 463, 1350),
    "paper_a": (648, 1296, 719, 1350),
    "paper_b": (721, 1296, 792, 1350),
    "paper_c": (486, 1299, 557, 1350),
    "paper_d": (563, 1299, 634, 1350),
}


def find_file(folder: Path, file_name: str) -> Path:
    matches = [p for p in folder.rglob(file_name) if "processed" not in p.parts]
    if not matches:
        raise FileNotFoundError(f"{file_name} not found under {folder}")
    matches.sort(key=lambda p: (len(p.parts), str(p)))
    return matches[0]


def trim_alpha(image: Image.Image, padding: int = 3) -> Image.Image:
    rgba = image.convert("RGBA")
    bbox = rgba.getbbox()
    if not bbox:
        return rgba
    left = max(0, bbox[0] - padding)
    top = max(0, bbox[1] - padding)
    right = min(rgba.width, bbox[2] + padding)
    bottom = min(rgba.height, bbox[3] + padding)
    return rgba.crop((left, top, right, bottom))


def resize_future(image: Image.Image) -> Image.Image:
    max_dim = max(image.width, image.height)
    if max_dim <= MAX_FUTURE_DIMENSION:
        return image
    scale = MAX_FUTURE_DIMENSION / float(max_dim)
    size = (
        max(1, round(image.width * scale)),
        max(1, round(image.height * scale)),
    )
    return image.resize(size, Image.Resampling.LANCZOS)


def save_png(image: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path, format="PNG", optimize=True)


def process_future() -> dict[str, dict]:
    source = ROOT / "future"
    manifest = {}
    FUTURE_OUT.mkdir(parents=True, exist_ok=True)
    for index in range(1, 38):
        src = find_file(source, f"{index}.png")
        with Image.open(src) as original:
            image = resize_future(trim_alpha(original, 6))
        name = f"future_{index:02d}"
        out = FUTURE_OUT / f"{name}.png"
        save_png(image, out)
        manifest[name] = {
            "path": str(out).replace("\\", "/"),
            "size": [image.width, image.height],
            "source": f"{index}.png",
        }
    return manifest


def process_dystopian() -> dict[str, dict]:
    source = ROOT / "dystopian"
    sheet_path = find_file(source, "Dystopian City Starter Pack.png")
    with Image.open(sheet_path) as original:
        sheet = original.convert("RGBA")

    manifest = {}
    DYSTOPIAN_OUT.mkdir(parents=True, exist_ok=True)
    for name, box in DYSTOPIAN_COMPONENTS.items():
        image = trim_alpha(sheet.crop(box), 2)
        asset_name = f"dystopian_{name}"
        out = DYSTOPIAN_OUT / f"{asset_name}.png"
        save_png(image, out)
        manifest[asset_name] = {
            "path": str(out).replace("\\", "/"),
            "size": [image.width, image.height],
            "source_box": list(box),
        }
    return manifest


def main() -> None:
    if PROCESSED.exists():
        shutil.rmtree(PROCESSED)
    PROCESSED.mkdir(parents=True, exist_ok=True)

    assets = {}
    assets.update(process_future())
    assets.update(process_dystopian())

    manifest = {
        "version": 1,
        "future_max_dimension": MAX_FUTURE_DIMENSION,
        "assets": assets,
    }
    (PROCESSED / "manifest.json").write_text(
        json.dumps(manifest, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    print(
        f"[CityAssets] Prepared {len(assets)} optimized assets "
        f"({len([k for k in assets if k.startswith('future_')])} future, "
        f"{len([k for k in assets if k.startswith('dystopian_')])} dystopian)."
    )


if __name__ == "__main__":
    main()
