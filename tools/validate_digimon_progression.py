#!/usr/bin/env python3
"""Validate the canonical Digimon catalogue and progression configuration."""
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DATABASE = ROOT / "database" / "base-digimon-list.json"
BALANCE = ROOT / "database" / "progression-balance.json"
REQUIRED_STATS = ("hp", "mp", "atk", "def", "speed")
SUPPORTED_STATS = {"hp", "mp", "sp", "atk", "attack", "def", "defense", "int", "speed"}
KNOWN_REQUIREMENTS = {
    "level", "potential", "abi", "stat", "item", "link", "battles_won",
    "species_defeated", "quest", "flag", "time", "party_condition",
    "hp", "mp", "sp", "atk", "attack", "def", "defense", "int", "speed",
}
NUMERIC_REQUIREMENTS = {
    "level", "potential", "abi", "link", "battles_won", "time",
    "hp", "mp", "sp", "atk", "attack", "def", "defense", "int", "speed",
}
KNOWN_RANKS = {"Fresh", "In-Training", "Rookie", "Champion", "Ultimate", "Mega", "Ultra", "Armor", "Hybrid"}


def fail(message: str) -> None:
    raise SystemExit(message)


def load(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def route_targets(entry: dict, forward: bool) -> list[tuple[str, list]]:
    modern_key = "evolutions" if forward else "degenerations"
    legacy_key = "digiEvolutionSeedList" if forward else "degenerateSeedList"
    if modern_key in entry:
        routes = entry.get(modern_key)
        if not isinstance(routes, list):
            fail(f"{entry.get('name')}: {modern_key} must be an array")
        result: list[tuple[str, list]] = []
        for route in routes:
            if not isinstance(route, dict):
                fail(f"{entry.get('name')}: route in {modern_key} must be an object")
            target = str(route.get("targetSeed", route.get("seed", ""))).strip()
            requirements = route.get("requirements", [])
            if not isinstance(requirements, list):
                fail(f"{entry.get('name')}: route requirements must be an array")
            result.append((target, requirements))
        return result
    seeds = entry.get(legacy_key, [])
    if not isinstance(seeds, list):
        fail(f"{entry.get('name')}: {legacy_key} must be an array")
    requirements = entry.get("evolutionRequirements", []) if forward else []
    if not isinstance(requirements, list):
        fail(f"{entry.get('name')}: evolutionRequirements must be an array")
    return [(str(seed).strip(), requirements) for seed in seeds]


def non_negative_number(name: str, requirement_type: str, value) -> None:
    try:
        parsed = float(value)
    except (TypeError, ValueError):
        fail(f"{name}: {requirement_type} requirement value must be numeric")
    if parsed < 0:
        fail(f"{name}: {requirement_type} requirement cannot be negative")


def validate_requirements(name: str, requirements: list) -> None:
    for requirement in requirements:
        if not isinstance(requirement, dict):
            fail(f"{name}: evolution requirement must be an object")
        requirement_type = str(requirement.get("type", "")).strip().lower()
        if not requirement_type:
            fail(f"{name}: evolution requirement is missing type")
        if requirement_type not in KNOWN_REQUIREMENTS:
            fail(f"{name}: unknown evolution requirement type {requirement_type!r}")
        if requirement_type == "stat":
            stat = str(requirement.get("stat", "")).strip().lower()
            if stat not in SUPPORTED_STATS:
                fail(f"{name}: stat requirement references unknown stat {stat!r}")
            if "value" not in requirement:
                fail(f"{name}: stat requirement is missing value")
            non_negative_number(name, f"stat/{stat}", requirement["value"])
            continue
        if requirement_type == "item":
            item_id = str(requirement.get("id", requirement.get("item", ""))).strip()
            if not item_id:
                fail(f"{name}: item requirement is missing id")
            amount = requirement.get("amount", requirement.get("value", 1))
            non_negative_number(name, "item", amount)
            if int(amount) < 1:
                fail(f"{name}: item requirement amount must be at least 1")
            continue
        if requirement_type in {"quest", "flag", "party_condition"}:
            requirement_id = str(requirement.get("id", requirement.get("condition", ""))).strip()
            if not requirement_id:
                fail(f"{name}: {requirement_type} requirement is missing id")
            continue
        if requirement_type == "species_defeated":
            species_id = str(requirement.get("species_id", requirement.get("id", ""))).strip()
            if not species_id:
                fail(f"{name}: species_defeated requirement is missing species_id")
            if "value" not in requirement:
                fail(f"{name}: species_defeated requirement is missing value")
            non_negative_number(name, requirement_type, requirement["value"])
            continue
        if requirement_type in NUMERIC_REQUIREMENTS:
            if "value" not in requirement:
                fail(f"{name}: {requirement_type} requirement is missing value")
            non_negative_number(name, requirement_type, requirement["value"])


def validate_balance(balance: dict) -> None:
    if int(balance.get("maxLevel", 0)) < 2:
        fail("maxLevel must be at least 2")
    exp = balance.get("experience", {})
    if not isinstance(exp, dict) or float(exp.get("base", 0)) <= 0 or float(exp.get("exponent", 0)) <= 0:
        fail("experience base/exponent must be positive")
    party = balance.get("party", {})
    if not isinstance(party, dict):
        fail("party section must be an object")
    minimum = int(party.get("minActive", 1))
    maximum = int(party.get("maxActive", 0))
    if minimum < 1 or maximum < minimum:
        fail("party minActive/maxActive are invalid")
    reconstruction = balance.get("reconstruction", {})
    if not isinstance(reconstruction, dict) or int(reconstruction.get("defaultRequired", 0)) < 1:
        fail("reconstruction defaultRequired must be positive")


def main() -> int:
    data = load(DATABASE)
    balance = load(BALANCE)
    if not isinstance(data, list) or not data:
        fail("Digimon database root must be a non-empty array")
    if not isinstance(balance, dict):
        fail("progression-balance.json root must be an object")
    validate_balance(balance)

    seeds: dict[str, str] = {}
    names: set[str] = set()
    for index, entry in enumerate(data):
        if not isinstance(entry, dict):
            fail(f"entry {index} must be an object")
        seed = str(entry.get("seed", "")).strip()
        name = str(entry.get("name", "")).strip()
        if not seed or not name:
            fail(f"entry {index} is missing seed/name")
        if seed in seeds:
            fail(f"duplicate seed {seed}: {seeds[seed]} / {name}")
        name_key = name.casefold()
        if name_key in names:
            fail(f"duplicate Digimon name: {name}")
        seeds[seed] = name
        names.add(name_key)
        rank = str(entry.get("rank", "")).strip()
        if not rank or rank not in KNOWN_RANKS:
            fail(f"{name}: invalid or missing rank {rank!r}")
        if "dataRequired" in entry and int(entry.get("dataRequired", 0)) < 1:
            fail(f"{name}: dataRequired must be positive")
        for stat in REQUIRED_STATS:
            try:
                value = int(entry.get(stat, 0))
            except (TypeError, ValueError):
                fail(f"{name}: {stat} must be numeric")
            if value < 0:
                fail(f"{name}: {stat} cannot be negative")

    edges = 0
    for entry in data:
        seed = str(entry["seed"])
        name = str(entry["name"])
        seen_targets: set[tuple[bool, str]] = set()
        for forward in (True, False):
            for target, requirements in route_targets(entry, forward):
                if not target:
                    fail(f"{name}: empty evolution target")
                if target == seed:
                    fail(f"{name}: self-referencing evolution/degeneration route is invalid")
                if target not in seeds:
                    fail(f"{name}: route points to missing seed {target}")
                marker = (forward, target)
                if marker in seen_targets:
                    fail(f"{name}: duplicate {'evolution' if forward else 'degeneration'} route to {seeds[target]}")
                seen_targets.add(marker)
                validate_requirements(name, requirements)
                edges += 1

    print(f"progression data valid: {len(data)} species, {edges} evolution/degeneration edges")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
