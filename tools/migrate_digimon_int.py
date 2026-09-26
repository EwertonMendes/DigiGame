#!/usr/bin/env python3
"""One-time/repeatable helper for canonical Digimon INT migration.

INT maps to Dawn/Dusk Spirit when the species exists in the pinned source.
Known localization/variant aliases are explicit. Species absent from the source
receive a deterministic same-rank KNN estimate based on HP/MP/ATK/DEF/SPD.

This tool only fills missing INT values, removes the retired `checked` flag and
normalizes property order. Existing INT values are never overwritten.
"""
from __future__ import annotations

import argparse
import json
import math
import re
import urllib.request
from pathlib import Path
from typing import Any

DATABASE = Path("database/base-digimon-list.json")
SOURCE_COMMIT = "07ad9940951a5b0de342523355cb65ba23bf64af"
SOURCE_URL = (
    "https://raw.githubusercontent.com/clokken/digimon-dawn-dusk-data/"
    f"{SOURCE_COMMIT}/data/digimon.json"
)
ALIASES = {
    "Grass Agumon": "Agumon",
    "SnowGoburimon": "Snow Goblimon",
    "Blue Greymon": "Greymon",
    "Rize Greymon": "RiseGreymon",
    "Were Garurumon": "WarGarurumon(Blue)",
    "Blue Metal Greymon": "MetalGreymon",
    "Black Were Garurumon": "WarGarurumon(Black)",
    "Vajiramon": "Vajramon",
    "RockChessmon": "RookChessmon",
    "Holydramon": "Magna Dramon",
    "GranKuwagamon": "GrandisKuwagamon"
}
FEATURES = ("hp", "mp", "atk", "def", "speed")
CANONICAL_KEYS = (
    "seed", "name", "img", "rank", "species", "attribute", "element",
    "hp", "mp", "atk", "def", "int", "speed", "bitFarmingRate",
    "MOV", "movementType", "digiEvolutionSeedList", "degenerateSeedList",
    "evolutionRequirements",
)


def normalize_name(value: str) -> str:
    return re.sub(r"[^a-z0-9]+", "", value.lower())


def load_source() -> list[dict[str, Any]]:
    with urllib.request.urlopen(SOURCE_URL, timeout=30) as response:
        payload = json.loads(response.read().decode("utf-8"))
    if not isinstance(payload, list):
        raise RuntimeError("Dawn/Dusk source root must be an array")
    return payload


def source_index(rows: list[dict[str, Any]]) -> dict[str, dict[str, Any]]:
    result: dict[str, dict[str, Any]] = {}
    for row in rows:
        for key in ("fullName", "shortName", "altName", "name"):
            value = row.get(key)
            if value:
                result[normalize_name(str(value))] = row
    return result


def resolve_source(entry: dict[str, Any], index: dict[str, dict[str, Any]]) -> dict[str, Any] | None:
    direct = index.get(normalize_name(str(entry.get("name", ""))))
    if direct is not None:
        return direct
    alias = ALIASES.get(str(entry.get("name", "")))
    return index.get(normalize_name(alias)) if alias else None


def estimate_int(
    entry: dict[str, Any],
    resolved: list[tuple[dict[str, Any], dict[str, Any]]],
) -> int:
    same_rank = [pair for pair in resolved if pair[0].get("rank") == entry.get("rank")]
    group = same_rank or resolved
    means: dict[str, float] = {}
    deviations: dict[str, float] = {}
    for key in FEATURES:
        values = [float(pair[0][key]) for pair in group]
        mean = sum(values) / len(values)
        means[key] = mean
        deviations[key] = math.sqrt(sum((value - mean) ** 2 for value in values) / len(values)) or 1.0

    scored: list[tuple[float, int]] = []
    for candidate, source in group:
        distance = math.sqrt(sum(
            ((float(entry[key]) - float(candidate[key])) / deviations[key]) ** 2
            for key in FEATURES
        ))
        scored.append((distance, int(source["spirit"])))
    scored.sort(key=lambda item: item[0])

    numerator = 0.0
    denominator = 0.0
    for distance, spirit in scored[:5]:
        weight = 1.0 / max(0.05, distance)
        numerator += weight * spirit
        denominator += weight
    return max(1, round(numerator / denominator))


def canonicalize(entry: dict[str, Any]) -> dict[str, Any]:
    ordered: dict[str, Any] = {}
    for key in CANONICAL_KEYS:
        if key in entry:
            ordered[key] = entry[key]
    for key, value in entry.items():
        if key not in ordered and key != "checked":
            ordered[key] = value
    return ordered


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true", help="Fail if the catalogue would change")
    args = parser.parse_args()

    database = json.loads(DATABASE.read_text(encoding="utf-8"))
    if not isinstance(database, list) or not database:
        raise SystemExit("Digimon database root must be a non-empty array")

    source_rows = load_source()
    index = source_index(source_rows)
    resolved = [
        (entry, source)
        for entry in database
        if (source := resolve_source(entry, index)) is not None
    ]

    output: list[dict[str, Any]] = []
    direct = aliases = estimated = 0
    for original in database:
        entry = dict(original)
        entry.pop("checked", None)
        if "int" not in entry:
            source = resolve_source(entry, index)
            if source is not None:
                entry["int"] = int(source["spirit"])
                if str(entry.get("name", "")) in ALIASES:
                    aliases += 1
                else:
                    direct += 1
            else:
                entry["int"] = estimate_int(entry, resolved)
                estimated += 1
        output.append(canonicalize(entry))

    rendered = json.dumps(output, ensure_ascii=False, indent=2) + "\n"
    current = DATABASE.read_text(encoding="utf-8")
    if args.check:
        if rendered != current:
            raise SystemExit("base-digimon-list.json is not canonical; run tools/migrate_digimon_int.py")
        print(f"canonical Digimon catalogue: {len(output)} species")
        return 0

    DATABASE.write_text(rendered, encoding="utf-8")
    print(
        f"migrated {len(output)} species: "
        f"{direct} direct Dawn/Dusk, {aliases} aliases, {estimated} estimates"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
