#!/usr/bin/env python3
"""Validate exact audited DS direction coordinates and generated metadata."""
from __future__ import annotations

import json
from pathlib import Path

from build_early_rank_ds_fields import WTW_IDS, portrait_key

REGISTRY = Path("database/ds-direction-registry.json")
DIRECTIONS = ["down_left", "down_right", "up_left", "up_right"]
KNOWN_REGRESSIONS = {
    "Agumon": [0, 1, 2, 3],
    "BlackAgumon": [2, 3, 0, 1],
    "Candlemon": [2, 3, 0, 1],
    "Chicchimon": [2, 3, 0, 1],
    "Koromon": [0, 2, 1, 3],
}


def main() -> None:
    data = json.loads(REGISTRY.read_text(encoding="utf-8"))
    assert data["schema_version"] >= 2
    assert data["canonical_reference"] == "Agumon"
    assert data["canonical_runtime_order"] == DIRECTIONS
    assert data["frames_per_direction"] == 3
    assert "semantics only from reviewed per-species map" in data["source_policy"]
    assert len(data["review_map_sha256"]) == 64

    species = data["species"]
    assert data["species_count"] == 82
    assert set(species) == set(WTW_IDS), (
        sorted(set(WTW_IDS) - set(species)),
        sorted(set(species) - set(WTW_IDS)),
    )

    for name, spec in species.items():
        assert int(spec["source_id"]) == WTW_IDS[name], name
        assert len(spec["source_sha256"]) == 64, name
        assert len(spec["background_rgb"]) == 3, name
        permutation = spec["runtime_group_indices"]
        assert sorted(permutation) == [0, 1, 2, 3], (name, permutation)
        assert sorted(spec["source_group_order"]) == DIRECTIONS, (name, spec["source_group_order"])
        assert list(spec["frames"]) == DIRECTIONS, name
        seen: list[tuple[int, int, int, int]] = []
        for direction in DIRECTIONS:
            boxes = spec["frames"][direction]
            assert len(boxes) == 3, (name, direction)
            for box in boxes:
                assert set(box) == {"x", "y", "w", "h"}, (name, direction, box)
                assert box["x"] >= 0 and box["y"] >= 0 and box["w"] > 0 and box["h"] > 0, (name, direction, box)
                seen.append((box["x"], box["y"], box["w"], box["h"]))
        assert len(seen) == 12 and len(set(seen)) == 12, name

    for name, expected in KNOWN_REGRESSIONS.items():
        actual = species[name]["runtime_group_indices"]
        assert actual == expected, (name, expected, actual)

    # When the rebuild has already run, prove every official non-Agumon output
    # was produced through this exact registry rather than an older heuristic.
    database = json.loads(Path("database/base-digimon-list.json").read_text(encoding="utf-8"))
    by_name = {str(row.get("name")): row for row in database}
    generated = 0
    for name in WTW_IDS:
        if name == "Agumon":
            continue
        row = by_name[name]
        meta_path = Path("assets/characters") / portrait_key(row) / "field.json"
        if not meta_path.exists():
            continue
        meta = json.loads(meta_path.read_text(encoding="utf-8"))
        spec = species[name]
        assert meta.get("source_variant") == "withthewill_audited_exact_boxes", name
        assert meta.get("direction_registry") == "res://database/ds-direction-registry.json", name
        assert meta.get("source_sha256") == spec["source_sha256"], name
        assert meta.get("runtime_group_indices") == spec["runtime_group_indices"], name
        assert meta.get("audited_source_frames") == spec["frames"], name
        assert meta.get("directions") == DIRECTIONS, name
        generated += 1

    if generated not in (0, 81):
        raise RuntimeError(f"Partial exact-registry generation detected: {generated}/81 official non-Agumon sprites")
    print(f"DS direction registry valid: 82/82 exact mappings; generated metadata checked={generated}/81")


if __name__ == "__main__":
    main()
