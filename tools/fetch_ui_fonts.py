#!/usr/bin/env python3
"""Fetch pinned, redistributable UI fonts used by DigiGame.

The runtime typography stack is:
- Oxanium: display / game identity
- Exo 2: dense interface text
- Noto Sans: reading and localization fallback
- Rajdhani: committed bootstrap fallback for partial/offline checkouts

Every download is verified against the exact Git blob SHA published by the
Google Fonts repository, so the script remains reproducible even though the
raw URL points at the repository's main branch.
"""

from __future__ import annotations

import hashlib
from pathlib import Path
from urllib.request import Request, urlopen

ROOT = Path(__file__).resolve().parents[1]
FONT_DIR = ROOT / "assets" / "ui" / "fonts"
BASE_URL = "https://raw.githubusercontent.com/google/fonts/main/ofl"

FONTS = {
    "Oxanium[wght].ttf": {
        "url": f"{BASE_URL}/oxanium/Oxanium%5Bwght%5D.ttf",
        "git_blob_sha": "ead485c7bf517197db91ef657614ac37d8007775",
    },
    "Exo2[wght].ttf": {
        "url": f"{BASE_URL}/exo2/Exo2%5Bwght%5D.ttf",
        "git_blob_sha": "9cb20188a07687580312d2099e6c79ca8ecb7b58",
    },
    "NotoSans[wdth,wght].ttf": {
        "url": f"{BASE_URL}/notosans/NotoSans%5Bwdth%2Cwght%5D.ttf",
        "git_blob_sha": "75575046c015ff623a848096a15779867ba71453",
    },
    "Rajdhani-Regular.ttf": {
        "url": f"{BASE_URL}/rajdhani/Rajdhani-Regular.ttf",
        "git_blob_sha": "d25bd37233b672ef565e01d998a9412d761d7b00",
    },
    "Rajdhani-SemiBold.ttf": {
        "url": f"{BASE_URL}/rajdhani/Rajdhani-SemiBold.ttf",
        "git_blob_sha": "d43750bd05c130d36c8e7fbeb06ecd7c5d3c3b17",
    },
}


def git_blob_sha(data: bytes) -> str:
    header = f"blob {len(data)}\0".encode("ascii")
    return hashlib.sha1(header + data).hexdigest()


def fetch(url: str) -> bytes:
    request = Request(url, headers={"User-Agent": "DigiGame-asset-fetcher/2.0"})
    with urlopen(request, timeout=45) as response:
        return response.read()


def main() -> None:
    FONT_DIR.mkdir(parents=True, exist_ok=True)
    for filename, metadata in FONTS.items():
        destination = FONT_DIR / filename
        data = fetch(str(metadata["url"]))
        actual = git_blob_sha(data)
        expected = str(metadata["git_blob_sha"])
        if actual != expected:
            raise RuntimeError(
                f"Integrity check failed for {filename}: expected Git blob "
                f"{expected}, got {actual}"
            )
        destination.write_bytes(data)
        print(f"UI font ready: {destination.relative_to(ROOT)} ({len(data)} bytes, {actual})")


if __name__ == "__main__":
    main()
