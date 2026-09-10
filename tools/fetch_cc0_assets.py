#!/usr/bin/env python3
"""Fetch pinned CC0 terrain and combat VFX required by DigiGame's clean CI build."""

from __future__ import annotations

import hashlib
from pathlib import Path
from urllib.request import Request, urlopen

TERRAIN_MIRROR_COMMIT = "45df48c4d45f8716216b1a9e22df0b69cd9f5932"
TERRAIN_BASE_URL = (
    "https://raw.githubusercontent.com/ETdoFresh/kenney.nl/"
    f"{TERRAIN_MIRROR_COMMIT}/isometriclandscape/PNG"
)

# Kenney Particle Pack, packaged for Godot by Calinou. The upstream pack is CC0.
# Pin the public mirror to one immutable commit so CI always receives identical bytes.
VFX_MIRROR_COMMIT = "ab7086639ee73be31abd87feb21bf1402d4e8144"
VFX_BASE_URL = (
    "https://raw.githubusercontent.com/Calinou/kenney-particle-pack/"
    f"{VFX_MIRROR_COMMIT}/addons/kenney_particle_pack"
)

ASSETS = (
    (
        f"{TERRAIN_BASE_URL}/landscapeTiles_010.png",
        Path("assets/terrain/kenney/grass.png"),
        "cb244de5ff52525b5afb7d8d64ce3180d0c32f54",
    ),
    (
        f"{TERRAIN_BASE_URL}/landscapeTiles_014.png",
        Path("assets/terrain/kenney/earth.png"),
        "c7d48eea143016d148d46db5d1ffad8b234078fa",
    ),
    (
        f"{TERRAIN_BASE_URL}/landscapeTiles_015.png",
        Path("assets/terrain/kenney/lush_grass.png"),
        "fd1e55397462fcb347f62e3763bbbc53ff666583",
    ),
    (
        f"{VFX_BASE_URL}/slash_03.png",
        Path("assets/vfx/kenney/slash_03.png"),
        "31f250ab448fcd8c767a4960c6fbc7105b326fa5",
    ),
    (
        f"{VFX_BASE_URL}/spark_04.png",
        Path("assets/vfx/kenney/spark_04.png"),
        "6eaf328696ec8640571a69318b6211223c14224e",
    ),
    (
        f"{VFX_BASE_URL}/magic_03.png",
        Path("assets/vfx/kenney/magic_03.png"),
        "47c4a22ff7b104ec9ab8926bd6e68d8709fe7b1a",
    ),
    (
        f"{VFX_BASE_URL}/flare_01.png",
        Path("assets/vfx/kenney/flare_01.png"),
        "bd25bd874e47467e95d6623aa0364be1c619617a",
    ),
    (
        f"{VFX_BASE_URL}/muzzle_01.png",
        Path("assets/vfx/kenney/muzzle_01.png"),
        "ce0324cf90254f4c84f61b1b05f3a166f0e00fc0",
    ),
    (
        f"{VFX_BASE_URL}/smoke_03.png",
        Path("assets/vfx/kenney/smoke_03.png"),
        "34cad39231026b6617f25e03e99c0b860258d010",
    ),
)


def git_blob_sha(data: bytes) -> str:
    header = f"blob {len(data)}\0".encode("utf-8")
    return hashlib.sha1(header + data).hexdigest()


def download(url: str) -> bytes:
    request = Request(url, headers={"User-Agent": "DigiGame-CI/1.0"})
    with urlopen(request, timeout=60) as response:
        return response.read()


def main() -> None:
    for url, target, expected_sha in ASSETS:
        target.parent.mkdir(parents=True, exist_ok=True)

        if target.exists():
            existing = target.read_bytes()
            if git_blob_sha(existing) == expected_sha:
                print(f"OK (cached): {target}")
                continue

        print(f"Fetching {url}")
        data = download(url)
        actual_sha = git_blob_sha(data)
        if actual_sha != expected_sha:
            raise RuntimeError(
                f"Integrity check failed for {target.name}: "
                f"expected Git blob {expected_sha}, got {actual_sha}"
            )

        target.write_bytes(data)
        print(f"OK: {target} ({len(data)} bytes)")


if __name__ == "__main__":
    main()
