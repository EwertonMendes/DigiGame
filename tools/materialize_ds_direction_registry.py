#!/usr/bin/env python3
"""Materialize exact DS source rectangles from the reviewed semantic map.

This is intentionally a two-phase pipeline:
1. database/ds-direction-review-map.json is the human-reviewed semantic truth.
2. this script fresh-downloads the original WtW archive and turns each reviewed
   group mapping into exact x/y/w/h rectangles plus a pinned source SHA-256.

No direction is inferred from row position here. Row/group detection only finds
four authored movement groups; the reviewed per-species map decides what each
of those groups *means* relative to Agumon's runtime contract.
"""
from __future__ import annotations

import hashlib
import io
import json
from pathlib import Path
from typing import Any

from PIL import Image

from build_early_rank_ds_fields import WTW_IDS, _components, _group_by_y, load_wtw_archive

REVIEW_MAP = Path("database/ds-direction-review-map.json")
REGISTRY = Path("database/ds-direction-registry.json")
DIRECTION_ORDER = ("down_left", "down_right", "up_left", "up_right")
EXPECTED_REGRESSIONS = {
    "Agumon": [0, 1, 2, 3],
    "BlackAgumon": [2, 3, 0, 1],
    "Candlemon": [2, 3, 0, 1],
    "Chicchimon": [2, 3, 0, 1],
    "Koromon": [0, 2, 1, 3],
}


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def exact_box(component: dict[str, float]) -> dict[str, int]:
    return {key: int(component[key]) for key in ("x", "y", "w", "h")}


def candidate_groups(image: Image.Image) -> tuple[tuple[int, int, int], list[list[dict[str, float]]]]:
    background, components = _components(image)
    candidates = [
        item
        for item in components
        if 10 <= item["w"] <= 50
        and 10 <= item["h"] <= 50
        and item["area"] >= 100
    ]
    groups = _group_by_y(candidates)
    for group in groups:
        group.sort(key=lambda item: item["cx"])
    return background, groups


def authored_groups(image: Image.Image, sprite_id: int) -> tuple[tuple[int, int, int], list[list[dict[str, int]]], str]:
    """Find four source movement triples without assigning direction semantics."""
    background, groups = candidate_groups(image)

    six_rows = [group for group in groups if len(group) == 6]
    if len(six_rows) == 2:
        rows = sorted(six_rows, key=lambda group: sum(item["cy"] for item in group) / len(group))
        raw = [rows[0][:3], rows[0][3:6], rows[1][:3], rows[1][3:6]]
        return background, [[exact_box(item) for item in group] for group in raw], "two_rows_of_six"

    # Kudamon includes additional poses on the movement rows.
    if sprite_id == 72:
        movement_rows = [group for group in groups if len(group) >= 6]
        movement_rows = sorted(
            movement_rows,
            key=lambda group: sum(item["cy"] for item in group) / len(group),
        )[-2:]
        if len(movement_rows) != 2:
            raise RuntimeError("Kudamon movement rows were not detected")
        rows = [sorted(group, key=lambda item: item["cx"])[:6] for group in movement_rows]
        raw = [rows[0][:3], rows[0][3:6], rows[1][:3], rows[1][3:6]]
        return background, [[exact_box(item) for item in group] for group in raw], "kudamon_two_rows"

    # Compact sheets have one movement triple per row on the right. This finds
    # the four triples only; ds-direction-review-map.json supplies their meaning.
    triples: list[tuple[float, float, list[dict[str, float]]]] = []
    for group in groups:
        if len(group) < 3:
            continue
        ordered = sorted(group, key=lambda item: item["cx"])
        triple = ordered[-3:]
        triples.append(
            (
                sum(item["cx"] for item in triple) / 3.0,
                sum(item["cy"] for item in triple) / 3.0,
                triple,
            )
        )
    selected = sorted(triples, key=lambda item: item[0], reverse=True)[:4]
    selected.sort(key=lambda item: item[1])
    if len(selected) != 4:
        raise RuntimeError(f"{sprite_id:03d}: could not detect four authored movement groups")
    return background, [[exact_box(item) for item in triple] for _, _, triple in selected], "compact_four_groups"


def source_member(archive, sprite_id: int) -> str:
    prefix = f"sprite thread/{sprite_id:03d}_"
    matches = [
        name
        for name in archive.namelist()
        if name.startswith(prefix) and name.lower().endswith((".png", ".gif"))
    ]
    if len(matches) != 1:
        raise RuntimeError(f"{sprite_id:03d}: expected exactly one original source, found {matches}")
    return matches[0]


def load_review_map() -> dict[str, Any]:
    data = json.loads(REVIEW_MAP.read_text(encoding="utf-8"))
    if data.get("canonical_reference") != "Agumon":
        raise RuntimeError("Review map canonical reference must be Agumon")
    if data.get("canonical_runtime_order") != list(DIRECTION_ORDER):
        raise RuntimeError("Review map runtime order does not match DigiGame")
    species = data.get("species", {})
    if set(species) != set(WTW_IDS):
        raise RuntimeError(
            f"Review map must cover exactly all {len(WTW_IDS)} WtW species; "
            f"missing={sorted(set(WTW_IDS) - set(species))}, extra={sorted(set(species) - set(WTW_IDS))}"
        )
    patterns = data.get("patterns", {})
    for name, permutation in patterns.items():
        if sorted(permutation) != [0, 1, 2, 3]:
            raise RuntimeError(f"Invalid direction permutation {name}: {permutation}")
    return data


def main() -> None:
    review = load_review_map()
    review_bytes = REVIEW_MAP.read_bytes()
    archive = load_wtw_archive()  # fresh download on every materialization run
    registry_species: dict[str, Any] = {}

    for name, sprite_id in sorted(WTW_IDS.items(), key=lambda item: item[1]):
        member = source_member(archive, sprite_id)
        payload = archive.read(member)
        image = Image.open(io.BytesIO(payload)).convert("RGBA")
        background, groups, layout = authored_groups(image, sprite_id)
        if len(groups) != 4 or any(len(group) != 3 for group in groups):
            raise RuntimeError(f"{name}: structural extraction did not yield 4x3 movement frames")

        pattern_name = str(review["species"][name])
        permutation = list(review["patterns"].get(pattern_name, []))
        if sorted(permutation) != [0, 1, 2, 3]:
            raise RuntimeError(f"{name}: unknown/invalid reviewed pattern {pattern_name}")

        frames = {
            direction: groups[permutation[index]]
            for index, direction in enumerate(DIRECTION_ORDER)
        }
        source_group_order: list[str | None] = [None, None, None, None]
        for runtime_index, source_index in enumerate(permutation):
            source_group_order[source_index] = DIRECTION_ORDER[runtime_index]

        registry_species[name] = {
            "source_id": sprite_id,
            "source_member": member,
            "source_sha256": sha256(payload),
            "source_size": [image.width, image.height],
            "background_rgb": list(background),
            "layout": layout,
            "review_pattern": pattern_name,
            "runtime_group_indices": permutation,
            "source_group_order": source_group_order,
            "frames": frames,
        }
        print(f"materialized {sprite_id:03d} {name}: {pattern_name} {permutation}")

    for name, expected in EXPECTED_REGRESSIONS.items():
        actual = registry_species[name]["runtime_group_indices"]
        if actual != expected:
            raise RuntimeError(f"Regression mapping changed for {name}: expected {expected}, got {actual}")

    payload = {
        "schema_version": 2,
        "canonical_reference": "Agumon",
        "canonical_runtime_order": list(DIRECTION_ORDER),
        "frames_per_direction": 3,
        "source_policy": "fresh-download source, detect groups structurally, assign semantics only from reviewed per-species map",
        "review_map": "database/ds-direction-review-map.json",
        "review_map_sha256": sha256(review_bytes),
        "species_count": len(registry_species),
        "species": registry_species,
    }
    if len(registry_species) != 82:
        raise RuntimeError(f"Expected 82 official WtW species, got {len(registry_species)}")
    REGISTRY.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
    print(f"wrote {REGISTRY}: 82/82 species with exact audited boxes")


if __name__ == "__main__":
    main()
