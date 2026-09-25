#!/usr/bin/env python3
"""Validate the higher-rank directional DS assets generated for DigiGame."""
from __future__ import annotations

import json
import re
from pathlib import Path
from PIL import Image, ImageChops

CONFIG = Path("database/ds-additional-sources.json")
MANIFEST = Path("database/additional-ds-playables.json")
DIRECTIONS = ["down_left", "down_right", "up_left", "up_right"]


def compact_key(value: str) -> str:
    return re.sub(r"[^a-z0-9]+", "", value.lower())


def main() -> None:
    config = json.loads(CONFIG.read_text(encoding="utf-8"))
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    patterns = config.get("patterns", {})
    for pattern_name, permutation in patterns.items():
        if sorted(permutation) != [0, 1, 2, 3]:
            raise RuntimeError(f"Invalid additional DS direction pattern {pattern_name}: {permutation}")

    expected = set(config["species"])
    rows = manifest.get("species", [])
    by_name = {row["name"]: row for row in rows}
    if set(by_name) != expected or manifest.get("count") != len(expected):
        raise RuntimeError(f"Additional manifest mismatch: expected={sorted(expected)} actual={sorted(by_name)}")
    if manifest.get("canonical_runtime_order") != DIRECTIONS:
        raise RuntimeError("Additional manifest direction order is not canonical")

    for name in sorted(expected):
        row = by_name[name]
        key = compact_key(name)
        field_path = Path("assets/characters") / key / "field.png"
        meta_path = Path("assets/characters") / key / "field.json"
        portrait_path = Path("assets/characters") / key / "portrait_frames.png"
        portrait_meta_path = Path("assets/characters") / key / "portrait_frames.json"
        resource_path = Path("assets/resources") / f"{name.lower()}.tres"
        for path in (field_path, meta_path, portrait_path, portrait_meta_path, resource_path):
            if not path.exists() or path.stat().st_size <= 0:
                raise RuntimeError(f"{name}: missing generated asset {path}")

        meta = json.loads(meta_path.read_text(encoding="utf-8"))
        if meta.get("canonical_runtime_order") != DIRECTIONS or meta.get("frame_count") != 12:
            raise RuntimeError(f"{name}: invalid canonical field metadata")
        if meta.get("existing_runtime_strip_used_as_input") is not False:
            raise RuntimeError(f"{name}: field rebuild must not reuse an old runtime strip")
        if meta.get("source_sha256") != config["species"][name]["source_sha256"]:
            raise RuntimeError(f"{name}: field source SHA differs from pinned source")
        pattern_name = config["species"][name]["pattern"]
        if pattern_name not in patterns:
            raise RuntimeError(f"{name}: unknown reviewed source convention {pattern_name}")
        if meta.get("review_pattern") != pattern_name:
            raise RuntimeError(f"{name}: field pattern differs from reviewed source convention")
        if meta.get("runtime_group_indices") != patterns[pattern_name]:
            raise RuntimeError(
                f"{name}: runtime direction mapping drifted; "
                f"expected={patterns[pattern_name]} actual={meta.get('runtime_group_indices')}"
            )

        mirror_from = config["species"][name].get("horizontal_mirror_from", {})
        if not isinstance(mirror_from, dict):
            raise RuntimeError(f"{name}: horizontal_mirror_from must be an object")
        allowed_horizontal_mirrors = {
            ("down_left", "down_right"),
            ("down_right", "down_left"),
            ("up_left", "up_right"),
            ("up_right", "up_left"),
        }
        for target_direction, source_direction in mirror_from.items():
            if (str(target_direction), str(source_direction)) not in allowed_horizontal_mirrors:
                raise RuntimeError(
                    f"{name}: invalid generated mirror {target_direction} <- {source_direction}"
                )
        if meta.get("horizontal_mirror_from", {}) != mirror_from:
            raise RuntimeError(f"{name}: generated horizontal mirror metadata drifted")

        expected_effective = list(patterns[pattern_name])
        for target_direction, source_direction in mirror_from.items():
            expected_effective[DIRECTIONS.index(str(target_direction))] = patterns[pattern_name][
                DIRECTIONS.index(str(source_direction))
            ]
        if meta.get("effective_runtime_group_indices", meta.get("runtime_group_indices")) != expected_effective:
            raise RuntimeError(
                f"{name}: effective runtime source groups drifted; "
                f"expected={expected_effective} actual={meta.get('effective_runtime_group_indices')}"
            )
        if row.get("pattern") != pattern_name:
            raise RuntimeError(f"{name}: generated manifest pattern differs from reviewed source convention")

        image = Image.open(field_path).convert("RGBA")
        cell_w = int(meta["cell_width"])
        cell_h = int(meta["cell_height"])
        if image.size != (cell_w * 12, cell_h):
            raise RuntimeError(f"{name}: field strip has unexpected dimensions {image.size}")
        for index in range(12):
            if image.crop((index * cell_w, 0, (index + 1) * cell_w, cell_h)).getbbox() is None:
                raise RuntimeError(f"{name}: empty directional frame {index}")

        for target_direction, source_direction in mirror_from.items():
            target_base = DIRECTIONS.index(str(target_direction)) * 3
            source_base = DIRECTIONS.index(str(source_direction)) * 3
            for phase in range(3):
                source_cell = image.crop(((source_base + phase) * cell_w, 0, (source_base + phase + 1) * cell_w, cell_h))
                target_cell = image.crop(((target_base + phase) * cell_w, 0, (target_base + phase + 1) * cell_w, cell_h))
                source_bbox = source_cell.getbbox()
                target_bbox = target_cell.getbbox()
                if source_bbox is None or target_bbox is None:
                    raise RuntimeError(f"{name}: generated mirror contains an empty frame")
                expected_mirror = source_cell.crop(source_bbox).transpose(Image.Transpose.FLIP_LEFT_RIGHT)
                actual = target_cell.crop(target_bbox)
                if expected_mirror.size != actual.size or ImageChops.difference(expected_mirror, actual).getbbox() is not None:
                    raise RuntimeError(
                        f"{name}: {target_direction} phase {phase} is not the exact horizontal mirror of {source_direction}"
                    )

        portrait_meta = json.loads(portrait_meta_path.read_text(encoding="utf-8"))
        portrait = Image.open(portrait_path).convert("RGBA")
        fw = int(portrait_meta["frame_width"])
        fh = int(portrait_meta["frame_height"])
        count = int(portrait_meta["frame_count"])
        if count <= 0 or portrait.size != (fw * count, fh):
            raise RuntimeError(f"{name}: portrait strip/metadata mismatch")

        text = resource_path.read_text(encoding="utf-8")
        required = [
            'sprite_layout = "directional_12"',
            'sprite_hframes = 12',
            f'display_name = "{name}"',
            f'path="res://assets/characters/{key}/field.png"',
        ]
        missing = [needle for needle in required if needle not in text]
        if missing:
            raise RuntimeError(f"{name}: resource is not canonical directional_12; missing={missing}")
        if "flip_h" in text or "horizontal_facing_inverted" in text:
            raise RuntimeError(f"{name}: resource must not encode a runtime facing workaround")
        print(f"validated {name}: 12 directional frames + portrait + resource")

    print(f"additional DS field validation passed: {len(expected)} species")


if __name__ == "__main__":
    main()
