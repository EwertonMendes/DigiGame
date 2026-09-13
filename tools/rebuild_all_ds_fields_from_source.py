#!/usr/bin/env python3
"""Hard-reset every runtime DS directional sprite except the golden Agumon strip.

This rebuild deliberately refuses to reuse any existing non-Agumon runtime strip.
All early-rank official sprites are reconstructed from the original WithTheWill
DS source archive. The output contract is the same one proven by Agumon:

    0..2   down_left  (front-left)
    3..5   down_right (horizontal mirror of down_left)
    6..8   up_left    (rear-left)
    9..11  up_right   (horizontal mirror of up_left)

The WtW archive uses two source-layout families:

* two rows of six: front-left, front-right / rear-right, rear-left
* compact four groups: front-left / rear-left / front-right / rear-right

Only the authored left-facing groups are trusted. Right-facing runtime frames are
always mirrored from the corresponding left-facing frames, exactly like Agumon.
This removes source-order ambiguity completely.
"""
from __future__ import annotations

import hashlib
import io
import json
import re
from pathlib import Path
from typing import Any

import numpy as np
from PIL import Image, ImageOps

from build_early_rank_ds_fields import (
    COMMUNITY_SOURCES,
    EARLY_RANKS,
    WTW_IDS,
    _components,
    _group_by_y,
    _transparent_source,
    build_community_exception,
    fetch,
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

DIRECTION_ORDER = ("down_left", "down_right", "up_left", "up_right")
FRAMES_PER_DIRECTION = 3
FRAME_COUNT = 12
GOLDEN_NAME = "Agumon"
GOLDEN_FIELD = Path("assets/characters/agumon/field.png")
GOLDEN_META = Path("assets/characters/agumon/field.json")
MANIFEST = Path("database/ds-full-rebuild-manifest.json")
OBSOLETE_REPORTS = (
    Path("database/ds-facing-audit.json"),
    Path("database/ds-four-facing-normalization.json"),
)


def _sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def _git_blob_sha(data: bytes) -> str:
    header = f"blob {len(data)}\0".encode("ascii")
    return hashlib.sha1(header + data).hexdigest()


def _load_early_database() -> list[dict[str, Any]]:
    rows = json.loads(Path("database/base-digimon-list.json").read_text(encoding="utf-8"))
    rows = [row for row in rows if str(row.get("rank", "")) in EARLY_RANKS]
    rows.sort(key=lambda row: (EARLY_RANKS.index(str(row.get("rank", ""))), str(row.get("name", ""))))
    if len(rows) != 87:
        raise RuntimeError(f"Expected 87 early-rank rows, got {len(rows)}")
    return rows


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


def _three(items: list[dict[str, float]], label: str) -> list[dict[str, float]]:
    if len(items) != 3:
        raise RuntimeError(f"{label}: expected exactly three authored frames, got {len(items)}")
    return list(items)


def _select_authored_left_groups(
    image: Image.Image,
    sprite_id: int,
) -> tuple[tuple[int, int, int], list[dict[str, float]], list[dict[str, float]], dict[str, Any]]:
    """Return authored front-left and rear-left walk groups from the raw source."""
    background, groups = _candidate_groups(image)

    # Normal rookie layout. Visual review against the golden Agumon source:
    # row 0 = [front-left x3][front-right x3]
    # row 1 = [rear-right x3][rear-left x3]
    six_rows = [group for group in groups if len(group) == 6]
    if len(six_rows) == 2:
        rows = sorted(six_rows, key=lambda group: sum(item["cy"] for item in group) / len(group))
        down_left = _three(rows[0][:3], f"{sprite_id:03d} front-left")
        up_left = _three(rows[1][3:6], f"{sprite_id:03d} rear-left")
        return background, down_left, up_left, {
            "source_layout": "two_rows_of_six",
            "source_group_order": ["down_left", "down_right", "up_right", "up_left"],
            "authored_groups_used": [0, 3],
        }

    # Kudamon has extra small poses on the movement rows. The first six cells
    # of the final two movement rows follow the same source convention above.
    if sprite_id == 72:
        movement_rows = [group for group in groups if len(group) >= 6]
        movement_rows = sorted(
            movement_rows,
            key=lambda group: sum(item["cy"] for item in group) / len(group),
        )[-2:]
        if len(movement_rows) != 2:
            raise RuntimeError("Kudamon movement rows were not detected")
        rows = [sorted(group, key=lambda item: item["cx"])[:6] for group in movement_rows]
        return background, _three(rows[0][:3], "Kudamon front-left"), _three(rows[1][3:6], "Kudamon rear-left"), {
            "source_layout": "kudamon_two_rows",
            "source_group_order": ["down_left", "down_right", "up_right", "up_left"],
            "authored_groups_used": [0, 3],
        }

    # Compact Baby layouts place the useful movement triples on the right side
    # in vertical order: front-left, rear-left, front-right, rear-right.
    # This was visually verified on the raw Tokomon and Koromon sheets.
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
        raise RuntimeError(f"{sprite_id:03d}: compact four-facing movement grid was not detected")
    authored = [item[2] for item in selected]
    down_left = _three(authored[0], f"{sprite_id:03d} compact front-left")
    up_left = _three(authored[1], f"{sprite_id:03d} compact rear-left")
    return background, down_left, up_left, {
        "source_layout": "compact_four_groups",
        "source_group_order": ["down_left", "up_left", "down_right", "up_right"],
        "authored_groups_used": [0, 1],
    }


def _crop_authored_frames(
    source: Image.Image,
    background: tuple[int, int, int],
    boxes: list[dict[str, float]],
) -> list[Image.Image]:
    keyed = _transparent_source(source, background)
    result: list[Image.Image] = []
    pad = 2
    for box in boxes:
        x, y, w, h = int(box["x"]), int(box["y"]), int(box["w"]), int(box["h"])
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
            raise RuntimeError("Authored DS walk frame became empty after background removal")
        result.append(crop.crop(bbox))
    if len(result) != 3:
        raise RuntimeError(f"Expected three authored frames, got {len(result)}")
    return result


def _compose_agumon_contract(
    down_left_raw: list[Image.Image],
    up_left_raw: list[Image.Image],
    minimum_cell: tuple[int, int] = (32, 32),
) -> tuple[Image.Image, int, int]:
    authored = down_left_raw + up_left_raw
    cell_w = max(minimum_cell[0], max(frame.width for frame in authored) + 4)
    cell_h = max(minimum_cell[1], max(frame.height for frame in authored) + 4)

    def normalize(frame: Image.Image) -> Image.Image:
        canvas = Image.new("RGBA", (cell_w, cell_h), (0, 0, 0, 0))
        canvas.alpha_composite(
            frame,
            ((cell_w - frame.width) // 2, cell_h - frame.height - 1),
        )
        return canvas

    down_left = [normalize(frame) for frame in down_left_raw]
    up_left = [normalize(frame) for frame in up_left_raw]
    down_right = [ImageOps.mirror(frame) for frame in down_left]
    up_right = [ImageOps.mirror(frame) for frame in up_left]
    ordered = down_left + down_right + up_left + up_right

    output = Image.new("RGBA", (cell_w * FRAME_COUNT, cell_h), (0, 0, 0, 0))
    for index, frame in enumerate(ordered):
        output.alpha_composite(frame, (index * cell_w, 0))
    _validate_agumon_contract(output, cell_w, cell_h)
    return output, cell_w, cell_h


def _validate_agumon_contract(sheet: Image.Image, cell_w: int, cell_h: int) -> None:
    if sheet.size != (cell_w * 12, cell_h):
        raise RuntimeError(f"Unexpected directional strip size {sheet.size}")
    frames = [
        sheet.crop((index * cell_w, 0, (index + 1) * cell_w, cell_h))
        for index in range(12)
    ]
    for index, frame in enumerate(frames):
        if frame.getbbox() is None:
            raise RuntimeError(f"Directional frame {index} is empty")
    for left_base, right_base in ((0, 3), (6, 9)):
        for offset in range(3):
            expected = ImageOps.mirror(frames[left_base + offset])
            if np.array_equal(np.asarray(expected), np.asarray(frames[right_base + offset])) is False:
                raise RuntimeError(
                    f"Mirror contract failed for frames {left_base + offset}/{right_base + offset}"
                )


def _patch_resource_scale(resource_path: Path, scale: float) -> None:
    text = resource_path.read_text(encoding="utf-8")
    replacement = f"sprite_scale = Vector2({scale:.4f}, {scale:.4f})"
    if re.search(r"^sprite_scale\s*=", text, re.MULTILINE):
        text = re.sub(r"^sprite_scale\s*=.*$", replacement, text, count=1, flags=re.MULTILINE)
    else:
        marker = 'sprite_layout = "directional_12"\n'
        if marker in text:
            text = text.replace(marker, marker + replacement + "\n", 1)
        else:
            # Digimon.gd defaults to directional_12; add the scale next to texture.
            marker = re.search(r"^texture\s*=.*$", text, re.MULTILINE)
            if marker is None:
                raise RuntimeError(f"{resource_path}: texture assignment not found")
            insert_at = marker.end()
            text = text[:insert_at] + "\n" + replacement + text[insert_at:]
    resource_path.write_text(text, encoding="utf-8")


def _official_wtw_source(archive, sprite_id: int) -> tuple[str, bytes]:
    prefix = f"sprite thread/{sprite_id:03d}_"
    names = [
        name
        for name in archive.namelist()
        if name.startswith(prefix) and name.lower().endswith((".png", ".gif"))
    ]
    if len(names) != 1:
        raise RuntimeError(f"Expected one WtW source for {sprite_id:03d}, found {names}")
    return names[0], archive.read(names[0])


def _rebuild_early_official(
    archive,
    entry: dict[str, Any],
) -> dict[str, Any]:
    name = str(entry["name"])
    sprite_id = WTW_IDS[name]
    source_name, payload = _official_wtw_source(archive, sprite_id)
    source = Image.open(io.BytesIO(payload)).convert("RGBA")
    background, down_boxes, up_boxes, source_mapping = _select_authored_left_groups(source, sprite_id)
    down_left = _crop_authored_frames(source, background, down_boxes)
    up_left = _crop_authored_frames(source, background, up_boxes)
    sheet, cell_w, cell_h = _compose_agumon_contract(down_left, up_left)

    key = portrait_key(entry)
    directory = Path("assets/characters") / key
    directory.mkdir(parents=True, exist_ok=True)
    output = directory / "field.png"
    meta_path = directory / "field.json"
    sheet.save(output, "PNG", optimize=True)
    meta = {
        "source_kind": "official_ds",
        "source_variant": "withthewill_original_archive",
        "source_archive_file": source_name,
        "source_id": sprite_id,
        "source_sha256": _sha256(payload),
        "canonical_reference": GOLDEN_NAME,
        "rebuilt_from_source": True,
        "existing_runtime_strip_used_as_input": False,
        "rebuild_version": 1,
        "cell_width": cell_w,
        "cell_height": cell_h,
        "frame_count": 12,
        "frames_per_direction": 3,
        "directions": list(DIRECTION_ORDER),
        "right_facing_policy": "horizontal_mirror_of_corresponding_left_facing_group",
        "runtime_scale": 1.0,
        "field_path": f"res://assets/characters/{key}/field.png",
        **source_mapping,
    }
    meta_path.write_text(json.dumps(meta, indent=2) + "\n", encoding="utf-8")
    _patch_resource_scale(Path("assets/resources") / resource_filename(name), 1.0)
    return {
        "name": name,
        "kind": "official_wtw",
        "source": source_name,
        "source_sha256": meta["source_sha256"],
        "output": str(output),
        "output_sha256": _sha256(output.read_bytes()),
        "cell": [cell_w, cell_h],
        "source_layout": source_mapping["source_layout"],
    }


def _rebuild_community(entry: dict[str, Any]) -> dict[str, Any]:
    name = str(entry["name"])
    url, credit = COMMUNITY_SOURCES[name]
    # build_community_exception fetches the original external source every run;
    # it never consumes the runtime field.png we deleted during the hard reset.
    sheet, meta = build_community_exception(name, url, credit)
    key = portrait_key(entry)
    directory = Path("assets/characters") / key
    directory.mkdir(parents=True, exist_ok=True)
    output = directory / "field.png"
    meta_path = directory / "field.json"
    sheet.save(output, "PNG", optimize=True)
    meta.update(
        {
            "canonical_reference": GOLDEN_NAME,
            "rebuilt_from_source": True,
            "existing_runtime_strip_used_as_input": False,
            "rebuild_version": 1,
            "directions": list(DIRECTION_ORDER),
            "field_path": f"res://assets/characters/{key}/field.png",
        }
    )
    meta_path.write_text(json.dumps(meta, indent=2) + "\n", encoding="utf-8")
    _patch_resource_scale(Path("assets/resources") / resource_filename(name), float(meta.get("runtime_scale", 1.0)))
    return {
        "name": name,
        "kind": "community_source_rebuilt",
        "source": url,
        "output": str(output),
        "output_sha256": _sha256(output.read_bytes()),
        "cell": [int(meta["cell_width"]), int(meta["cell_height"])],
    }


def _rebuild_greymon() -> dict[str, Any]:
    config = LEGACY_CHARACTER_SOURCES["greymon"]
    gallery = legacy_curl(GALLERY_URL).decode("utf-8", "replace")
    sheet_url = _discover_sheet_url(gallery, config["sheet_id"])
    payload = legacy_curl(sheet_url)
    actual = _sha256(payload)
    if actual != config["expected_sha256"]:
        raise RuntimeError(f"Greymon source hash changed: {actual}")
    source = Image.open(io.BytesIO(payload)).convert("RGBA")
    authored: dict[str, list[Image.Image]] = {}
    for direction in ("down_left", "up_left"):
        authored[direction] = [
            legacy_crop_frame(
                source,
                position,
                config["frame_size"],
                config["background"],
                config["tolerance"],
            )
            for position in config["directions"][direction]
        ]
    frame_w, frame_h = config["frame_size"]
    output = Image.new("RGBA", (frame_w * 12, frame_h), (0, 0, 0, 0))
    groups = (
        authored["down_left"],
        [ImageOps.mirror(frame) for frame in authored["down_left"]],
        authored["up_left"],
        [ImageOps.mirror(frame) for frame in authored["up_left"]],
    )
    for direction_index, frames in enumerate(groups):
        for frame_index, frame in enumerate(frames):
            output.alpha_composite(frame, ((direction_index * 3 + frame_index) * frame_w, 0))
    _validate_agumon_contract(output, frame_w, frame_h)
    path = Path("assets/characters/greymon.png")
    output.save(path, "PNG", optimize=True)
    return {
        "name": "Greymon",
        "kind": "official_spriters_resource",
        "source": sheet_url,
        "source_sha256": actual,
        "output": str(path),
        "output_sha256": _sha256(path.read_bytes()),
        "cell": [frame_w, frame_h],
    }


def _rebuild_metalgreymon() -> dict[str, Any]:
    payload = metal_source.fetch(metal_source.SOURCE_URL)
    actual = _sha256(payload)
    if actual != metal_source.EXPECTED_SOURCE_SHA256:
        raise RuntimeError(f"MetalGreymon source hash changed: {actual}")
    source = Image.open(io.BytesIO(payload)).convert("RGBA")
    left: dict[str, list[Image.Image]] = {}
    for direction in ("down_left", "up_left"):
        frames: list[Image.Image] = []
        for index, box in enumerate(metal_source.SOURCE_FRAMES[direction]):
            crop = source.crop(box)
            metal_source.validate_source_crop(crop, direction, index)
            frames.append(metal_source.normalize(crop))
        left[direction] = frames
    cell_w, cell_h = metal_source.CELL_SIZE
    output = Image.new("RGBA", (cell_w * 12, cell_h), (0, 0, 0, 0))
    groups = (
        left["down_left"],
        [ImageOps.mirror(frame) for frame in left["down_left"]],
        left["up_left"],
        [ImageOps.mirror(frame) for frame in left["up_left"]],
    )
    for direction_index, frames in enumerate(groups):
        for frame_index, frame in enumerate(frames):
            output.alpha_composite(frame, ((direction_index * 3 + frame_index) * cell_w, 0))
    _validate_agumon_contract(output, cell_w, cell_h)
    path = Path("assets/characters/metalgreymon/field.png")
    path.parent.mkdir(parents=True, exist_ok=True)
    output.save(path, "PNG", optimize=True)
    meta = {
        "source_kind": "official_ds",
        "source_variant": "spriters_resource_48322",
        "source_url": metal_source.SOURCE_URL,
        "source_sha256": actual,
        "canonical_reference": GOLDEN_NAME,
        "rebuilt_from_source": True,
        "existing_runtime_strip_used_as_input": False,
        "rebuild_version": 1,
        "cell_width": cell_w,
        "cell_height": cell_h,
        "frame_count": 12,
        "frames_per_direction": 3,
        "directions": list(DIRECTION_ORDER),
        "right_facing_policy": "horizontal_mirror_of_corresponding_left_facing_group",
        "field_path": "res://assets/characters/metalgreymon/field.png",
    }
    Path("assets/characters/metalgreymon/field.json").write_text(json.dumps(meta, indent=2) + "\n", encoding="utf-8")
    return {
        "name": "Metal Greymon",
        "kind": "official_spriters_resource",
        "source": metal_source.SOURCE_URL,
        "source_sha256": actual,
        "output": str(path),
        "output_sha256": _sha256(path.read_bytes()),
        "cell": [cell_w, cell_h],
    }


def _hard_delete_non_golden_runtime_inputs(entries: list[dict[str, Any]]) -> list[str]:
    deleted: list[str] = []
    for entry in entries:
        name = str(entry["name"])
        if name == GOLDEN_NAME:
            continue
        key = portrait_key(entry)
        for path in (
            Path("assets/characters") / key / "field.png",
            Path("assets/characters") / key / "field.json",
        ):
            if path.exists():
                path.unlink()
                deleted.append(str(path))
    for path in (Path("assets/characters/greymon.png"), Path("assets/characters/metalgreymon/field.png"), Path("assets/characters/metalgreymon/field.json")):
        if path.exists():
            path.unlink()
            deleted.append(str(path))
    for path in OBSOLETE_REPORTS:
        if path.exists():
            path.unlink()
            deleted.append(str(path))
    return deleted


def _update_pinned_generated_blob_hashes() -> None:
    path = Path("tools/validate_runtime_assets.py")
    text = path.read_text(encoding="utf-8")
    for asset in ("assets/characters/veemon/field.png", "assets/characters/metalgreymon/field.png"):
        data = Path(asset).read_bytes()
        new_hash = _git_blob_sha(data)
        pattern = rf'(\"{re.escape(asset)}\"\s*:\s*\")[0-9a-f]+(\")'
        text, count = re.subn(pattern, rf'\g<1>{new_hash}\2', text, count=1)
        if count != 1:
            raise RuntimeError(f"Could not update pinned generated blob hash for {asset}")
    path.write_text(text, encoding="utf-8")


def main() -> None:
    entries = _load_early_database()
    if not GOLDEN_FIELD.exists() or not GOLDEN_META.exists():
        raise RuntimeError("Golden Agumon field strip/metadata is missing")
    golden_before = _sha256(GOLDEN_FIELD.read_bytes())
    golden_meta_before = _sha256(GOLDEN_META.read_bytes())

    deleted = _hard_delete_non_golden_runtime_inputs(entries)
    archive = load_wtw_archive()
    rebuilt: list[dict[str, Any]] = []
    unresolved: list[str] = []

    for entry in entries:
        name = str(entry["name"])
        if name == GOLDEN_NAME:
            continue
        try:
            if name in WTW_IDS:
                result = _rebuild_early_official(archive, entry)
            elif name in COMMUNITY_SOURCES:
                result = _rebuild_community(entry)
            else:
                raise RuntimeError("no original/community source registered")
            rebuilt.append(result)
            print(f"rebuilt from source: {name} -> {result['output']}")
        except Exception as exc:  # report every missing source in one failed run
            unresolved.append(f"{name}: {exc}")

    try:
        rebuilt.append(_rebuild_greymon())
        print("rebuilt from source: Greymon")
    except Exception as exc:
        unresolved.append(f"Greymon: {exc}")
    try:
        rebuilt.append(_rebuild_metalgreymon())
        print("rebuilt from source: Metal Greymon")
    except Exception as exc:
        unresolved.append(f"Metal Greymon: {exc}")

    golden_after = _sha256(GOLDEN_FIELD.read_bytes())
    golden_meta_after = _sha256(GOLDEN_META.read_bytes())
    if golden_before != golden_after or golden_meta_before != golden_meta_after:
        raise RuntimeError("Agumon golden reference was modified by the hard rebuild")

    expected_rebuilt = 88  # 86 other early-rank + Greymon + Metal Greymon
    if len(rebuilt) != expected_rebuilt:
        unresolved.append(f"rebuild count mismatch: expected {expected_rebuilt}, got {len(rebuilt)}")

    manifest = {
        "canonical_reference": GOLDEN_NAME,
        "canonical_runtime_order": list(DIRECTION_ORDER),
        "canonical_slot_ranges": {
            "down_left": [0, 2],
            "down_right": [3, 5],
            "up_left": [6, 8],
            "up_right": [9, 11],
        },
        "right_facing_policy": "mirror the corresponding authored left-facing group, matching Agumon",
        "existing_non_agumon_runtime_strips_allowed_as_input": False,
        "preserved_count": 1,
        "preserved": [{
            "name": GOLDEN_NAME,
            "field": str(GOLDEN_FIELD),
            "sha256": golden_after,
        }],
        "deleted_before_rebuild_count": len(deleted),
        "deleted_before_rebuild": deleted,
        "rebuilt_count": len(rebuilt),
        "rebuilt": rebuilt,
        "unresolved": unresolved,
    }
    MANIFEST.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")

    if unresolved:
        raise RuntimeError("DS hard rebuild is incomplete:\n- " + "\n- ".join(unresolved))

    _update_pinned_generated_blob_hashes()
    print(f"DS hard rebuild complete: 1 preserved (Agumon), {len(rebuilt)} rebuilt from source")


if __name__ == "__main__":
    main()
