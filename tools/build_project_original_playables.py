#!/usr/bin/env python3
"""Build and synchronize project-original Digimon playable assets.

Project-original species are intentionally kept out of the audited official/community
DS extraction pipelines. Their source sheets, crop boxes, frame ordering, stats,
progression links and learnsets are declared in database/project-original-playables.json.
"""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
from typing import Any

from PIL import Image
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
MANIFEST_PATH = ROOT / "database/project-original-playables.json"
DATABASE_PATH = ROOT / "database/base-digimon-list.json"
EARLY_MANIFEST_PATH = ROOT / "database/early-rank-playables.json"
LEARNSETS_PATH = ROOT / "database/digimon-learnsets.json"
EARLY_RANKS = ("Fresh", "In-Training", "Rookie")
BACKGROUND_TOLERANCE = 85.0


def _res_path_to_local(value: str) -> Path:
    if not value.startswith("res://"):
        raise RuntimeError(f"Expected res:// path, got {value!r}")
    return ROOT / value.removeprefix("res://")


def _sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _key_background(image: Image.Image, background_rgb: list[int]) -> Image.Image:
    rgba = np.asarray(image.convert("RGBA"), dtype=np.uint8).copy()
    # Project-original source atlases may already carry audited transparency.
    # In that case preserve opaque black outlines instead of chroma-keying them.
    if np.any(rgba[:, :, 3] < 255):
        return Image.fromarray(rgba, "RGBA")
    bg = np.asarray(background_rgb, dtype=np.int32)
    rgb = rgba[:, :, :3].astype(np.int32)
    distance = np.sqrt(np.sum((rgb - bg) ** 2, axis=2))
    rgba[distance <= BACKGROUND_TOLERANCE, 3] = 0
    return Image.fromarray(rgba, "RGBA")


def _crop_box(keyed: Image.Image, box: list[int]) -> Image.Image:
    if len(box) != 4:
        raise RuntimeError(f"Invalid source box: {box}")
    x, y, w, h = map(int, box)
    if x < 0 or y < 0 or w <= 0 or h <= 0 or x + w > keyed.width or y + h > keyed.height:
        raise RuntimeError(f"Source box outside sheet {keyed.size}: {box}")
    crop = keyed.crop((x, y, x + w, y + h))
    bbox = crop.getbbox()
    if bbox is None:
        raise RuntimeError(f"Source box contains no foreground pixels: {box}")
    return crop.crop(bbox)


def _uniform_scale(frames: list[Image.Image], max_width: int, max_height: int) -> float:
    if not frames:
        raise RuntimeError("No frames supplied")
    source_width = max(frame.width for frame in frames)
    source_height = max(frame.height for frame in frames)
    return min(max_width / float(source_width), max_height / float(source_height))


def _resize(frame: Image.Image, scale: float) -> Image.Image:
    width = max(1, int(round(frame.width * scale)))
    height = max(1, int(round(frame.height * scale)))
    return frame.resize((width, height), Image.Resampling.NEAREST)


def _compose_strip(
    frames: list[Image.Image],
    cell_width: int,
    cell_height: int,
    max_sprite_width: int,
    max_sprite_height: int,
) -> Image.Image:
    scale = _uniform_scale(frames, max_sprite_width, max_sprite_height)
    resized = [_resize(frame, scale) for frame in frames]
    strip = Image.new("RGBA", (cell_width * len(resized), cell_height), (0, 0, 0, 0))
    for index, frame in enumerate(resized):
        x = index * cell_width + (cell_width - frame.width) // 2
        y = cell_height - frame.height - 1
        strip.alpha_composite(frame, (x, y))
    return strip


def _build_species_assets(spec: dict[str, Any]) -> dict[str, Any]:
    name = str(spec["name"])
    key = str(spec["portrait_key"])
    source_path = _res_path_to_local(str(spec["source_sheet"]))
    if not source_path.is_file():
        raise RuntimeError(f"{name}: missing source sheet {source_path.relative_to(ROOT)}")
    actual_sha = _sha256(source_path)
    expected_sha = str(spec["source_sha256"])
    if actual_sha != expected_sha:
        raise RuntimeError(f"{name}: source sheet SHA-256 mismatch: {actual_sha} != {expected_sha}")

    source = Image.open(source_path).convert("RGBA")
    keyed = _key_background(source, list(spec["background_rgb"]))
    directory = ROOT / "assets/characters" / key
    directory.mkdir(parents=True, exist_ok=True)

    field = dict(spec["field"])
    authored_frames = [_crop_box(keyed, box) for box in field["source_boxes"]]
    order = [int(index) for index in field["runtime_frame_indices"]]
    if sorted(order) != list(range(12)):
        raise RuntimeError(f"{name}: runtime frame indices must be a permutation of 0..11")
    runtime_frames = [authored_frames[index] for index in order]
    field_strip = _compose_strip(
        runtime_frames,
        int(field["cell_width"]),
        int(field["cell_height"]),
        int(field["max_sprite_width"]),
        int(field["max_sprite_height"]),
    )
    field_path = directory / "field.png"
    field_strip.save(field_path, "PNG", optimize=True)

    field_metadata = {
        "source_kind": "project_original",
        "source_variant": "grass_agumon_concept_sheet",
        "source_name": name,
        "source_sheet": str(spec["source_sheet"]),
        "source_sha256": actual_sha,
        "background_rgb": list(spec["background_rgb"]),
        "background_tolerance": BACKGROUND_TOLERANCE,
        "authored_source_boxes": field["source_boxes"],
        "runtime_frame_indices": order,
        "canonical_runtime_phases": list(field["phases"]),
        "cell_width": int(field["cell_width"]),
        "cell_height": int(field["cell_height"]),
        "frame_count": 12,
        "frames_per_direction": 3,
        "directions": list(field["directions"]),
        "runtime_scale": float(field["runtime_scale"]),
        "field_path": f"res://assets/characters/{key}/field.png",
        "anchor_policy": "bottom_center",
    }
    (directory / "field.json").write_text(json.dumps(field_metadata, indent=2) + "\n", encoding="utf-8")

    portrait = dict(spec["portrait"])
    portrait_frames = [_crop_box(keyed, box) for box in portrait["source_boxes"]]
    portrait_strip = _compose_strip(
        portrait_frames,
        int(portrait["frame_width"]),
        int(portrait["frame_height"]),
        int(portrait["max_sprite_width"]),
        int(portrait["max_sprite_height"]),
    )
    portrait_path = directory / "portrait_frames.png"
    portrait_strip.save(portrait_path, "PNG", optimize=True)
    portrait_metadata = {
        "source": Path(str(spec["source_sheet"])).name,
        "source_path": "source/sheet.png",
        "source_kind": "project_original",
        "frame_width": int(portrait["frame_width"]),
        "frame_height": int(portrait["frame_height"]),
        "frame_count": len(portrait_frames),
        "durations_ms": [int(value) for value in portrait["durations_ms"]],
        "source_sha256": actual_sha,
    }
    (directory / "portrait_frames.json").write_text(json.dumps(portrait_metadata, indent=2) + "\n", encoding="utf-8")

    entry = dict(spec["database_entry"])
    resource_path = ROOT / "assets/resources" / f"{name.lower()}.tres"
    resource_path.parent.mkdir(parents=True, exist_ok=True)
    resource_text = f'''[gd_resource type="Resource" script_class="Digimon" load_steps=3 format=3]\n\n[ext_resource type="Script" path="res://src/resources/Digimon.gd" id="1_script"]\n[ext_resource type="Texture2D" path="res://assets/characters/{key}/field.png" id="2_texture"]\n\n[resource]\nscript = ExtResource("1_script")\ntexture = ExtResource("2_texture")\ninitial_frame = 0\ninitial_facing = "down_left"\nsprite_hframes = 12\nsprite_vframes = 1\nsprite_layout = "directional_12"\nsprite_scale = Vector2({float(field["runtime_scale"]):.4f}, {float(field["runtime_scale"]):.4f})\nsprite_frame_duration = 0.120\nsprite_deviation = Vector2(0, 20)\nparticle_deviation = Vector2(0, 10)\ninitial_position = Vector2i(0, 0)\ntype = {json.dumps(str(entry.get("attribute", "Free")))}\ndisplay_name = {json.dumps(name)}\nlevel = 1\nhp = {max(1, int(entry["hp"]))}\nmp = {max(0, int(entry["mp"]))}\nattack = {max(1, int(entry["atk"]))}\ndefense = {max(1, int(entry["def"]))}\nage = 1\nbattles = 0\nvictories = 0\ndefeats = 0\n'''
    resource_path.write_text(resource_text, encoding="utf-8")

    return {
        "name": name,
        "seed": str(spec["seed"]),
        "rank": str(entry["rank"]),
        "attribute": str(entry["attribute"]),
        "database_image": str(entry["img"]),
        "portrait_key": key,
        "portrait_source": str(spec["source_sheet"]),
        "portrait_strip": f"res://assets/characters/{key}/portrait_frames.png",
        "resource": f"res://assets/resources/{name.lower()}.tres",
        "visual_mode": "directional_12",
        "frame_count": len(portrait_frames),
        "field_sprite": f"res://assets/characters/{key}/field.png",
        "field_metadata": f"res://assets/characters/{key}/field.json",
        "field_source_kind": "project_original",
        "field_frame_count": 12,
    }


def _sync_database(specs: list[dict[str, Any]]) -> None:
    database = json.loads(DATABASE_PATH.read_text(encoding="utf-8"))
    if not isinstance(database, list):
        raise RuntimeError("base-digimon-list.json root must be an array")

    for spec in specs:
        entry = dict(spec["database_entry"])
        seed = str(spec["seed"])
        name_key = str(spec["name"]).casefold()
        existing_index = next(
            (
                index
                for index, row in enumerate(database)
                if str(row.get("seed", "")) == seed
                or str(row.get("name", "")).casefold() == name_key
            ),
            -1,
        )
        if existing_index >= 0:
            database[existing_index] = entry
        else:
            agumon_index = next(
                (index for index, row in enumerate(database) if str(row.get("name", "")) == "Agumon"),
                len(database) - 1,
            )
            database.insert(agumon_index + 1, entry)

        parent_seed = str(spec["evolves_from_seed"])
        parent = next((row for row in database if str(row.get("seed", "")) == parent_seed), None)
        if parent is None:
            raise RuntimeError(f"{spec['name']}: missing evolution parent seed {parent_seed}")
        routes = parent.setdefault("digiEvolutionSeedList", [])
        if seed not in routes:
            routes.append(seed)

    DATABASE_PATH.write_text(json.dumps(database, indent=2) + "\n", encoding="utf-8")


def _sync_early_manifest(rows: list[dict[str, Any]]) -> None:
    manifest = json.loads(EARLY_MANIFEST_PATH.read_text(encoding="utf-8"))
    species_rows = [row for row in manifest.get("species", []) if isinstance(row, dict)]
    by_name = {str(row.get("name", "")): row for row in rows}
    species_rows = [row for row in species_rows if str(row.get("name", "")) not in by_name]
    species_rows.extend(rows)
    species_rows.sort(
        key=lambda row: (
            EARLY_RANKS.index(str(row.get("rank", ""))) if str(row.get("rank", "")) in EARLY_RANKS else 99,
            str(row.get("name", "")),
        )
    )
    manifest["ranks"] = list(EARLY_RANKS)
    manifest["count"] = len(species_rows)
    manifest["counts_by_rank"] = {
        rank: sum(1 for row in species_rows if str(row.get("rank", "")) == rank)
        for rank in EARLY_RANKS
    }
    field_sources = dict(manifest.get("field_sources", {}))
    field_sources["project_original"] = sum(
        1 for row in species_rows if str(row.get("field_source_kind", "")) == "project_original"
    )
    manifest["field_sources"] = field_sources
    manifest["species"] = species_rows
    EARLY_MANIFEST_PATH.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")


def _sync_learnsets(specs: list[dict[str, Any]]) -> None:
    learnsets = json.loads(LEARNSETS_PATH.read_text(encoding="utf-8"))
    if not isinstance(learnsets, list):
        raise RuntimeError("digimon-learnsets.json root must be an array")
    names = {str(spec["name"]) for spec in specs}
    learnsets = [row for row in learnsets if str(row.get("species", "")) not in names]
    for spec in specs:
        learnsets.append({
            "species": str(spec["name"]),
            "skills": list(spec.get("learnset", [])),
        })
    LEARNSETS_PATH.write_text(json.dumps(learnsets, indent=2) + "\n", encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--assets-only",
        action="store_true",
        help="Rebuild sprite/portrait/resources without synchronizing database/manifests.",
    )
    args = parser.parse_args()

    manifest = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
    if int(manifest.get("schema_version", 0)) != 1:
        raise RuntimeError("Unsupported project-original playable manifest schema")
    specs = [row for row in manifest.get("species", []) if isinstance(row, dict)]
    if not specs:
        raise RuntimeError("Project-original playable manifest contains no species")

    rows = [_build_species_assets(spec) for spec in specs]
    if not args.assets_only:
        _sync_database(specs)
        _sync_early_manifest(rows)
        _sync_learnsets(specs)

    print(
        "project-original playables built: "
        + ", ".join(str(spec["name"]) for spec in specs)
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
