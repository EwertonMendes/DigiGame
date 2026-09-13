#!/usr/bin/env python3
"""Hard-reset non-Agumon DS field sprites from exact audited source boxes.

Official WtW directions are never inferred and never synthesized by mirroring.
Every one of the 12 runtime frames is cropped from an explicit rectangle stored
in database/ds-direction-registry.json. The registry itself is materialized from
a fresh source download plus the human-reviewed per-species semantic map.
"""
from __future__ import annotations

import hashlib
import io
import json
import re
from pathlib import Path
from typing import Any

import numpy as np
from PIL import Image

from build_early_rank_ds_fields import (
    COMMUNITY_SOURCES,
    EARLY_RANKS,
    WTW_IDS,
    build_community_exception,
    load_wtw_archive,
    portrait_key,
    resource_filename,
)
from fetch_character_assets import (
    CHARACTERS as LEGACY_CHARACTER_SOURCES,
    GALLERY_URL,
    _crop_frame as legacy_crop_frame,
    _curl as legacy_curl,
    _discover_sheet_url,
)
import fetch_metalgreymon_field as metal_source

DIRECTIONS = ("down_left", "down_right", "up_left", "up_right")
FRAME_COUNT = 12
FRAMES_PER_DIRECTION = 3
GOLDEN_NAME = "Agumon"
GOLDEN_FIELD = Path("assets/characters/agumon/field.png")
GOLDEN_META = Path("assets/characters/agumon/field.json")
REGISTRY_PATH = Path("database/ds-direction-registry.json")
MANIFEST_PATH = Path("database/ds-full-rebuild-manifest.json")


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def git_blob_sha(data: bytes) -> str:
    header = f"blob {len(data)}\0".encode("ascii")
    return hashlib.sha1(header + data).hexdigest()


def early_entries() -> list[dict[str, Any]]:
    rows = json.loads(Path("database/base-digimon-list.json").read_text(encoding="utf-8"))
    rows = [row for row in rows if str(row.get("rank", "")) in EARLY_RANKS]
    rows.sort(key=lambda row: (EARLY_RANKS.index(str(row.get("rank", ""))), str(row.get("name", ""))))
    if len(rows) != 87:
        raise RuntimeError(f"Expected 87 early-rank rows, got {len(rows)}")
    return rows


def load_registry() -> dict[str, Any]:
    data = json.loads(REGISTRY_PATH.read_text(encoding="utf-8"))
    if data.get("canonical_reference") != GOLDEN_NAME:
        raise RuntimeError("Exact DS registry is not based on Agumon")
    if data.get("canonical_runtime_order") != list(DIRECTIONS):
        raise RuntimeError("Exact DS registry order differs from runtime order")
    species = data.get("species", {})
    if set(species) != set(WTW_IDS):
        raise RuntimeError("Exact DS registry does not cover all 82 official sources")
    return data


def keyed_source(image: Image.Image, background_rgb: list[int]) -> Image.Image:
    rgba = np.array(image.convert("RGBA"), copy=True)
    background = np.asarray(background_rgb, dtype=np.uint8)
    rgba[np.all(rgba[:, :, :3] == background, axis=2), 3] = 0
    return Image.fromarray(rgba, "RGBA")


def crop_exact(keyed: Image.Image, box: dict[str, Any]) -> Image.Image:
    x, y, w, h = (int(box[key]) for key in ("x", "y", "w", "h"))
    if x < 0 or y < 0 or w <= 0 or h <= 0 or x + w > keyed.width or y + h > keyed.height:
        raise RuntimeError(f"Invalid audited source rectangle {box} for source {keyed.size}")
    pad = 2
    crop = keyed.crop(
        (
            max(0, x - pad),
            max(0, y - pad),
            min(keyed.width, x + w + pad),
            min(keyed.height, y + h + pad),
        )
    )
    bbox = crop.getbbox()
    if bbox is None:
        raise RuntimeError(f"Audited source rectangle became empty: {box}")
    return crop.crop(bbox)


def compose_exact_strip(source: Image.Image, spec: dict[str, Any]) -> tuple[Image.Image, int, int, dict[str, list[str]]]:
    keyed = keyed_source(source, list(spec["background_rgb"]))
    frames: list[Image.Image] = []
    frame_hashes: dict[str, list[str]] = {}
    for direction in DIRECTIONS:
        boxes = spec["frames"][direction]
        if len(boxes) != 3:
            raise RuntimeError(f"{direction}: expected exactly three audited boxes")
        direction_frames = [crop_exact(keyed, box) for box in boxes]
        frames.extend(direction_frames)
        frame_hashes[direction] = [sha256(frame.tobytes()) for frame in direction_frames]

    cell_w = max(32, max(frame.width for frame in frames) + 4)
    cell_h = max(32, max(frame.height for frame in frames) + 4)
    strip = Image.new("RGBA", (cell_w * FRAME_COUNT, cell_h), (0, 0, 0, 0))
    for index, frame in enumerate(frames):
        strip.alpha_composite(frame, (index * cell_w + (cell_w - frame.width) // 2, cell_h - frame.height - 1))
    validate_strip(strip, cell_w, cell_h)
    return strip, cell_w, cell_h, frame_hashes


def validate_strip(strip: Image.Image, cell_w: int, cell_h: int) -> None:
    if strip.size != (cell_w * FRAME_COUNT, cell_h):
        raise RuntimeError(f"Unexpected directional strip dimensions {strip.size}")
    for index in range(FRAME_COUNT):
        if strip.crop((index * cell_w, 0, (index + 1) * cell_w, cell_h)).getbbox() is None:
            raise RuntimeError(f"Generated directional frame {index} is empty")


def patch_resource_scale(resource_path: Path, scale: float) -> None:
    text = resource_path.read_text(encoding="utf-8")
    replacement = f"sprite_scale = Vector2({scale:.4f}, {scale:.4f})"
    if re.search(r"^sprite_scale\s*=", text, re.MULTILINE):
        text = re.sub(r"^sprite_scale\s*=.*$", replacement, text, count=1, flags=re.MULTILINE)
    else:
        marker = 'sprite_layout = "directional_12"\n'
        if marker in text:
            text = text.replace(marker, marker + replacement + "\n", 1)
        else:
            texture = re.search(r"^texture\s*=.*$", text, re.MULTILINE)
            if texture is None:
                raise RuntimeError(f"{resource_path}: texture assignment not found")
            text = text[: texture.end()] + "\n" + replacement + text[texture.end() :]
    resource_path.write_text(text, encoding="utf-8")


def rebuild_official(archive, entry: dict[str, Any], registry: dict[str, Any]) -> dict[str, Any]:
    name = str(entry["name"])
    spec = registry["species"][name]
    source_id = int(spec["source_id"])
    if source_id != WTW_IDS[name]:
        raise RuntimeError(f"{name}: source id differs from canonical WTW_IDS")
    member = str(spec["source_member"])
    if member not in archive.namelist():
        raise RuntimeError(f"{name}: original archive member missing: {member}")
    source_bytes = archive.read(member)
    actual_sha = sha256(source_bytes)
    if actual_sha != spec["source_sha256"]:
        raise RuntimeError(
            f"{name}: source SHA changed ({actual_sha}); refusing to guess. Re-audit and re-materialize the registry."
        )
    source = Image.open(io.BytesIO(source_bytes)).convert("RGBA")
    strip, cell_w, cell_h, frame_hashes = compose_exact_strip(source, spec)

    key = portrait_key(entry)
    directory = Path("assets/characters") / key
    directory.mkdir(parents=True, exist_ok=True)
    output = directory / "field.png"
    metadata_path = directory / "field.json"
    strip.save(output, "PNG", optimize=True)
    metadata = {
        "source_kind": "official_ds",
        "source_variant": "withthewill_audited_exact_boxes",
        "source_archive_file": member,
        "source_id": source_id,
        "source_sha256": actual_sha,
        "canonical_reference": GOLDEN_NAME,
        "rebuilt_from_source": True,
        "existing_runtime_strip_used_as_input": False,
        "direction_registry": "res://database/ds-direction-registry.json",
        "direction_registry_schema_version": registry["schema_version"],
        "review_pattern": spec["review_pattern"],
        "runtime_group_indices": spec["runtime_group_indices"],
        "source_group_order": spec["source_group_order"],
        "source_layout": spec["layout"],
        "audited_source_frames": spec["frames"],
        "audited_frame_hashes": frame_hashes,
        "cell_width": cell_w,
        "cell_height": cell_h,
        "frame_count": FRAME_COUNT,
        "frames_per_direction": FRAMES_PER_DIRECTION,
        "directions": list(DIRECTIONS),
        "runtime_scale": 1.0,
        "field_path": f"res://assets/characters/{key}/field.png",
    }
    metadata_path.write_text(json.dumps(metadata, indent=2) + "\n", encoding="utf-8")
    patch_resource_scale(Path("assets/resources") / resource_filename(name), 1.0)
    return {
        "name": name,
        "kind": "official_wtw_exact_registry",
        "source": member,
        "source_sha256": actual_sha,
        "runtime_group_indices": spec["runtime_group_indices"],
        "output": str(output),
        "output_sha256": sha256(output.read_bytes()),
        "cell": [cell_w, cell_h],
    }


def rebuild_community(entry: dict[str, Any]) -> dict[str, Any]:
    name = str(entry["name"])
    url, credit = COMMUNITY_SOURCES[name]
    strip, metadata = build_community_exception(name, url, credit)
    key = portrait_key(entry)
    directory = Path("assets/characters") / key
    directory.mkdir(parents=True, exist_ok=True)
    output = directory / "field.png"
    metadata_path = directory / "field.json"
    strip.save(output, "PNG", optimize=True)
    metadata.update(
        {
            "canonical_reference": GOLDEN_NAME,
            "rebuilt_from_source": True,
            "existing_runtime_strip_used_as_input": False,
            "rebuild_version": 3,
            "directions": list(DIRECTIONS),
            "field_path": f"res://assets/characters/{key}/field.png",
        }
    )
    metadata_path.write_text(json.dumps(metadata, indent=2) + "\n", encoding="utf-8")
    patch_resource_scale(Path("assets/resources") / resource_filename(name), float(metadata.get("runtime_scale", 1.0)))
    return {
        "name": name,
        "kind": "community_source_rebuilt",
        "source": url,
        "output": str(output),
        "output_sha256": sha256(output.read_bytes()),
        "cell": [int(metadata["cell_width"]), int(metadata["cell_height"])],
    }


def rebuild_greymon() -> dict[str, Any]:
    config = LEGACY_CHARACTER_SOURCES["greymon"]
    gallery = legacy_curl(GALLERY_URL).decode("utf-8", "replace")
    source_url = _discover_sheet_url(gallery, config["sheet_id"])
    source_bytes = legacy_curl(source_url)
    actual_sha = sha256(source_bytes)
    if actual_sha != config["expected_sha256"]:
        raise RuntimeError(f"Greymon source hash changed: {actual_sha}")
    source = Image.open(io.BytesIO(source_bytes)).convert("RGBA")
    groups: dict[str, list[Image.Image]] = {}
    for direction in DIRECTIONS:
        positions = config["directions"].get(direction)
        if positions:
            groups[direction] = [
                legacy_crop_frame(source, position, config["frame_size"], config["background"], config["tolerance"])
                for position in positions
            ]
    if "down_right" not in groups:
        groups["down_right"] = [frame.transpose(Image.Transpose.FLIP_LEFT_RIGHT) for frame in groups["down_left"]]
    if "up_right" not in groups:
        groups["up_right"] = [frame.transpose(Image.Transpose.FLIP_LEFT_RIGHT) for frame in groups["up_left"]]
    frame_w, frame_h = config["frame_size"]
    output = Image.new("RGBA", (frame_w * FRAME_COUNT, frame_h), (0, 0, 0, 0))
    for direction_index, direction in enumerate(DIRECTIONS):
        if len(groups[direction]) != 3:
            raise RuntimeError(f"Greymon {direction} does not contain three reviewed frames")
        for frame_index, frame in enumerate(groups[direction]):
            output.alpha_composite(frame, ((direction_index * 3 + frame_index) * frame_w, 0))
    validate_strip(output, frame_w, frame_h)
    path = Path("assets/characters/greymon.png")
    output.save(path, "PNG", optimize=True)
    return {
        "name": "Greymon",
        "kind": "official_spriters_resource_reviewed",
        "source": source_url,
        "source_sha256": actual_sha,
        "output": str(path),
        "output_sha256": sha256(path.read_bytes()),
        "cell": [frame_w, frame_h],
    }


def rebuild_metalgreymon() -> dict[str, Any]:
    source_bytes = metal_source.fetch(metal_source.SOURCE_URL)
    actual_sha = sha256(source_bytes)
    if actual_sha != metal_source.EXPECTED_SOURCE_SHA256:
        raise RuntimeError(f"MetalGreymon source hash changed: {actual_sha}")
    source = Image.open(io.BytesIO(source_bytes)).convert("RGBA")
    groups: dict[str, list[Image.Image]] = {}
    for direction in DIRECTIONS:
        boxes = metal_source.SOURCE_FRAMES.get(direction)
        if boxes:
            frames: list[Image.Image] = []
            for index, box in enumerate(boxes):
                crop = source.crop(box)
                metal_source.validate_source_crop(crop, direction, index)
                frames.append(metal_source.normalize(crop))
            groups[direction] = frames
    if "down_right" not in groups:
        groups["down_right"] = [frame.transpose(Image.Transpose.FLIP_LEFT_RIGHT) for frame in groups["down_left"]]
    if "up_right" not in groups:
        groups["up_right"] = [frame.transpose(Image.Transpose.FLIP_LEFT_RIGHT) for frame in groups["up_left"]]
    cell_w, cell_h = metal_source.CELL_SIZE
    output = Image.new("RGBA", (cell_w * FRAME_COUNT, cell_h), (0, 0, 0, 0))
    for direction_index, direction in enumerate(DIRECTIONS):
        if len(groups[direction]) != 3:
            raise RuntimeError(f"MetalGreymon {direction} does not contain three reviewed frames")
        for frame_index, frame in enumerate(groups[direction]):
            output.alpha_composite(frame, ((direction_index * 3 + frame_index) * cell_w, 0))
    validate_strip(output, cell_w, cell_h)
    path = Path("assets/characters/metalgreymon/field.png")
    path.parent.mkdir(parents=True, exist_ok=True)
    output.save(path, "PNG", optimize=True)
    metadata = {
        "source_kind": "official_ds",
        "source_variant": "spriters_resource_reviewed_exact_boxes",
        "source_url": metal_source.SOURCE_URL,
        "source_sha256": actual_sha,
        "canonical_reference": GOLDEN_NAME,
        "rebuilt_from_source": True,
        "existing_runtime_strip_used_as_input": False,
        "cell_width": cell_w,
        "cell_height": cell_h,
        "frame_count": FRAME_COUNT,
        "frames_per_direction": FRAMES_PER_DIRECTION,
        "directions": list(DIRECTIONS),
        "field_path": "res://assets/characters/metalgreymon/field.png",
    }
    Path("assets/characters/metalgreymon/field.json").write_text(json.dumps(metadata, indent=2) + "\n", encoding="utf-8")
    return {
        "name": "Metal Greymon",
        "kind": "official_spriters_resource_reviewed",
        "source": metal_source.SOURCE_URL,
        "source_sha256": actual_sha,
        "output": str(path),
        "output_sha256": sha256(path.read_bytes()),
        "cell": [cell_w, cell_h],
    }


def hard_delete(entries: list[dict[str, Any]]) -> list[str]:
    deleted: list[str] = []
    for entry in entries:
        if str(entry["name"]) == GOLDEN_NAME:
            continue
        key = portrait_key(entry)
        for path in (Path("assets/characters") / key / "field.png", Path("assets/characters") / key / "field.json"):
            if path.exists():
                path.unlink()
                deleted.append(str(path))
    for path in (
        Path("assets/characters/greymon.png"),
        Path("assets/characters/metalgreymon/field.png"),
        Path("assets/characters/metalgreymon/field.json"),
    ):
        if path.exists():
            path.unlink()
            deleted.append(str(path))
    return deleted


def update_pinned_hashes() -> None:
    path = Path("tools/validate_runtime_assets.py")
    text = path.read_text(encoding="utf-8")
    for asset in ("assets/characters/veemon/field.png", "assets/characters/metalgreymon/field.png"):
        new_hash = git_blob_sha(Path(asset).read_bytes())
        pattern = rf'("{re.escape(asset)}"\s*:\s*")[0-9a-f]+(")'
        text, count = re.subn(pattern, rf'\g<1>{new_hash}\2', text, count=1)
        if count != 1:
            raise RuntimeError(f"Could not update pinned generated blob hash for {asset}")
    path.write_text(text, encoding="utf-8")


def main() -> None:
    entries = early_entries()
    registry = load_registry()
    if not GOLDEN_FIELD.exists() or not GOLDEN_META.exists():
        raise RuntimeError("Golden Agumon field strip/metadata is missing")
    golden_png_sha = sha256(GOLDEN_FIELD.read_bytes())
    golden_meta_sha = sha256(GOLDEN_META.read_bytes())

    deleted = hard_delete(entries)
    archive = load_wtw_archive()  # fresh second download: registry materialization is a separate phase
    rebuilt: list[dict[str, Any]] = []
    failures: list[str] = []
    for entry in entries:
        name = str(entry["name"])
        if name == GOLDEN_NAME:
            continue
        try:
            if name in WTW_IDS:
                result = rebuild_official(archive, entry, registry)
            elif name in COMMUNITY_SOURCES:
                result = rebuild_community(entry)
            else:
                raise RuntimeError("no original/community source registered")
            rebuilt.append(result)
            print(f"rebuilt: {name} -> {result['output']}")
        except Exception as exc:
            failures.append(f"{name}: {exc}")

    for label, rebuild in (("Greymon", rebuild_greymon), ("Metal Greymon", rebuild_metalgreymon)):
        try:
            rebuilt.append(rebuild())
            print(f"rebuilt: {label}")
        except Exception as exc:
            failures.append(f"{label}: {exc}")

    if sha256(GOLDEN_FIELD.read_bytes()) != golden_png_sha or sha256(GOLDEN_META.read_bytes()) != golden_meta_sha:
        raise RuntimeError("Agumon golden reference was modified")
    if len(rebuilt) != 88:
        failures.append(f"expected 88 rebuilt sprites, got {len(rebuilt)}")

    manifest = {
        "canonical_reference": GOLDEN_NAME,
        "canonical_runtime_order": list(DIRECTIONS),
        "direction_registry": str(REGISTRY_PATH),
        "direction_registry_schema_version": registry["schema_version"],
        "source_policy": "fresh download + SHA-256 pin + 12 exact audited source rectangles; no semantic direction inference",
        "existing_non_agumon_runtime_strips_allowed_as_input": False,
        "preserved_count": 1,
        "preserved": [{"name": GOLDEN_NAME, "field": str(GOLDEN_FIELD), "sha256": golden_png_sha}],
        "deleted_before_rebuild_count": len(deleted),
        "deleted_before_rebuild": deleted,
        "rebuilt_count": len(rebuilt),
        "rebuilt": rebuilt,
        "unresolved": failures,
    }
    MANIFEST_PATH.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    if failures:
        raise RuntimeError("Exact DS rebuild failed:\n- " + "\n- ".join(failures))

    update_pinned_hashes()
    print("Exact DS rebuild complete: Agumon preserved; 88 sprites recreated from fresh sources")


if __name__ == "__main__":
    main()
