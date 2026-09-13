#!/usr/bin/env python3
"""Materialize canonical DS directions and walk phases from reviewed source conventions.

The pipeline deliberately separates two concerns:
1. database/ds-direction-review-map.json classifies the authored *sheet convention*
   (where DL/DR/UL/UR groups live in the original DS art).
2. this script fresh-downloads the WtW archive, extracts those authored groups,
   and derives right-facing walk-phase order by deterministic mirrored-pose
   comparison against the corresponding left-facing frames.

There are no runtime species conditionals, no per-Digimon facing flips, and no
per-species walk-phase overrides. Every source convention materializes into the
same canonical runtime contract: DL, DR, UL, UR × idle, step_a, step_b.
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
DIRECTION_PAIRS = (("down_left", "down_right"), ("up_left", "up_right"))


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
    """Rank every right-frame permutation against mirrored left-frame poses."""
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
    candidates.sort(key=lambda item: (item[0], item[1]))
    return candidates


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


def authored_groups(
    image: Image.Image, sprite_id: int
) -> tuple[tuple[int, int, int], list[list[dict[str, int]]], str]:
    """Find four authored movement triples without assigning direction semantics."""
    background, groups = candidate_groups(image)

    six_rows = [group for group in groups if len(group) == 6]
    if len(six_rows) == 2:
        rows = sorted(six_rows, key=lambda group: sum(item["cy"] for item in group) / len(group))
        raw = [rows[0][:3], rows[0][3:6], rows[1][:3], rows[1][3:6]]
        return background, [[exact_box(item) for item in group] for group in raw], "two_rows_of_six"

    # Kudamon carries extra poses on the same rows. This is a structural crop
    # rule only; direction semantics still come from the reusable source pattern.
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

    # Compact sheets place one movement triple per row on the right. Detection
    # finds the four triples; the review map supplies the reusable source order.
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
    if data.get("schema_version", 0) < 4:
        raise RuntimeError("Review map must use convention-driven direction/phase schema v4+")
    if data.get("canonical_runtime_phases") != list(PHASE_ORDER):
        raise RuntimeError("Review map phase order must be idle, step_a, step_b")
    if data.get("left_source_phase_order") != [0, 1, 2]:
        raise RuntimeError("Left-facing authored triples must define idle/step_a/step_b as [0,1,2]")
    if data.get("right_phase_policy") != "deterministic_mirror_pose_match":
        raise RuntimeError("Right-facing phases must use deterministic mirror-pose matching")
    if "source_phase_overrides" in data:
        raise RuntimeError("Per-species source phase overrides are not allowed")

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
    if set(regressions.values()) != set(patterns):
        missing = sorted(set(patterns) - set(regressions.values()))
        raise RuntimeError(f"Every source convention needs a regression representative; missing={missing}")

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
    left_phase_order = list(review["left_source_phase_order"])

    for name, sprite_id in sorted(WTW_IDS.items(), key=lambda item: item[1]):
        member = source_member(archive, sprite_id)
        payload = archive.read(member)
        image = Image.open(io.BytesIO(payload)).convert("RGBA")
        background, groups, layout = authored_groups(image, sprite_id)
        if len(groups) != 4 or any(len(group) != 3 for group in groups):
            raise RuntimeError(f"{name}: structural extraction did not yield 4x3 movement frames")

        pattern_name = str(review["species"][name])
        permutation = [int(index) for index in review["patterns"].get(pattern_name, [])]
        if sorted(permutation) != [0, 1, 2, 3]:
            raise RuntimeError(f"{name}: unknown/invalid reviewed pattern {pattern_name}")

        raw_frames = {
            direction: groups[permutation[index]]
            for index, direction in enumerate(DIRECTION_ORDER)
        }
        source_frame_order: dict[str, list[int]] = {
            "down_left": list(left_phase_order),
            "up_left": list(left_phase_order),
            "down_right": [],
            "up_right": [],
        }
        pose_alignment: dict[str, Any] = {}

        for left_direction, right_direction in DIRECTION_PAIRS:
            candidates = pose_match_candidates(
                image,
                background,
                raw_frames[left_direction],
                raw_frames[right_direction],
            )
            best_cost, best_order = candidates[0]
            source_frame_order[right_direction] = list(best_order)
            equivalent_best = sum(1 for cost, _ in candidates if cost == best_cost)
            pose_alignment[right_direction] = {
                "compared_with": left_direction,
                "policy": review["right_phase_policy"],
                "source_phase_order": list(best_order),
                "pixel_error": best_cost,
                "confidence_margin": candidates[1][0] - best_cost,
                "equivalent_best_count": equivalent_best,
            }

        frames = {
            direction: [raw_frames[direction][source_index] for source_index in source_frame_order[direction]]
            for direction in DIRECTION_ORDER
        }
        source_group_order = expected_source_group_order(permutation)
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

    # Regression truth is data-driven; Python contains no species-facing table.
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
        "schema_version": 4,
        "canonical_reference": "Agumon",
        "canonical_runtime_order": list(DIRECTION_ORDER),
        "frames_per_direction": 3,
        "canonical_runtime_phases": list(PHASE_ORDER),
        "source_policy": (
            "fresh-download source; reviewed reusable direction conventions; "
            "left authored phase order; deterministic mirrored-pose derivation for right phases; "
            "uniform bottom-center runtime anchor"
        ),
        "review_map": "database/ds-direction-review-map.json",
        "review_map_sha256": sha256(review_bytes),
        "species_count": len(registry_species),
        "species": registry_species,
    }
    if len(registry_species) != 82:
        raise RuntimeError(f"Expected 82 official WtW species, got {len(registry_species)}")
    REGISTRY.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
    print(f"wrote {REGISTRY}: 82/82 species with canonical direction, phase, and anchor data")


if __name__ == "__main__":
    main()
