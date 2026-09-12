from pathlib import Path
from PIL import Image, ImageSequence

source = Path("assets/characters/metalgreymon/source/portrait.webp")
target = Path("assets/characters/metalgreymon/portrait_frames.png")

with Image.open(source) as image:
    frames = [frame.convert("RGBA").copy() for frame in ImageSequence.Iterator(image)]

if len(frames) != 4:
    raise SystemExit(f"expected 4 MetalGreymon portrait frames, got {len(frames)}")
if any(frame.size != (150, 150) for frame in frames):
    raise SystemExit(f"unexpected MetalGreymon frame sizes: {[frame.size for frame in frames]}")

strip = Image.new("RGBA", (600, 150), (0, 0, 0, 0))
for index, frame in enumerate(frames):
    strip.alpha_composite(frame, (index * 150, 0))
strip.save(target, format="PNG", optimize=True)

with Image.open(target) as check:
    check.verify()
print(f"wrote valid {target} ({target.stat().st_size} bytes)")
