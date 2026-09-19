#!/usr/bin/env python3
"""Validate the canonical Digi Game application icon and export wiring."""

from __future__ import annotations

from pathlib import Path
import struct
import sys

ROOT = Path(__file__).resolve().parents[1]
ICON = ROOT / "assets/ui/icons/favicon.png"
ANDROID_BACKGROUND = ROOT / "assets/ui/icons/android_adaptive_background.svg"
PROJECT = ROOT / "project.godot"
PRESETS = ROOT / "export_presets.cfg"

RESOURCE_ICON = "res://assets/ui/icons/favicon.png"
RESOURCE_ANDROID_BACKGROUND = "res://assets/ui/icons/android_adaptive_background.svg"


def fail(message: str) -> None:
    print(f"App icon validation failed: {message}", file=sys.stderr)
    raise SystemExit(1)


def read_png_size(path: Path) -> tuple[int, int]:
    data = path.read_bytes()[:24]
    if len(data) < 24 or data[:8] != b"\x89PNG\r\n\x1a\n":
        fail(f"{path.relative_to(ROOT)} is not a valid PNG file.")
    if data[12:16] != b"IHDR":
        fail(f"{path.relative_to(ROOT)} is missing a PNG IHDR header.")
    return struct.unpack(">II", data[16:24])


def require(text: str, value: str, source: str) -> None:
    if value not in text:
        fail(f"{source} is missing {value!r}.")


def main() -> None:
    if not ICON.is_file():
        fail("assets/ui/icons/favicon.png does not exist.")
    width, height = read_png_size(ICON)
    if width != height:
        fail(f"favicon.png must be square, got {width}x{height}.")
    if width < 512:
        fail(
            f"favicon.png must be at least 512x512 so Android adaptive and Web/PWA "
            f"icons can be generated cleanly, got {width}x{height}."
        )

    if not ANDROID_BACKGROUND.is_file():
        fail("Android adaptive icon background is missing.")

    project = PROJECT.read_text(encoding="utf-8")
    presets = PRESETS.read_text(encoding="utf-8")

    require(project, f'config/icon="{RESOURCE_ICON}"', "project.godot")

    required_preset_entries = (
        f'progressive_web_app/icon_144x144="{RESOURCE_ICON}"',
        f'progressive_web_app/icon_180x180="{RESOURCE_ICON}"',
        f'progressive_web_app/icon_512x512="{RESOURCE_ICON}"',
        f'application/icon="{RESOURCE_ICON}"',
        f'launcher_icons/main_192x192="{RESOURCE_ICON}"',
        f'launcher_icons/adaptive_foreground_432x432="{RESOURCE_ICON}"',
        f'launcher_icons/adaptive_background_432x432="{RESOURCE_ANDROID_BACKGROUND}"',
    )
    for entry in required_preset_entries:
        require(presets, entry, "export_presets.cfg")

    if presets.count(f'application/icon="{RESOURCE_ICON}"') < 2:
        fail("Windows and macOS export presets must both use favicon.png.")

    print(
        f"App icon configuration OK: favicon.png is {width}x{height} and is wired "
        "to project, Web/PWA, Windows, macOS, Android and Linux runtime fallback."
    )


if __name__ == "__main__":
    main()
