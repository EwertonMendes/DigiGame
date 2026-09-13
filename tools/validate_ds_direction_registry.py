#!/usr/bin/env python3
"""Validate the reviewed DS direction registry and generated runtime metadata."""
from __future__ import annotations

import json
from pathlib import Path

from build_early_rank_ds_fields import WTW_IDS, portrait_key
from ds_direction_registry import DIRECTIONS, REGISTRY_PATH, load_registry


def main() -> None:
    registry = load_registry()
    entries = registry["entries"]
    if len(entries) != 82:
        raise RuntimeError(f"Expected 82 reviewed WtW entries, found {len(entries)}")

    # Explicit regression guard for the concrete failure that motivated the
    # registry rewrite. BlackAgumon's source uses the opposite front/back row
    # family from Agumon and therefore must never fall back to Agumon's groups.
    expected_black = {"down_left": 2, "down_right": 3, "up_left": 1, "up_right": 0}
    if entries["BlackAgumon"]["groups"] != expected_black:
        raise RuntimeError("BlackAgumon semantic mapping regressed")
    if entries["Agumon"]["groups"] == entries["BlackAgumon"]["groups"]:
        raise RuntimeError("BlackAgumon must not reuse Agumon's physical group mapping")

    database = json.loads(Path("database/base-digimon-list.json").read_text(encoding="utf-8"))
    by_name = {str(row.get("name")): row for row in database}
    failures: list[str] = []
    generated = 0
    for name in WTW_IDS:
        if name == "Agumon":
            continue
        row = by_name.get(name)
        if row is None:
            failures.append(f"{name}: missing canonical database row")
            continue
        meta_path = Path("assets/characters") / portrait_key(row) / "field.json"
        if not meta_path.exists():
            failures.append(f"{name}: missing generated metadata")
            continue
        meta = json.loads(meta_path.read_text(encoding="utf-8"))
        expected = {direction: int(entries[name]["groups"][direction]) for direction in DIRECTIONS}
        if meta.get("registered_direction_groups") != expected:
            failures.append(f"{name}: field.json mapping differs from reviewed registry")
        if meta.get("semantic_mapping_source") != str(REGISTRY_PATH):
            failures.append(f"{name}: field.json was not generated through the registry")
        if meta.get("source_archive_file") != entries[name]["source_archive_file"]:
            failures.append(f"{name}: generated source member differs from reviewed registry")
        generated += 1

    if generated != 81:
        failures.append(f"Expected 81 generated WtW metadata files besides Agumon, got {generated}")
    if failures:
        raise RuntimeError("DS registry validation failed:\n- " + "\n- ".join(failures))

    print("DS direction registry valid: 82/82 sources reviewed; 81/81 generated WtW sprites registry-backed")


if __name__ == "__main__":
    main()
