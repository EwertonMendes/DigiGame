#!/usr/bin/env python3
"""Validate the canonical Digimon species catalogue and progression configuration.

The legacy catalogue is intentionally not rewritten here. This validator treats
legacy evolution lists and the newer target-specific route structure equally so
schema migration can happen incrementally without risking partial corruption.
"""
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DATABASE = ROOT / "database" / "base-digimon-list.json"
BALANCE = ROOT / "database" / "progression-balance.json"
REQUIRED_STATS = ("hp", "mp", "atk", "def", "speed")
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


def validate_requirements(name: str, requirements: list) -> None:
    for requirement in requirements:
        if not isinstance(requirement, dict):
            fail(f"{name}: evolution requirement must be an object")
        requirement_type = str(requirement.get("type", "")).strip()
        if not requirement_type:
            fail(f"{name}: evolution requirement is missing type")
        if requirement_type.lower() != "item" and "value" not in requirement:
            fail(f"{name}: {requirement_type} requirement is missing value")


def main() -> int:
    data = load(DATABASE)
    balance = load(BALANCE)
    if not isinstance(data, list) or not data:
        fail("Digimon database root must be a non-empty array")
    if not isinstance(balance, dict):
        fail("progression-balance.json root must be an object")
    if int(balance.get("maxLevel", 0)) < 2:
        fail("maxLevel must be at least 2")

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
        rank = str(entry.get("rank", ""))
        if rank and rank not in KNOWN_RANKS:
            print(f"warning: {name} uses non-standard rank {rank!r}")
        for stat in REQUIRED_STATS:
            try:
                value = int(entry.get(stat, 0))
            except (TypeError, ValueError):
                fail(f"{name}: {stat} must be numeric")
            if value < 0:
                fail(f"{name}: {stat} cannot be negative")

    edges = 0
    for entry in data:
        name = str(entry["name"])
        seen_targets: set[tuple[bool, str]] = set()
        for forward in (True, False):
            for target, requirements in route_targets(entry, forward):
                if not target:
                    fail(f"{name}: empty evolution target")
                if target not in seeds:
                    fail(f"{name}: route points to missing seed {target}")
                marker = (forward, target)
                if marker in seen_targets:
                    fail(f"{name}: duplicate {'evolution' if forward else 'degeneration'} route to {seeds[target]}")
                seen_targets.add(marker)
                validate_requirements(name, requirements)
                edges += 1

    exp = balance.get("experience", {})
    if not isinstance(exp, dict) or float(exp.get("base", 0)) <= 0 or float(exp.get("exponent", 0)) <= 0:
        fail("experience base/exponent must be positive")
    print(f"progression data valid: {len(data)} species, {edges} evolution/degeneration edges")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
