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


def source_member(archive, expected: str) -> bytes:
    if expected not in archive.namelist():
        raise RuntimeError(f"Pinned WtW source missing: {expected}")
    return archive.read(expected)


def movement_groups(image: Image.Image, profile: dict[str, Any]) -> list[list[dict[str, int]]]:
    _background, components = _components(image)
    candidates = [
        item for item in components
        if 10 <= item["w"] <= 50 and 7 <= item["h"] <= 50 and item["area"] >= 60
    ]
    rows = _group_by_y(candidates, tolerance=8.0)
    kind = str(profile.get("kind", ""))

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
    else:
        raise RuntimeError(f"Unknown reusable extraction profile: {kind}")

    if len(groups) != 4 or any(len(group) != 3 for group in groups):
        raise RuntimeError(f"Profile {kind} did not yield exactly 4x3 movement frames")
    return [[exact_box(item) for item in group] for group in groups]


def build_field(name: str, source: Image.Image, source_bytes: bytes, spec: dict[str, Any], config: dict[str, Any]) -> dict[str, Any]:
    profile_name = str(spec["profile"])
    pattern_name = str(spec["pattern"])
    profile = config["profiles"][profile_name]
    permutation = [int(value) for value in config["patterns"][pattern_name]]
    if sorted(permutation) != [0, 1, 2, 3]:
        raise RuntimeError(f"{name}: invalid direction permutation {permutation}")

    raw_groups = movement_groups(source, profile)
    raw_frames = {direction: raw_groups[permutation[index]] for index, direction in enumerate(DIRECTIONS)}
    background, _ = _components(source)
    source_frame_order: dict[str, list[int]] = {
        "down_left": [0, 1, 2],
        "up_left": [0, 1, 2],
        "down_right": [],
        "up_right": [],
    }
    pose_alignment: dict[str, Any] = {}
    for left_direction, right_direction in (("down_left", "down_right"), ("up_left", "up_right")):
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

    keyed = keyed_source(source, background)
    frames: list[Image.Image] = []
    audited_boxes: dict[str, list[dict[str, int]]] = {}
    for direction in DIRECTIONS:
        ordered_boxes = [raw_frames[direction][index] for index in source_frame_order[direction]]
        audited_boxes[direction] = ordered_boxes
        frames.extend(crop_component(keyed, box) for box in ordered_boxes)

    cell_w = max(32, max(frame.width for frame in frames) + 4)
    cell_h = max(32, max(frame.height for frame in frames) + 4)
    strip = Image.new("RGBA", (cell_w * FRAME_COUNT, cell_h), (0, 0, 0, 0))
    for index, frame in enumerate(frames):
        strip.alpha_composite(frame, (index * cell_w + (cell_w - frame.width) // 2, cell_h - frame.height - 1))
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
        "source_id": int(spec["source_id"]),
        "source_archive_file": str(spec["source_member"]),
        "source_url": str(spec["source_url"]),
        "source_sha256": sha256(source_bytes),
        "rebuilt_from_source": True,
        "existing_runtime_strip_used_as_input": False,
        "extraction_profile": profile_name,
        "review_pattern": pattern_name,
        "runtime_group_indices": permutation,
        "canonical_runtime_order": list(DIRECTIONS),
        "canonical_runtime_phases": list(PHASES),
        "source_frame_order": source_frame_order,
        "pose_alignment": pose_alignment,
        "anchor_policy": "bottom_center_in_uniform_species_cell",
        "frame_anchor": [cell_w // 2, cell_h - 1],
        "audited_source_frames": audited_boxes,
        "cell_width": cell_w,
        "cell_height": cell_h,
        "frame_count": FRAME_COUNT,
        "frames_per_direction": 3,
        "field_path": f"res://assets/characters/{key}/field.png",
    }
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
        payload = source_member(archive, str(spec["source_member"]))
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
            "source_id": int(spec["source_id"]),
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
