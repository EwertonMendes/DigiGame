#!/usr/bin/env python3
"""Fetch and normalize Koromon and Tanemon field sheets.

Runtime layout is always 12 x 32x32 frames:
  0..2 down_left, 3..5 down_right, 6..8 up_left, 9..11 up_right.

The Photobucket sources mix field sprites, portraits, watermarks, labels, and a
solid blue background. Only clean baby field poses are used. Background removal
first clears edge-connected blue, then removes any remaining source-blue pixels
inside the connected sprite component so no tiny blue islands survive.

Koromon's source-facing convention is opposite Tanemon's, so its left/right
assignments are intentionally swapped after extraction. Both babies use clean
front/back poses repeated across three animation slots because their alternate
source cells are crossed by watermarks.
"""
from __future__ import annotations

from collections import deque
import hashlib
import io
import subprocess
from pathlib import Path

from PIL import Image, ImageOps

USER_AGENT = (
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
    "AppleWebKit/537.36 Chrome/140 Safari/537.36"
)
REFERER = (
    "https://withthewill.net/threads/"
    "the-new-digimon-world-dawn-dusk-lost-evo-sxw-sprite-topic-no-sprite-requests.10654/"
)
BG = (123, 198, 255)
ORDER = ("down_left", "down_right", "up_left", "up_right")
SOURCES = {
    "koromon": (
        "https://i874.photobucket.com/albums/ab308/WtWSprites/Baby/002_Koromon.png",
        "dac126e72b5b96ebd018aef0e79bb1baba4caa2b493e21309dca8d25de4a7595",
    ),
    "tanemon": (
        "https://i874.photobucket.com/albums/ab308/WtWSprites/Baby/006_Tanemon.png",
        "4f276334f6b6e5cb58348de9ad7e9cc00b9892929b37cc355fb2400a1124c44f",
    ),
}

BABY_POSES = {
    "koromon": {
        "front_left": (197, 0, 224, 25),
        "back_left": (199, 25, 224, 50),
    },
    "tanemon": {
        "front_left": (186, 0, 211, 25),
        "back_left": (185, 25, 211, 50),
    },
}


def fetch(url: str) -> bytes:
    result = subprocess.run(
        [
            "curl",
            "-sS",
            "-L",
            "--fail",
            "--retry",
            "2",
            "-A",
            USER_AGENT,
            "-e",
            REFERER,
            url,
        ],
        capture_output=True,
        timeout=90,
        check=False,
    )
    if result.returncode != 0:
        raise RuntimeError(result.stderr.decode("utf-8", "replace"))
    return result.stdout


def distance(a: tuple[int, int, int], b: tuple[int, int, int]) -> int:
    return max(abs(a[i] - b[i]) for i in range(3))


def clean_background(frame: Image.Image, tolerance: int = 10) -> Image.Image:
    rgba = frame.convert("RGBA")
    px = rgba.load()
    width, height = rgba.size

    border = (
        {(x, 0) for x in range(width)}
        | {(x, height - 1) for x in range(width)}
        | {(0, y) for y in range(height)}
        | {(width - 1, y) for y in range(height)}
    )

    queue: deque[tuple[int, int]] = deque()
    seen: set[tuple[int, int]] = set()

    for point in border:
        if distance(px[point[0], point[1]][:3], BG) <= tolerance:
            queue.append(point)
            seen.add(point)

    while queue:
        x, y = queue.popleft()
        for neighbor in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
            nx, ny = neighbor
            if (
                0 <= nx < width
                and 0 <= ny < height
                and neighbor not in seen
                and distance(px[nx, ny][:3], BG) <= tolerance
            ):
                seen.add(neighbor)
                queue.append(neighbor)

    for x, y in seen:
        r, g, b, _ = px[x, y]
        px[x, y] = (r, g, b, 0)

    return rgba


def keep_main_component(frame: Image.Image) -> Image.Image:
    """Keep the connected Digimon body and discard detached text/scan lines."""
    rgba = frame.convert("RGBA")
    px = rgba.load()
    width, height = rgba.size

    opaque = {
        (x, y)
        for y in range(height)
        for x in range(width)
        if px[x, y][3] > 0
    }
    if not opaque:
        raise RuntimeError("Sprite extraction produced an empty frame")

    components: list[set[tuple[int, int]]] = []
    remaining = set(opaque)

    while remaining:
        start = remaining.pop()
        component = {start}
        queue = deque([start])
        while queue:
            x, y = queue.popleft()
            for neighbor in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
                if neighbor in remaining:
                    remaining.remove(neighbor)
                    component.add(neighbor)
                    queue.append(neighbor)
        components.append(component)

    main_component = max(components, key=len)
    for x, y in opaque - main_component:
        r, g, b, _ = px[x, y]
        px[x, y] = (r, g, b, 0)

    return rgba


def remove_source_blue(frame: Image.Image, tolerance: int = 12) -> Image.Image:
    """Remove blue pixels trapped inside sprite-shaped regions after flood fill."""
    rgba = frame.convert("RGBA")
    px = rgba.load()
    for y in range(rgba.height):
        for x in range(rgba.width):
            r, g, b, a = px[x, y]
            if a > 0 and distance((r, g, b), BG) <= tolerance:
                px[x, y] = (r, g, b, 0)
    return rgba


def extract_pose(source: Image.Image, box: tuple[int, int, int, int]) -> Image.Image:
    cleaned = clean_background(source.crop(box))
    main = keep_main_component(cleaned)
    return remove_source_blue(main)


def normalize(frame: Image.Image) -> Image.Image:
    output = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    output.alpha_composite(frame, ((32 - frame.width) // 2, 32 - frame.height))
    return output


def repeated(frame: Image.Image) -> list[Image.Image]:
    return [frame, frame.copy(), frame.copy()]


def compose(prepared: dict[str, list[Image.Image]]) -> Image.Image:
    output = Image.new("RGBA", (384, 32), (0, 0, 0, 0))
    for direction_index, direction in enumerate(ORDER):
        frames = prepared[direction]
        if len(frames) != 3:
            raise RuntimeError(f"{direction}: expected exactly 3 frames")
        for frame_index, frame in enumerate(frames):
            output.alpha_composite(
                frame,
                ((direction_index * 3 + frame_index) * 32, 0),
            )
    return output


def baby_sheet(source: Image.Image, name: str) -> Image.Image:
    pose_boxes = BABY_POSES[name]
    front_left = normalize(extract_pose(source, pose_boxes["front_left"]))
    back_left = normalize(extract_pose(source, pose_boxes["back_left"]))

    if name == "koromon":
        # Koromon's extracted source pose points to screen-right despite the
        # historical crop label. Swap the horizontal assignment explicitly.
        return compose(
            {
                "down_left": repeated(ImageOps.mirror(front_left)),
                "down_right": repeated(front_left),
                "up_left": repeated(ImageOps.mirror(back_left)),
                "up_right": repeated(back_left),
            }
        )

    return compose(
        {
            "down_left": repeated(front_left),
            "down_right": repeated(ImageOps.mirror(front_left)),
            "up_left": repeated(back_left),
            "up_right": repeated(ImageOps.mirror(back_left)),
        }
    )


def validate_sheet(name: str, sheet: Image.Image) -> None:
    if sheet.size != (384, 32):
        raise RuntimeError(f"{name}: unexpected sheet size {sheet.size}")

    for frame_index in range(12):
        frame = sheet.crop((frame_index * 32, 0, (frame_index + 1) * 32, 32))
        if frame.getbbox() is None:
            raise RuntimeError(f"{name}: frame {frame_index} is empty")
        for r, g, b, a in frame.getdata():
            if a > 0 and distance((r, g, b), BG) <= 12:
                raise RuntimeError(f"{name}: source-blue pixel survived in frame {frame_index}")


def main() -> None:
    Path("assets/characters").mkdir(parents=True, exist_ok=True)

    for name, (url, expected_sha) in SOURCES.items():
        payload = fetch(url)
        digest = hashlib.sha256(payload).hexdigest()
        if digest != expected_sha:
            raise RuntimeError(f"{name}: expected {expected_sha}, got {digest}")

        source = Image.open(io.BytesIO(payload)).convert("RGBA")
        sheet = baby_sheet(source, name)
        validate_sheet(name, sheet)

        path = Path(f"assets/characters/{name}.png")
        sheet.save(path, format="PNG", optimize=True)
        print(f"{name}: prepared clean 384x32 runtime sheet at {path}")


if __name__ == "__main__":
    main()
