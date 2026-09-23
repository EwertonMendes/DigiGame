#!/usr/bin/env python3
from __future__ import annotations

import json
import shutil
import sys
from pathlib import Path
from PIL import Image, ImageFilter

ROOT = Path("assets/terrain/tblack-central-city")
SOURCE = ROOT / "source"
RUNTIME = ROOT / "runtime"

TARGET_MAX = {
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

def trim_alpha(image: Image.Image, padding: int = 4) -> Image.Image:
    rgba = image.convert("RGBA")
    alpha = rgba.getchannel("A")
    bbox = alpha.getbbox()
    if bbox is None:
        raise RuntimeError("asset has no visible pixels")
    left=max(0,bbox[0]-padding); top=max(0,bbox[1]-padding)
    right=min(rgba.width,bbox[2]+padding); bottom=min(rgba.height,bbox[3]+padding)
    return rgba.crop((left,top,right,bottom))

def resize_max(image: Image.Image, max_dim: int) -> Image.Image:
    largest=max(image.size)
    if largest <= max_dim:
        return image
    scale=max_dim/float(largest)
    size=(max(1,round(image.width*scale)),max(1,round(image.height*scale)))
    return image.resize(size, Image.Resampling.LANCZOS)

def save_runtime(name: str, image: Image.Image, max_dim: int) -> dict:
    prepared=resize_max(trim_alpha(image),max_dim)
    out=RUNTIME/f"{name}.png"
    out.parent.mkdir(parents=True,exist_ok=True)
    prepared.save(out,format="PNG",optimize=True)
    return {"path":str(out).replace("\\","/"),"size":[prepared.width,prepared.height]}

def connected_components(sheet: Image.Image) -> list[tuple[int,int,int,int]]:
    rgba=sheet.convert("RGBA")
    mask=rgba.getchannel("A").point(lambda a:255 if a>14 else 0).filter(ImageFilter.MaxFilter(7))
    w,h=mask.size; px=mask.load(); seen=bytearray(w*h); boxes=[]
    def visit(sx:int,sy:int):
        stack=[(sx,sy)]; seen[sy*w+sx]=1
        minx=maxx=sx; miny=maxy=sy; count=0
        while stack:
            x,y=stack.pop(); count+=1
            minx=min(minx,x); maxx=max(maxx,x); miny=min(miny,y); maxy=max(maxy,y)
            for nx,ny in ((x-1,y),(x+1,y),(x,y-1),(x,y+1)):
                if nx<0 or ny<0 or nx>=w or ny>=h: continue
                idx=ny*w+nx
                if seen[idx] or px[nx,ny]==0: continue
                seen[idx]=1; stack.append((nx,ny))
        return minx,miny,maxx+1,maxy+1,count
    for y in range(h):
        for x in range(w):
            idx=y*w+x
            if seen[idx] or px[x,y]==0: continue
            box=visit(x,y)
            if box[4] > 350:
                boxes.append(box[:4])
    boxes.sort(key=lambda b:(round(((b[1]+b[3])*0.5)/120.0),b[0]))
    return boxes

def main() -> None:
    if RUNTIME.exists():
        shutil.rmtree(RUNTIME)
    RUNTIME.mkdir(parents=True,exist_ok=True)
    manifest={"version":1,"assets":{}}

    for name,max_dim in TARGET_MAX.items():
        src=SOURCE/f"{name}.png"
        if not src.exists():
            raise FileNotFoundError(src)
        with Image.open(src) as image:
            manifest["assets"][name]=save_runtime(name,image,max_dim)

    curb_src=SOURCE/"curbs-edges.png"
    if not curb_src.exists():
        raise FileNotFoundError(curb_src)
    with Image.open(curb_src) as original:
        sheet=original.convert("RGBA")
    boxes=connected_components(sheet)
    if len(boxes) < 10:
        raise RuntimeError(f"expected multiple curb variants, found {len(boxes)}")
    curb_assets=[]
    for index,box in enumerate(boxes):
        crop=sheet.crop(box)
        name=f"curb_{index:02d}"
        entry=save_runtime(name,crop,256)
        entry["source_box"]=list(box)
        manifest["assets"][name]=entry
        curb_assets.append(name)
    manifest["curb_variants"]=curb_assets

    (RUNTIME/"manifest.json").write_text(json.dumps(manifest,indent=2,sort_keys=True)+"\n",encoding="utf-8")
    print(f"[TblackCityAssets] PASS runtime={len(manifest['assets'])} curbs={len(curb_assets)}")

if __name__ == "__main__":
    main()
