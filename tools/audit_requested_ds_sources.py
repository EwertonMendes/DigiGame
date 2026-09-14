#!/usr/bin/env python3
from __future__ import annotations

import hashlib
import io
import json
import re
import sys
from pathlib import Path

from PIL import Image

from build_early_rank_ds_fields import _components, _group_by_y, load_wtw_archive
from build_additional_ds_fields import movement_groups

REQUESTED = {
    "BlackWarGrowlmon": 248,
    "War Growlmon": 229,
    "Chaos Gallantmon": 358,
    "Megidramon": 372,
    "Gallantmon": 323,
    "Triceramon": 244,
    "Cannondramon": 344,
    "REFERENCE Growlmon canonical_rows": 113,
    "REFERENCE Geo Greymon rear_rows_first": 139,
    "REFERENCE Tyrannomon canonical_rows_front_reversed": 87,
    "REFERENCE Darkdramon rear_rows_first_horizontal_reversed": 350,
}

PROFILES = {
    "two_rows_of_six": {"kind": "two_rows_of_six"},
    "two_rows_right_region_of_six": {"kind": "two_rows_of_six", "min_cx_ratio": 0.37},
    "single_row_four_triples": {"kind": "single_row_four_triples"},
    "four_rows_rightmost_triples": {"kind": "four_rows_rightmost_triples"},
}
RAW_OUT = Path("/tmp/requested-ds-raw")


def sha256(payload: bytes) -> str:
    return hashlib.sha256(payload).hexdigest()


def find_member(names: list[str], source_id: int) -> str:
    pattern = re.compile(rf"(?:^|/)0*{source_id}_[^/]+$", re.IGNORECASE)
    matches = [name for name in names if pattern.search(name)]
    if len(matches) != 1:
        raise RuntimeError(f"source {source_id}: expected one archive member, got {matches}")
    return matches[0]


def manager_matches(source_id: int) -> list[dict]:
    root = Path("/tmp/digimon-sprite-manager/specs/digimon")
    if not root.is_dir():
        return []
    matches = []
    for path in sorted(root.glob("*.extract.json")):
        data = json.loads(path.read_text(encoding="utf-8"))
        sheet_id = str(data.get("sheet_id") or "")
        source = Path(str(data.get("source") or "")).stem
        if sheet_id != str(source_id) and source != str(source_id):
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


def main() -> None:
    archive = load_wtw_archive()
    names = archive.namelist()
    RAW_OUT.mkdir(parents=True, exist_ok=True)
    report = []
    for canonical_name, source_id in REQUESTED.items():
        member = find_member(names, source_id)
        payload = archive.read(member)
        (RAW_OUT / f"{source_id}_{Path(member).name}").write_bytes(payload)
        with Image.open(io.BytesIO(payload)) as image:
            source = image.convert("RGBA")
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
                profiles[profile_name] = {"ok": True, "groups": groups}
        report.append({
            "name": canonical_name,
            "source_id": source_id,
            "member": member,
            "source_sha256": sha256(payload),
            "size": list(source.size),
            "candidate_rows": [
                {
                    "count": len(row),
                    "mean_y": round(sum(item["cy"] for item in row) / len(row), 2),
                    "centers_x": [round(item["cx"], 2) for item in sorted(row, key=lambda i: i["cx"])],
                }
                for row in rows
            ],
            "profiles": profiles,
            "sprite_manager": manager_matches(source_id),
        })
    json.dump(report, sys.stdout, indent=2)
    print()


if __name__ == "__main__":
    main()
