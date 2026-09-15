#!/usr/bin/env python3
"""Temporary one-shot materializer for the audited Blue Greymon Xros sources."""
from __future__ import annotations

import json
from pathlib import Path

GENERATOR = Path("tools/build_additional_ds_fields.py")
CONFIG = Path("database/ds-additional-sources.json")

DIRECT_SPECIES = {
    "Blue Greymon": {
        "source_id": None,
        "source_member": None,
        "source_sha256": "4e232dff3b5855ba59f0f77dae583aa9110d6c89edd3fc45a9ca5dac68469278",
        "source_url": "https://i874.photobucket.com/albums/ab308/WtWSprites/Super%20Xros%20Wars/GreymonXrosBlue.png",
        "profile": "two_rows_of_six",
        "pattern": "canonical_rows",
    },
    "Blue Metal Greymon": {
        "source_id": None,
        "source_member": None,
        "source_sha256": "9312fefc9131db7fbb819dde611a1abe482b3ab10c026ded4532d4f7e9788bed",
        "source_url": "https://i874.photobucket.com/albums/ab308/WtWSprites/Super%20Xros%20Wars/MetalGreymonXros.png",
        "profile": "two_rows_of_six",
        "pattern": "canonical_rows",
    },
}


def patch_generator() -> None:
    text = GENERATOR.read_text(encoding="utf-8")

    old_metadata = '        "source_archive_file": str(spec["source_member"]),\n'
    new_metadata = '        "source_archive_file": spec.get("source_member"),\n'
    if old_metadata in text:
        text = text.replace(old_metadata, new_metadata, 1)
    elif new_metadata not in text:
        raise RuntimeError("Could not locate source_archive_file metadata assignment")

    old_payload = '        payload = source_member(archive, str(spec["source_member"]))\n'
    new_payload = '''        pinned_member = spec.get("source_member")\n        if pinned_member:\n            payload = source_member(archive, str(pinned_member))\n        else:\n            source_url = str(spec.get("source_url") or "").strip()\n            if not source_url:\n                raise RuntimeError(f"{name}: source_member or source_url is required")\n            payload = fetch(source_url)\n'''
    if old_payload in text:
        text = text.replace(old_payload, new_payload, 1)
    elif new_payload not in text:
        raise RuntimeError("Could not locate pinned archive payload read")

    GENERATOR.write_text(text, encoding="utf-8")


def patch_config() -> None:
    data = json.loads(CONFIG.read_text(encoding="utf-8"))
    species = data.setdefault("species", {})
    for name, spec in DIRECT_SPECIES.items():
        species[name] = spec
    CONFIG.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")


def main() -> None:
    patch_generator()
    patch_config()
    print("Configured audited direct-source Blue Greymon batch.")


if __name__ == "__main__":
    main()
