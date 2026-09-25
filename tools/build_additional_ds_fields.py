#!/usr/bin/env python3
"""Build higher-rank DS field sprites into DigiGame's canonical directional_12 contract.

The source manifest describes reusable sheet layouts and semantic direction patterns.
No runtime code knows individual species quirks: every generated field strip is
DL, DR, UL, UR x idle, step_a, step_b with a uniform bottom-center anchor.
"""
from __future__ import annotations

import hashlib
import io
import json
import re
from pathlib import Path, PurePosixPath
from typing import Any
from urllib.parse import quote

from PIL import Image, ImageSequence
import numpy as np

from build_early_rank_ds_fields import _components, _group_by_y, load_wtw_archive
from materialize_ds_direction_registry import crop_component, keyed_source, pose_match_candidates
from sync_digimon_database_assets import fetch

CONFIG_PATH = Path("database/ds-additional-sources.json")
DATABASE_PATH = Path("database/base-digimon-list.json")
MANIFEST_PATH = Path("database/additional-ds-playables.json")
DIRECTIONS = ("down_left", "down_right", "up_left", "up_right")
PHASES = ("idle", "step_a", "step_b")
PORTRAIT_ROOT = "https://raw.githubusercontent.com/EwertonMendes/digimon-ng/master/public/assets/digimons"
FRAME_COUNT = 12


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def compact_key(value: str) -> str:
    return re.sub(r"[^a-z0-9]+", "", value.lower())


def resource_filename(name: str) -> str:
    return f"{name.strip().lower()}.tres"


def exact_box(component: dict[str, float]) -> dict[str, int]:
    return {key: int(component[key]) for key in ("x", "y", "w", "h")}


def optional_source_id(spec: dict[str, Any]) -> int | None:
    value = spec.get("source_id")
    return None if value is None else int(value)


def source_member(archive, expected: str) -> bytes:
    if expected not in archive.namelist():
        raise RuntimeError(f"Pinned WtW source missing: {expected}")
    return archive.read(expected)


def movement_groups(
    image: Image.Image,
    profile: dict[str, Any],
    explicit_groups: Any = None,
) -> list[list[dict[str, int]]]:
    kind = str(profile.get("kind", ""))
    if kind == "explicit_groups":
        if not isinstance(explicit_groups, list) or len(explicit_groups) != 4:
            raise RuntimeError("explicit_groups profile requires exactly four direction groups")
        groups: list[list[dict[str, int]]] = []
        for group_index, group in enumerate(explicit_groups):
            if not isinstance(group, list) or len(group) != 3:
                raise RuntimeError(
                    f"explicit_groups direction {group_index} must contain exactly three source boxes"
                )
            normalized: list[dict[str, int]] = []
            for frame_index, box in enumerate(group):
                if not isinstance(box, dict):
                    raise RuntimeError(
                        f"explicit_groups direction {group_index} frame {frame_index} must be an object"
                    )
                normalized_box = {key: int(box[key]) for key in ("x", "y", "w", "h")}
                x, y, w, h = (
                    normalized_box["x"], normalized_box["y"],
                    normalized_box["w"], normalized_box["h"],
                )
                if w <= 0 or h <= 0 or x < 0 or y < 0 or x + w > image.width or y + h > image.height:
                    raise RuntimeError(
                        f"explicit_groups box is outside source bounds: {normalized_box} "
                        f"for {image.width}x{image.height}"
                    )
                normalized.append(normalized_box)
            groups.append(normalized)
        return groups

    _background, components = _components(image)
    min_cx_ratio = float(profile.get("min_cx_ratio", 0.0))
    max_cx_ratio = float(profile.get("max_cx_ratio", 1.0))
    min_cy_ratio = float(profile.get("min_cy_ratio", 0.0))
    max_cy_ratio = float(profile.get("max_cy_ratio", 1.0))
    if not 0.0 <= min_cx_ratio < max_cx_ratio <= 1.0:
        raise RuntimeError(
            f"Invalid structural profile x-range: min_cx_ratio={min_cx_ratio} max_cx_ratio={max_cx_ratio}"
        )
    if not 0.0 <= min_cy_ratio < max_cy_ratio <= 1.0:
        raise RuntimeError(
            f"Invalid structural profile y-range: min_cy_ratio={min_cy_ratio} max_cy_ratio={max_cy_ratio}"
        )
    min_cx = image.width * min_cx_ratio
    max_cx = image.width * max_cx_ratio
    min_cy = image.height * min_cy_ratio
    max_cy = image.height * max_cy_ratio
    candidates = [
        item for item in components
        if 10 <= item["w"] <= 50
        and 7 <= item["h"] <= 50
        and item["area"] >= 60
        and min_cx <= item["cx"] <= max_cx
        and min_cy <= item["cy"] <= max_cy
    ]
    rows = _group_by_y(candidates, tolerance=8.0)
    if kind == "two_rows_of_six":
        six_rows = [sorted(row, key=lambda item: item["cx"]) for row in rows if len(row) >= 6]
        if len(six_rows) < 2:
            raise RuntimeError(f"Expected at least two six-frame movement rows, got {[len(row) for row in rows]}")
        first, second = six_rows[:2]
        groups = [first[:3], first[3:6], second[:3], second[3:6]]
    elif kind == "single_row_four_triples":
        wide_rows = [sorted(row, key=lambda item: item["cx"]) for row in rows if len(row) >= 12]
        if not wide_rows:
            raise RuntimeError(f"Expected one row with at least 12 movement cells, got {[len(row) for row in rows]}")
        row = max(wide_rows, key=len)[:12]
        groups = [row[0:3], row[3:6], row[6:9], row[9:12]]
    elif kind == "four_rows_rightmost_triples":
        movement_rows = [sorted(row, key=lambda item: item["cx"])[-3:] for row in rows if len(row) >= 3]
        if len(movement_rows) < 4:
            raise RuntimeError(f"Expected four movement rows, got {[len(row) for row in rows]}")
        groups = movement_rows[:4]
    elif kind == "four_rows_first_two_leftmost_last_two_rightmost":
        movement_rows = [sorted(row, key=lambda item: item["cx"]) for row in rows if len(row) >= 3]
        if len(movement_rows) < 4:
            raise RuntimeError(f"Expected four movement rows, got {[len(row) for row in rows]}")
        first, second, third, fourth = movement_rows[:4]
        groups = [first[:3], second[:3], third[-3:], fourth[-3:]]
    elif kind == "four_rows_selected_triples":
        movement_rows = [sorted(row, key=lambda item: item["cx"]) for row in rows if len(row) >= 3]
        if len(movement_rows) < 4:
            raise RuntimeError(f"Expected four movement rows, got {[len(row) for row in rows]}")
        sides = profile.get("triplet_sides")
        if not isinstance(sides, list) or len(sides) != 4 or any(side not in {"left", "right"} for side in sides):
            raise RuntimeError(
                "four_rows_selected_triples requires triplet_sides with exactly four 'left'/'right' values"
            )
        groups = [
            row[:3] if side == "left" else row[-3:]
            for row, side in zip(movement_rows[:4], sides)
        ]
    elif kind == "four_rows_leftmost_triples":
        movement_rows = [sorted(row, key=lambda item: item["cx"])[:3] for row in rows if len(row) >= 3]
        if len(movement_rows) < 4:
            raise RuntimeError(f"Expected four movement rows, got {[len(row) for row in rows]}")
        groups = movement_rows[:4]
    else:
        raise RuntimeError(f"Unknown reusable extraction profile: {kind}")

    if len(groups) != 4 or any(len(group) != 3 for group in groups):
        raise RuntimeError(f"Profile {kind} did not yield exactly 4x3 movement frames")
    return [[exact_box(item) for item in group] for group in groups]


def keyed_source_with_tolerance(
    image: Image.Image,
    background_rgb: tuple[int, int, int],
    tolerance: int,
) -> Image.Image:
    if tolerance <= 0:
        return keyed_source(image, background_rgb)
    rgba = np.array(image.convert("RGBA"), copy=True)
    background = np.asarray(background_rgb, dtype=np.int16)
    delta = np.max(np.abs(rgba[:, :, :3].astype(np.int16) - background), axis=2)
    rgba[(delta <= tolerance) & (rgba[:, :, 3] > 0), 3] = 0
    return Image.fromarray(rgba, "RGBA")


def keyed_source_preserving_outline(
    image: Image.Image,
    background_rgb: tuple[int, int, int],
    tolerance: int,
    outline_radius: int,
) -> Image.Image:
    """Remove a flat matte while preserving same-color outline pixels near authored art.

    Some legacy WTW sheets use black both for the canvas and for one/two-pixel
    sprite outlines. A global black color-key destroys the silhouette. Instead,
    seed the foreground from pixels that differ from the matte and keep matte-
    colored pixels only when they are within outline_radius pixels of that
    authored foreground.
    """
    rgba = np.array(image.convert("RGBA"), copy=True)
    background = np.asarray(background_rgb, dtype=np.int16)
    delta = np.max(np.abs(rgba[:, :, :3].astype(np.int16) - background), axis=2)
    seed = (delta > tolerance) & (rgba[:, :, 3] > 0)
    keep = seed.copy()
    radius = int(outline_radius)
    if radius < 0 or radius > 4:
        raise RuntimeError(f"Invalid background_outline_radius {radius}; expected 0..4")
    if radius:
        padded = np.pad(seed, radius, mode="constant", constant_values=False)
        dilated = np.zeros_like(seed)
        h, w = seed.shape
        for dy in range(2 * radius + 1):
            for dx in range(2 * radius + 1):
                dilated |= padded[dy:dy + h, dx:dx + w]
        keep |= dilated
    rgba[(~keep) & (rgba[:, :, 3] > 0), 3] = 0
    return Image.fromarray(rgba, "RGBA")


def crop_frame_border_connected_matte(
    source: Image.Image,
    box: dict[str, int],
    background_rgb: tuple[int, int, int],
    tolerance: int,
) -> Image.Image:
    """Remove only matte pixels connected to the border of one authored frame.

    This preserves same-color pixels enclosed by the Digimon itself while
    removing legacy opaque WTW/Photobucket canvas colors around the sprite.
    """
    x, y, w, h = (int(box[key]) for key in ("x", "y", "w", "h"))
    pad = 2
    crop = source.crop((
        max(0, x - pad),
        max(0, y - pad),
        min(source.width, x + w + pad),
        min(source.height, y + h + pad),
    )).convert("RGBA")
    rgba = np.array(crop, copy=True)
    background = np.asarray(background_rgb, dtype=np.int16)
    delta = np.max(np.abs(rgba[:, :, :3].astype(np.int16) - background), axis=2)
    matte = (delta <= tolerance) & (rgba[:, :, 3] > 0)

    connected = np.zeros_like(matte)
    h_px, w_px = matte.shape
    stack: list[tuple[int, int]] = []
    for xx in range(w_px):
        if matte[0, xx]:
            stack.append((0, xx))
        if h_px > 1 and matte[h_px - 1, xx]:
            stack.append((h_px - 1, xx))
    for yy in range(h_px):
        if matte[yy, 0]:
            stack.append((yy, 0))
        if w_px > 1 and matte[yy, w_px - 1]:
            stack.append((yy, w_px - 1))

    while stack:
        yy, xx = stack.pop()
        if connected[yy, xx] or not matte[yy, xx]:
            continue
        connected[yy, xx] = True
        if yy > 0:
            stack.append((yy - 1, xx))
        if yy + 1 < h_px:
            stack.append((yy + 1, xx))
        if xx > 0:
            stack.append((yy, xx - 1))
        if xx + 1 < w_px:
            stack.append((yy, xx + 1))

    rgba[connected, 3] = 0
    frame = Image.fromarray(rgba, "RGBA")
    bbox = frame.getbbox()
    if bbox is None:
        raise RuntimeError(f"Source component became empty after border matte removal: {box}")
    return frame.crop(bbox)


def remove_tiny_alpha_islands(frame: Image.Image, max_pixels: int) -> Image.Image:
    """Remove tiny disconnected alpha components while preserving connected sprite art."""
    if max_pixels <= 0:
        return frame
    rgba = np.array(frame.convert("RGBA"), copy=True)
    mask = rgba[:, :, 3] > 0
    height, width = mask.shape
    visited = np.zeros_like(mask)
    for start_y in range(height):
        for start_x in range(width):
            if visited[start_y, start_x] or not mask[start_y, start_x]:
                continue
            stack = [(start_y, start_x)]
            component: list[tuple[int, int]] = []
            visited[start_y, start_x] = True
            while stack:
                yy, xx = stack.pop()
                component.append((yy, xx))
                for dy in (-1, 0, 1):
                    for dx in (-1, 0, 1):
                        if dx == 0 and dy == 0:
                            continue
                        ny, nx = yy + dy, xx + dx
                        if 0 <= ny < height and 0 <= nx < width and mask[ny, nx] and not visited[ny, nx]:
                            visited[ny, nx] = True
                            stack.append((ny, nx))
            if len(component) <= max_pixels:
                for yy, xx in component:
                    rgba[yy, xx, 3] = 0
    return Image.fromarray(rgba, "RGBA")


def remove_small_border_islands(frame: Image.Image, max_pixels: int) -> Image.Image:
    """Remove tiny disconnected alpha islands touching a crop border.

    Legacy sprite sheets can contain a few pixels from a neighbouring cell or
    watermark at the edge of an otherwise correct explicit frame box. Only
    small connected components that touch the frame border are removed; the
    Digimon's main connected artwork is left untouched.
    """
    if max_pixels <= 0:
        return frame
    rgba = np.array(frame.convert("RGBA"), copy=True)
    mask = rgba[:, :, 3] > 0
    height, width = mask.shape
    visited = np.zeros_like(mask)
    for start_y in range(height):
        for start_x in range(width):
            if visited[start_y, start_x] or not mask[start_y, start_x]:
                continue
            stack = [(start_y, start_x)]
            component: list[tuple[int, int]] = []
            touches_border = False
            visited[start_y, start_x] = True
            while stack:
                yy, xx = stack.pop()
                component.append((yy, xx))
                if yy == 0 or xx == 0 or yy == height - 1 or xx == width - 1:
                    touches_border = True
                for dy in (-1, 0, 1):
                    for dx in (-1, 0, 1):
                        if dx == 0 and dy == 0:
                            continue
                        ny, nx = yy + dy, xx + dx
                        if 0 <= ny < height and 0 <= nx < width and mask[ny, nx] and not visited[ny, nx]:
                            visited[ny, nx] = True
                            stack.append((ny, nx))
            if touches_border and len(component) <= max_pixels:
                for yy, xx in component:
                    rgba[yy, xx, 3] = 0
    return Image.fromarray(rgba, "RGBA")


def build_field(name: str, source: Image.Image, source_bytes: bytes, spec: dict[str, Any], config: dict[str, Any]) -> dict[str, Any]:
    profile_name = str(spec["profile"])
    pattern_name = str(spec["pattern"])
    profile = config["profiles"][profile_name]
    permutation = [int(value) for value in config["patterns"][pattern_name]]
    if sorted(permutation) != [0, 1, 2, 3]:
        raise RuntimeError(f"{name}: invalid direction permutation {permutation}")

    mirror_config = spec.get("horizontal_mirror_from", {})
    if not isinstance(mirror_config, dict):
        raise RuntimeError(f"{name}: horizontal_mirror_from must be an object")
    allowed_horizontal_mirrors = {
        ("down_left", "down_right"),
        ("down_right", "down_left"),
        ("up_left", "up_right"),
        ("up_right", "up_left"),
    }
    horizontal_mirror_from: dict[str, str] = {}
    for target_direction, source_direction in mirror_config.items():
        target_direction = str(target_direction)
        source_direction = str(source_direction)
        if (target_direction, source_direction) not in allowed_horizontal_mirrors:
            raise RuntimeError(
                f"{name}: unsupported horizontal mirror {target_direction} <- {source_direction}; "
                "only matching left/right facings at the same front/back depth may be synthesized"
            )
        horizontal_mirror_from[target_direction] = source_direction

    raw_groups = movement_groups(source, profile, spec.get("explicit_groups"))
    raw_frames = {direction: raw_groups[permutation[index]] for index, direction in enumerate(DIRECTIONS)}
    effective_runtime_group_indices = list(permutation)
    for target_direction, source_direction in horizontal_mirror_from.items():
        raw_frames[target_direction] = raw_frames[source_direction]
        effective_runtime_group_indices[DIRECTIONS.index(target_direction)] = permutation[DIRECTIONS.index(source_direction)]
    background, _ = _components(source)
    source_frame_order: dict[str, list[int]] = {
        "down_left": [0, 1, 2],
        "up_left": [0, 1, 2],
        "down_right": [],
        "up_right": [],
    }
    pose_alignment: dict[str, Any] = {}
    for left_direction, right_direction in (("down_left", "down_right"), ("up_left", "up_right")):
        if horizontal_mirror_from.get(right_direction) == left_direction:
            source_frame_order[right_direction] = list(source_frame_order[left_direction])
            pose_alignment[right_direction] = {
                "compared_with": left_direction,
                "policy": "generated_horizontal_mirror",
                "source_phase_order": list(source_frame_order[left_direction]),
                "pixel_error": 0,
                "confidence_margin": None,
            }
            continue
        if horizontal_mirror_from.get(left_direction) == right_direction:
            source_frame_order[right_direction] = [0, 1, 2]
            source_frame_order[left_direction] = list(source_frame_order[right_direction])
            pose_alignment[left_direction] = {
                "compared_with": right_direction,
                "policy": "generated_horizontal_mirror",
                "source_phase_order": list(source_frame_order[right_direction]),
                "pixel_error": 0,
                "confidence_margin": None,
            }
            continue
        candidates = pose_match_candidates(
            source,
            background,
            raw_frames[left_direction],
            raw_frames[right_direction],
        )
        best_cost, best_order = candidates[0]
        source_frame_order[right_direction] = list(best_order)
        pose_alignment[right_direction] = {
            "compared_with": left_direction,
            "policy": "deterministic_mirror_pose_match",
            "source_phase_order": list(best_order),
            "pixel_error": int(best_cost),
            "confidence_margin": int(candidates[1][0] - best_cost),
        }

    background_tolerance = int(spec.get("background_tolerance", 0))
    if not 0 <= background_tolerance <= 255:
        raise RuntimeError(f"{name}: invalid background_tolerance {background_tolerance}")
    background_outline_radius = int(spec.get("background_outline_radius", 0))

    frame_background_policy = str(spec.get("frame_background_policy", "global_key"))
    if frame_background_policy not in {"global_key", "source_alpha", "border_connected_matte"}:
        raise RuntimeError(f"{name}: unknown frame_background_policy {frame_background_policy}")
    frame_background_tolerance = int(spec.get("frame_background_tolerance", 0))
    if not 0 <= frame_background_tolerance <= 255:
        raise RuntimeError(f"{name}: invalid frame_background_tolerance {frame_background_tolerance}")
    frame_background_rgb_raw = spec.get("frame_background_rgb")
    if frame_background_rgb_raw is None:
        frame_background_rgb = tuple(int(value) for value in background)
    else:
        if not isinstance(frame_background_rgb_raw, list) or len(frame_background_rgb_raw) != 3:
            raise RuntimeError(f"{name}: frame_background_rgb must contain exactly three values")
        frame_background_rgb = tuple(int(value) for value in frame_background_rgb_raw)
        if any(value < 0 or value > 255 for value in frame_background_rgb):
            raise RuntimeError(f"{name}: invalid frame_background_rgb {frame_background_rgb}")

    if frame_background_policy in {"source_alpha", "border_connected_matte"}:
        keyed = source
    elif background_outline_radius:
        keyed = keyed_source_preserving_outline(
            source,
            background,
            background_tolerance,
            background_outline_radius,
        )
    else:
        keyed = keyed_source_with_tolerance(source, background, background_tolerance)
    vertical_alignment = str(spec.get("vertical_alignment", "frame_bottom"))
    if vertical_alignment not in {"frame_bottom", "source_group_envelope"}:
        raise RuntimeError(f"{name}: unknown vertical alignment policy {vertical_alignment}")
    preserve_source_box = bool(spec.get("preserve_source_box", False))
    border_island_cleanup_max_pixels = int(spec.get("border_island_cleanup_max_pixels", 0))
    alpha_island_cleanup_max_pixels = int(spec.get("alpha_island_cleanup_max_pixels", 0))
    if border_island_cleanup_max_pixels < 0 or border_island_cleanup_max_pixels > 64:
        raise RuntimeError(
            f"{name}: border_island_cleanup_max_pixels must be within 0..64"
        )
    if alpha_island_cleanup_max_pixels < 0 or alpha_island_cleanup_max_pixels > 32:
        raise RuntimeError(
            f"{name}: alpha_island_cleanup_max_pixels must be within 0..32"
        )
    if preserve_source_box and frame_background_policy == "border_connected_matte":
        raise RuntimeError(
            f"{name}: preserve_source_box is not supported with border_connected_matte; "
            "use source_alpha/global_key or add an exact matte implementation first"
        )

    frames: list[Image.Image] = []
    frame_placements: list[tuple[int, int]] = []
    audited_boxes: dict[str, list[dict[str, int]]] = {}
    source_group_envelopes: dict[str, dict[str, int]] = {}
    for direction in DIRECTIONS:
        ordered_boxes = [raw_frames[direction][index] for index in source_frame_order[direction]]
        audited_boxes[direction] = ordered_boxes
        group_top = min(box["y"] for box in ordered_boxes)
        group_bottom = max(box["y"] + box["h"] for box in ordered_boxes)
        envelope_height = group_bottom - group_top
        source_group_envelopes[direction] = {
            "source_top": group_top,
            "source_bottom": group_bottom,
            "height": envelope_height,
        }
        for box in ordered_boxes:
            if preserve_source_box:
                x, y, w, h = (int(box[key]) for key in ("x", "y", "w", "h"))
                frame_source = source if frame_background_policy == "source_alpha" else keyed
                frame = frame_source.crop((x, y, x + w, y + h))
                if frame.getbbox() is None:
                    raise RuntimeError(f"{name}: exact source box became empty: {box}")
            elif frame_background_policy == "source_alpha":
                frame = crop_component(source, box)
            elif frame_background_policy == "border_connected_matte":
                frame = crop_frame_border_connected_matte(
                    source,
                    box,
                    frame_background_rgb,
                    frame_background_tolerance,
                )
            else:
                frame = crop_component(keyed, box)
            if border_island_cleanup_max_pixels:
                frame = remove_small_border_islands(frame, border_island_cleanup_max_pixels)
            if alpha_island_cleanup_max_pixels:
                frame = remove_tiny_alpha_islands(frame, alpha_island_cleanup_max_pixels)
            if direction in horizontal_mirror_from:
                frame = frame.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
            frames.append(frame)
            if vertical_alignment == "source_group_envelope":
                frame_placements.append((box["y"] - group_top, envelope_height))
            else:
                frame_placements.append((0, frame.height))

    cell_w = max(32, max(frame.width for frame in frames) + 4)
    if vertical_alignment == "source_group_envelope":
        cell_h = max(32, max(envelope_height for _, envelope_height in frame_placements) + 4)
    else:
        cell_h = max(32, max(frame.height for frame in frames) + 4)

    strip = Image.new("RGBA", (cell_w * FRAME_COUNT, cell_h), (0, 0, 0, 0))
    for index, frame in enumerate(frames):
        offset_y, envelope_height = frame_placements[index]
        if vertical_alignment == "source_group_envelope":
            y = cell_h - envelope_height - 1 + offset_y
        else:
            y = cell_h - frame.height - 1
        strip.alpha_composite(frame, (index * cell_w + (cell_w - frame.width) // 2, y))
    for index in range(FRAME_COUNT):
        if strip.crop((index * cell_w, 0, (index + 1) * cell_w, cell_h)).getbbox() is None:
            raise RuntimeError(f"{name}: generated empty runtime frame {index}")

    key = compact_key(name)
    directory = Path("assets/characters") / key
    directory.mkdir(parents=True, exist_ok=True)
    field_path = directory / "field.png"
    strip.save(field_path, "PNG", optimize=True)
    metadata = {
        "source_kind": "official_ds",
        "source_variant": "withthewill_additional_audited",
        "source_id": optional_source_id(spec),
        "source_archive_file": spec.get("source_member"),
        "source_url": str(spec["source_url"]),
        "source_sha256": sha256(source_bytes),
        "rebuilt_from_source": True,
        "existing_runtime_strip_used_as_input": False,
        "extraction_profile": profile_name,
        "review_pattern": pattern_name,
        "runtime_group_indices": permutation,
        "effective_runtime_group_indices": effective_runtime_group_indices,
        "horizontal_mirror_from": horizontal_mirror_from,
        "generated_horizontal_mirrors": sorted(horizontal_mirror_from),
        "canonical_runtime_order": list(DIRECTIONS),
        "canonical_runtime_phases": list(PHASES),
        "source_frame_order": source_frame_order,
        "pose_alignment": pose_alignment,
        "vertical_alignment_policy": vertical_alignment,
        "preserve_source_box": preserve_source_box,
        "border_island_cleanup_max_pixels": border_island_cleanup_max_pixels,
        "alpha_island_cleanup_max_pixels": alpha_island_cleanup_max_pixels,
        "source_group_envelopes": source_group_envelopes,
        "anchor_policy": (
            "source_group_envelope_bottom_center"
            if vertical_alignment == "source_group_envelope"
            else "bottom_center_in_uniform_species_cell"
        ),
        "frame_anchor": [cell_w // 2, cell_h - 1],
        "audited_source_frames": audited_boxes,
        "cell_width": cell_w,
        "cell_height": cell_h,
        "frame_count": FRAME_COUNT,
        "frames_per_direction": 3,
        "field_path": f"res://assets/characters/{key}/field.png",
    }
    if background_tolerance > 0:
        metadata["background_tolerance"] = background_tolerance
    if background_outline_radius > 0:
        metadata["background_outline_radius"] = background_outline_radius
    if frame_background_policy != "global_key":
        metadata["frame_background_policy"] = frame_background_policy
        if frame_background_policy == "border_connected_matte":
            metadata["frame_background_rgb"] = list(frame_background_rgb)
            metadata["frame_background_tolerance"] = frame_background_tolerance
    (directory / "field.json").write_text(json.dumps(metadata, indent=2) + "\n", encoding="utf-8")
    return metadata


def build_portrait(entry: dict[str, Any]) -> dict[str, Any]:
    image_name = PurePosixPath(str(entry["img"])).name
    payload = fetch(f"{PORTRAIT_ROOT}/{quote(image_name, safe='')}")
    with Image.open(io.BytesIO(payload)) as image:
        frames: list[Image.Image] = []
        durations: list[int] = []
        for frame in ImageSequence.Iterator(image):
            frames.append(frame.convert("RGBA").copy())
            durations.append(max(20, int(frame.info.get("duration", image.info.get("duration", 120)))))
        if not frames:
            frames = [image.convert("RGBA").copy()]
            durations = [120]
    width, height = frames[0].size
    if any(frame.size != (width, height) for frame in frames):
        raise RuntimeError(f"{entry['name']}: portrait frames do not share one canvas size")
    strip = Image.new("RGBA", (width * len(frames), height), (0, 0, 0, 0))
    for index, frame in enumerate(frames):
        strip.alpha_composite(frame, (index * width, 0))
    key = compact_key(str(entry["name"]))
    directory = Path("assets/characters") / key
    directory.mkdir(parents=True, exist_ok=True)
    strip.save(directory / "portrait_frames.png", "PNG", optimize=True)
    metadata = {
        "source": image_name,
        "source_url": f"{PORTRAIT_ROOT}/{quote(image_name, safe='')}",
        "frame_width": width,
        "frame_height": height,
        "frame_count": len(frames),
        "durations_ms": durations,
        "source_sha256": sha256(payload),
    }
    (directory / "portrait_frames.json").write_text(json.dumps(metadata, indent=2) + "\n", encoding="utf-8")
    return metadata


def write_resource(entry: dict[str, Any], field: dict[str, Any]) -> str:
    name = str(entry["name"])
    key = compact_key(name)
    path = Path("assets/resources") / resource_filename(name)
    path.parent.mkdir(parents=True, exist_ok=True)
    text = f'''[gd_resource type="Resource" script_class="Digimon" load_steps=3 format=3]\n\n[ext_resource type="Script" path="res://src/resources/Digimon.gd" id="1_script"]\n[ext_resource type="Texture2D" path="res://assets/characters/{key}/field.png" id="2_texture"]\n\n[resource]\nscript = ExtResource("1_script")\ntexture = ExtResource("2_texture")\ninitial_frame = 0\ninitial_facing = "down_left"\nsprite_hframes = 12\nsprite_vframes = 1\nsprite_layout = "directional_12"\nsprite_scale = Vector2(1.0000, 1.0000)\nsprite_frame_duration = 0.120\nsprite_deviation = Vector2(0, 20)\nparticle_deviation = Vector2(0, 10)\ninitial_position = Vector2i(0, 0)\ntype = {json.dumps(str(entry.get("attribute", "Free")))}\ndisplay_name = {json.dumps(name)}\nlevel = 1\nhp = {max(1, int(entry.get("hp", 1)))}\nmp = {max(0, int(entry.get("mp", entry.get("sp", 0))))}\nattack = {max(1, int(entry.get("atk", entry.get("attack", 1))))}\ndefense = {max(1, int(entry.get("def", entry.get("defense", 1))))}\nage = 1\nbattles = 0\nvictories = 0\ndefeats = 0\n'''
    path.write_text(text, encoding="utf-8")
    return f"res://assets/resources/{resource_filename(name)}"


def main() -> None:
    config = json.loads(CONFIG_PATH.read_text(encoding="utf-8"))
    if config.get("canonical_runtime_order") != list(DIRECTIONS):
        raise RuntimeError("Additional DS config runtime direction order is not canonical")
    if config.get("canonical_runtime_phases") != list(PHASES):
        raise RuntimeError("Additional DS config phase order is not canonical")
    database = json.loads(DATABASE_PATH.read_text(encoding="utf-8"))
    by_name = {str(entry["name"]): entry for entry in database}
    requested = config.get("species", {})
    if set(requested) - set(by_name):
        raise RuntimeError(f"Additional DS species missing from canonical database: {sorted(set(requested) - set(by_name))}")

    archive = load_wtw_archive()
    manifest_rows = []
    for name, spec in requested.items():
        if spec["profile"] not in config["profiles"] or spec["pattern"] not in config["patterns"]:
            raise RuntimeError(f"{name}: unknown profile/pattern")
        pinned_member = spec.get("source_member")
        if pinned_member:
            payload = source_member(archive, str(pinned_member))
        else:
            source_url = str(spec.get("source_url") or "").strip()
            if not source_url:
                raise RuntimeError(f"{name}: source_member or source_url is required")
            payload = fetch(source_url)
        actual_sha = sha256(payload)
        if actual_sha != str(spec["source_sha256"]):
            raise RuntimeError(f"{name}: source SHA changed ({actual_sha}); refusing to infer from changed art")
        source = Image.open(io.BytesIO(payload)).convert("RGBA")
        field = build_field(name, source, payload, spec, config)
        portrait = build_portrait(by_name[name])
        resource = write_resource(by_name[name], field)
        key = compact_key(name)
        manifest_rows.append({
            "name": name,
            "seed": str(by_name[name]["seed"]),
            "rank": str(by_name[name]["rank"]),
            "attribute": str(by_name[name].get("attribute", "")),
            "resource": resource,
            "visual_mode": "directional_12",
            "field_sprite": f"res://assets/characters/{key}/field.png",
            "field_metadata": f"res://assets/characters/{key}/field.json",
            "portrait_strip": f"res://assets/characters/{key}/portrait_frames.png",
            "portrait_metadata": f"res://assets/characters/{key}/portrait_frames.json",
            "source_id": optional_source_id(spec),
            "profile": str(spec["profile"]),
            "pattern": str(spec["pattern"]),
            "field_cell": [int(field["cell_width"]), int(field["cell_height"])],
            "portrait_frames": int(portrait["frame_count"]),
        })
        print(f"built {name}: profile={spec['profile']} pattern={spec['pattern']} cell={field['cell_width']}x{field['cell_height']}")

    manifest = {
        "schema_version": 1,
        "canonical_runtime_order": list(DIRECTIONS),
        "canonical_runtime_phases": list(PHASES),
        "count": len(manifest_rows),
        "species": manifest_rows,
    }
    MANIFEST_PATH.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(f"additional DS fields built: {len(manifest_rows)} species")


if __name__ == "__main__":
    main()
