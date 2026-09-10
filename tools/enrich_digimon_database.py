#!/usr/bin/env python3
"""Add tactical movement metadata to every Digimon species record.

The source JSON remains the canonical species catalogue. MOV is intentionally
stored on the species record after this migration, while DigimonDatabase keeps
the same derivation as a compatibility fallback for older/custom databases.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path

DATABASE = Path("database/base-digimon-list.json")
MOV_BY_RANK = {
    "Fresh": 2,
    "In-Training": 3,
    "Rookie": 4,
    "Champion": 4,
    "Ultimate": 4,
    "Mega": 5,
    "Ultra": 5,
    "Armor": 4,
    "Hybrid": 5,
}
MOV_OVERRIDES = {
    "agumon": 4,
    "gabumon": 4,
    "greymon": 4,
    "koromon": 3,
    "tanemon": 3,
    "veemon": 5,
}
MOVEMENT_TYPE_OVERRIDES = {
    "birdramon": "flying",
    "garudamon": "flying",
    "aeroveedramon": "flying",
    "megadramon": "flying",
    "airdramon": "flying",
    "seadramon": "aquatic",
    "whamon": "aquatic",
    "gomamon": "amphibious",
}


def derive_mov(entry: dict) -> int:
    key = str(entry.get("name", "")).strip().lower()
    if key in MOV_OVERRIDES:
        return MOV_OVERRIDES[key]
    mov = MOV_BY_RANK.get(str(entry.get("rank", "")), 4)
    speed = int(entry.get("speed", 50) or 50)
    if speed >= 90:
        mov += 1
    elif speed <= 20:
        mov -= 1
    return max(2, min(6, mov))


def derive_movement_type(entry: dict) -> str:
    key = str(entry.get("name", "")).strip().lower()
    return MOVEMENT_TYPE_OVERRIDES.get(key, "ground")


def enrich(data: list[dict]) -> int:
    changed = 0
    for entry in data:
        if "MOV" not in entry:
            entry["MOV"] = derive_mov(entry)
            changed += 1
        if "movementType" not in entry:
            entry["movementType"] = derive_movement_type(entry)
            changed += 1
    return changed


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true", help="Fail when migration would change the file")
    args = parser.parse_args()

    data = json.loads(DATABASE.read_text(encoding="utf-8"))
    if not isinstance(data, list):
        raise SystemExit("database root must be an array")
    changed = enrich(data)
    if args.check:
        if changed:
            raise SystemExit(f"database still needs {changed} movement metadata fields")
        print(f"movement metadata complete for {len(data)} species")
        return 0
    if changed:
        DATABASE.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"updated {changed} fields across {len(data)} species")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
