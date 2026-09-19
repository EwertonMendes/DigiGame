#!/usr/bin/env python3
"""Inject CI release metadata into Godot project/export configuration.

The repository keeps platform presets stable and version-agnostic. Release builds
call this script on the disposable CI checkout so a manually selected version can
be reused across as many build attempts as necessary without creating commits.
"""

from __future__ import annotations

import argparse
import re
from pathlib import Path


SEMVER_RE = re.compile(
    r"^(?P<major>0|[1-9]\d*)\.(?P<minor>0|[1-9]\d*)\.(?P<patch>0|[1-9]\d*)"
    r"(?:-(?P<prerelease>[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*))?$"
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--version", required=True, help="Release version, with or without a leading v.")
    parser.add_argument("--version-code", required=True, type=int, help="Positive Android versionCode.")
    parser.add_argument("--project", default="project.godot")
    parser.add_argument("--presets", default="export_presets.cfg")
    return parser.parse_args()


def normalize_version(raw: str) -> tuple[str, str]:
    version = raw.strip()
    if version.startswith("v"):
        version = version[1:]

    match = SEMVER_RE.fullmatch(version)
    if match is None:
        raise SystemExit(
            "Version must use major.minor.patch or major.minor.patch-prerelease "
            "(for example 0.1.0 or 0.1.0-rc.1)."
        )

    core = f"{match.group('major')}.{match.group('minor')}.{match.group('patch')}"
    return version, core


def set_project_version(path: Path, core_version: str) -> None:
    text = path.read_text(encoding="utf-8")
    replacement = f'config/version="{core_version}"'

    if re.search(r"(?m)^config/version=", text):
        text = re.sub(r'(?m)^config/version=.*$', replacement, text, count=1)
    else:
        application_match = re.search(r"(?m)^\[application\]\s*$", text)
        if application_match is None:
            raise SystemExit(f"{path}: missing [application] section")
        insert_at = application_match.end()
        text = text[:insert_at] + f"\n\n{replacement}" + text[insert_at:]

    path.write_text(text, encoding="utf-8")


def find_preset_indices(text: str) -> dict[str, str]:
    presets: dict[str, str] = {}
    for match in re.finditer(r"(?ms)^\[preset\.(\d+)\]\s*$(.*?)(?=^\[preset\.|\Z)", text):
        index, body = match.group(1), match.group(2)
        name_match = re.search(r'(?m)^name="([^"]+)"\s*$', body)
        if name_match:
            presets[name_match.group(1)] = index
    return presets


def replace_option(text: str, preset_index: str, key: str, value: str) -> str:
    header = f"[preset.{preset_index}.options]"
    start = text.find(header)
    if start < 0:
        raise SystemExit(f"Missing {header}")

    next_section = text.find("\n[preset.", start + len(header))
    end = len(text) if next_section < 0 else next_section
    block = text[start:end]

    pattern = re.compile(rf"(?m)^{re.escape(key)}=.*$")
    if not pattern.search(block):
        raise SystemExit(f"Missing option {key!r} in preset {preset_index}")

    block = pattern.sub(f"{key}={value}", block, count=1)
    return text[:start] + block + text[end:]


def set_export_versions(path: Path, version: str, core_version: str, version_code: int) -> None:
    if version_code <= 0 or version_code > 2_100_000_000:
        raise SystemExit("Android versionCode must be between 1 and 2100000000.")

    text = path.read_text(encoding="utf-8")
    presets = find_preset_indices(text)

    required = {"Windows Desktop", "macOS", "Android"}
    missing = sorted(required - presets.keys())
    if missing:
        raise SystemExit(f"{path}: missing required presets: {', '.join(missing)}")

    windows = presets["Windows Desktop"]
    text = replace_option(text, windows, "application/file_version", f'"{core_version}.0"')
    text = replace_option(text, windows, "application/product_version", f'"{core_version}.0"')

    macos = presets["macOS"]
    text = replace_option(text, macos, "application/short_version", f'"{core_version}"')
    text = replace_option(text, macos, "application/version", f'"{core_version}"')

    android = presets["Android"]
    text = replace_option(text, android, "version/code", str(version_code))
    text = replace_option(text, android, "version/name", f'"{version}"')

    path.write_text(text, encoding="utf-8")


def main() -> None:
    args = parse_args()
    version, core_version = normalize_version(args.version)
    project_path = Path(args.project)
    presets_path = Path(args.presets)

    set_project_version(project_path, core_version)
    set_export_versions(presets_path, version, core_version, args.version_code)

    print(f"Prepared DigiGame release metadata: version={version}, versionCode={args.version_code}")


if __name__ == "__main__":
    main()
