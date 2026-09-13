#!/usr/bin/env python3
"""Explicit semantic direction registry for the DS overworld sprite sources.

Geometric extraction and semantic facing are intentionally separate concerns:
source sheets may place the four walk groups in different physical positions.
The registry records the reviewed meaning of each physical group.  No caller is
allowed to infer down/up/left/right from row or group position.
"""
from __future__ import annotations

import json
from pathlib import Path
from typing import Any

from PIL import Image

from build_early_rank_ds_fields import WTW_IDS, _components, _group_by_y

REGISTRY_PATH = Path("database/ds-source-direction-registry.json")
DIRECTIONS = ("down_left", "down_right", "up_left", "up_right")
EXPECTED_GOLDEN_MAPPING = {
    "down_left": 0,
    "down_right": 1,
    "up_left": 3,
    "up_right": 2,
}


def load_registry() -> dict[str, Any]:
    data = json.loads(REGISTRY_PATH.read_text(encoding="utf-8"))
    if data.get("schema_version") != 1:
        raise RuntimeError("Unsupported DS direction registry schema")
    if data.get("canonical_reference") != "Agumon":
        raise RuntimeError("DS direction registry must use Agumon as canonical reference")
    if tuple(data.get("canonical_runtime_order", [])) != DIRECTIONS:
        raise RuntimeError("DS direction registry runtime order does not match DigiGame")

    entries = data.get("entries")
    if not isinstance(entries, dict):
        raise RuntimeError("DS direction registry entries must be an object")

    expected_names = set(WTW_IDS)
    actual_names = set(entries)
    if actual_names != expected_names:
        missing = sorted(expected_names - actual_names)
        extra = sorted(actual_names - expected_names)
        raise RuntimeError(f"DS direction registry coverage mismatch; missing={missing}, extra={extra}")

    seen_ids: set[int] = set()
    for name, source_id in WTW_IDS.items():
        entry = entries[name]
        if int(entry.get("source_id", -1)) != source_id:
            raise RuntimeError(f"{name}: registry source_id does not match WTW_IDS")
        if source_id in seen_ids:
            raise RuntimeError(f"Duplicate DS source id {source_id}")
        seen_ids.add(source_id)

        expected_prefix = f"sprite thread/{source_id:03d}_"
        archive_file = str(entry.get("source_archive_file", ""))
        if not archive_file.startswith(expected_prefix):
            raise RuntimeError(f"{name}: unexpected registered source file {archive_file!r}")

        layout = str(entry.get("expected_layout", ""))
        if layout not in {"two_rows_of_six", "compact_four_groups", "kudamon_two_rows"}:
            raise RuntimeError(f"{name}: unsupported registered layout {layout!r}")

        groups = entry.get("groups")
        if not isinstance(groups, dict) or set(groups) != set(DIRECTIONS):
            raise RuntimeError(f"{name}: registry must define all four semantic directions")
        values = [int(groups[direction]) for direction in DIRECTIONS]
        if sorted(values) != [0, 1, 2, 3]:
            raise RuntimeError(f"{name}: semantic groups must be a one-to-one permutation of G0..G3")

        frame_orders = entry.get("frame_order", {})
        if frame_orders and not isinstance(frame_orders, dict):
            raise RuntimeError(f"{name}: frame_order must be an object when provided")
        for direction, order in frame_orders.items():
            if direction not in DIRECTIONS or sorted(int(value) for value in order) != [0, 1, 2]:
                raise RuntimeError(f"{name}: invalid frame order for {direction}")

        if not str(entry.get("audit", "")).strip():
            raise RuntimeError(f"{name}: missing manual audit marker")

    if entries["Agumon"]["groups"] != EXPECTED_GOLDEN_MAPPING:
        raise RuntimeError("Agumon registry mapping changed from the reviewed golden reference")
    return data


def _candidate_groups(image: Image.Image) -> tuple[tuple[int, int, int], list[list[dict[str, float]]]]:
    background, all_components = _components(image)
    candidates = [
        item
        for item in all_components
        if 10 <= item["w"] <= 50
        and 10 <= item["h"] <= 50
        and item["area"] >= 100
    ]
    groups = _group_by_y(candidates)
    for group in groups:
        group.sort(key=lambda item: item["cx"])
    return background, groups


def extract_physical_groups(
    image: Image.Image,
    sprite_id: int,
) -> tuple[tuple[int, int, int], list[list[dict[str, float]]], str]:
    """Extract physical G0..G3 without assigning semantic directions."""
    background, groups = _candidate_groups(image)

    six_rows = [group for group in groups if len(group) == 6]
    if len(six_rows) == 2:
        rows = sorted(six_rows, key=lambda group: sum(item["cy"] for item in group) / len(group))
        rows = [sorted(group, key=lambda item: item["cx"]) for group in rows]
        physical = [rows[0][:3], rows[0][3:6], rows[1][:3], rows[1][3:6]]
        return background, physical, "two_rows_of_six"

    if sprite_id == 72:
        movement_rows = [group for group in groups if len(group) >= 6]
        movement_rows = sorted(
            movement_rows,
            key=lambda group: sum(item["cy"] for item in group) / len(group),
        )[-2:]
        if len(movement_rows) != 2:
            raise RuntimeError("Kudamon movement rows were not detected")
        rows = [sorted(group, key=lambda item: item["cx"])[:6] for group in movement_rows]
        physical = [rows[0][:3], rows[0][3:6], rows[1][:3], rows[1][3:6]]
        return background, physical, "kudamon_two_rows"

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
        raise RuntimeError(f"{sprite_id:03d}: could not detect four physical movement groups")
    return background, [item[2] for item in selected], "compact_four_groups"


def select_registered_left_groups(
    image: Image.Image,
    sprite_id: int,
    registry: dict[str, Any] | None = None,
) -> tuple[tuple[int, int, int], list[dict[str, float]], list[dict[str, float]], dict[str, Any]]:
    """Resolve reviewed down-left/up-left groups for one original WtW source."""
    registry = registry or load_registry()
    by_id = {int(entry["source_id"]): (name, entry) for name, entry in registry["entries"].items()}
    if sprite_id not in by_id:
        raise RuntimeError(f"{sprite_id:03d}: no reviewed semantic direction registry entry")
    name, entry = by_id[sprite_id]

    background, physical_groups, detected_layout = extract_physical_groups(image, sprite_id)
    expected_layout = str(entry["expected_layout"])
    if detected_layout != expected_layout:
        raise RuntimeError(
            f"{name}: source geometry changed; registry expects {expected_layout}, detected {detected_layout}"
        )
    if len(physical_groups) != 4 or any(len(group) != 3 for group in physical_groups):
        raise RuntimeError(f"{name}: expected exactly four physical groups of three frames")

    groups = {direction: int(entry["groups"][direction]) for direction in DIRECTIONS}
    default_order = [int(value) for value in registry.get("default_frame_order", [0, 1, 2])]
    per_direction_orders = entry.get("frame_order", {})

    def resolve(direction: str) -> list[dict[str, float]]:
        group = physical_groups[groups[direction]]
        order = [int(value) for value in per_direction_orders.get(direction, default_order)]
        if sorted(order) != [0, 1, 2]:
            raise RuntimeError(f"{name}: invalid registered frame order for {direction}")
        return [group[index] for index in order]

    inverse = [None, None, None, None]
    for direction, group_index in groups.items():
        inverse[group_index] = direction

    return background, resolve("down_left"), resolve("up_left"), {
        "source_layout": detected_layout,
        "source_group_order": inverse,
        "registered_direction_groups": groups,
        "registered_frame_order": {
            direction: [int(value) for value in per_direction_orders.get(direction, default_order)]
            for direction in DIRECTIONS
        },
        "semantic_mapping_source": "database/ds-source-direction-registry.json",
        "semantic_mapping_audit": entry["audit"],
        "authored_groups_used": [groups["down_left"], groups["up_left"]],
    }
