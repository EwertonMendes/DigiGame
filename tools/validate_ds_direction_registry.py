#!/usr/bin/env python3
"""Validate exact audited DS direction coordinates and generated metadata."""
from __future__ import annotations

import json
from pathlib import Path

from build_early_rank_ds_fields import WTW_IDS, portrait_key

REGISTRY = Path("database/ds-direction-registry.json")
REVIEW_MAP = Path("database/ds-direction-review-map.json")
DIRECTIONS = ["down_left", "down_right", "up_left", "up_right"]
PHASES = ["idle", "step_a", "step_b"]


def expected_source_group_order(permutation: list[int]) -> list[str]:
    source_order: list[str | None] = [None, None, None, None]
    for runtime_index, source_index in enumerate(permutation):
        source_order[source_index] = DIRECTIONS[runtime_index]
    if any(direction is None for direction in source_order):
        raise AssertionError(("invalid permutation", permutation, source_order))
    return [str(direction) for direction in source_order]


def main() -> None:
    data = json.loads(REGISTRY.read_text(encoding="utf-8"))
    review = json.loads(REVIEW_MAP.read_text(encoding="utf-8"))

    assert data["schema_version"] >= 3
    assert data["canonical_reference"] == "Agumon"
    assert data["canonical_runtime_order"] == DIRECTIONS
    assert data["frames_per_direction"] == 3
    assert data["canonical_runtime_phases"] == PHASES
    assert "reviewed per-direction phase order" in data["source_policy"]
    assert len(data["review_map_sha256"]) == 64

    assert review["canonical_reference"] == "Agumon"
    assert review["canonical_runtime_order"] == DIRECTIONS
    patterns = review["patterns"]
    declared_source_orders = review.get("pattern_source_group_order", {})
    assert set(declared_source_orders) == set(patterns)
    for pattern_name, permutation in patterns.items():
        assert sorted(permutation) == [0, 1, 2, 3], (pattern_name, permutation)
        assert declared_source_orders[pattern_name] == expected_source_group_order(permutation), (
            pattern_name,
            declared_source_orders[pattern_name],
            expected_source_group_order(permutation),
        )

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
        assert spec["source_group_order"] == expected_source_group_order(permutation), (
            name,
            spec["source_group_order"],
            expected_source_group_order(permutation),
        )
        assert spec["review_pattern"] == review["species"][name], (name, spec["review_pattern"], review["species"][name])
        assert permutation == patterns[spec["review_pattern"]], (name, spec["review_pattern"], permutation)
        assert spec["canonical_runtime_phases"] == PHASES, name
        assert spec["anchor_policy"] == "bottom_center_in_uniform_species_cell", name
        assert set(spec["source_frame_order"]) == set(DIRECTIONS), name
        for direction, order in spec["source_frame_order"].items():
            assert sorted(order) == [0, 1, 2], (name, direction, order)
        assert set(spec["pose_alignment"]) == {"down_right", "up_right"}, name
        for direction, alignment in spec["pose_alignment"].items():
            assert alignment["source_phase_order"] == spec["source_frame_order"][direction], (name, direction)
            assert int(alignment["pixel_error"]) >= 0, (name, direction)
            assert int(alignment["confidence_margin"]) >= 0, (name, direction)
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

    # Regression truth is data-driven. Source-sheet conventions belong in the
    # reviewed semantic map, never in runtime species conditionals or Python
    # name-specific facing hacks.
    for name, pattern_name in review.get("regression_cases", {}).items():
        expected = patterns[pattern_name]
        actual = species[name]["runtime_group_indices"]
        assert actual == expected, (name, pattern_name, expected, actual)
        assert species[name]["review_pattern"] == pattern_name, (
            name,
            pattern_name,
            species[name]["review_pattern"],
        )

    for name, expected in review.get("phase_regression_cases", {}).items():
        actual = species[name]["source_frame_order"]
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
        assert meta.get("source_group_order") == spec["source_group_order"], name
        assert meta.get("canonical_runtime_phases") == PHASES, name
        assert meta.get("source_frame_order") == spec["source_frame_order"], name
        assert meta.get("pose_alignment") == spec["pose_alignment"], name
        assert meta.get("anchor_policy") == spec["anchor_policy"], name
        assert meta.get("frame_anchor") == [int(meta["cell_width"]) // 2, int(meta["cell_height"]) - 1], name
        assert meta.get("audited_source_frames") == spec["frames"], name
        assert meta.get("directions") == DIRECTIONS, name
        generated += 1

    if generated not in (0, 81):
        raise RuntimeError(f"Partial exact-registry generation detected: {generated}/81 official non-Agumon sprites")
    print(f"DS direction/phase registry valid: 82/82 exact mappings; generated metadata checked={generated}/81")


if __name__ == "__main__":
    main()
