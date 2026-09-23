#!/usr/bin/env python3
from __future__ import annotations

import json
import shutil
from pathlib import Path

from PIL import Image, ImageFilter

ROOT = Path("assets/terrain/tblack-central-city")
SOURCE = ROOT / "source"
RUNTIME = ROOT / "runtime"

REQUIRED_TARGET_MAX = {
    "road": 640,
    "sidewalk": 576,
    "plaza-floor": 640,
    "grass-ground": 640,
    "crosswalk": 640,
    "digital-terminal": 256,
    "public-bench": 320,
    "trash-bin": 192,
    "planter": 320,
    "small-tree": 384,
    "medium-tree": 448,
}

# These are intentionally optional today. When the dedicated road pieces are
# supplied, the build pipeline will process them automatically; only the runtime
# catalog/layout needs to activate the corresponding piece.
OPTIONAL_TARGET_MAX = {
    "road-corner": 640,
    "road-t-junction": 640,
    "road-intersection": 640,
}


def trim_alpha(image: Image.Image, padding: int = 4) -> Image.Image:
    rgba = image.convert("RGBA")
    alpha = rgba.getchannel("A")
    bbox = alpha.getbbox()
    if bbox is None:
        raise RuntimeError("asset has no visible pixels")

    left = max(0, bbox[0] - padding)
    top = max(0, bbox[1] - padding)
    right = min(rgba.width, bbox[2] + padding)
    bottom = min(rgba.height, bbox[3] + padding)
    return rgba.crop((left, top, right, bottom))


def resize_max(image: Image.Image, max_dim: int) -> Image.Image:
    largest = max(image.size)
    if largest <= max_dim:
        return image
    scale = max_dim / float(largest)
    size = (
        max(1, round(image.width * scale)),
        max(1, round(image.height * scale)),
    )
    return image.resize(size, Image.Resampling.LANCZOS)


def save_runtime(name: str, image: Image.Image, max_dim: int) -> dict:
    prepared = resize_max(trim_alpha(image), max_dim)
    out = RUNTIME / f"{name}.png"
    out.parent.mkdir(parents=True, exist_ok=True)
    prepared.save(out, format="PNG", optimize=True)
    return {
        "path": str(out).replace("\\", "/"),
        "size": [prepared.width, prepared.height],
    }


def prepare_named_asset(name: str, max_dim: int, *, required: bool) -> dict | None:
    src = SOURCE / f"{name}.png"
    if not src.exists():
        if required:
            raise FileNotFoundError(src)
        return None
    with Image.open(src) as image:
        return save_runtime(name, image, max_dim)


def connected_components(sheet: Image.Image) -> list[tuple[int, int, int, int]]:
    rgba = sheet.convert("RGBA")
    mask = (
        rgba.getchannel("A")
        .point(lambda alpha: 255 if alpha > 14 else 0)
        .filter(ImageFilter.MaxFilter(7))
    )
    width, height = mask.size
    pixels = mask.load()
    seen = bytearray(width * height)
    boxes: list[tuple[int, int, int, int]] = []

    def visit(start_x: int, start_y: int) -> tuple[int, int, int, int, int]:
        stack = [(start_x, start_y)]
        seen[start_y * width + start_x] = 1
        min_x = max_x = start_x
        min_y = max_y = start_y
        count = 0

        while stack:
            x, y = stack.pop()
            count += 1
            min_x = min(min_x, x)
            max_x = max(max_x, x)
            min_y = min(min_y, y)
            max_y = max(max_y, y)

            for next_x, next_y in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
                if next_x < 0 or next_y < 0 or next_x >= width or next_y >= height:
                    continue
                index = next_y * width + next_x
                if seen[index] or pixels[next_x, next_y] == 0:
                    continue
                seen[index] = 1
                stack.append((next_x, next_y))

        return min_x, min_y, max_x + 1, max_y + 1, count

    for y in range(height):
        for x in range(width):
            index = y * width + x
            if seen[index] or pixels[x, y] == 0:
                continue
            box = visit(x, y)
            if box[4] > 350:
                boxes.append(box[:4])

    boxes.sort(key=lambda box: (round(((box[1] + box[3]) * 0.5) / 120.0), box[0]))
    return boxes


def main() -> None:
    if RUNTIME.exists():
        shutil.rmtree(RUNTIME)
    RUNTIME.mkdir(parents=True, exist_ok=True)

    manifest = {
        "version": 2,
        "assets": {},
        "road_capabilities": {
            "straight": True,
            "corner": False,
            "t_junction": False,
            "intersection": False,
        },
    }

    for name, max_dim in REQUIRED_TARGET_MAX.items():
        entry = prepare_named_asset(name, max_dim, required=True)
        assert entry is not None
        manifest["assets"][name] = entry

    optional_to_capability = {
        "road-corner": "corner",
        "road-t-junction": "t_junction",
        "road-intersection": "intersection",
    }
    for name, max_dim in OPTIONAL_TARGET_MAX.items():
        entry = prepare_named_asset(name, max_dim, required=False)
        if entry is None:
            continue
        manifest["assets"][name] = entry
        manifest["road_capabilities"][optional_to_capability[name]] = True

    curb_src = SOURCE / "curbs-edges.png"
    if not curb_src.exists():
        raise FileNotFoundError(curb_src)
    with Image.open(curb_src) as original:
        sheet = original.convert("RGBA")

    boxes = connected_components(sheet)
    if len(boxes) < 10:
        raise RuntimeError(f"expected multiple curb variants, found {len(boxes)}")

    curb_assets = []
    for index, box in enumerate(boxes):
        crop = sheet.crop(box)
        name = f"curb_{index:02d}"
        entry = save_runtime(name, crop, 256)
        entry["source_box"] = list(box)
        manifest["assets"][name] = entry
        curb_assets.append(name)
    manifest["curb_variants"] = curb_assets

    (RUNTIME / "manifest.json").write_text(
        json.dumps(manifest, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    print(
        "[TblackCityAssets] PASS "
        f"runtime={len(manifest['assets'])} "
        f"curbs={len(curb_assets)} "
        f"road_capabilities={manifest['road_capabilities']}"
    )


if __name__ == "__main__":
    main()
