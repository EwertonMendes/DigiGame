#!/usr/bin/env python3
"""Normalize DS field strips whose source stores left facings before right facings.

The runtime contract is always 12 frames in this exact group order:
  down_left, down_right, up_left, up_right
with three frames per group.

Several original DS/WtW sheets instead store their four authored groups as:
  front_left, back_left, front_right, back_right
which corresponds to:
  down_left, up_left, down_right, up_right

That physical source order is valid, but copying it verbatim swaps the runtime's
second and third groups. The result is exactly the visual bug where a Digimon
moves up-left while showing a front/right-facing sprite.

This tool performs the one-time normalization on existing field.png strips and
records the permutation in field.json so it is idempotent. For SpriteManager
assets it only applies the correction when the reviewed spec actually authors
all four diagonal facings; two-facing + mirror specs (Agumon, Chibomon,
Dorumon, etc.) are already assembled into the runtime order and must not move.
"""
from __future__ import annotations

import argparse
import json
import urllib.request
from pathlib import Path
from typing import Any

from PIL import Image

RUNTIME_DIRECTIONS = ["down_left", "down_right", "up_left", "up_right"]
SOURCE_GROUP_ORDER = ["front_left", "back_left", "front_right", "back_right"]
GROUP_PERMUTATION = [0, 2, 1, 3]
FRAMES_PER_DIRECTION = 3
MANAGER_SPEC_BASE = (
    "https://raw.githubusercontent.com/netraular/"
    "DigimonWorldSpriteManager/main/specs/digimon/"
)


def _load_manager_spec(spec_name: str, manager_root: Path | None) -> dict[str, Any]:
    if manager_root is not None:
        path = manager_root / "specs" / "digimon" / spec_name
        return json.loads(path.read_text(encoding="utf-8"))
    with urllib.request.urlopen(MANAGER_SPEC_BASE + spec_name, timeout=30) as response:
        return json.loads(response.read().decode("utf-8"))


def _authors_all_four_diagonals(spec: dict[str, Any]) -> bool:
    walk = spec.get("clips", {}).get("walk", {})
    return all(isinstance(walk.get(direction), list) and bool(walk[direction]) for direction in RUNTIME_DIRECTIONS)


def _already_normalized(metadata: dict[str, Any]) -> bool:
    return metadata.get("direction_group_permutation") == GROUP_PERMUTATION


def _reorder_strip(field_path: Path, metadata: dict[str, Any]) -> None:
    image = Image.open(field_path).convert("RGBA")
    cell_w = int(metadata.get("cell_width", 0))
    cell_h = int(metadata.get("cell_height", image.height))
    expected_width = cell_w * len(RUNTIME_DIRECTIONS) * FRAMES_PER_DIRECTION
    if cell_w <= 0 or image.width != expected_width or image.height != cell_h:
        raise RuntimeError(
            f"{field_path}: expected 12 cells of {cell_w}x{cell_h}, got {image.size}"
        )

    groups: list[list[Image.Image]] = []
    for group_index in range(4):
        group: list[Image.Image] = []
        for frame_index in range(FRAMES_PER_DIRECTION):
            index = group_index * FRAMES_PER_DIRECTION + frame_index
            group.append(
                image.crop((index * cell_w, 0, (index + 1) * cell_w, cell_h))
            )
        groups.append(group)

    output = Image.new("RGBA", image.size, (0, 0, 0, 0))
    output_index = 0
    for source_group in GROUP_PERMUTATION:
        for frame in groups[source_group]:
            output.alpha_composite(frame, (output_index * cell_w, 0))
            output_index += 1
    output.save(field_path, "PNG", optimize=True)


def _mark_metadata(metadata: dict[str, Any], source: str) -> None:
    metadata["direction_source"] = source
    metadata["source_group_order"] = SOURCE_GROUP_ORDER
    metadata["normalized_group_order"] = RUNTIME_DIRECTIONS
    metadata["direction_group_permutation"] = GROUP_PERMUTATION


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--characters", type=Path, default=Path("assets/characters"))
    parser.add_argument("--manager-root", type=Path)
    parser.add_argument("--report", type=Path, default=Path("database/ds-four-facing-normalization.json"))
    args = parser.parse_args()

    corrected: list[dict[str, str]] = []
    preserved: list[dict[str, str]] = []

    for metadata_path in sorted(args.characters.glob("*/field.json")):
        metadata = json.loads(metadata_path.read_text(encoding="utf-8"))
        field_path = metadata_path.with_name("field.png")
        if not field_path.exists() or int(metadata.get("frame_count", 0)) != 12:
            continue

        variant = str(metadata.get("source_variant", ""))
        name = str(metadata.get("source_name") or metadata_path.parent.name)

        if _already_normalized(metadata):
            preserved.append({"name": name, "reason": "already_normalized"})
            continue

        should_reorder = False
        reason = ""

        if variant == "withthewill_sprite_thread" and metadata.get("extraction_layout") == "two_rows_of_six":
            should_reorder = True
            reason = "wtw_four_authored_source_order"
        elif variant == "digimon_world_sprite_manager":
            spec_name = str(metadata.get("manager_spec", ""))
            if not spec_name:
                raise RuntimeError(f"{metadata_path}: SpriteManager metadata has no manager_spec")
            spec = _load_manager_spec(spec_name, args.manager_root)
            if _authors_all_four_diagonals(spec):
                should_reorder = True
                reason = "manager_four_authored_source_order"
            else:
                preserved.append({"name": name, "reason": "two_authored_plus_mirror"})

        if not should_reorder:
            continue

        _reorder_strip(field_path, metadata)
        _mark_metadata(metadata, reason)
        metadata_path.write_text(json.dumps(metadata, indent=2) + "\n", encoding="utf-8")
        corrected.append({"name": name, "reason": reason, "path": str(field_path)})
        print(f"normalized DS facing groups: {name} ({reason})")

    report = {
        "runtime_direction_order": RUNTIME_DIRECTIONS,
        "source_group_order": SOURCE_GROUP_ORDER,
        "group_permutation": GROUP_PERMUTATION,
        "corrected_count": len(corrected),
        "corrected": corrected,
        "preserved_count": len(preserved),
        "preserved": preserved,
    }
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(f"corrected={len(corrected)} preserved={len(preserved)}")


if __name__ == "__main__":
    main()
