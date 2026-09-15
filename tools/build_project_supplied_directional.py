#!/usr/bin/env python3
"""Normalize project-supplied directional sprite sheets into DigiGame's canonical 12-frame contract."""
from __future__ import annotations

import hashlib
import json
import re
from pathlib import Path
from typing import Any

import numpy as np
from PIL import Image, ImageSequence

ROOT = Path(__file__).resolve().parents[1]
CONFIG_PATH = ROOT / "database/project-supplied-sources.json"
DATABASE_PATH = ROOT / "database/base-digimon-list.json"
MANIFEST_PATH = ROOT / "database/project-supplied-playables.json"
DIRECTIONS = ["down_left", "down_right", "up_left", "up_right"]
PHASES = ["idle", "step_a", "step_b"]
DEFAULT_FRAME_DURATION_MS = 120


def compact_key(value: str) -> str:
    return re.sub(r"[^a-z0-9]+", "", value.lower())


def resource_filename(value: str) -> str:
    return f"{value.strip().lower()}.tres"


def local_res(value: str) -> Path:
    if not value.startswith("res://"):
        raise RuntimeError(f"Expected res:// path, got {value!r}")
    return ROOT / value.removeprefix("res://")


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def git_blob_sha(path: Path) -> str:
    payload = path.read_bytes()
    return hashlib.sha1(f"blob {len(payload)}\0".encode("ascii") + payload).hexdigest()


def rgb_to_hsv(rgb: np.ndarray) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    rgb = rgb.astype(np.float32) / 255.0
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    maximum = np.max(rgb, axis=-1)
    minimum = np.min(rgb, axis=-1)
    delta = maximum - minimum
    hue = np.zeros_like(maximum)
    nonzero = delta > 1e-6
    red = nonzero & (maximum == r)
    green = nonzero & (maximum == g)
    blue = nonzero & (maximum == b)
    hue[red] = ((g[red] - b[red]) / delta[red]) % 6.0
    hue[green] = ((b[green] - r[green]) / delta[green]) + 2.0
    hue[blue] = ((r[blue] - g[blue]) / delta[blue]) + 4.0
    hue *= 60.0
    saturation = np.zeros_like(maximum)
    nz_value = maximum > 1e-6
    saturation[nz_value] = delta[nz_value] / maximum[nz_value]
    return hue, saturation, maximum


def key_background(image: Image.Image, config: dict[str, Any]) -> Image.Image:
    if str(config.get("mode")) != "hsv_range":
        raise RuntimeError(f"Unsupported project-supplied background mode: {config.get('mode')}")
    rgba = np.array(image.convert("RGBA"), copy=True)
    hue, saturation, value = rgb_to_hsv(rgba[..., :3])
    background = (
        (hue >= float(config["hue_min"]))
        & (hue <= float(config["hue_max"]))
        & (saturation >= float(config["saturation_min"]))
        & (saturation <= float(config["saturation_max"]))
        & (value >= float(config["value_min"]))
        & (value <= float(config["value_max"]))
    )
    rgba[background, 3] = 0
    return Image.fromarray(rgba, "RGBA")


def intervals(mask: np.ndarray, minimum_span: int) -> list[tuple[int, int]]:
    result: list[tuple[int, int]] = []
    start: int | None = None
    for index, active in enumerate(mask.tolist()):
        if active and start is None:
            start = index
        elif not active and start is not None:
            if index - start >= minimum_span:
                result.append((start, index))
            start = None
    if start is not None and len(mask) - start >= minimum_span:
        result.append((start, len(mask)))
    return result


def detect_rows(image: Image.Image, projection_min_pixels: int, minimum_span: int) -> list[tuple[int, int]]:
    alpha = np.asarray(image.getchannel("A")) > 0
    counts = alpha.sum(axis=1)
    return intervals(counts > projection_min_pixels, minimum_span)


def detect_columns(image: Image.Image, row: tuple[int, int], projection_min_pixels: int, minimum_span: int) -> list[tuple[int, int]]:
    y0, y1 = row
    alpha = np.asarray(image.getchannel("A"))[y0:y1, :] > 0
    counts = alpha.sum(axis=0)
    return intervals(counts > projection_min_pixels, minimum_span)


def crop_box(image: Image.Image, x_span: tuple[int, int], y_span: tuple[int, int], padding: int) -> tuple[Image.Image, list[int]]:
    x0, x1 = x_span
    y0, y1 = y_span
    box = [max(0, x0 - padding), max(0, y0 - padding), min(image.width, x1 + padding), min(image.height, y1 + padding)]
    crop = image.crop(tuple(box))
    bbox = crop.getbbox()
    if bbox is None:
        raise RuntimeError(f"Detected frame became empty: {box}")
    left, top, right, bottom = bbox
    exact = [box[0] + left, box[1] + top, right - left, bottom - top]
    return crop.crop(bbox), exact


def movement_groups(image: Image.Image, cfg: dict[str, Any]) -> tuple[list[list[Image.Image]], list[list[list[int]]], list[tuple[int, int]]]:
    if str(cfg.get("layout")) != "two_rows_of_six":
        raise RuntimeError(f"Unsupported project-supplied movement layout: {cfg.get('layout')}")
    projection = int(cfg.get("projection_min_pixels", 5))
    minimum_span = int(cfg.get("minimum_span", 16))
    padding = int(cfg.get("crop_padding", 2))
    rows = detect_rows(image, projection, minimum_span)
    row_indices = [int(v) for v in cfg.get("row_indices", [0, 1])]
    if len(row_indices) != 2 or max(row_indices, default=-1) >= len(rows):
        raise RuntimeError(f"Movement row indices {row_indices} unavailable in detected rows {rows}")
    raw_groups: list[list[Image.Image]] = []
    raw_boxes: list[list[list[int]]] = []
    for row_index in row_indices:
        row = rows[row_index]
        columns = detect_columns(image, row, projection, minimum_span)
        if len(columns) != 6:
            raise RuntimeError(f"Expected six movement frames in row {row_index}, got {columns}")
        row_frames: list[Image.Image] = []
        row_boxes: list[list[int]] = []
        for column in columns:
            frame, box = crop_box(image, column, row, padding)
            row_frames.append(frame)
            row_boxes.append(box)
        raw_groups.extend([row_frames[:3], row_frames[3:6]])
        raw_boxes.extend([row_boxes[:3], row_boxes[3:6]])
    return raw_groups, raw_boxes, rows


def compose_field(groups: list[list[Image.Image]], cfg: dict[str, Any], runtime: dict[str, Any]) -> tuple[Image.Image, float, int, int, list[Image.Image]]:
    pattern = [int(v) for v in cfg.get("direction_group_pattern", [0, 1, 2, 3])]
    phase_order = [int(v) for v in cfg.get("phase_order", [0, 1, 2])]
    if sorted(pattern) != [0, 1, 2, 3] or sorted(phase_order) != [0, 1, 2]:
        raise RuntimeError(f"Invalid project-supplied direction/phase mapping pattern={pattern} phases={phase_order}")
    frames: list[Image.Image] = []
    for source_group in pattern:
        frames.extend(groups[source_group][phase] for phase in phase_order)
    max_width = max(frame.width for frame in frames)
    max_height = max(frame.height for frame in frames)
    scale = min(1.0, float(runtime["max_sprite_width"]) / max_width, float(runtime["max_sprite_height"]) / max_height)
    scaled: list[Image.Image] = []
    for frame in frames:
        size = (max(1, int(round(frame.width * scale))), max(1, int(round(frame.height * scale))))
        scaled.append(frame.resize(size, Image.Resampling.NEAREST))
    pad_x = int(runtime.get("cell_padding_x", 2))
    pad_y = int(runtime.get("cell_padding_y", 2))
    cell_w = max(int(runtime.get("minimum_cell_width", 1)), max(frame.width for frame in scaled) + 2 * pad_x)
    cell_h = max(int(runtime.get("minimum_cell_height", 1)), max(frame.height for frame in scaled) + 2 * pad_y)
    strip = Image.new("RGBA", (cell_w * 12, cell_h), (0, 0, 0, 0))
    for index, frame in enumerate(scaled):
        x = index * cell_w + (cell_w - frame.width) // 2
        y = cell_h - frame.height - 1
        strip.alpha_composite(frame, (x, y))
    return strip, scale, cell_w, cell_h, scaled


def build_sheet_portrait(keyed: Image.Image, cfg: dict[str, Any], rows: list[tuple[int, int]], source_path: Path, source_sha: str) -> tuple[Image.Image, dict[str, Any]]:
    projection = int(cfg.get("projection_min_pixels", 5))
    minimum_span = int(cfg.get("minimum_span", 16))
    padding = int(cfg.get("crop_padding", 2))
    row_index = int(cfg.get("row_index", -1))
    frame_index = int(cfg.get("frame_index", 0))
    if row_index < 0 or row_index >= len(rows):
        raise RuntimeError(f"Portrait row {row_index} unavailable in detected rows {rows}")
    columns = detect_columns(keyed, rows[row_index], projection, minimum_span)
    if frame_index < 0 or frame_index >= len(columns):
        raise RuntimeError(f"Portrait frame {frame_index} unavailable in row columns {columns}")
    portrait, source_box = crop_box(keyed, columns[frame_index], rows[row_index], padding)
    return portrait, {
        "source": source_path.name,
        "source_path": str(cfg.get("source_path", "")),
        "source_kind": "project_supplied_sheet_frame",
        "source_sha256": source_sha,
        "frame_width": portrait.width,
        "frame_height": portrait.height,
        "frame_count": 1,
        "durations_ms": [int(cfg.get("duration_ms", 220))],
        "source_box": source_box,
    }


def build_animated_webp_portrait(cfg: dict[str, Any]) -> tuple[Image.Image, dict[str, Any]]:
    source_value = str(cfg.get("source_webp", ""))
    if not source_value:
        raise RuntimeError("animated_webp portrait requires source_webp")
    source_path = local_res(source_value)
    if not source_path.is_file():
        raise RuntimeError(f"Missing animated portrait source {source_path}; materialize project-supplied sources first")
    expected_blob_sha = str(cfg.get("source_git_blob_sha", ""))
    if expected_blob_sha and git_blob_sha(source_path) != expected_blob_sha:
        raise RuntimeError(f"Animated portrait source Git blob changed for {source_value}")

    default_duration = max(20, int(cfg.get("default_duration_ms", DEFAULT_FRAME_DURATION_MS)))
    with Image.open(source_path) as image:
        expected_count = max(1, int(getattr(image, "n_frames", 1)))
        frames: list[Image.Image] = []
        durations_ms: list[int] = []
        for frame in ImageSequence.Iterator(image):
            rgba = frame.convert("RGBA")
            frames.append(rgba.copy())
            durations_ms.append(max(20, int(frame.info.get("duration", image.info.get("duration", default_duration)))))
        if not frames:
            frames.append(image.convert("RGBA").copy())
            durations_ms.append(default_duration)
        if len(frames) != expected_count:
            expected_count = len(frames)

    width, height = frames[0].size
    if width <= 0 or height <= 0:
        raise RuntimeError(f"{source_path.name}: invalid animated portrait frame size {width}x{height}")
    if any(frame.size != (width, height) for frame in frames):
        raise RuntimeError(f"{source_path.name}: animated portrait frames do not share one canvas size")
    minimum_frames = max(1, int(cfg.get("minimum_frames", 1)))
    if expected_count < minimum_frames:
        raise RuntimeError(f"{source_path.name}: expected at least {minimum_frames} animated frames, got {expected_count}")

    strip = Image.new("RGBA", (width * len(frames), height), (0, 0, 0, 0))
    for index, frame in enumerate(frames):
        strip.alpha_composite(frame, (index * width, 0))
    return strip, {
        "source": source_path.name,
        "source_path": source_value,
        "source_kind": "project_supplied_animated_webp",
        "source_sha256": sha256(source_path),
        "source_git_blob_sha": git_blob_sha(source_path),
        "frame_width": width,
        "frame_height": height,
        "frame_count": len(frames),
        "durations_ms": durations_ms,
    }


def build_portrait(keyed: Image.Image, cfg: dict[str, Any], rows: list[tuple[int, int]], source_path: Path, source_sha: str) -> tuple[Image.Image, dict[str, Any]]:
    mode = str(cfg.get("mode", "sheet_frame"))
    if mode == "animated_webp":
        return build_animated_webp_portrait(cfg)
    if mode == "sheet_frame":
        enriched = dict(cfg)
        enriched["source_path"] = enriched.get("source_path", "") or f"res://{source_path.relative_to(ROOT).as_posix()}"
        return build_sheet_portrait(keyed, enriched, rows, source_path, source_sha)
    raise RuntimeError(f"Unsupported project-supplied portrait mode: {mode}")


def write_resource(entry: dict[str, Any], field_path: str) -> str:
    name = str(entry["name"])
    path = ROOT / "assets/resources" / resource_filename(name)
    path.parent.mkdir(parents=True, exist_ok=True)
    text = f'''[gd_resource type="Resource" script_class="Digimon" load_steps=3 format=3]\n\n[ext_resource type="Script" path="res://src/resources/Digimon.gd" id="1_script"]\n[ext_resource type="Texture2D" path="{field_path}" id="2_texture"]\n\n[resource]\nscript = ExtResource("1_script")\ntexture = ExtResource("2_texture")\ninitial_frame = 0\ninitial_facing = "down_left"\nsprite_hframes = 12\nsprite_vframes = 1\nsprite_layout = "directional_12"\nsprite_scale = Vector2(1.0000, 1.0000)\nsprite_frame_duration = 0.120\nsprite_deviation = Vector2(0, 20)\nparticle_deviation = Vector2(0, 10)\ninitial_position = Vector2i(0, 0)\ntype = {json.dumps(str(entry.get("attribute", "Free")))}\ndisplay_name = {json.dumps(name)}\nlevel = 1\nhp = {max(1, int(entry.get("hp", 1)))}\nmp = {max(0, int(entry.get("mp", 0)))}\nattack = {max(1, int(entry.get("atk", 1)))}\ndefense = {max(1, int(entry.get("def", 1)))}\nage = 1\nbattles = 0\nvictories = 0\ndefeats = 0\n'''
    path.write_text(text, encoding="utf-8")
    return f"res://assets/resources/{resource_filename(name)}"


def main() -> None:
    config = json.loads(CONFIG_PATH.read_text(encoding="utf-8"))
    database = json.loads(DATABASE_PATH.read_text(encoding="utf-8"))
    if config.get("canonical_runtime_order") != DIRECTIONS or config.get("canonical_runtime_phases") != PHASES:
        raise RuntimeError("Project-supplied source config does not use the canonical directional_12 contract")
    db_by_name = {str(entry.get("name", "")): entry for entry in database}
    rows_out: list[dict[str, Any]] = []
    for spec in config.get("species", []):
        name = str(spec["name"])
        entry = db_by_name.get(name)
        if entry is None or str(entry.get("seed")) != str(spec["seed"]):
            raise RuntimeError(f"{name}: canonical database identity does not match project-supplied source manifest")
        source_path = local_res(str(spec["source_sheet"]))
        if not source_path.is_file():
            raise RuntimeError(f"{name}: missing supplied source sheet {source_path}")
        actual_sha = sha256(source_path)
        if actual_sha != str(spec["source_sha256"]):
            raise RuntimeError(f"{name}: supplied source SHA changed ({actual_sha})")
        source = Image.open(source_path).convert("RGBA")
        keyed = key_background(source, dict(spec["background"]))
        groups, raw_boxes, detected_rows = movement_groups(keyed, dict(spec["movement"]))
        strip, scale, cell_w, cell_h, _scaled = compose_field(groups, dict(spec["movement"]), dict(spec["runtime"]))
        portrait, portrait_meta = build_portrait(keyed, dict(spec["portrait"]), detected_rows, source_path, actual_sha)

        key = compact_key(name)
        directory = ROOT / "assets/characters" / key
        directory.mkdir(parents=True, exist_ok=True)
        field_path = directory / "field.png"
        portrait_path = directory / "portrait_frames.png"
        strip.save(field_path, "PNG", optimize=True)
        portrait.save(portrait_path, "PNG", optimize=True)

        pattern = [int(v) for v in spec["movement"]["direction_group_pattern"]]
        phase_order = [int(v) for v in spec["movement"]["phase_order"]]
        audited = {}
        for direction_index, direction in enumerate(DIRECTIONS):
            group_boxes = raw_boxes[pattern[direction_index]]
            audited[direction] = [group_boxes[index] for index in phase_order]
        field_meta = {
            "source_kind": "project_supplied_directional",
            "source_variant": str(spec["movement"]["layout"]),
            "source_name": name,
            "source_sheet": str(spec["source_sheet"]),
            "source_sha256": actual_sha,
            "background_policy": dict(spec["background"]),
            "detected_source_rows": [list(row) for row in detected_rows],
            "canonical_runtime_order": DIRECTIONS,
            "canonical_runtime_phases": PHASES,
            "runtime_group_indices": pattern,
            "source_frame_order": {direction: phase_order for direction in DIRECTIONS},
            "audited_source_frames": audited,
            "normalization_scale": scale,
            "anchor_policy": "bottom_center_in_uniform_species_cell",
            "frame_anchor": [cell_w // 2, cell_h - 1],
            "cell_width": cell_w,
            "cell_height": cell_h,
            "frame_count": 12,
            "frames_per_direction": 3,
            "field_path": f"res://assets/characters/{key}/field.png"
        }
        (directory / "field.json").write_text(json.dumps(field_meta, indent=2) + "\n", encoding="utf-8")
        (directory / "portrait_frames.json").write_text(json.dumps(portrait_meta, indent=2) + "\n", encoding="utf-8")

        resource = write_resource(entry, f"res://assets/characters/{key}/field.png")
        rows_out.append({
            "name": name,
            "seed": str(spec["seed"]),
            "rank": str(entry.get("rank", "")),
            "attribute": str(entry.get("attribute", "")),
            "resource": resource,
            "visual_mode": "directional_12",
            "field_sprite": f"res://assets/characters/{key}/field.png",
            "field_metadata": f"res://assets/characters/{key}/field.json",
            "portrait_strip": f"res://assets/characters/{key}/portrait_frames.png",
            "portrait_metadata": f"res://assets/characters/{key}/portrait_frames.json",
            "portrait_source": str(portrait_meta.get("source_path", "")),
            "source_sheet": str(spec["source_sheet"]),
            "field_cell": [cell_w, cell_h],
            "portrait_frames": int(portrait_meta["frame_count"]),
        })
        print(f"built {name}: 12 canonical field frames + {portrait_meta['frame_count']} portrait frames, cell={cell_w}x{cell_h}, scale={scale:.4f}")

    manifest = {
        "schema_version": 1,
        "source_kind": "project_supplied_directional",
        "canonical_runtime_order": DIRECTIONS,
        "canonical_runtime_phases": PHASES,
        "count": len(rows_out),
        "species": rows_out,
    }
    MANIFEST_PATH.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
