#!/usr/bin/env python3
"""Validate higher-rank directional assets generated for DigiGame."""
from __future__ import annotations

import hashlib
import json
import re
from pathlib import Path

from PIL import Image

CONFIG = Path("database/ds-additional-sources.json")
PROJECT_SOURCES = Path("database/ds-project-supplied-sources.json")
MANIFEST = Path("database/additional-ds-playables.json")
DIRECTIONS = ["down_left", "down_right", "up_left", "up_right"]


def compact_key(value: str) -> str:
    return re.sub(r"[^a-z0-9]+", "", value.lower())


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def load_config() -> dict:
    config = json.loads(CONFIG.read_text(encoding="utf-8"))
    if PROJECT_SOURCES.is_file():
        extension = json.loads(PROJECT_SOURCES.read_text(encoding="utf-8"))
        for section in ("profiles", "patterns", "species"):
            target = config.setdefault(section, {})
            additions = extension.get(section, {})
            overlap = set(target) & set(additions)
            if overlap:
                raise RuntimeError(
                    f"Project-supplied additional DS config duplicates {section}: {sorted(overlap)}"
                )
            target.update(additions)
    return config


def main() -> None:
    config = load_config()
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
        spec = config["species"][name]
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

        source_path_value = str(spec.get("source_path") or "")
        if source_path_value:
            source_path = Path(source_path_value)
            if not source_path.is_file():
                raise RuntimeError(f"{name}: missing project-supplied source {source_path}")
            if sha256(source_path) != str(spec["source_sha256"]):
                raise RuntimeError(f"{name}: project-supplied source SHA differs from pinned source")
            with Image.open(source_path) as source_image:
                expected_dimensions = spec.get("source_dimensions")
                if expected_dimensions and list(source_image.size) != [int(v) for v in expected_dimensions]:
                    raise RuntimeError(
                        f"{name}: source dimensions {source_image.size} != {expected_dimensions}"
                    )

        meta = json.loads(meta_path.read_text(encoding="utf-8"))
        if meta.get("canonical_runtime_order") != DIRECTIONS or meta.get("frame_count") != 12:
            raise RuntimeError(f"{name}: invalid canonical field metadata")
        if meta.get("existing_runtime_strip_used_as_input") is not False:
            raise RuntimeError(f"{name}: field rebuild must not reuse an old runtime strip")
        if meta.get("source_sha256") != spec["source_sha256"]:
            raise RuntimeError(f"{name}: field source SHA differs from pinned source")
        if meta.get("source_kind") != str(spec.get("source_kind", "official_ds")):
            raise RuntimeError(f"{name}: field source kind differs from source config")
        pattern_name = spec["pattern"]
        if pattern_name not in patterns:
            raise RuntimeError(f"{name}: unknown reviewed source convention {pattern_name}")
        if meta.get("review_pattern") != pattern_name:
            raise RuntimeError(f"{name}: field pattern differs from reviewed source convention")
        if meta.get("runtime_group_indices") != patterns[pattern_name]:
            raise RuntimeError(
                f"{name}: runtime direction mapping drifted; "
                f"expected={patterns[pattern_name]} actual={meta.get('runtime_group_indices')}"
            )
        if row.get("pattern") != pattern_name:
            raise RuntimeError(f"{name}: generated manifest pattern differs from reviewed source convention")
        if source_path_value and meta.get("source_path") != source_path_value:
            raise RuntimeError(f"{name}: field metadata lost project-supplied source provenance")
        if spec.get("original_attachment_sha256") and meta.get("original_attachment_sha256") != spec["original_attachment_sha256"]:
            raise RuntimeError(f"{name}: original attachment provenance drifted")
        if spec.get("source_crop") and meta.get("source_crop") != spec["source_crop"]:
            raise RuntimeError(f"{name}: source crop provenance drifted")
        if spec.get("background_policy") and meta.get("background_policy") != spec["background_policy"]:
            raise RuntimeError(f"{name}: field background policy drifted")
        if spec.get("phase_orders") and meta.get("source_frame_order") != spec["phase_orders"]:
            raise RuntimeError(f"{name}: authored walking phase order drifted")

        image = Image.open(field_path).convert("RGBA")
        cell_w = int(meta["cell_width"])
        cell_h = int(meta["cell_height"])
        if image.size != (cell_w * 12, cell_h):
            raise RuntimeError(f"{name}: field strip has unexpected dimensions {image.size}")
        for index in range(12):
            frame = image.crop((index * cell_w, 0, (index + 1) * cell_w, cell_h))
            if frame.getbbox() is None:
                raise RuntimeError(f"{name}: empty directional frame {index}")
            if spec.get("background_policy"):
                alpha = frame.getchannel("A")
                transparent = sum(1 for value in alpha.getdata() if value == 0)
                if transparent < int(cell_w * cell_h * 0.20):
                    raise RuntimeError(f"{name}: source background was not normalized in frame {index}")

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
        runtime_scale = float(spec.get("runtime_scale", 1.0))
        required.append(f"sprite_scale = Vector2({runtime_scale:.4f}, {runtime_scale:.4f})")
        missing = [needle for needle in required if needle not in text]
        if missing:
            raise RuntimeError(f"{name}: resource is not canonical directional_12; missing={missing}")
        if "flip_h" in text or "horizontal_facing_inverted" in text:
            raise RuntimeError(f"{name}: resource must not encode a runtime facing workaround")
        print(f"validated {name}: 12 directional frames + portrait + resource")

    print(f"additional DS field validation passed: {len(expected)} species")


if __name__ == "__main__":
    main()
