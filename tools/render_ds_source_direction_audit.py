#!/usr/bin/env python3
"""Render every WtW directional source group for manual semantic-facing audit."""
from __future__ import annotations

import io
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

from build_early_rank_ds_fields import WTW_IDS, _components, _group_by_y, load_wtw_archive

OUT = Path("/tmp/ds-direction-audit")
SCALE = 4
ROW_H = 190
PAGE_ROWS = 18


def candidates(image: Image.Image):
    bg, comps = _components(image)
    kept = [c for c in comps if 10 <= c["w"] <= 50 and 10 <= c["h"] <= 50 and c["area"] >= 100]
    groups = _group_by_y(kept)
    for group in groups:
        group.sort(key=lambda c: c["cx"])
    return bg, groups


def extract_groups(image: Image.Image, sprite_id: int):
    bg, groups = candidates(image)
    six = [g for g in groups if len(g) == 6]
    if len(six) == 2:
        rows = sorted(six, key=lambda g: sum(c["cy"] for c in g) / len(g))
        return bg, [rows[0][:3], rows[0][3:6], rows[1][:3], rows[1][3:6]], "two_rows_of_six"
    if sprite_id == 72:
        rows = [g for g in groups if len(g) >= 6]
        rows = sorted(rows, key=lambda g: sum(c["cy"] for c in g) / len(g))[-2:]
        rows = [sorted(g, key=lambda c: c["cx"])[:6] for g in rows]
        return bg, [rows[0][:3], rows[0][3:6], rows[1][:3], rows[1][3:6]], "kudamon_two_rows"
    triples = []
    for group in groups:
        if len(group) < 3:
            continue
        triple = sorted(group, key=lambda c: c["cx"])[-3:]
        triples.append((sum(c["cx"] for c in triple) / 3, sum(c["cy"] for c in triple) / 3, triple))
    selected = sorted(triples, key=lambda x: x[0], reverse=True)[:4]
    selected.sort(key=lambda x: x[1])
    if len(selected) != 4:
        raise RuntimeError(f"{sprite_id:03d}: could not detect four directional groups")
    return bg, [x[2] for x in selected], "compact_four_groups"


def crop_group(image: Image.Image, bg, group):
    rgba = np.array(image.convert("RGBA"), copy=True)
    bgcolor = np.asarray(bg, dtype=np.uint8)
    rgba[np.all(rgba[:, :, :3] == bgcolor, axis=2), 3] = 0
    keyed = Image.fromarray(rgba, "RGBA")
    frames=[]
    for c in group:
        x,y,w,h = int(c["x"]),int(c["y"]),int(c["w"]),int(c["h"])
        frame=keyed.crop((max(0,x-2),max(0,y-2),min(keyed.width,x+w+2),min(keyed.height,y+h+2)))
        bbox=frame.getbbox()
        frames.append(frame.crop(bbox) if bbox else frame)
    return frames


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    archive = load_wtw_archive()
    rows=[]
    for name, sprite_id in sorted(WTW_IDS.items(), key=lambda item: item[1]):
        prefix=f"sprite thread/{sprite_id:03d}_"
        matches=[p for p in archive.namelist() if p.startswith(prefix) and p.lower().endswith((".png",".gif"))]
        if len(matches)!=1:
            raise RuntimeError(f"{name}: expected one source, got {matches}")
        image=Image.open(io.BytesIO(archive.read(matches[0]))).convert("RGBA")
        bg, groups, layout=extract_groups(image,sprite_id)
        rendered=[crop_group(image,bg,g) for g in groups]
        rows.append({"name":name,"id":sprite_id,"source":matches[0],"layout":layout,"groups":rendered})

    manifest=[]
    for page_index in range((len(rows)+PAGE_ROWS-1)//PAGE_ROWS):
        subset=rows[page_index*PAGE_ROWS:(page_index+1)*PAGE_ROWS]
        page=Image.new("RGBA",(1500,ROW_H*len(subset)),(242,242,242,255))
        draw=ImageDraw.Draw(page)
        for ri,row in enumerate(subset):
            y0=ri*ROW_H
            draw.rectangle((0,y0,1499,y0+ROW_H-1),fill=(255,255,255,255) if ri%2==0 else (232,232,232,255))
            draw.text((8,y0+8),f"{row['id']:03d}  {row['name']}  [{row['layout']}]",fill=(0,0,0,255))
            for gi,frames in enumerate(row["groups"]):
                gx=230+gi*310
                draw.text((gx,y0+8),f"G{gi}",fill=(0,0,0,255))
                for fi,frame in enumerate(frames):
                    scaled=frame.resize((frame.width*SCALE,frame.height*SCALE),Image.Resampling.NEAREST)
                    x=gx+fi*95+(85-scaled.width)//2
                    y=y0+35+(145-scaled.height)//2
                    page.alpha_composite(scaled,(x,y))
                if gi>0:
                    draw.line((gx-10,y0,gx-10,y0+ROW_H),fill=(180,180,180,255),width=1)
            manifest.append({k:row[k] for k in ("name","id","source","layout")})
        page.save(OUT/f"page-{page_index+1:02d}.png")
    (OUT/"manifest.json").write_text(json.dumps(manifest,indent=2)+"\n")
    print(f"rendered {len(rows)} WtW source sheets into {(len(rows)+PAGE_ROWS-1)//PAGE_ROWS} audit pages")

if __name__ == "__main__":
    main()
