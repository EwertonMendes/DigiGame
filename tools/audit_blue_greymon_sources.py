#!/usr/bin/env python3
"""Temporary audit helper for Blue Greymon / Blue Metal Greymon WtW sheets."""
from __future__ import annotations

import hashlib
import io
import json
import re
import sys
from pathlib import Path

from PIL import Image, ImageDraw

from build_early_rank_ds_fields import _components, _group_by_y, fetch
from build_additional_ds_fields import movement_groups
from materialize_ds_direction_registry import crop_component, keyed_source

REQUESTED = {
    "Blue Greymon": "https://i874.photobucket.com/albums/ab308/WtWSprites/Super%20Xros%20Wars/GreymonXrosBlue.png",
    "Blue Metal Greymon": "https://i874.photobucket.com/albums/ab308/WtWSprites/Super%20Xros%20Wars/MetalGreymonXros.png",
}

PROFILES = {
    "two_rows_of_six": {"kind": "two_rows_of_six"},
    "two_rows_right_region_of_six": {"kind": "two_rows_of_six", "min_cx_ratio": 0.37},
    "single_row_four_triples": {"kind": "single_row_four_triples"},
    "four_rows_rightmost_triples": {"kind": "four_rows_rightmost_triples"},
}

OUT = Path("/tmp/blue-greymon-audit")


def sha256(payload: bytes) -> str:
    return hashlib.sha256(payload).hexdigest()


def slug(value: str) -> str:
    return re.sub(r"[^a-z0-9]+", "-", value.lower()).strip("-")


def manager_matches(source_url: str) -> list[dict]:
    root = Path("/tmp/digimon-sprite-manager/specs/digimon")
    if not root.is_dir():
        return []
    wanted = Path(source_url).stem.lower()
    matches: list[dict] = []
    for path in sorted(root.glob("*.extract.json")):
        data = json.loads(path.read_text(encoding="utf-8"))
        source = Path(str(data.get("source") or "")).stem.lower()
        if source != wanted:
            continue
        walk = ((data.get("clips") or {}).get("walk") or {})
        used_ids = {frame_id for ids in walk.values() if isinstance(ids, list) for frame_id in ids}
        boxes = [box for box in (data.get("boxes") or []) if box.get("id") in used_ids]
        matches.append({
            "spec_file": path.name,
            "creature_name": data.get("creature_name"),
            "id": data.get("id"),
            "source": data.get("source"),
            "sheet_id": data.get("sheet_id"),
            "walk": walk,
            "mirror": data.get("mirror") or {},
            "walk_style": data.get("walk_style"),
            "anchor": data.get("anchor"),
            "boxes": boxes,
        })
    return matches


def render_groups(source: Image.Image, groups: list[list[dict[str, int]]], destination: Path) -> None:
    background, _ = _components(source)
    keyed = keyed_source(source, background)
    crops = [[crop_component(keyed, box) for box in group] for group in groups]
    max_w = max(frame.width for group in crops for frame in group)
    max_h = max(frame.height for group in crops for frame in group)
    label_w = 44
    pad = 6
    canvas = Image.new("RGBA", (label_w + (max_w + pad) * 3 + pad, (max_h + pad) * 4 + pad), (24, 26, 30, 255))
    draw = ImageDraw.Draw(canvas)
    for group_index, frames in enumerate(crops):
        y = pad + group_index * (max_h + pad)
        draw.text((5, y + 2), f"G{group_index}", fill=(255, 255, 255, 255))
        for frame_index, frame in enumerate(frames):
            x = label_w + frame_index * (max_w + pad) + (max_w - frame.width) // 2
            fy = y + max_h - frame.height
            canvas.alpha_composite(frame, (x, fy))
    destination.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(destination, "PNG")


def main() -> None:
    raw_dir = OUT / "raw"
    candidates_dir = OUT / "candidates"
    raw_dir.mkdir(parents=True, exist_ok=True)
    candidates_dir.mkdir(parents=True, exist_ok=True)

    report = []
    for canonical_name, source_url in REQUESTED.items():
        payload = fetch(source_url)
        with Image.open(io.BytesIO(payload)) as image:
            source = image.convert("RGBA")
        raw_name = f"{slug(canonical_name)}.png"
        (raw_dir / raw_name).write_bytes(payload)

        _background, components = _components(source)
        candidates = [
            item for item in components
            if 10 <= item["w"] <= 50 and 7 <= item["h"] <= 50 and item["area"] >= 60
        ]
        rows = _group_by_y(candidates, tolerance=8.0)
        profiles = {}
        for profile_name, profile in PROFILES.items():
            try:
                groups = movement_groups(source, profile)
            except Exception as exc:
                profiles[profile_name] = {"ok": False, "error": str(exc)}
            else:
                preview = candidates_dir / f"{slug(canonical_name)}__{profile_name}.png"
                render_groups(source, groups, preview)
                profiles[profile_name] = {"ok": True, "groups": groups, "preview": preview.name}

        report.append({
            "name": canonical_name,
            "source_url": source_url,
            "source_sha256": sha256(payload),
            "size": list(source.size),
            "raw_file": raw_name,
            "candidate_rows": [
                {
                    "count": len(row),
                    "mean_y": round(sum(item["cy"] for item in row) / len(row), 2),
                    "centers_x": [round(item["cx"], 2) for item in sorted(row, key=lambda item: item["cx"])],
                }
                for row in rows
            ],
            "profiles": profiles,
            "sprite_manager": manager_matches(source_url),
        })

    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / "report.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    json.dump(report, sys.stdout, indent=2)
    print()


if __name__ == "__main__":
    main()
