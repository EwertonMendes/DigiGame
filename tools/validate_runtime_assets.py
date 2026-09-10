#!/usr/bin/env python3
"""Validate that every runtime-critical asset is committed and local."""
from __future__ import annotations

import hashlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

EXPECTED_BLOBS = {
    "assets/terrain/kenney/grass.png": "cb244de5ff52525b5afb7d8d64ce3180d0c32f54",
    "assets/terrain/kenney/earth.png": "c7d48eea143016d148d46db5d1ffad8b234078fa",
    "assets/terrain/kenney/lush_grass.png": "fd1e55397462fcb347f62e3763bbbc53ff666583",
    "assets/vfx/kenney/slash_03.png": "31f250ab448fcd8c767a4960c6fbc7105b326fa5",
    "assets/vfx/kenney/spark_04.png": "6eaf328696ec8640571a69318b6211223c14224e",
    "assets/vfx/kenney/magic_03.png": "47c4a22ff7b104ec9ab8926bd6e68d8709fe7b1a",
    "assets/vfx/kenney/flare_01.png": "bd25bd874e47467e95d6623aa0364be1c619617a",
    "assets/vfx/kenney/muzzle_01.png": "ce0324cf90254f4c84f61b1b05f3a166f0e00fc0",
    "assets/vfx/library/atlas/foozle-pixel-magic.png": "f54fc319a8ceef199aa36499a4db268a4eb12ddd",
    "assets/vfx/library/atlas/nature-magic.png": "8fdf07fe3840df86d7355c061ab62c9be9413cd0",
    "assets/vfx/library/atlas/pixel-art-spells.png": "78697c7ac6cb369e2e216988ccda6fff22c06e9b",
    "assets/vfx/library/atlas/pvfx-foundry.png": "3be2525ff571b5e57096082d24f3781ef66b9404",
    "assets/audio/digimon-world-ds/normal-attack-impact.wav": "411c4c3f859259ffcccc643b5bc46d8bf5b337ed",
    "assets/audio/digimon-world-ds/normal-attack-whoosh.wav": "1c6ded576a3063f16f2349c285451ad69fa09521",
    "assets/audio/digimon-world-ds/technique-cast.wav": "c2878983ca8a667896b72b612d576aff68292908",
    "assets/audio/digimon-world-ds/technique-impact.wav": "616a06436be22f15a3852924acb4ecbc7df34474",
    "assets/ui/fonts/Rajdhani-Regular.ttf": "d25bd37233b672ef565e01d998a9412d761d7b00",
    "assets/ui/fonts/Rajdhani-SemiBold.ttf": "d43750bd05c130d36c8e7fbeb06ecd7c5d3c3b17",
    "assets/characters/agumon.png": "f5e1d3c25c9ba011373103c8768a00b50faac96d",
    "assets/characters/gabumon.png": "3fc37bf57e47a1f197ad2ee684d9ae056d3566f9",
    "assets/characters/greymon.png": "acc466df89f3854954fee6e110d30ebc233004d1",
    "assets/characters/koromon.png": "7be3ffad6cf60fd35e1f31e08052fff4b9e7b6f8",
    "assets/characters/tanemon.png": "53da8d44945acfab69505ba2d7e111aab19f97bb",
    "assets/characters/veemon/field.png": "4de1db9fac82ae76ff285bf53f5b8280e2939a22",
}

EXPECTED_SOURCE_SHA256 = {
    "vendor/vfx-source/pixel-art-spells.zip": "bf6e751559942aad40a50359ab5ae8f9750054546de0b21b4519d39904e163cb",
    "vendor/vfx-source/foozle-pixel-magic.zip": "0c04ab8ee856988b55885a92305d5382459cc855b2a6361c417bb11606f41e9a",
    "vendor/vfx-source/pvfx-foundry-0.7.0.zip": "a2a26a2c162ff9d58037c921d6c568d7fa944cfb166e25eef68f908046c29add",
    "vendor/vfx-source/nature-magic.zip": "46f44a30d38b65d55ed1101ce8dc8907e31043958abaf9e2b1894508438815f8",
}

RUNTIME_TEXT_ROOTS = (
    ROOT / "src",
    ROOT / "scenes",
    ROOT / "assets" / "resources",
)
NETWORK_RUNTIME_MARKERS = (
    "http://",
    "https://",
    "HTTPRequest",
    "HTTPClient",
    "WebSocketPeer",
)


def git_blob_sha(data: bytes) -> str:
    header = f"blob {len(data)}\0".encode("ascii")
    return hashlib.sha1(header + data).hexdigest()


def validate_binary(path_text: str, expected_blob: str) -> None:
    path = ROOT / path_text
    if not path.is_file():
        raise RuntimeError(f"missing vendored runtime asset: {path_text}")
    data = path.read_bytes()
    actual_blob = git_blob_sha(data)
    if actual_blob != expected_blob:
        raise RuntimeError(
            f"runtime asset changed unexpectedly: {path_text}; "
            f"expected blob {expected_blob}, got {actual_blob}"
        )

    suffix = path.suffix.lower()
    if suffix == ".png" and not data.startswith(b"\x89PNG\r\n\x1a\n"):
        raise RuntimeError(f"invalid PNG signature: {path_text}")
    if suffix == ".ttf" and data[:4] not in (b"\x00\x01\x00\x00", b"OTTO", b"true"):
        raise RuntimeError(f"invalid font signature: {path_text}")
    if suffix == ".wav" and not (data.startswith(b"RIFF") and data[8:12] == b"WAVE"):
        raise RuntimeError(f"invalid WAV signature: {path_text}")
    print(f"local runtime asset OK: {path_text} ({len(data)} bytes, {actual_blob})")


def validate_source_archive(path_text: str, expected_sha256: str) -> None:
    path = ROOT / path_text
    if not path.is_file():
        raise RuntimeError(f"missing vendored VFX source archive: {path_text}")
    data = path.read_bytes()
    actual = hashlib.sha256(data).hexdigest()
    if actual != expected_sha256:
        raise RuntimeError(
            f"VFX source archive changed unexpectedly: {path_text}; "
            f"expected sha256 {expected_sha256}, got {actual}"
        )
    if not data.startswith(b"PK"):
        raise RuntimeError(f"invalid ZIP signature: {path_text}")
    print(f"vendored VFX source OK: {path_text} ({len(data)} bytes, sha256={actual})")


def validate_no_runtime_network_references() -> None:
    candidates: list[Path] = [ROOT / "project.godot"]
    for root in RUNTIME_TEXT_ROOTS:
        if not root.exists():
            continue
        for path in root.rglob("*"):
            if path.is_file() and path.suffix.lower() in {".gd", ".tscn", ".tres", ".godot"}:
                candidates.append(path)

    violations: list[str] = []
    for path in candidates:
        text = path.read_text(encoding="utf-8", errors="replace")
        for marker in NETWORK_RUNTIME_MARKERS:
            if marker in text:
                violations.append(f"{path.relative_to(ROOT)} contains {marker!r}")
    if violations:
        raise RuntimeError(
            "runtime network dependency detected; game assets/data must load from res:// only:\n- "
            + "\n- ".join(violations)
        )
    print(f"runtime network scan OK: {len(candidates)} project files contain no HTTP/WebSocket clients or URLs")


def main() -> None:
    for path_text, expected_blob in EXPECTED_BLOBS.items():
        validate_binary(path_text, expected_blob)
    for path_text, expected_sha256 in EXPECTED_SOURCE_SHA256.items():
        validate_source_archive(path_text, expected_sha256)
    validate_no_runtime_network_references()
    print(
        f"validated {len(EXPECTED_BLOBS)} runtime assets and "
        f"{len(EXPECTED_SOURCE_SHA256)} reproducible VFX source archives"
    )


if __name__ == "__main__":
    main()
