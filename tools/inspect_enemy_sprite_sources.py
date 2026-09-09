#!/usr/bin/env python3
"""Temporary diagnostic for the three With the Will / Photobucket sprite sheets.

Downloads exactly the user-provided source images, copies them into build/ for
artifact inspection, and prints image metadata useful for deterministic crop
planning. This file is removed once the production extraction is finalized.
"""

from __future__ import annotations

import hashlib
import io
import subprocess
from collections import Counter
from pathlib import Path

from PIL import Image

USER_AGENT = (
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
    "(KHTML, like Gecko) Chrome/140.0 Safari/537.36"
)
REFERER = "https://withthewill.net/threads/the-new-digimon-world-dawn-dusk-lost-evo-sxw-sprite-topic-no-sprite-requests.10654/"

SOURCES = {
    "koromon": "https://i874.photobucket.com/albums/ab308/WtWSprites/Baby/002_Koromon.png",
    "tanemon": "https://i874.photobucket.com/albums/ab308/WtWSprites/Baby/006_Tanemon.png",
    "veemon": "https://i874.photobucket.com/albums/ab308/WtWSprites/Child/026_V-mon.png",
}


def fetch(url: str) -> bytes:
    result = subprocess.run(
        [
            "curl", "-sS", "-L", "--fail", "--retry", "2",
            "-A", USER_AGENT,
            "-e", REFERER,
            url,
        ],
        capture_output=True,
        timeout=90,
        check=False,
    )
    if result.returncode != 0:
        raise RuntimeError(
            f"Failed to fetch {url}: {result.stderr.decode('utf-8', 'replace').strip()}"
        )
    return result.stdout


def border_colors(image: Image.Image, limit: int = 8) -> list[tuple[tuple[int, int, int, int], int]]:
    rgba = image.convert("RGBA")
    colors: Counter[tuple[int, int, int, int]] = Counter()
    for x in range(rgba.width):
        colors[rgba.getpixel((x, 0))] += 1
        if rgba.height > 1:
            colors[rgba.getpixel((x, rgba.height - 1))] += 1
    for y in range(1, rgba.height - 1):
        colors[rgba.getpixel((0, y))] += 1
        if rgba.width > 1:
            colors[rgba.getpixel((rgba.width - 1, y))] += 1
    return colors.most_common(limit)


def main() -> None:
    Path("build").mkdir(exist_ok=True)
    for name, url in SOURCES.items():
        payload = fetch(url)
        digest = hashlib.sha256(payload).hexdigest()
        image = Image.open(io.BytesIO(payload)).convert("RGBA")
        destination = Path(f"build/source-{name}.png")
        image.save(destination)
        print(f"{name}: url={url}")
        print(f"{name}: sha256={digest}")
        print(f"{name}: size={image.width}x{image.height}")
        print(f"{name}: border_colors={border_colors(image)}")


if __name__ == "__main__":
    main()
