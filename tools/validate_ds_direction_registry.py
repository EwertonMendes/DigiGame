#!/usr/bin/env python3
"""Fail closed if the exact audited DS direction registry is incomplete."""
from __future__ import annotations

import json
from pathlib import Path

from build_early_rank_ds_fields import WTW_IDS

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

    print("DS direction registry valid: 82/82 official species have explicit audited source boxes")


if __name__ == "__main__":
    main()
