#!/usr/bin/env python3
"""Materialize exact DS source rectangles from the reviewed semantic map.

This is intentionally a two-phase pipeline:
1. database/ds-direction-review-map.json is the human-reviewed semantic truth.
2. this script fresh-downloads the original WtW archive and turns each reviewed
   source convention into exact x/y/w/h rectangles plus a pinned source SHA-256.

No runtime species workaround exists here. Row/group detection finds authored
movement groups; the reviewed data classifies the source-sheet convention and
this materializer always emits one canonical runtime direction contract.
"""
from __future__ import annotations

import hashlib
import io
import itertools
import json
from pathlib import Path
from typing import Any

import numpy as np
from PIL import Image

from build_early_rank_ds_fields import WTW_IDS, _components, _group_by_y, load_wtw_archive

REVIEW_MAP = Path("database/ds-direction-review-map.json")
REGISTRY = Path("database/ds-direction-registry.json")
DIRECTION_ORDER = ("down_left", "down_right", "up_left", "up_right")
PHASE_ORDER = ("idle", "step_a", "step_b")


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def exact_box(component: dict[str, float]) -> dict[str, int]:
    return {key: int(component[key]) for key in ("x", "y", "w", "h")}


def expected_source_group_order(permutation: list[int]) -> list[str]:
    source_order: list[str | None] = [None, None, None, None]
    for runtime_index, source_index in enumerate(permutation):
        source_order[source_index] = DIRECTION_ORDER[runtime_index]
    if any(direction is None for direction in source_order):
        raise RuntimeError(f"Invalid direction permutation {permutation}")
    return [str(direction) for direction in source_order]


def keyed_source(image: Image.Image, background_rgb: tuple[int, int, int]) -> Image.Image:
    rgba = np.array(image.convert("RGBA"), copy=True)
    background = np.asarray(background_rgb, dtype=np.uint8)
    rgba[np.all(rgba[:, :, :3] == background, axis=2), 3] = 0
    return Image.fromarray(rgba, "RGBA")


def crop_component(source: Image.Image, box: dict[str, int]) -> Image.Image:
    x, y, w, h = (int(box[key]) for key in ("x", "y", "w", "h"))
    pad = 2
    crop = source.crop(
        (
            max(0, x - pad),
            max(0, y - pad),
            min(source.width, x + w + pad),
            min(source.height, y + h + pad),
        )
    )
    bbox = crop.getbbox()
    if bbox is None:
        raise RuntimeError(f"Source component became empty: {box}")
    return crop.crop(bbox)


def comparison_cells(
    image: Image.Image,
    background: tuple[int, int, int],
    left_boxes: list[dict[str, int]],
    right_boxes: list[dict[str, int]],
) -> tuple[list[Image.Image], list[Image.Image]]:
    source = keyed_source(image, background)
    crops = [crop_component(source, box) for box in left_boxes + right_boxes]
    cell_w = max(frame.width for frame in crops) + 4
    cell_h = max(frame.height for frame in crops) + 4
    cells: list[Image.Image] = []
    for frame in crops:
        cell = Image.new("RGBA", (cell_w, cell_h), (0, 0, 0, 0))
        cell.alpha_composite(frame, ((cell_w - frame.width) // 2, cell_h - frame.height - 1))
        cells.append(cell)
    return cells[:3], cells[3:]


def pose_match_candidates(
    image: Image.Image,
    background: tuple[int, int, int],
    left_boxes: list[dict[str, int]],
    right_boxes: list[dict[str, int]],
) -> list[tuple[int, tuple[int, int, int]]]:
    left, right = comparison_cells(image, background, left_boxes, right_boxes)
    candidates: list[tuple[int, tuple[int, int, int]]] = []
    for permutation in itertools.permutations(range(3)):
        cost = 0
        for phase, source_index in enumerate(permutation):
            mirrored = np.asarray(
                left[phase].transpose(Image.Transpose.FLIP_LEFT_RIGHT), dtype=np.int16
            )
            candidate = np.asarray(right[source_index], dtype=np.int16)
            cost += int(np.abs(mirrored - candidate).sum())
        candidates.append((cost, permutation))
    candidates.sort()
    return candidates


def reviewed_phase_order(review: dict[str, Any], name: str, direction: str) -> list[int]:
    default = review["default_source_phase_order"][direction]
    override = review.get("source_phase_overrides", {}).get(name, {}).get(direction, default)
    order = [int(index) for index in override]
    if sorted(order) != [0, 1, 2]:
        raise RuntimeError(f"{name} {direction}: invalid source phase order {order}")
    return order


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

    # Compact sheets have one authored movement triple per row. Detection finds
    # the four triples only; source semantics come from a reusable convention in
    # ds-direction-review-map.json (for example DL/UL/DR/UR or DL/UR/DR/UL).
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
    if data.get("schema_version", 0) < 2:
        raise RuntimeError("Review map does not define canonical frame phases")
    if data.get("canonical_runtime_phases") != list(PHASE_ORDER):
        raise RuntimeError("Review map phase order must be idle, step_a, step_b")

    species = data.get("species", {})
    if set(species) != set(WTW_IDS):
        raise RuntimeError(
            f"Review map must cover exactly all {len(WTW_IDS)} WtW species; "
            f"missing={sorted(set(WTW_IDS) - set(species))}, extra={sorted(set(species) - set(WTW_IDS))}"
        )

    patterns = data.get("patterns", {})
    declared_source_orders = data.get("pattern_source_group_order", {})
    if set(declared_source_orders) != set(patterns):
        raise RuntimeError("Every source convention must declare its authored source group order")
    for pattern_name, permutation in patterns.items():
        if sorted(permutation) != [0, 1, 2, 3]:
            raise RuntimeError(f"Invalid direction permutation {pattern_name}: {permutation}")
        expected_order = expected_source_group_order([int(index) for index in permutation])
        if declared_source_orders[pattern_name] != expected_order:
            raise RuntimeError(
                f"{pattern_name}: declared source order {declared_source_orders[pattern_name]} "
                f"does not match runtime permutation {permutation} -> {expected_order}"
            )

    for name, pattern_name in species.items():
        if pattern_name not in patterns:
            raise RuntimeError(f"{name}: unknown source convention {pattern_name}")

    regressions = data.get("regression_cases", {})
    if not set(regressions).issubset(species):
        raise RuntimeError(f"Unknown direction regression species: {sorted(set(regressions) - set(species))}")
    for name, pattern_name in regressions.items():
        if pattern_name not in patterns:
            raise RuntimeError(f"{name}: regression references unknown convention {pattern_name}")
        if species[name] != pattern_name:
            raise RuntimeError(
                f"{name}: regression convention {pattern_name} differs from species convention {species[name]}"
            )

    defaults = data.get("default_source_phase_order", {})
    if set(defaults) != set(DIRECTION_ORDER):
        raise RuntimeError("Review map must define a default phase order for every direction")
    for direction, order in defaults.items():
        if sorted(order) != [0, 1, 2]:
            raise RuntimeError(f"Invalid default source phase order {direction}: {order}")

    overrides = data.get("source_phase_overrides", {})
    if not set(overrides).issubset(WTW_IDS):
        raise RuntimeError(f"Unknown phase override species: {sorted(set(overrides) - set(WTW_IDS))}")
    for name, directions in overrides.items():
        if not set(directions).issubset(DIRECTION_ORDER):
            raise RuntimeError(f"{name}: unknown phase override direction")
        for direction, order in directions.items():
            if sorted(order) != [0, 1, 2]:
                raise RuntimeError(f"{name} {direction}: invalid phase override {order}")

    phase_regressions = data.get("phase_regression_cases", {})
    if not set(phase_regressions).issubset(species):
        raise RuntimeError(
            f"Unknown phase regression species: {sorted(set(phase_regressions) - set(species))}"
        )
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

        raw_frames = {
            direction: groups[permutation[index]]
            for index, direction in enumerate(DIRECTION_ORDER)
        }
        source_frame_order = {
            direction: reviewed_phase_order(review, name, direction)
            for direction in DIRECTION_ORDER
        }
        pose_alignment: dict[str, Any] = {}
        for left_direction, right_direction in (("down_left", "down_right"), ("up_left", "up_right")):
            candidates = pose_match_candidates(
                image,
                background,
                raw_frames[left_direction],
                raw_frames[right_direction],
            )
            chosen = tuple(source_frame_order[right_direction])
            chosen_cost = next(cost for cost, order in candidates if order == chosen)
            best_cost = candidates[0][0]
            if chosen_cost != best_cost:
                raise RuntimeError(
                    f"{name} {right_direction}: reviewed phase order {chosen} costs {chosen_cost}, "
                    f"but deterministic mirror-pose match prefers {candidates[0][1]} at {best_cost}"
                )
            pose_alignment[right_direction] = {
                "compared_with": left_direction,
                "source_phase_order": list(chosen),
                "pixel_error": chosen_cost,
                "confidence_margin": candidates[1][0] - candidates[0][0],
            }

        frames = {
            direction: [raw_frames[direction][source_index] for source_index in source_frame_order[direction]]
            for direction in DIRECTION_ORDER
        }
        source_group_order = expected_source_group_order([int(index) for index in permutation])
        if source_group_order != review["pattern_source_group_order"][pattern_name]:
            raise RuntimeError(
                f"{name}: materialized source order {source_group_order} differs from "
                f"review convention {review['pattern_source_group_order'][pattern_name]}"
            )

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
            "canonical_runtime_phases": list(PHASE_ORDER),
            "source_frame_order": source_frame_order,
            "pose_alignment": pose_alignment,
            "anchor_policy": "bottom_center_in_uniform_species_cell",
            "frames": frames,
        }
        print(
            f"materialized {sprite_id:03d} {name}: groups={pattern_name} {permutation} "
            f"source_order={source_group_order} phases={source_frame_order}"
        )

    # Direction and phase regression truth is itself data-driven. The Python
    # materializer intentionally contains no species-specific direction list.
    for name, pattern_name in review.get("regression_cases", {}).items():
        expected = list(review["patterns"][pattern_name])
        actual = registry_species[name]["runtime_group_indices"]
        if actual != expected:
            raise RuntimeError(
                f"Regression mapping changed for {name}: convention={pattern_name}, "
                f"expected {expected}, got {actual}"
            )

    for name, expected in review.get("phase_regression_cases", {}).items():
        actual = registry_species[name]["source_frame_order"]
        if actual != expected:
            raise RuntimeError(f"Phase regression changed for {name}: expected {expected}, got {actual}")

    payload = {
        "schema_version": 3,
        "canonical_reference": "Agumon",
        "canonical_runtime_order": list(DIRECTION_ORDER),
        "frames_per_direction": 3,
        "canonical_runtime_phases": list(PHASE_ORDER),
        "source_policy": "fresh-download source; reviewed reusable source conventions; reviewed per-direction phase order; deterministic mirror-pose verification; uniform bottom-center runtime anchor",
        "review_map": "database/ds-direction-review-map.json",
        "review_map_sha256": sha256(review_bytes),
        "species_count": len(registry_species),
        "species": registry_species,
    }
    if len(registry_species) != 82:
        raise RuntimeError(f"Expected 82 official WtW species, got {len(registry_species)}")
    REGISTRY.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
    print(f"wrote {REGISTRY}: 82/82 species with exact audited direction, phase, and anchor data")


if __name__ == "__main__":
    main()
