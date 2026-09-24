#!/usr/bin/env python3
"""Fast no-dependency guard against stale generated Additional DS runtime assets."""
from __future__ import annotations

import json
import re
from pathlib import Path

CONFIG = Path("database/ds-additional-sources.json")
MANIFEST = Path("database/additional-ds-playables.json")
DIRECTIONS = ["down_left", "down_right", "up_left", "up_right"]


def compact_key(value: str) -> str:
    return re.sub(r"[^a-z0-9]+", "", value.lower())


def main() -> None:
    config = json.loads(CONFIG.read_text(encoding="utf-8"))
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    patterns = config.get("patterns", {})
    species = config.get("species", {})

    if config.get("canonical_runtime_order") != DIRECTIONS:
        raise RuntimeError("Additional DS config direction order is not canonical")
    if manifest.get("canonical_runtime_order") != DIRECTIONS:
        raise RuntimeError("Additional DS manifest direction order is not canonical")

    rows = {str(row["name"]): row for row in manifest.get("species", [])}
    if set(rows) != set(species):
        raise RuntimeError(
            f"Additional DS manifest species drifted: expected={sorted(species)} actual={sorted(rows)}"
        )
    if int(manifest.get("count", -1)) != len(species):
        raise RuntimeError("Additional DS manifest count drifted")

    for name, spec in species.items():
        pattern_name = str(spec["pattern"])
        if pattern_name not in patterns:
            raise RuntimeError(f"{name}: unknown direction pattern {pattern_name}")
        permutation = [int(value) for value in patterns[pattern_name]]
        if sorted(permutation) != [0, 1, 2, 3]:
            raise RuntimeError(f"{name}: invalid direction permutation {permutation}")

        key = compact_key(name)
        meta_path = Path("assets/characters") / key / "field.json"
        field_path = Path("assets/characters") / key / "field.png"
        resource_path = Path("assets/resources") / f"{name.lower()}.tres"
        for path in (meta_path, field_path, resource_path):
            if not path.exists() or path.stat().st_size <= 0:
                raise RuntimeError(f"{name}: missing generated runtime asset {path}")

        meta = json.loads(meta_path.read_text(encoding="utf-8"))
        if meta.get("review_pattern") != pattern_name:
            raise RuntimeError(
                f"{name}: stale field metadata pattern; config={pattern_name} generated={meta.get('review_pattern')}"
            )
        if meta.get("runtime_group_indices") != permutation:
            raise RuntimeError(
                f"{name}: stale field direction mapping; config={permutation} generated={meta.get('runtime_group_indices')}"
            )
        if meta.get("source_sha256") != spec.get("source_sha256"):
            raise RuntimeError(f"{name}: generated field source SHA drifted")
        if meta.get("horizontal_mirror_from", {}) != spec.get("horizontal_mirror_from", {}):
            raise RuntimeError(f"{name}: generated horizontal mirror policy drifted")

        row = rows[name]
        if row.get("pattern") != pattern_name:
            raise RuntimeError(f"{name}: stale generated manifest pattern")
        if row.get("field_sprite") != f"res://assets/characters/{key}/field.png":
            raise RuntimeError(f"{name}: generated manifest field path drifted")

    print(f"additional DS generated-asset sync passed: {len(species)} species")


if __name__ == "__main__":
    main()
