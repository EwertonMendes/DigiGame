#!/usr/bin/env python3
"""Normalize authoring metadata in the canonical Digimon species catalogue.

The JSON is the source of truth. This helper may persist missing MOV and
movementType authoring defaults, remove the retired `checked` flag and enforce
stable property order, but it deliberately refuses to invent INT. New species
must supply INT explicitly (or be migrated with migrate_digimon_int.py).
"""
from __future__ import annotations

import argparse
import json
import os
import tempfile
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
    "Fusion": 6,
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
CANONICAL_KEYS = (
    "seed", "name", "img", "rank", "species", "attribute", "element",
    "hp", "mp", "atk", "def", "int", "speed", "bitFarmingRate",
    "MOV", "movementType", "digiEvolutionSeedList", "degenerateSeedList",
    "evolutionRequirements",
)


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


def canonicalize(entry: dict) -> dict:
    value = dict(entry)
    value.pop("checked", None)
    if "MOV" not in value:
        value["MOV"] = derive_mov(value)
    if "movementType" not in value:
        value["movementType"] = derive_movement_type(value)

    ordered: dict = {}
    for key in CANONICAL_KEYS:
        if key in value:
            ordered[key] = value[key]
    for key, field_value in value.items():
        if key not in ordered:
            ordered[key] = field_value
    return ordered


def normalize(data: list[dict]) -> tuple[list[dict], list[str]]:
    missing_int: list[str] = []
    output: list[dict] = []
    for entry in data:
        if "int" not in entry:
            missing_int.append(str(entry.get("name", "<unnamed>")))
        output.append(canonicalize(entry))
    return output, missing_int


def atomic_write_json(path: Path, data: object) -> None:
    payload = json.dumps(data, ensure_ascii=False, indent=2) + "\n"
    json.loads(payload)
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, raw_temp = tempfile.mkstemp(prefix=f".{path.name}.", suffix=".tmp", dir=path.parent)
    temp_path = Path(raw_temp)
    try:
        with os.fdopen(fd, "w", encoding="utf-8", newline="\n") as handle:
            handle.write(payload)
            handle.flush()
            os.fsync(handle.fileno())
        json.loads(temp_path.read_text(encoding="utf-8"))
        os.replace(temp_path, path)
    finally:
        if temp_path.exists():
            temp_path.unlink()


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true", help="Fail when canonicalization would change the file")
    args = parser.parse_args()

    data = json.loads(DATABASE.read_text(encoding="utf-8"))
    if not isinstance(data, list):
        raise SystemExit("database root must be an array")
    if not all(isinstance(entry, dict) for entry in data):
        raise SystemExit("every database entry must be an object")

    normalized, missing_int = normalize(data)
    if missing_int:
        preview = ", ".join(missing_int[:8])
        suffix = "..." if len(missing_int) > 8 else ""
        raise SystemExit(
            f"{len(missing_int)} species are missing canonical INT: {preview}{suffix}. "
            "Supply INT or run tools/migrate_digimon_int.py."
        )

    changed = normalized != data
    if args.check:
        if changed:
            raise SystemExit("Digimon catalogue is not canonical; run tools/enrich_digimon_database.py")
        print(f"canonical species metadata complete for {len(data)} species")
        return 0

    if changed:
        atomic_write_json(DATABASE, normalized)
    print(f"canonicalized {len(data)} species; changed={int(changed)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
