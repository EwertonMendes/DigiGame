#!/usr/bin/env python3
"""Fetch pinned CC0 terrain assets required by DigiGame's clean CI build."""

from __future__ import annotations

import hashlib
from pathlib import Path
from urllib.request import Request, urlopen

MIRROR_COMMIT = "45df48c4d45f8716216b1a9e22df0b69cd9f5932"
BASE_URL = (
    "https://raw.githubusercontent.com/ETdoFresh/kenney.nl/"
    f"{MIRROR_COMMIT}/isometriclandscape/PNG"
)
OUTPUT_DIR = Path("assets/terrain/kenney")

ASSETS = (
    ("landscapeTiles_010.png", "grass.png", "cb244de5ff52525b5afb7d8d64ce3180d0c32f54"),
    ("landscapeTiles_014.png", "earth.png", "c7d48eea143016d148d46db5d1ffad8b234078fa"),
    ("landscapeTiles_015.png", "lush_grass.png", "fd1e55397462fcb347f62e3763bbbc53ff666583"),
)


def git_blob_sha(data: bytes) -> str:
    header = f"blob {len(data)}\0".encode("utf-8")
    return hashlib.sha1(header + data).hexdigest()


def download(url: str) -> bytes:
    request = Request(url, headers={"User-Agent": "DigiGame-CI/1.0"})
    with urlopen(request, timeout=60) as response:
        return response.read()


def main() -> None:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    for source_name, target_name, expected_sha in ASSETS:
        target = OUTPUT_DIR / target_name

        if target.exists():
            existing = target.read_bytes()
            if git_blob_sha(existing) == expected_sha:
                print(f"OK (cached): {target}")
                continue

        url = f"{BASE_URL}/{source_name}"
        print(f"Fetching {url}")
        data = download(url)
        actual_sha = git_blob_sha(data)
        if actual_sha != expected_sha:
            raise RuntimeError(
                f"Integrity check failed for {source_name}: "
                f"expected Git blob {expected_sha}, got {actual_sha}"
            )

        target.write_bytes(data)
        print(f"OK: {target} ({len(data)} bytes)")


if __name__ == "__main__":
    main()
