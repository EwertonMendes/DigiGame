#!/usr/bin/env python3
"""Build and synchronize project-original Digimon playable assets."""
from __future__ import annotations

import argparse
import hashlib
import json
from collections import deque
from pathlib import Path
from typing import Any

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
MANIFEST_PATH = ROOT / "database/project-original-playables.json"
DATABASE_PATH = ROOT / "database/base-digimon-list.json"
EARLY_MANIFEST_PATH = ROOT / "database/early-rank-playables.json"
LEARNSETS_PATH = ROOT / "database/digimon-learnsets.json"
EARLY_RANKS = ("Fresh", "In-Training", "Rookie")
CANONICAL_DIRECTIONS = ["down_left", "down_right", "up_left", "up_right"]
CANONICAL_PHASES = ["idle", "step_a", "step_b"]


def _res_path_to_local(value: str) -> Path:
    if not value.startswith("res://"):
        raise RuntimeError(f"Expected res:// path, got {value!r}")
    return ROOT / value.removeprefix("res://")


def _sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _canonical_entry(spec: dict[str, Any]) -> dict[str, Any]:
    database = json.loads(DATABASE_PATH.read_text(encoding="utf-8"))
    seed = str(spec["seed"])
    name_key = str(spec["name"]).casefold()
    entry = next(
        (
            row for row in database
            if str(row.get("seed", "")) == seed
            or str(row.get("name", "")).casefold() == name_key
        ),
        None,
    )
    if entry is None:
        raise RuntimeError(f"{spec['name']}: canonical database entry is missing")
    return dict(entry)


def _remove_connected_black_background(image: Image.Image, threshold: int = 8) -> Image.Image:
    """Remove only dark pixels connected to a frame edge, preserving black outlines."""
    rgba = image.convert("RGBA")
    pixels = rgba.load()
    width, height = rgba.size
    queue: deque[tuple[int, int]] = deque()
    seen: set[tuple[int, int]] = set()

    def is_background(x: int, y: int) -> bool:
        r, g, b, a = pixels[x, y]
        return a == 0 or (r <= threshold and g <= threshold and b <= threshold)

    def seed(x: int, y: int) -> None:
        if (x, y) not in seen and is_background(x, y):
            seen.add((x, y))
            queue.append((x, y))

    for x in range(width):
        seed(x, 0)
        seed(x, height - 1)
    for y in range(height):
        seed(0, y)
        seed(width - 1, y)

    while queue:
        x, y = queue.popleft()
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if 0 <= nx < width and 0 <= ny < height and (nx, ny) not in seen and is_background(nx, ny):
                seen.add((nx, ny))
                queue.append((nx, ny))

    output = rgba.copy()
    out_pixels = output.load()
    for x, y in seen:
        out_pixels[x, y] = (0, 0, 0, 0)
    return output


def _crop_frame(sheet: Image.Image, box: list[int]) -> Image.Image:
    if len(box) != 4:
        raise RuntimeError(f"Invalid source box: {box}")
    x, y, w, h = map(int, box)
    if x < 0 or y < 0 or w <= 0 or h <= 0 or x + w > sheet.width or y + h > sheet.height:
        raise RuntimeError(f"Source box outside sheet {sheet.size}: {box}")
    crop = sheet.crop((x, y, x + w, y + h))
    crop = _remove_connected_black_background(crop)
    bbox = crop.getbbox()
    if bbox is None:
        raise RuntimeError(f"Source box contains no foreground pixels: {box}")
    return crop.crop(bbox)


def _compose_field_strip(frames: list[Image.Image], field: dict[str, Any]) -> Image.Image:
    max_width = max(frame.width for frame in frames)
    max_height = max(frame.height for frame in frames)
    scale = min(
        int(field["max_sprite_width"]) / float(max_width),
        int(field["max_sprite_height"]) / float(max_height),
    )
    cell_width = int(field["cell_width"])
    cell_height = int(field["cell_height"])
    strip = Image.new("RGBA", (cell_width * len(frames), cell_height), (0, 0, 0, 0))
    for index, frame in enumerate(frames):
        width = max(1, int(round(frame.width * scale)))
        height = max(1, int(round(frame.height * scale)))
        resized = frame.resize((width, height), Image.Resampling.NEAREST)
        x = index * cell_width + (cell_width - width) // 2
        y = cell_height - height - 1
        strip.alpha_composite(resized, (x, y))
    return strip


def _load_profile_strip(path: Path, portrait: dict[str, Any], name: str) -> Image.Image:
    if not path.is_file():
        raise RuntimeError(f"{name}: missing portrait source {path.relative_to(ROOT)}")
    image = Image.open(path).convert("RGBA")
    expected = (int(portrait["frame_width"]) * int(portrait["frame_count"]), int(portrait["frame_height"]))
    if image.size != expected:
        raise RuntimeError(f"{name}: portrait source expected {expected}, got {image.size}")
    lo, hi = image.getchannel("A").getextrema()
    if lo >= 255 or hi <= 0:
        raise RuntimeError(f"{name}: portrait source must contain visible pixels over transparency")
    return image


def _build_species_assets(spec: dict[str, Any]) -> dict[str, Any]:
    name = str(spec["name"])
    key = str(spec["portrait_key"])
    field = dict(spec["field"])
    portrait = dict(spec["portrait"])
    if list(field.get("directions", [])) != CANONICAL_DIRECTIONS or list(field.get("phases", [])) != CANONICAL_PHASES:
        raise RuntimeError(f"{name}: field direction/phase contract is not canonical")

    source_boxes = list(field.get("source_boxes", []))
    order = [int(value) for value in field.get("runtime_frame_indices", [])]
    if len(source_boxes) != 12 or sorted(order) != list(range(12)):
        raise RuntimeError(f"{name}: field source boxes/order must define 12 canonical frames")

    field_source_value = str(spec["field_source"])
    portrait_source_value = str(spec["portrait_source"])
    field_source = _res_path_to_local(field_source_value)
    portrait_source = _res_path_to_local(portrait_source_value)
    if not field_source.is_file():
        raise RuntimeError(f"{name}: missing field source {field_source.relative_to(ROOT)}")

    sheet = Image.open(field_source).convert("RGBA")
    authored_frames = [_crop_frame(sheet, box) for box in source_boxes]
    runtime_frames = [authored_frames[index] for index in order]
    field_strip = _compose_field_strip(runtime_frames, field)
    portrait_strip = _load_profile_strip(portrait_source, portrait, name)

    directory = ROOT / "assets/characters" / key
    directory.mkdir(parents=True, exist_ok=True)
    field_path = directory / "field.png"
    portrait_path = directory / "portrait_frames.png"
    field_strip.save(field_path, "PNG", optimize=True)
    portrait_path.write_bytes(portrait_source.read_bytes())

    field_metadata = {
        "source_kind": "project_original",
        "source_variant": "grass_agumon_concept_sheet",
        "source_name": name,
        "source_sheet": field_source_value,
        "source_sha256": _sha256(field_source),
        "background_policy": "edge_connected_near_black_only",
        "authored_source_boxes": source_boxes,
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

    durations = [int(value) for value in portrait.get("durations_ms", [])]
    if len(durations) != int(portrait["frame_count"]):
        raise RuntimeError(f"{name}: portrait duration count must equal frame count")
    portrait_metadata = {
        "source": portrait_source.name,
        "source_path": str(portrait_source.relative_to(directory)),
        "source_kind": "project_original",
        "frame_width": int(portrait["frame_width"]),
        "frame_height": int(portrait["frame_height"]),
        "frame_count": int(portrait["frame_count"]),
        "durations_ms": durations,
        "source_sha256": _sha256(portrait_source),
    }
    (directory / "portrait_frames.json").write_text(json.dumps(portrait_metadata, indent=2) + "\n", encoding="utf-8")

    entry = _canonical_entry(spec)
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
        "portrait_source": portrait_source_value,
        "portrait_strip": f"res://assets/characters/{key}/portrait_frames.png",
        "resource": f"res://assets/resources/{name.lower()}.tres",
        "visual_mode": "directional_12",
        "frame_count": int(portrait["frame_count"]),
        "field_sprite": f"res://assets/characters/{key}/field.png",
        "field_metadata": f"res://assets/characters/{key}/field.json",
        "field_source_kind": "project_original",
        "field_frame_count": 12,
    }


def _validate_database_integration(specs: list[dict[str, Any]]) -> None:
    database = json.loads(DATABASE_PATH.read_text(encoding="utf-8"))
    if not isinstance(database, list):
        raise RuntimeError("base-digimon-list.json root must be an array")
    by_seed = {str(row.get("seed", "")): row for row in database}
    for spec in specs:
        seed = str(spec["seed"])
        entry = by_seed.get(seed)
        if entry is None:
            raise RuntimeError(f"{spec['name']}: canonical database entry is missing")
        parent_seed = str(spec["evolves_from_seed"])
        parent = by_seed.get(parent_seed)
        if parent is None:
            raise RuntimeError(f"{spec['name']}: missing evolution parent seed {parent_seed}")
        if seed not in parent.get("digiEvolutionSeedList", []):
            raise RuntimeError(f"{spec['name']}: canonical parent evolution route is missing")
        if parent_seed not in entry.get("degenerateSeedList", []):
            raise RuntimeError(f"{spec['name']}: canonical degeneration route is missing")


def _sync_early_manifest(rows: list[dict[str, Any]]) -> None:
    manifest = json.loads(EARLY_MANIFEST_PATH.read_text(encoding="utf-8"))
    species_rows = [row for row in manifest.get("species", []) if isinstance(row, dict)]
    by_name = {str(row.get("name", "")): row for row in rows}
    species_rows = [row for row in species_rows if str(row.get("name", "")) not in by_name]
    species_rows.extend(rows)
    species_rows.sort(key=lambda row: (EARLY_RANKS.index(str(row.get("rank", ""))) if str(row.get("rank", "")) in EARLY_RANKS else 99, str(row.get("name", ""))))
    manifest["ranks"] = list(EARLY_RANKS)
    manifest["count"] = len(species_rows)
    manifest["counts_by_rank"] = {rank: sum(1 for row in species_rows if str(row.get("rank", "")) == rank) for rank in EARLY_RANKS}
    field_sources = dict(manifest.get("field_sources", {}))
    field_sources["project_original"] = sum(1 for row in species_rows if str(row.get("field_source_kind", "")) == "project_original")
    manifest["field_sources"] = field_sources
    manifest["species"] = species_rows
    EARLY_MANIFEST_PATH.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")


def _sync_learnsets(specs: list[dict[str, Any]]) -> None:
    learnsets = json.loads(LEARNSETS_PATH.read_text(encoding="utf-8"))
    if not isinstance(learnsets, list):
        raise RuntimeError("digimon-learnsets.json root must be an array")
    seeds = {str(spec["seed"]) for spec in specs}
    names = {str(spec["name"]) for spec in specs}
    learnsets = [row for row in learnsets if str(row.get("speciesSeed", "")) not in seeds and str(row.get("species", "")) not in names]
    for spec in specs:
        entry = _canonical_entry(spec)
        learnsets.append({"speciesSeed": str(spec["seed"]), "species": str(spec["name"]), "rank": str(entry.get("rank", "")), "skills": list(spec.get("learnset", []))})
    database = json.loads(DATABASE_PATH.read_text(encoding="utf-8"))
    order = {str(row.get("seed", "")): index for index, row in enumerate(database)}
    learnsets.sort(key=lambda row: order.get(str(row.get("speciesSeed", "")), 10**9))
    LEARNSETS_PATH.write_text(json.dumps(learnsets, indent=2) + "\n", encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--assets-only", action="store_true")
    args = parser.parse_args()
    manifest = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
    if int(manifest.get("schema_version", 0)) != 2 or manifest.get("source_kind") != "project_original":
        raise RuntimeError("Unsupported project-original playable manifest schema/source kind")
    specs = [row for row in manifest.get("species", []) if isinstance(row, dict)]
    if not specs:
        raise RuntimeError("Project-original playable manifest contains no species")
    _validate_database_integration(specs)
    rows = [_build_species_assets(spec) for spec in specs]
    if not args.assets_only:
        _sync_early_manifest(rows)
        _sync_learnsets(specs)
    print("project-original playables built: " + ", ".join(str(spec["name"]) for spec in specs))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
