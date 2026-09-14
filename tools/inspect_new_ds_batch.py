#!/usr/bin/env python3
from __future__ import annotations

import hashlib
import io
import json
import re
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageSequence

from build_early_rank_ds_fields import _components, _group_by_y, load_wtw_archive
from materialize_ds_direction_registry import crop_component, keyed_source

TARGETS = [
    ("DKTyrannomon", "sprite thread/131_DarkTyranomon.png", "champion/DarkTyrannomon.gif"),
    ("Machinedramon", "sprite thread/311_Mugendramon.png", "mega/Machinedramon.gif"),
    ("Millenniummon", "sprite thread/370_Milleniumon.png", "mega/Millenniummon.gif"),
    ("Growlmon", "sprite thread/113_Growlmon.png", "champion/Growlmon.gif"),
    ("Tyrannomon", "sprite thread/087_Tyrannomon.png", "champion/tyranomon.gif"),
    ("MetalTyrannomon", "sprite thread/269_MetalTyranomon.png", "ultimate/MetalTyrannomon.gif"),
    ("Monochromon", "sprite thread/181_Monochromon.png", "champion/Monochromon.gif"),
    ("Vermilimon", "sprite thread/273_Vermilimon.png", "ultimate/Vermilimon.gif"),
    ("Black War Greymon", "sprite thread/363_BlackWarGreymon.png", "mega/BlackWarGreymon.gif"),
    ("Darkdramon", "sprite thread/350_DarkdramonGarmmon.png", "mega/Darkdramon.gif"),
    ("Megadramon", "sprite thread/201_Megadramon.png", "ultimate/Megadramon.gif"),
    ("Airdramon", "sprite thread/089_Airdramon.png", "champion/Airdramon.gif"),
]

ANIMATED_REPO = Path("/tmp/ds-animated")
OUT = Path("/tmp/new-ds-batch-audit")


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def trim(image: Image.Image) -> Image.Image:
    rgba = image.convert("RGBA")
    box = rgba.getbbox()
    return rgba.crop(box) if box else rgba


def component_rows(image: Image.Image):
    _bg, components = _components(image)
    candidates = [c for c in components if 10 <= c["w"] <= 50 and 7 <= c["h"] <= 70 and c["area"] >= 60]
    rows = _group_by_y(candidates, tolerance=8.0)
    return [[{k: int(c[k]) for k in ("x", "y", "w", "h")} for c in sorted(row, key=lambda x: x["cx"])] for row in rows]


def render_candidates(source: Image.Image, rows, name: str) -> None:
    bg, _ = _components(source)
    keyed = keyed_source(source, bg)
    selected = [row for row in rows if len(row) >= 3]
    cells = []
    for ri, row in enumerate(selected):
        for ci, box in enumerate(row):
            crop = trim(crop_component(keyed, box))
            cells.append((ri, ci, crop))
    if not cells:
        return
    cell_w, cell_h = 80, 80
    canvas = Image.new("RGBA", (cell_w * max(len(r) for r in selected), cell_h * len(selected)), (30, 30, 30, 255))
    draw = ImageDraw.Draw(canvas)
    cursor = 0
    for ri, row in enumerate(selected):
        for ci, _box in enumerate(row):
            _, _, crop = cells[cursor]
            cursor += 1
            x = ci * cell_w + (cell_w - crop.width) // 2
            y = ri * cell_h + 12 + (cell_h - 12 - crop.height) // 2
            canvas.alpha_composite(crop, (x, y))
            draw.text((ci * cell_w + 2, ri * cell_h + 1), f"r{ri}c{ci}", fill=(255, 255, 255, 255))
    canvas.save(OUT / f"{name.replace(' ', '_')}_movement_candidates.png")


def exact_gif_matches(source: Image.Image, gif_path: Path):
    bg, components = _components(source)
    keyed = keyed_source(source, bg)
    crops = []
    for idx, c in enumerate(components):
        if 7 <= c["w"] <= 70 and 7 <= c["h"] <= 80 and c["area"] >= 40:
            crop = trim(crop_component(keyed, {k: int(c[k]) for k in ("x", "y", "w", "h")}))
            crops.append((idx, {k: int(c[k]) for k in ("x", "y", "w", "h")}, crop))
    with Image.open(gif_path) as gif:
        frames = [trim(f.convert("RGBA")) for f in ImageSequence.Iterator(gif)]
    result = []
    for fi, frame in enumerate(frames):
        matches = []
        variants = [frame]
        if frame.width % 2 == 0 and frame.height % 2 == 0:
            variants.append(frame.resize((frame.width // 2, frame.height // 2), Image.Resampling.NEAREST))
        variants.append(frame.resize((frame.width * 2, frame.height * 2), Image.Resampling.NEAREST))
        for ci, box, crop in crops:
            for vi, candidate in enumerate(variants):
                if crop.size == candidate.size and ImageChops.difference(crop, candidate).getbbox() is None:
                    matches.append({"component": ci, "box": box, "scale_variant": vi})
        result.append({"gif_frame": fi, "size": list(frame.size), "matches": matches})
    return result


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    archive = load_wtw_archive()
    summary = []
    for name, member, gif_rel in TARGETS:
        print(f"\n=== {name} ===")
        if member not in archive.namelist():
            print(f"MISSING_WTW_MEMBER {member}")
            similar = [x for x in archive.namelist() if re.sub(r"[^a-z]", "", name.lower())[:8] in re.sub(r"[^a-z]", "", x.lower())]
            print("SIMILAR", similar[:20])
            continue
        payload = archive.read(member)
        source = Image.open(io.BytesIO(payload)).convert("RGBA")
        rows = component_rows(source)
        sha = digest(payload)
        print("member", member)
        print("sha256", sha)
        print("size", source.size)
        print("movement_candidate_row_lengths", [len(r) for r in rows])
        print("rows", json.dumps(rows))
        source.save(OUT / f"{name.replace(' ', '_')}_source.png")
        render_candidates(source, rows, name)
        gif_path = ANIMATED_REPO / gif_rel
        gif_frames = None
        if gif_path.is_file():
            with Image.open(gif_path) as gif:
                gif_frames = getattr(gif, "n_frames", 1)
                print("gif", gif_rel, "frames", gif_frames, "size", gif.size)
            matches = exact_gif_matches(source, gif_path)
            matched = [m for m in matches if m["matches"]]
            print("exact_gif_matches", json.dumps(matched))
        else:
            print("MISSING_GIF", gif_rel)
        summary.append({"name": name, "member": member, "sha256": sha, "size": list(source.size), "rows": rows, "gif": gif_rel if gif_path.is_file() else None, "gif_frames": gif_frames})
    (OUT / "summary.json").write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
