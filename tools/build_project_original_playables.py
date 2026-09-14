#!/usr/bin/env python3
"""Build and synchronize project-original Digimon playable assets.

Project-original art is kept outside the official/community DS extraction pipeline.
Schema v2 stores already-normalized field and profile sources separately so a field
sprite can never accidentally become a details portrait and transparent runtime art
is reproduced byte-for-byte.
"""
from __future__ import annotations

import argparse
import hashlib
import json
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


def _load_transparent_png(path: Path, expected_size: tuple[int, int], label: str) -> Image.Image:
    if not path.is_file():
        raise RuntimeError(f"{label}: missing source {path.relative_to(ROOT)}")
    image = Image.open(path).convert("RGBA")
    if image.size != expected_size:
        raise RuntimeError(f"{label}: expected source size {expected_size}, got {image.size}")
    alpha = image.getchannel("A")
    lo, hi = alpha.getextrema()
    if lo >= 255:
        raise RuntimeError(f"{label}: source has no transparent pixels")
    if hi <= 0:
        raise RuntimeError(f"{label}: source contains no visible pixels")
    return image


def _copy_source(source: Path, destination: Path) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_bytes(source.read_bytes())


def _build_species_assets(spec: dict[str, Any]) -> dict[str, Any]:
    name = str(spec["name"])
    key = str(spec["portrait_key"])
    field = dict(spec["field"])
    portrait = dict(spec["portrait"])

    directions = list(field.get("directions", []))
    phases = list(field.get("phases", []))
    if directions != CANONICAL_DIRECTIONS or phases != CANONICAL_PHASES:
        raise RuntimeError(f"{name}: field direction/phase contract is not canonical")
    frame_count = int(field.get("frame_count", 0))
    if frame_count != 12:
        raise RuntimeError(f"{name}: field source must contain exactly 12 frames")
    order = [int(value) for value in field.get("runtime_frame_indices", [])]
    if order != list(range(12)):
        raise RuntimeError(f"{name}: normalized field source must already be in canonical runtime order")

    field_source_value = str(spec["field_source"])
    portrait_source_value = str(spec["portrait_source"])
    field_source = _res_path_to_local(field_source_value)
    portrait_source = _res_path_to_local(portrait_source_value)
    cell_width = int(field["cell_width"])
    cell_height = int(field["cell_height"])
    portrait_width = int(portrait["frame_width"])
    portrait_height = int(portrait["frame_height"])
    portrait_count = int(portrait["frame_count"])

    _load_transparent_png(field_source, (cell_width * 12, cell_height), f"{name} field")
    _load_transparent_png(
        portrait_source,
        (portrait_width * portrait_count, portrait_height),
        f"{name} portrait",
    )

    directory = ROOT / "assets/characters" / key
    directory.mkdir(parents=True, exist_ok=True)
    field_path = directory / "field.png"
    portrait_path = directory / "portrait_frames.png"
    _copy_source(field_source, field_path)
    _copy_source(portrait_source, portrait_path)

    field_digest = _sha256(field_source)
    portrait_digest = _sha256(portrait_source)
    field_metadata = {
        "source_kind": "project_original",
        "source_variant": "normalized_transparent_field_strip",
        "source_name": name,
        "source_sheet": field_source_value,
        "source_sha256": field_digest,
        "authored_source_boxes": [
            [index * cell_width, 0, cell_width, cell_height]
            for index in range(12)
        ],
        "runtime_frame_indices": order,
        "canonical_runtime_phases": phases,
        "cell_width": cell_width,
        "cell_height": cell_height,
        "frame_count": 12,
        "frames_per_direction": 3,
        "directions": directions,
        "runtime_scale": float(field["runtime_scale"]),
        "field_path": f"res://assets/characters/{key}/field.png",
        "anchor_policy": "bottom_center",
    }
    (directory / "field.json").write_text(json.dumps(field_metadata, indent=2) + "\n", encoding="utf-8")

    durations = [int(value) for value in portrait.get("durations_ms", [])]
    if len(durations) != portrait_count:
        raise RuntimeError(f"{name}: portrait duration count must equal frame count")
    portrait_metadata = {
        "source": portrait_source.name,
        "source_path": str(portrait_source.relative_to(directory)),
        "source_kind": "project_original",
        "frame_width": portrait_width,
        "frame_height": portrait_height,
        "frame_count": portrait_count,
        "durations_ms": durations,
        "source_sha256": portrait_digest,
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
        "portrait_source": portrait_source_value,
        "portrait_strip": f"res://assets/characters/{key}/portrait_frames.png",
        "resource": f"res://assets/resources/{name.lower()}.tres",
        "visual_mode": "directional_12",
        "frame_count": portrait_count,
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

    seeds = {str(spec["seed"]) for spec in specs}
    names = {str(spec["name"]) for spec in specs}
    learnsets = [
        row for row in learnsets
        if str(row.get("speciesSeed", "")) not in seeds
        and str(row.get("species", "")) not in names
    ]
    for spec in specs:
        entry = dict(spec["database_entry"])
        learnsets.append({
            "speciesSeed": str(spec["seed"]),
            "species": str(spec["name"]),
            "rank": str(entry.get("rank", "")),
            "skills": list(spec.get("learnset", [])),
        })

    database = json.loads(DATABASE_PATH.read_text(encoding="utf-8"))
    order = {str(row.get("seed", "")): index for index, row in enumerate(database)}
    learnsets.sort(key=lambda row: order.get(str(row.get("speciesSeed", "")), 10**9))
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
    if int(manifest.get("schema_version", 0)) != 2:
        raise RuntimeError("Unsupported project-original playable manifest schema")
    if manifest.get("source_kind") != "project_original":
        raise RuntimeError("Project-original manifest source kind is invalid")
    specs = [row for row in manifest.get("species", []) if isinstance(row, dict)]
    if not specs:
        raise RuntimeError("Project-original playable manifest contains no species")

    rows = [_build_species_assets(spec) for spec in specs]
    if not args.assets_only:
        _sync_database(specs)
        _sync_early_manifest(rows)
        _sync_learnsets(specs)

    print("project-original playables built: " + ", ".join(str(spec["name"]) for spec in specs))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
