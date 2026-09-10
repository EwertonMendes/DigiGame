#!/usr/bin/env python3
"""Fetch pinned, redistributable UI fonts used by DigiGame.

The repository keeps provenance/license text in source control while the font
binaries are fetched for local development and CI. Each download is pinned to
an immutable google/fonts commit and verified using its Git blob SHA-1.
"""

from __future__ import annotations

import hashlib
from pathlib import Path
from urllib.request import Request, urlopen

ROOT = Path(__file__).resolve().parents[1]
FONT_DIR = ROOT / "assets" / "ui" / "fonts"
GOOGLE_FONTS_COMMIT = "9d1ce2fc3c335cca32b6db00c19f55d57b0a68fe"
BASE_URL = f"https://raw.githubusercontent.com/google/fonts/{GOOGLE_FONTS_COMMIT}/ofl/rajdhani"

FONTS = {
    "Rajdhani-Regular.ttf": {
        "url": f"{BASE_URL}/Rajdhani-Regular.ttf",
        "git_blob_sha": "d25bd37233b672ef565e01d998a9412d761d7b00",
    },
    "Rajdhani-SemiBold.ttf": {
        "url": f"{BASE_URL}/Rajdhani-SemiBold.ttf",
        "git_blob_sha": "d43750bd05c130d36c8e7fbeb06ecd7c5d3c3b17",
    },
}


def git_blob_sha(data: bytes) -> str:
    header = f"blob {len(data)}\0".encode("ascii")
    return hashlib.sha1(header + data).hexdigest()


def fetch(url: str) -> bytes:
    request = Request(url, headers={"User-Agent": "DigiGame-asset-fetcher/1.0"})
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
