#!/usr/bin/env python3
"""Fetch and normalize the three With the Will / Photobucket enemy field sheets.

Generated runtime layout is always 12 x 32x32 frames:
  0..2 down_left, 3..5 down_right, 6..8 up_left, 9..11 up_right.

Baby sheets contain watermark overlap in some animation cells. To avoid shipping
watermark pixels or unstable per-frame anchors, Koromon and Tanemon use the clean
rightmost pose for each source direction repeated across the 3-frame slot. Veemon
uses its clean 3-frame down-left sequence and mirrors it for down-right; its clean
up-left pose is repeated and mirrored for up-right. Every frame is bottom-centered
on a fixed 32x32 canvas, so animation never jumps from changing crop bounds.
"""
from __future__ import annotations

from collections import deque
import hashlib
import io
import subprocess
from pathlib import Path
from PIL import Image

USER_AGENT = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/140 Safari/537.36"
REFERER = "https://withthewill.net/threads/the-new-digimon-world-dawn-dusk-lost-evo-sxw-sprite-topic-no-sprite-requests.10654/"
BG = (123, 198, 255)
ORDER = ("down_left", "down_right", "up_left", "up_right")
SOURCES = {
    "koromon": ("https://i874.photobucket.com/albums/ab308/WtWSprites/Baby/002_Koromon.png", "dac126e72b5b96ebd018aef0e79bb1baba4caa2b493e21309dca8d25de4a7595"),
    "tanemon": ("https://i874.photobucket.com/albums/ab308/WtWSprites/Baby/006_Tanemon.png", "4f276334f6b6e5cb58348de9ad7e9cc00b9892929b37cc355fb2400a1124c44f"),
    "veemon": ("https://i874.photobucket.com/albums/ab308/WtWSprites/Child/026_V-mon.png", "dbb4df0d4047e7268a6be5a382b898235ec5f46256a66f15c9f626464fd77c7d"),
}

def fetch(url: str) -> bytes:
    result = subprocess.run(["curl", "-sS", "-L", "--fail", "--retry", "2", "-A", USER_AGENT, "-e", REFERER, url], capture_output=True, timeout=90, check=False)
    if result.returncode != 0:
        raise RuntimeError(result.stderr.decode("utf-8", "replace"))
    return result.stdout

def distance(a, b) -> int:
    return max(abs(a[i] - b[i]) for i in range(3))

def clean(frame: Image.Image, tolerance: int = 10) -> Image.Image:
    rgba = frame.convert("RGBA")
    px = rgba.load(); w, h = rgba.size
    border = {(x, 0) for x in range(w)} | {(x, h - 1) for x in range(w)} | {(0, y) for y in range(h)} | {(w - 1, y) for y in range(h)}
    q = deque(); seen = set()
    for p in border:
        if distance(px[p[0], p[1]][:3], BG) <= tolerance:
            q.append(p); seen.add(p)
    while q:
        x, y = q.popleft()
        for n in ((x-1,y),(x+1,y),(x,y-1),(x,y+1)):
            nx, ny = n
            if 0 <= nx < w and 0 <= ny < h and n not in seen and distance(px[nx,ny][:3], BG) <= tolerance:
                seen.add(n); q.append(n)
    for x, y in seen:
        r,g,b,_ = px[x,y]; px[x,y] = (r,g,b,0)
    return rgba

def normalize(frame: Image.Image) -> Image.Image:
    out = Image.new("RGBA", (32, 32), (0,0,0,0))
    out.alpha_composite(frame, ((32-frame.width)//2, 32-frame.height))
    return out

def baby_sheet(source: Image.Image) -> Image.Image:
    rows = {"down_left":0, "up_left":1, "down_right":2, "up_right":3}
    prepared = {}
    for direction, row in rows.items():
        frame = normalize(clean(source.crop((192, row*25, 224, (row+1)*25))))
        prepared[direction] = [frame, frame.copy(), frame.copy()]
    return compose(prepared)

def veemon_sheet(source: Image.Image) -> Image.Image:
    down_left = [normalize(clean(source.crop((x,192,x+30,224)))) for x in (0,30,60)]
    up_pose = normalize(clean(source.crop((0,160,30,192))) )
    up_left = [up_pose, up_pose.copy(), up_pose.copy()]
    prepared = {
        "down_left": down_left,
        "down_right": [f.transpose(Image.Transpose.FLIP_LEFT_RIGHT) for f in down_left],
        "up_left": up_left,
        "up_right": [f.transpose(Image.Transpose.FLIP_LEFT_RIGHT) for f in up_left],
    }
    return compose(prepared)

def compose(prepared) -> Image.Image:
    out = Image.new("RGBA", (384, 32), (0,0,0,0))
    for di, direction in enumerate(ORDER):
        for fi, frame in enumerate(prepared[direction]):
            out.alpha_composite(frame, ((di*3+fi)*32, 0))
    return out

def main() -> None:
    Path("assets/characters").mkdir(parents=True, exist_ok=True)
    for name, (url, expected_sha) in SOURCES.items():
        payload = fetch(url)
        digest = hashlib.sha256(payload).hexdigest()
        if digest != expected_sha:
            raise RuntimeError(f"{name}: expected {expected_sha}, got {digest}")
        source = Image.open(io.BytesIO(payload)).convert("RGBA")
        sheet = veemon_sheet(source) if name == "veemon" else baby_sheet(source)
        path = Path(f"assets/characters/{name}.png")
        sheet.save(path, format="PNG", optimize=True)
        print(f"{name}: prepared {path} 384x32 from {url}")

if __name__ == "__main__":
    main()
