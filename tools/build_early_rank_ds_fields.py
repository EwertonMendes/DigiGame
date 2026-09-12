#!/usr/bin/env python3
"""Build the complete Fresh/In-Training/Rookie field roster from DS sprite art.

For the 82 species present in the WithTheWill Dawn/Dusk/Lost Evolution sprite
archive, this script extracts the original small overworld sprites directly from
the archived sheets and writes one transparent 12-frame runtime strip:

  down_left[0..2], down_right[0..2], up_left[0..2], up_right[0..2]

The five canonical database species absent from that DS archive use explicitly
identified community DS-style art. WebP portraits are never used as field or
battle sprites; they remain exclusively for UI/details/Evolution Chart previews.
"""
from __future__ import annotations

import argparse
import html
import io
import json
import re
import subprocess
import zipfile
from pathlib import Path
from typing import Any

import numpy as np
from PIL import Image
from scipy import ndimage

EARLY_RANKS = ("Fresh", "In-Training", "Rookie")
DIRECTION_ORDER = ("down_left", "down_right", "up_left", "up_right")
FRAME_COUNT = 12
FRAMES_PER_DIRECTION = 3
WTW_THREAD = "https://withthewill.net/threads/the-new-digimon-world-dawn-dusk-lost-evo-sxw-sprite-topic-no-sprite-requests.10654/"
WTW_MEDIAFIRE = "https://www.mediafire.com/file/lk0pjupv8n88006/sprite_thread.zip/file"

# Exact entries in the WithTheWill archive. These cover 82/87 species in the
# project's early-rank canonical database. IDs 071/076 are Dot variants and are
# intentionally not part of the database roster.
WTW_IDS: dict[str, int] = {
    "Botamon": 21,
    "Budmon": 20, "Calumon": 13, "Chibomon": 11, "Chicchimon": 1,
    "Dorimon": 12, "Gigimon": 14, "Gummymon": 15, "Kapurimon": 8,
    "Kokomon": 16, "Koromon": 2, "Kuramon": 9, "Minomon": 18,
    "Moonmon": 23, "Pagumon": 7, "Poyomon": 4, "Puttimon": 10,
    "Sunmon": 22, "Tanemon": 6, "Tokomon": 5, "Tsumemon": 17,
    "Tsunomon": 3, "Wanyamon": 19,
    "Monodramon": 24, "Agumon": 25, "Veemon": 26, "Guilmon": 27,
    "Dorumon": 28, "Betamon": 29, "Gabumon": 30, "Patamon": 31,
    "Biyomon": 32, "Palmon": 33, "Tentomon": 34, "Gotsumon": 35,
    "Otamamon": 36, "Gomamon": 37, "Tapirmon": 38,
    "DemiDevimon": 39, "ToyAgumon": 40, "Hagurumon": 41,
    "Salamon": 42, "Wormmon": 43, "Hawkmon": 44, "Armadillomon": 45,
    "Terriermon": 46, "Lopmon": 47, "Renamon": 48, "Impmon": 49,
    "Keramon": 50, "Falcomon": 51, "Penguinmon": 52, "Goburimon": 53,
    "Kumamon": 54, "Kotemon": 55, "Shamamon": 56,
    "SnowGoburimon": 57, "Syakomon": 58, "SnowAgumon": 59,
    "BlackAgumon": 60, "Muchomon": 61, "Crabmon": 62,
    "Floramon": 63, "Gizamon": 64, "Lalamon": 65, "Aruraumon": 66,
    "ToyAgumon (Black)": 67, "Tsukaimon": 68,
    "PawnChessmon (Black)": 69, "Gaomon": 70, "Kudamon": 72,
    "Kamemon": 73, "Dracmon": 74, "PawnChessmon (White)": 75,
    "Kunemon": 77, "Mushroomon": 78, "Solarmon": 79,
    "Candlemon": 80, "Kokuwamon": 81, "DoKunemon": 82,
    "Coronamon": 83, "Lunamon": 84,
}

# Canonical species that do not exist in the WtW 001-084 DS roster. They remain
# separate from WebP portrait art and are deliberately marked in field metadata.
COMMUNITY_SOURCES: dict[str, tuple[str, str]] = {
    "Dodomon": ("https://i1136.photobucket.com/albums/n483/PixelDots/Digimon%20Sprites/1Dodomon.png", "PixelDots community DS-style sprite"),
    "Pitchmon": ("https://i1136.photobucket.com/albums/n483/PixelDots/Digimon%20Sprites/Pichimon.png", "PixelDots community DS-style sprite"),
    "Mochimon": ("https://i1136.photobucket.com/albums/n483/PixelDots/Digimon%20Sprites/motimon_sprite_by_wooded_wolf-d4ai2kv.gif", "Wooded-Wolf community DS-style sprite"),
    "Pukamon": ("https://i1136.photobucket.com/albums/n483/PixelDots/Digimon%20Sprites/bukamon_sprite_by_wooded_wolf-d4ai84c.gif", "Wooded-Wolf community DS-style sprite"),
    "Flamon": ("https://i1136.photobucket.com/albums/n483/PixelDots/Digimon%20Sprites/Flamemon_zpsb381aecd.gif", "Wooded-Wolf community DS-style sprite"),
}


def normalize(value: str) -> str:
    return re.sub(r"[^a-z0-9]+", "", value.lower())


def portrait_key(entry: dict[str, Any]) -> str:
    image_path = str(entry.get("img", ""))
    return normalize(Path(image_path).stem if image_path else str(entry.get("name", "")))


def resource_filename(name: str) -> str:
    return f"{name.strip().lower()}.tres"


def fetch(url: str) -> bytes:
    result = subprocess.run(
        ["curl", "-fsSL", "--retry", "3", "-A", "Mozilla/5.0", url],
        capture_output=True,
        check=False,
        timeout=120,
    )
    if result.returncode != 0:
        raise RuntimeError(f"Failed to fetch {url}: {result.stderr.decode('utf-8', 'replace').strip()}")
    return result.stdout


def load_wtw_archive() -> zipfile.ZipFile:
    page = fetch(WTW_MEDIAFIRE).decode("utf-8", "ignore")
    match = re.search(r'href="([^"]+)"\s+id="downloadButton"', page)
    if not match:
        raise RuntimeError("MediaFire direct link for WithTheWill sprite_thread.zip was not found")
    direct_url = html.unescape(match.group(1))
    payload = fetch(direct_url)
    archive = zipfile.ZipFile(io.BytesIO(payload))
    names = archive.namelist()
    if not any(name.endswith("025_Agumon.png") for name in names):
        raise RuntimeError("Downloaded WithTheWill archive does not contain the expected DS sprite roster")
    return archive


def load_early_database(path: Path) -> list[dict[str, Any]]:
    rows = [entry for entry in json.loads(path.read_text(encoding="utf-8")) if str(entry.get("rank", "")) in EARLY_RANKS]
    rows.sort(key=lambda entry: (EARLY_RANKS.index(str(entry.get("rank"))), str(entry.get("name", ""))))
    if len(rows) != 87:
        raise RuntimeError(f"Expected 87 early-rank database rows, got {len(rows)}")
    return rows


def _infer_background(rgba: np.ndarray) -> tuple[int, int, int]:
    border = np.concatenate((rgba[0, :, :3], rgba[-1, :, :3], rgba[:, 0, :3], rgba[:, -1, :3]), axis=0)
    colors, counts = np.unique(border.reshape(-1, 3), axis=0, return_counts=True)
    color = colors[int(np.argmax(counts))]
    return int(color[0]), int(color[1]), int(color[2])


def _components(image: Image.Image) -> tuple[tuple[int, int, int], list[dict[str, float]]]:
    rgba = np.asarray(image.convert("RGBA"))
    background = _infer_background(rgba)
    bg = np.asarray(background, dtype=np.uint8)
    mask = np.any(rgba[:, :, :3] != bg, axis=2) & (rgba[:, :, 3] > 0)
    labels, count = ndimage.label(mask, structure=np.ones((3, 3), dtype=np.uint8))
    objects = ndimage.find_objects(labels)
    result: list[dict[str, float]] = []
    for label_index in range(1, count + 1):
        slices = objects[label_index - 1]
        if slices is None:
            continue
        ys, xs = slices
        region = labels[ys, xs] == label_index
        area = int(region.sum())
        if area <= 0:
            continue
        y_coords, x_coords = np.nonzero(region)
        result.append({
            "x": float(xs.start), "y": float(ys.start),
            "w": float(xs.stop - xs.start), "h": float(ys.stop - ys.start),
            "area": float(area),
            "cx": float(xs.start) + float(x_coords.mean()),
            "cy": float(ys.start) + float(y_coords.mean()),
        })
    return background, result


def _group_by_y(components: list[dict[str, float]], tolerance: float = 6.0) -> list[list[dict[str, float]]]:
    groups: list[list[dict[str, float]]] = []
    for component in sorted(components, key=lambda item: item["cy"]):
        best: list[dict[str, float]] | None = None
        best_distance = 1e9
        for group in groups:
            mean_y = sum(item["cy"] for item in group) / len(group)
            distance = abs(component["cy"] - mean_y)
            if distance <= tolerance and distance < best_distance:
                best = group
                best_distance = distance
        if best is None:
            groups.append([component])
        else:
            best.append(component)
    groups.sort(key=lambda group: sum(item["cy"] for item in group) / len(group))
    return groups


def _select_wtw_boxes(image: Image.Image, sprite_id: int) -> tuple[tuple[int, int, int], list[dict[str, float]], str]:
    background, all_components = _components(image)
    candidates = [
        item for item in all_components
        if 10 <= item["w"] <= 50 and 10 <= item["h"] <= 50 and item["area"] >= 100
    ]
    groups = _group_by_y(candidates)

    # Most Dawn/Dusk sheets place the four diagonal facings as two rows of six:
    # [down-left x3][down-right x3], then [up-left x3][up-right x3].
    six_rows = [group for group in groups if len(group) == 6]
    if len(six_rows) == 2:
        rows = [sorted(group, key=lambda item: item["cx"]) for group in six_rows]
        rows.sort(key=lambda group: sum(item["cy"] for item in group) / len(group))
        boxes = rows[0][:3] + rows[0][3:] + rows[1][:3] + rows[1][3:]
        return background, boxes, "two_rows_of_six"

    # Kudamon carries additional small poses on the far right of the same rows.
    # The first six cells of each movement row are the 12 authored walk frames.
    if sprite_id == 72:
        movement_rows = [group for group in groups if len(group) >= 6]
        movement_rows.sort(key=lambda group: sum(item["cy"] for item in group) / len(group))
        movement_rows = movement_rows[-2:]
        if len(movement_rows) != 2:
            raise RuntimeError("Kudamon DS sheet movement rows were not detected")
        rows = [sorted(group, key=lambda item: item["cx"])[:6] for group in movement_rows]
        return background, rows[0][:3] + rows[0][3:] + rows[1][:3] + rows[1][3:], "kudamon_two_rows"

    # Compact Baby/rookie sheets arrange one three-frame facing per row on the
    # right side. Choosing the four right-most triples rejects portrait/credit
    # art while preserving the authored order: DL, DR, UL, UR.
    triples: list[tuple[float, float, list[dict[str, float]]]] = []
    for group in groups:
        if len(group) < 3:
            continue
        ordered = sorted(group, key=lambda item: item["cx"])
        triple = ordered[-3:]
        triples.append((sum(item["cx"] for item in triple) / 3.0, sum(item["cy"] for item in triple) / 3.0, triple))
    selected = sorted(triples, key=lambda item: item[0], reverse=True)[:4]
    selected.sort(key=lambda item: item[1])
    if len(selected) != 4:
        raise RuntimeError(f"DS movement grid could not be detected for sprite id {sprite_id:03d}")
    return background, [item for _, _, triple in selected for item in triple], "four_rows_of_three"


def _transparent_source(image: Image.Image, background: tuple[int, int, int]) -> Image.Image:
    rgba = np.array(image.convert("RGBA"), copy=True)
    bg = np.asarray(background, dtype=np.uint8)
    rgba[np.all(rgba[:, :, :3] == bg, axis=2), 3] = 0
    return Image.fromarray(rgba, "RGBA")


def _compose_strip(source: Image.Image, background: tuple[int, int, int], boxes: list[dict[str, float]]) -> tuple[Image.Image, int, int]:
    if len(boxes) != FRAME_COUNT:
        raise RuntimeError(f"Expected 12 authored movement cells, got {len(boxes)}")
    keyed = _transparent_source(source, background)
    crops: list[Image.Image] = []
    pad = 2
    for box in boxes:
        x, y, w, h = int(box["x"]), int(box["y"]), int(box["w"]), int(box["h"])
        x0, y0 = max(0, x - pad), max(0, y - pad)
        x1, y1 = min(keyed.width, x + w + pad), min(keyed.height, y + h + pad)
        crops.append(keyed.crop((x0, y0, x1, y1)))
    cell_w = max(crop.width for crop in crops) + 2
    cell_h = max(crop.height for crop in crops) + 2
    strip = Image.new("RGBA", (cell_w * FRAME_COUNT, cell_h), (0, 0, 0, 0))
    for index, crop in enumerate(crops):
        x = index * cell_w + (cell_w - crop.width) // 2
        y = cell_h - crop.height - 1
        strip.alpha_composite(crop, (x, y))
    return strip, cell_w, cell_h


def build_official_wtw(archive: zipfile.ZipFile, sprite_id: int) -> tuple[Image.Image, dict[str, Any]]:
    prefix = f"sprite thread/{sprite_id:03d}_"
    names = [name for name in archive.namelist() if name.startswith(prefix) and name.lower().endswith((".png", ".gif"))]
    if len(names) != 1:
        raise RuntimeError(f"Expected one WtW sheet for {sprite_id:03d}, found {names}")
    source_name = names[0]
    image = Image.open(io.BytesIO(archive.read(source_name))).convert("RGBA")
    background, boxes, layout = _select_wtw_boxes(image, sprite_id)
    strip, cell_w, cell_h = _compose_strip(image, background, boxes)
    return strip, {
        "source_kind": "official_ds",
        "source_variant": "withthewill_sprite_thread",
        "source_archive_file": source_name,
        "source_id": sprite_id,
        "extraction_layout": layout,
        "cell_width": cell_w, "cell_height": cell_h,
        "frame_count": FRAME_COUNT,
        "frames_per_direction": FRAMES_PER_DIRECTION,
        "directions": list(DIRECTION_ORDER),
        "runtime_scale": 1.0,
        "withthewill_thread": WTW_THREAD,
    }


def _remove_corner_background(image: Image.Image) -> Image.Image:
    rgba = np.array(image.convert("RGBA"), copy=True)
    if int(rgba[:, :, 3].min()) < 255:
        result = Image.fromarray(rgba, "RGBA")
    else:
        bg = rgba[0, 0, :3].astype(np.int16)
        distance = np.abs(rgba[:, :, :3].astype(np.int16) - bg).sum(axis=2)
        rgba[distance <= 18, 3] = 0
        result = Image.fromarray(rgba, "RGBA")
    bbox = result.getbbox()
    return result.crop(bbox) if bbox else result


def build_community_exception(name: str, url: str, credit: str) -> tuple[Image.Image, dict[str, Any]]:
    image = Image.open(io.BytesIO(fetch(url))).convert("RGBA")
    source = _remove_corner_background(image)
    # These five do not have authored Dawn/Dusk sheets. Keep their external
    # pixel art explicit; mirrored facings and a 1px stride are never confused
    # with the 82 official WtW extractions in metadata/validation.
    cell_w = max(32, source.width + 8)
    cell_h = max(32, source.height + 10)
    strip = Image.new("RGBA", (cell_w * FRAME_COUNT, cell_h), (0, 0, 0, 0))
    for direction_index, direction in enumerate(DIRECTION_ORDER):
        facing = source.transpose(Image.Transpose.FLIP_LEFT_RIGHT) if direction.endswith("right") else source
        for frame_index, bob in enumerate((0, -1, 0)):
            x = direction_index * 3 * cell_w + frame_index * cell_w + (cell_w - facing.width) // 2
            y = cell_h - facing.height - 4 + bob
            strip.alpha_composite(facing, (x, y))
    scale = min(1.0, 42.0 / float(max(source.width, source.height)))
    return strip, {
        "source_kind": "community_ds_style_exception",
        "source_url": url, "credit": credit,
        "cell_width": cell_w, "cell_height": cell_h,
        "frame_count": FRAME_COUNT,
        "frames_per_direction": FRAMES_PER_DIRECTION,
        "directions": list(DIRECTION_ORDER),
        "runtime_scale": round(scale, 4),
    }


def write_resource(entry: dict[str, Any], key: str, scale: float) -> Path:
    name = str(entry["name"])
    path = Path("assets/resources") / resource_filename(name)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(f'''[gd_resource type="Resource" script_class="Digimon" load_steps=3 format=3]\n\n[ext_resource type="Script" path="res://src/resources/Digimon.gd" id="1_script"]\n[ext_resource type="Texture2D" path="res://assets/characters/{key}/field.png" id="2_texture"]\n\n[resource]\nscript = ExtResource("1_script")\ntexture = ExtResource("2_texture")\ninitial_frame = 0\ninitial_facing = "down_left"\nsprite_hframes = 12\nsprite_vframes = 1\nsprite_layout = "directional_12"\nsprite_scale = Vector2({scale:.4f}, {scale:.4f})\nsprite_frame_duration = 0.120\nsprite_deviation = Vector2(0, 20)\nparticle_deviation = Vector2(0, 10)\ninitial_position = Vector2i(0, 0)\ntype = {json.dumps(str(entry.get("attribute", "Free")))}\ndisplay_name = {json.dumps(name)}\nlevel = 1\nhp = {max(1, int(entry.get("hp", 1)))}\nmp = {max(0, int(entry.get("sp", entry.get("mp", 0))))}\nattack = {max(1, int(entry.get("atk", entry.get("attack", 1))))}\ndefense = {max(1, int(entry.get("def", entry.get("defense", 1))))}\nage = 1\nbattles = 0\nvictories = 0\ndefeats = 0\n''', encoding="utf-8")
    return path


def main() -> None:
    parser = argparse.ArgumentParser()
    # Kept for compatibility with the temporary workflow; DS extraction now
    # comes directly from the source the user requested rather than the manager.
    parser.add_argument("--manager", type=Path, default=None)
    parser.add_argument("--database", type=Path, default=Path("database/base-digimon-list.json"))
    parser.add_argument("--manifest", type=Path, default=Path("database/early-rank-playables.json"))
    args = parser.parse_args()

    entries = load_early_database(args.database)
    archive = load_wtw_archive()
    existing_manifest = json.loads(args.manifest.read_text(encoding="utf-8"))
    old_rows = {str(row.get("name", "")): row for row in existing_manifest.get("species", [])}
    built: list[dict[str, Any]] = []
    official_count = 0
    exception_count = 0

    for index, entry in enumerate(entries, start=1):
        name = str(entry["name"])
        key = portrait_key(entry)
        directory = Path("assets/characters") / key
        directory.mkdir(parents=True, exist_ok=True)
        if name in WTW_IDS:
            strip, metadata = build_official_wtw(archive, WTW_IDS[name])
            official_count += 1
        elif name in COMMUNITY_SOURCES:
            url, credit = COMMUNITY_SOURCES[name]
            strip, metadata = build_community_exception(name, url, credit)
            exception_count += 1
        else:
            raise RuntimeError(f"No DS field source mapped for canonical species {name}")

        field_path = directory / "field.png"
        strip.save(field_path, "PNG", optimize=True)
        metadata["field_path"] = f"res://assets/characters/{key}/field.png"
        (directory / "field.json").write_text(json.dumps(metadata, indent=2) + "\n", encoding="utf-8")
        resource_path = write_resource(entry, key, float(metadata["runtime_scale"]))

        row = dict(old_rows.get(name, {}))
        row.update({
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
            "field_source_kind": str(metadata["source_kind"]),
            "resource": f"res://{resource_path.as_posix()}",
            "visual_mode": "directional_12",
            "field_frame_count": FRAME_COUNT,
        })
        built.append(row)
        print(f"field {index:02d}/87: {name} -> {metadata['source_kind']}")

    payload = {
        "ranks": list(EARLY_RANKS),
        "count": len(built),
        "counts_by_rank": {rank: sum(1 for entry in entries if str(entry.get("rank")) == rank) for rank in EARLY_RANKS},
        "field_sources": {"official_ds": official_count, "community_ds_style_exception": exception_count},
        "species": built,
    }
    args.manifest.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
    if official_count != 82 or exception_count != 5:
        raise RuntimeError(f"Unexpected source split: official={official_count}, exceptions={exception_count}")
    print("built complete early-rank field roster: 82 WithTheWill DS sheets + 5 explicit exceptions")


if __name__ == "__main__":
    main()
