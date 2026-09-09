#!/usr/bin/env python3
"""Fetch and prepare directional Digimon World DS prototype field sprites.

The source sprites are copyrighted Bandai/Namco assets and are used only as
legacy fan/prototype art. No free-content license is claimed.

Each generated field sheet uses the same deterministic layout:

    frames 0..2   down_left
    frames 3..5   down_right
    frames 6..8   up_left
    frames 9..11  up_right

Agumon and Greymon only expose the left-facing diagonals in their extraction
specs, so right-facing frames are mirrored exactly as the source-spec metadata
instructs. Gabumon has all four diagonal directions explicitly available.
"""

from __future__ import annotations

from collections import Counter, deque
import hashlib
import io
import re
import subprocess
from pathlib import Path
from typing import Iterable

from PIL import Image

GALLERY_URL = "https://www.spriters-resource.com/ds_dsi/dgmnworldds/"
BASE_URL = "https://www.spriters-resource.com"
USER_AGENT = (
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
    "(KHTML, like Gecko) Chrome/120.0 Safari/537.36"
)

DIRECTION_ORDER = ("down_left", "down_right", "up_left", "up_right")

CHARACTERS = {
    "agumon": {
        "sheet_id": "48418",
        "expected_sha256": None,
        "background": (0x74, 0xEC, 0x60),
        "tolerance": 40,
        "frame_size": (32, 32),
        "directions": {
            "up_left": ((13, 75), (46, 75), (79, 75)),
            "down_left": ((112, 75), (145, 75), (178, 75)),
        },
        "mirrors": {
            "down_right": "down_left",
            "up_right": "up_left",
        },
    },
    "gabumon": {
        "sheet_id": "41249",
        "expected_sha256": "746e0bda873f274568c8445fa90861d43348ecf2d98abdbf30b439a42e0c53cb",
        "background": (0x00, 0x80, 0x80),
        "tolerance": 40,
        "frame_size": (32, 32),
        "directions": {
            "down_left": ((310, 2), (344, 2), (378, 2)),
            "down_right": ((310, 36), (344, 36), (378, 36)),
            "up_left": ((310, 70), (344, 70), (378, 70)),
            "up_right": ((310, 104), (344, 104), (378, 104)),
        },
        "mirrors": {},
    },
    "greymon": {
        "sheet_id": "48406",
        "expected_sha256": None,
        "background": (0x00, 0x80, 0x80),
        "tolerance": 40,
        "frame_size": (32, 64),
        "directions": {
            "down_left": ((4, 302), (41, 302), (78, 302)),
            "up_left": ((120, 302), (157, 302), (194, 302)),
        },
        "mirrors": {
            "down_right": "down_left",
            "up_right": "up_left",
        },
    },
}


def _curl(url: str) -> bytes:
    result = subprocess.run(
        ["curl", "-sS", "-L", "-A", USER_AGENT, "--fail", url],
        capture_output=True,
        timeout=60,
        check=False,
    )
    if result.returncode != 0:
        raise RuntimeError(
            f"Failed to fetch {url}: {result.stderr.decode('utf-8', 'replace').strip()}"
        )
    return result.stdout


def _discover_sheet_url(gallery: str, sheet_id: str) -> str:
    match = re.search(rf"asset_icons/(\d+)/{sheet_id}\.png", gallery)
    if match is None:
        raise RuntimeError(f"Could not locate sheet {sheet_id} in the DWDS gallery")
    return f"{BASE_URL}/media/assets/{match.group(1)}/{sheet_id}.png"


def _distance(a: tuple[int, int, int], b: tuple[int, int, int]) -> int:
    return max(abs(a[0] - b[0]), abs(a[1] - b[1]), abs(a[2] - b[2]))


def _border_positions(width: int, height: int) -> Iterable[tuple[int, int]]:
    for x in range(width):
        yield x, 0
        if height > 1:
            yield x, height - 1
    for y in range(1, height - 1):
        yield 0, y
        if width > 1:
            yield width - 1, y


def _dominant_border_color(image: Image.Image) -> tuple[int, int, int]:
    rgba = image.convert("RGBA")
    colors = Counter(
        rgba.getpixel((x, y))[:3]
        for x, y in _border_positions(rgba.width, rgba.height)
    )
    return colors.most_common(1)[0][0]


def _make_background_transparent(
    frame: Image.Image,
    expected_background: tuple[int, int, int],
    tolerance: int,
) -> Image.Image:
    """Remove only background connected to frame edges.

    This avoids the old color-key behavior that could leave an opaque square or
    erase legitimate interior sprite colors. The dominant border color is used
    when the source crop differs from the extraction spec's nominal background.
    """

    rgba = frame.convert("RGBA")
    width, height = rgba.size
    dominant = _dominant_border_color(rgba)

    border_pixels = [
        rgba.getpixel((x, y))[:3]
        for x, y in _border_positions(width, height)
    ]
    expected_matches = sum(
        1 for color in border_pixels if _distance(color, expected_background) <= tolerance
    )
    reference = (
        expected_background
        if expected_matches >= max(4, len(border_pixels) // 8)
        else dominant
    )

    pixels = rgba.load()
    queue: deque[tuple[int, int]] = deque()
    visited: set[tuple[int, int]] = set()

    def is_background(x: int, y: int, extra: int = 0) -> bool:
        color = pixels[x, y][:3]
        limit = tolerance + extra
        return (
            _distance(color, reference) <= limit
            or _distance(color, expected_background) <= limit
        )

    for x, y in _border_positions(width, height):
        if is_background(x, y):
            queue.append((x, y))
            visited.add((x, y))

    while queue:
        x, y = queue.popleft()
        for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
            if nx < 0 or nx >= width or ny < 0 or ny >= height:
                continue
            position = (nx, ny)
            if position in visited or not is_background(nx, ny):
                continue
            visited.add(position)
            queue.append(position)

    for x, y in visited:
        r, g, b, _a = pixels[x, y]
        pixels[x, y] = (r, g, b, 0)

    # One restrained halo-cleaning pass removes edge pixels that are almost
    # background-colored but were separated by antialiasing in the source.
    halo_candidates: list[tuple[int, int]] = []
    for y in range(height):
        for x in range(width):
            if pixels[x, y][3] == 0:
                continue
            touches_transparency = any(
                0 <= nx < width
                and 0 <= ny < height
                and pixels[nx, ny][3] == 0
                for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1))
            )
            if touches_transparency and is_background(x, y, extra=12):
                halo_candidates.append((x, y))

    for x, y in halo_candidates:
        r, g, b, _a = pixels[x, y]
        pixels[x, y] = (r, g, b, 0)

    alpha = rgba.getchannel("A")
    bbox = alpha.getbbox()
    if bbox is None:
        raise RuntimeError("Background cleanup removed the entire sprite frame")

    corner_alphas = (
        pixels[0, 0][3],
        pixels[width - 1, 0][3],
        pixels[0, height - 1][3],
        pixels[width - 1, height - 1][3],
    )
    if any(corner_alphas):
        raise RuntimeError(
            f"Background cleanup left opaque frame corners (reference={reference})"
        )

    transparent_pixels = sum(1 for value in alpha.getdata() if value == 0)
    if transparent_pixels < width * height * 0.20:
        raise RuntimeError(
            f"Background cleanup left too little transparency ({transparent_pixels} pixels)"
        )

    return rgba


def _crop_frame(
    sheet: Image.Image,
    position: tuple[int, int],
    frame_size: tuple[int, int],
    background: tuple[int, int, int],
    tolerance: int,
) -> Image.Image:
    x, y = position
    width, height = frame_size
    if x + width > sheet.width or y + height > sheet.height:
        raise RuntimeError(
            f"Frame {(x, y, width, height)} is outside source sheet {sheet.size}"
        )
    frame = sheet.crop((x, y, x + width, y + height))
    return _make_background_transparent(frame, background, tolerance)


def _prepare_character(name: str, config: dict, gallery: str) -> None:
    sheet_url = _discover_sheet_url(gallery, config["sheet_id"])
    source = _curl(sheet_url)
    source_sha = hashlib.sha256(source).hexdigest()
    print(f"{name}: source {sheet_url}")
    print(f"{name}: source SHA-256 {source_sha}")

    expected_sha = config["expected_sha256"]
    if expected_sha is not None and source_sha != expected_sha:
        raise RuntimeError(
            f"{name}: source integrity check failed: expected {expected_sha}, got {source_sha}"
        )

    sheet = Image.open(io.BytesIO(source)).convert("RGBA")
    frame_width, frame_height = config["frame_size"]
    output = Image.new(
        "RGBA",
        (frame_width * len(DIRECTION_ORDER) * 3, frame_height),
        (0, 0, 0, 0),
    )

    prepared: dict[str, list[Image.Image]] = {}
    for direction, positions in config["directions"].items():
        prepared[direction] = [
            _crop_frame(
                sheet,
                position,
                config["frame_size"],
                config["background"],
                config["tolerance"],
            )
            for position in positions
        ]

    for direction, source_direction in config["mirrors"].items():
        prepared[direction] = [
            frame.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
            for frame in prepared[source_direction]
        ]

    for direction_index, direction in enumerate(DIRECTION_ORDER):
        frames = prepared.get(direction)
        if frames is None or len(frames) != 3:
            raise RuntimeError(f"{name}: missing three frames for {direction}")
        for frame_index, frame in enumerate(frames):
            output.alpha_composite(
                frame,
                ((direction_index * 3 + frame_index) * frame_width, 0),
            )

    output_path = Path(f"assets/characters/{name}.png")
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output.save(output_path, format="PNG", optimize=True)
    print(f"{name}: prepared {output_path} ({output.size[0]}x{output.size[1]})")


def main() -> None:
    gallery = _curl(GALLERY_URL).decode("utf-8", "replace")
    for name, config in CHARACTERS.items():
        _prepare_character(name, config, gallery)


if __name__ == "__main__":
    main()
