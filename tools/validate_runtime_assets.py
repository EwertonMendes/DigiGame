#!/usr/bin/env python3
"""Validate that every runtime-critical asset is committed and local.

Fetch scripts remain in the repository only as reproducible provenance tools. The game
and its normal Web CI must not depend on them. This validator intentionally uses only
Python's standard library so the asset check itself needs no network access.
"""
from __future__ import annotations

import hashlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

# Git blob SHA-1 values make these checks directly comparable with the pinned source
# records already used by the old fetchers and with GitHub's own file metadata.
EXPECTED_BLOBS = {
    "assets/terrain/kenney/grass.png": "cb244de5ff52525b5afb7d8d64ce3180d0c32f54",
    "assets/terrain/kenney/earth.png": "c7d48eea143016d148d46db5d1ffad8b234078fa",
    "assets/terrain/kenney/lush_grass.png": "fd1e55397462fcb347f62e3763bbbc53ff666583",
    "assets/vfx/kenney/slash_03.png": "31f250ab448fcd8c767a4960c6fbc7105b326fa5",
    "assets/vfx/kenney/spark_04.png": "6eaf328696ec8640571a69318b6211223c14224e",
    "assets/vfx/kenney/magic_03.png": "47c4a22ff7b104ec9ab8926bd6e68d8709fe7b1a",
    "assets/vfx/kenney/flare_01.png": "bd25bd874e47467e95d6623aa0364be1c619617a",
    "assets/vfx/kenney/muzzle_01.png": "ce0324cf90254f4c84f61b1b05f3a166f0e00fc0",
    "assets/ui/fonts/Rajdhani-Regular.ttf": "d25bd37233b672ef565e01d998a9412d761d7b00",
    "assets/ui/fonts/Rajdhani-SemiBold.ttf": "d43750bd05c130d36c8e7fbeb06ecd7c5d3c3b17",
    "assets/characters/agumon.png": "f5e1d3c25c9ba011373103c8768a00b50faac96d",
    "assets/characters/gabumon.png": "3fc37bf57e47a1f197ad2ee684d9ae056d3566f9",
    "assets/characters/greymon.png": "acc466df89f3854954fee6e110d30ebc233004d1",
    "assets/characters/koromon.png": "7be3ffad6cf60fd35e1f31e08052fff4b9e7b6f8",
    "assets/characters/tanemon.png": "53da8d44945acfab69505ba2d7e111aab19f97bb",
    "assets/characters/veemon/field.png": "4de1db9fac82ae76ff285bf53f5b8280e2939a22",
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
    print(f"local runtime asset OK: {path_text} ({len(data)} bytes, {actual_blob})")


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
    validate_no_runtime_network_references()
    print(f"validated {len(EXPECTED_BLOBS)} vendored runtime assets")


if __name__ == "__main__":
    main()
