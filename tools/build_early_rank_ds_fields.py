#!/usr/bin/env python3
"""Build field-ready 12-frame DS-style strips for the early-rank roster.

The runtime strip order is fixed to:
  down_left[0..2], down_right[0..2], up_left[0..2], up_right[0..2]

Official Digimon Story DS / Dawn-Dusk/Lost Evolution movement frames are read
from the extraction specs produced by DigimonWorldSpriteManager. Those specs
point at the same Nintendo DS field artwork catalogued by the WithTheWill sprite
thread, while explicitly identifying the walk cells and required horizontal
mirrors. The five database species that never had an official DS overworld
sheet use community DS-style source art as an explicit, documented exception.

This script is intended to run in the temporary asset-generation workflow where
network access and the pinned sprite-manager checkout are available. Generated
PNG strips and .tres resources are committed to the feature branch; the WebP
portrait pipeline remains completely separate and is used only for UI/details.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
import urllib.request
from pathlib import Path
from typing import Any

from PIL import Image, ImageChops

EARLY_RANKS = ("Fresh", "In-Training", "Rookie")
DIRECTION_ORDER = ("down_left", "down_right", "up_left", "up_right")
RUNTIME_FRAMES_PER_DIRECTION = 3
RUNTIME_FRAME_COUNT = 12

# Canonical database names that differ from names used by the DS-rip manager.
NAME_ALIASES: dict[str, tuple[str, ...]] = {
    "Aruraumon": ("Aruraumon", "Alraumon"),
    "Biyomon": ("Biyomon", "Piyomon"),
    "Crabmon": ("Crabmon", "Ganimon"),
    "DemiDevimon": ("DemiDevimon", "PicoDevimon"),
    "DoKunemon": ("DoKunemon", "Dokunemon"),
    "Goburimon": ("Goburimon", "Goblimon"),
    "Lalamon": ("Lalamon", "Raramon"),
    "Mushroomon": ("Mushroomon", "Mushmon"),
    "PawnChessmon (Black)": ("PawnChessmonBlack", "PawnChessmon (Black)"),
    "PawnChessmon (White)": ("PawnChessmonWhite", "PawnChessmon (White)"),
    "Penguinmon": ("Penguinmon", "Penmon"),
    "Salamon": ("Salamon", "Plotmon"),
    "SnowAgumon": ("SnowAgumon", "YukiAgumon"),
    "SnowGoburimon": ("SnowGoburimon", "SnowGoblimon"),
    "Syakomon": ("Syakomon", "Shakomon"),
    "Tapirmon": ("Tapirmon", "Bakumon"),
    "ToyAgumon (Black)": ("ShadowToyAgumon", "ToyAgumonBlack", "ToyAgumon (Black)"),
    "Veemon": ("Veemon", "Vmon", "V-mon"),
}

# These five entries are in DigiGame's canonical early-rank database but are not
# part of the official DS Story field roster represented by the WtW 001-084 set.
# We still keep field visuals separate from WebP portraits and use community
# DS-style pixel art rather than falling back to portrait animation.
COMMUNITY_SOURCES: dict[str, tuple[str, str]] = {
    "Dodomon": ("https://i1136.photobucket.com/albums/n483/PixelDots/Digimon%20Sprites/1Dodomon.png", "PixelDots/Wooded-Wolf community DS-style sprite"),
    "Pitchmon": ("https://i1136.photobucket.com/albums/n483/PixelDots/Digimon%20Sprites/Pichimon.png", "PixelDots/Wooded-Wolf community DS-style sprite"),
    "Mochimon": ("https://i1136.photobucket.com/albums/n483/PixelDots/Digimon%20Sprites/motimon_sprite_by_wooded_wolf-d4ai2kv.gif", "Wooded-Wolf community DS-style sprite"),
    "Pukamon": ("https://i1136.photobucket.com/albums/n483/PixelDots/Digimon%20Sprites/bukamon_sprite_by_wooded_wolf-d4ai84c.gif", "Wooded-Wolf community DS-style sprite"),
    "Flamon": ("https://i1136.photobucket.com/albums/n483/PixelDots/Digimon%20Sprites/Flamemon_zpsb381aecd.gif", "Wooded-Wolf community DS-style sprite"),
}


def normalize(value: str) -> str:
    return re.sub(r"[^a-z0-9]+", "", value.lower())


def portrait_key(entry: dict[str, Any]) -> str:
    img = str(entry.get("img", ""))
    stem = Path(img).stem if img else str(entry.get("name", ""))
    return normalize(stem)


def resource_filename(name: str) -> str:
    return f"{name.strip().lower()}.tres"


def load_early_database(path: Path) -> list[dict[str, Any]]:
    database = json.loads(path.read_text(encoding="utf-8"))
    rows = [entry for entry in database if str(entry.get("rank", "")) in EARLY_RANKS]
    rows.sort(key=lambda entry: (EARLY_RANKS.index(str(entry.get("rank"))), str(entry.get("name", ""))))
    if len(rows) != 87:
        raise RuntimeError(f"Expected 87 Fresh/In-Training/Rookie database rows, got {len(rows)}")
    return rows


def load_manager_specs(manager_root: Path) -> tuple[dict[str, Path], dict[str, dict[str, Any]]]:
    by_name: dict[str, Path] = {}
    parsed_by_path: dict[str, dict[str, Any]] = {}
    for path in sorted((manager_root / "specs/digimon").glob("*.extract.json")):
        spec = json.loads(path.read_text(encoding="utf-8"))
        creature_name = str(spec.get("creature_name", "")).strip()
        if not creature_name:
            continue
        key = normalize(creature_name)
        by_name.setdefault(key, path)
        parsed_by_path[str(path)] = spec
    if not by_name:
        raise RuntimeError("Pinned DigimonWorldSpriteManager checkout contains no extraction specs")
    return by_name, parsed_by_path


def resolve_spec(name: str, specs_by_name: dict[str, Path]) -> Path | None:
    candidates = NAME_ALIASES.get(name, (name,))
    for candidate in candidates:
        path = specs_by_name.get(normalize(candidate))
        if path is not None:
            return path
    return None


def _ensure_three(cells: list[dict[str, int]]) -> list[dict[str, int]]:
    if not cells:
        raise RuntimeError("Directional DS walk clip is empty")
    chosen = list(cells[:RUNTIME_FRAMES_PER_DIRECTION])
    while len(chosen) < RUNTIME_FRAMES_PER_DIRECTION:
        chosen.append(chosen[-1])
    return chosen


def build_from_manager(
    manager_root: Path,
    spec_path: Path,
    spec: dict[str, Any],
    temp_out: Path,
) -> tuple[Image.Image, dict[str, Any]]:
    # Import the pinned manager's own baker so extraction/background keying and
    # authored mirror semantics stay exactly aligned with its reviewed specs.
    sys.path.insert(0, str(manager_root))
    sys.path.insert(0, str(manager_root / "src"))
    from core import baker  # type: ignore

    temp_out.mkdir(parents=True, exist_ok=True)
    result = baker.bake(str(spec_path), out_dir=str(temp_out), log=lambda *_: None)
    baked = Image.open(result["png"]).convert("RGBA")
    layout = json.loads(Path(result["layout"]).read_text(encoding="utf-8"))
    cols = int(layout["cols"])
    rows = int(layout["rows"])
    if cols <= 0 or rows <= 0 or baked.width % cols or baked.height % rows:
        raise RuntimeError(f"Invalid baked DS grid {baked.size}, cols={cols}, rows={rows}")
    cell_w = baked.width // cols
    cell_h = baked.height // rows

    frames: list[Image.Image] = []
    for direction in DIRECTION_ORDER:
        cells = _ensure_three(list(layout.get("walk", {}).get(direction, [])))
        for cell in cells:
            col = int(cell["col"])
            row = int(cell["row"])
            crop = baked.crop((col * cell_w, row * cell_h, (col + 1) * cell_w, (row + 1) * cell_h))
            frames.append(crop)

    if len(frames) != RUNTIME_FRAME_COUNT:
        raise RuntimeError(f"Expected 12 runtime frames, got {len(frames)}")
    strip = Image.new("RGBA", (cell_w * RUNTIME_FRAME_COUNT, cell_h), (0, 0, 0, 0))
    for index, frame in enumerate(frames):
        strip.alpha_composite(frame, (index * cell_w, 0))

    return strip, {
        "source_kind": "official_ds",
        "source_name": str(spec.get("creature_name", "")),
        "manager_spec": spec_path.name,
        "manager_sheet_id": str(spec.get("sheet_id", "")),
        "cell_width": cell_w,
        "cell_height": cell_h,
        "frame_count": RUNTIME_FRAME_COUNT,
        "directions": list(DIRECTION_ORDER),
        "frames_per_direction": RUNTIME_FRAMES_PER_DIRECTION,
        # Manager bakes at 2x nearest-neighbour by default so 0.5 restores the
        # native DS apparent size in Godot while keeping crisp integer pixels.
        "runtime_scale": 0.5,
    }


def _download(url: str) -> bytes:
    request = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(request, timeout=60) as response:
        return response.read()


def _remove_corner_background(image: Image.Image) -> Image.Image:
    rgba = image.convert("RGBA")
    # Transparent sources need no color keying.
    alpha = rgba.getchannel("A")
    if alpha.getextrema()[0] < 255:
        return rgba
    corner = rgba.getpixel((0, 0))[:3]
    data = []
    for r, g, b, a in rgba.getdata():
        distance = abs(r - corner[0]) + abs(g - corner[1]) + abs(b - corner[2])
        data.append((r, g, b, 0 if distance <= 18 else a))
    rgba.putdata(data)
    bbox = rgba.getbbox()
    return rgba.crop(bbox) if bbox else rgba


def build_community_exception(name: str, url: str) -> tuple[Image.Image, dict[str, Any]]:
    import io

    source = _remove_corner_background(Image.open(io.BytesIO(_download(url))))
    # Keep original pixel art intact. Small Fresh/Baby shapes are effectively
    # radial, so mirrored facings plus a one-pixel stride bob read cleanly. For
    # the non-DS exceptions this is deliberately documented instead of silently
    # pretending the artwork came from the official DS sheet collection.
    pad = 4
    cell_w = max(32, source.width + pad * 2)
    cell_h = max(32, source.height + pad * 2 + 1)
    strip = Image.new("RGBA", (cell_w * RUNTIME_FRAME_COUNT, cell_h), (0, 0, 0, 0))
    for dir_index, direction in enumerate(DIRECTION_ORDER):
        facing = source.transpose(Image.Transpose.FLIP_LEFT_RIGHT) if direction.endswith("right") else source
        for frame_index, bob in enumerate((0, -1, 0)):
            cell = Image.new("RGBA", (cell_w, cell_h), (0, 0, 0, 0))
            x = (cell_w - facing.width) // 2
            y = cell_h - facing.height - pad + bob
            cell.alpha_composite(facing, (x, y))
            strip.alpha_composite(cell, ((dir_index * 3 + frame_index) * cell_w, 0))
    return strip, {
        "source_kind": "community_ds_style_exception",
        "source_url": url,
        "cell_width": cell_w,
        "cell_height": cell_h,
        "frame_count": RUNTIME_FRAME_COUNT,
        "directions": list(DIRECTION_ORDER),
        "frames_per_direction": RUNTIME_FRAMES_PER_DIRECTION,
        "runtime_scale": 1.0,
    }


def write_resource(entry: dict[str, Any], key: str, scale: float) -> Path:
    name = str(entry["name"])
    resource_path = Path("assets/resources") / resource_filename(name)
    resource_path.parent.mkdir(parents=True, exist_ok=True)
    text = f'''[gd_resource type="Resource" script_class="Digimon" load_steps=3 format=3]\n\n[ext_resource type="Script" path="res://src/resources/Digimon.gd" id="1_script"]\n[ext_resource type="Texture2D" path="res://assets/characters/{key}/field.png" id="2_texture"]\n\n[resource]\nscript = ExtResource("1_script")\ntexture = ExtResource("2_texture")\ninitial_frame = 0\ninitial_facing = "down_left"\nsprite_hframes = 12\nsprite_vframes = 1\nsprite_layout = "directional_12"\nsprite_scale = Vector2({scale:.3f}, {scale:.3f})\nsprite_frame_duration = 0.120\nsprite_deviation = Vector2(0, 20)\nparticle_deviation = Vector2(0, 10)\ninitial_position = Vector2i(0, 0)\ntype = {json.dumps(str(entry.get("attribute", "Free")))}\ndisplay_name = {json.dumps(name)}\nlevel = 1\nhp = {max(1, int(entry.get("hp", 1)))}\nmp = {max(0, int(entry.get("sp", entry.get("mp", 0))))}\nattack = {max(1, int(entry.get("atk", entry.get("attack", 1))))}\ndefense = {max(1, int(entry.get("def", entry.get("defense", 1))))}\nage = 1\nbattles = 0\nvictories = 0\ndefeats = 0\n'''
    resource_path.write_text(text, encoding="utf-8")
    return resource_path


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--manager", required=True, type=Path)
    parser.add_argument("--database", default=Path("database/base-digimon-list.json"), type=Path)
    parser.add_argument("--manifest", default=Path("database/early-rank-playables.json"), type=Path)
    parser.add_argument("--tmp", default=Path("/tmp/digigame-ds-baked"), type=Path)
    args = parser.parse_args()

    entries = load_early_database(args.database)
    specs_by_name, parsed_specs = load_manager_specs(args.manager)
    manifest_existing = json.loads(args.manifest.read_text(encoding="utf-8"))
    existing_by_name = {str(row["name"]): row for row in manifest_existing.get("species", [])}

    built: list[dict[str, Any]] = []
    missing: list[str] = []
    official_count = 0
    exception_count = 0

    for entry in entries:
        name = str(entry["name"])
        key = portrait_key(entry)
        destination = Path("assets/characters") / key
        destination.mkdir(parents=True, exist_ok=True)

        spec_path = resolve_spec(name, specs_by_name)
        if spec_path is not None:
            spec = parsed_specs[str(spec_path)]
            strip, field_meta = build_from_manager(args.manager, spec_path, spec, args.tmp / key)
            official_count += 1
        elif name in COMMUNITY_SOURCES:
            url, credit = COMMUNITY_SOURCES[name]
            strip, field_meta = build_community_exception(name, url)
            field_meta["credit"] = credit
            exception_count += 1
        else:
            missing.append(name)
            continue

        strip_path = destination / "field.png"
        strip.save(strip_path, "PNG", optimize=True)
        field_meta["field_path"] = f"res://assets/characters/{key}/field.png"
        field_meta["withthewill_thread"] = "https://withthewill.net/threads/the-new-digimon-world-dawn-dusk-lost-evo-sxw-sprite-topic-no-sprite-requests.10654/"
        (destination / "field.json").write_text(json.dumps(field_meta, indent=2) + "\n", encoding="utf-8")

        resource_path = write_resource(entry, key, float(field_meta["runtime_scale"]))
        existing = dict(existing_by_name.get(name, {}))
        existing.update({
            "name": name,
            "seed": str(entry.get("seed", "")),
            "rank": str(entry.get("rank", "")),
            "attribute": str(entry.get("attribute", "")),
            "database_image": str(entry.get("img", "")),
            "portrait_key": key,
            "portrait_source": f"res://assets/characters/{key}/source/portrait.webp",
            "portrait_strip": f"res://assets/characters/{key}/portrait_frames.png",
            "field_sprite": f"res://assets/characters/{key}/field.png",
            "field_metadata": f"res://assets/characters/{key}/field.json",
            "field_source_kind": str(field_meta["source_kind"]),
            "resource": f"res://{resource_path.as_posix()}",
            "visual_mode": "directional_12",
            "field_frame_count": RUNTIME_FRAME_COUNT,
        })
        built.append(existing)
        print(f"field {len(built):02d}/87: {name} -> {field_meta['source_kind']}")

    if missing:
        raise RuntimeError(f"No DS field source mapped for: {', '.join(missing)}")
    if len(built) != len(entries):
        raise RuntimeError(f"Built {len(built)} fields for {len(entries)} early-rank species")

    counts = {rank: sum(1 for entry in entries if str(entry.get("rank")) == rank) for rank in EARLY_RANKS}
    payload = {
        "ranks": list(EARLY_RANKS),
        "count": len(built),
        "counts_by_rank": counts,
        "field_sources": {
            "official_ds": official_count,
            "community_ds_style_exception": exception_count,
        },
        "species": built,
    }
    args.manifest.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
    print(f"built {official_count} official DS fields + {exception_count} explicit community DS-style exceptions")


if __name__ == "__main__":
    main()
