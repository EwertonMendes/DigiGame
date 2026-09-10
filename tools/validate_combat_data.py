#!/usr/bin/env python3
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def load(name: str):
    return json.loads((ROOT / "database" / name).read_text(encoding="utf-8"))


def main() -> None:
    balance = load("battle-balance.json")
    techniques = load("techniques.json")
    learnsets = load("digimon-learnsets.json")
    statuses = load("statuses.json")

    assert isinstance(balance, dict)
    for section in ("turnRecovery", "damage", "typeChart", "elementChart", "defend", "targeting"):
        assert section in balance, f"missing battle balance section: {section}"

    action_ids: set[str] = set()
    for action in techniques:
        action_id = str(action.get("id", "")).strip()
        assert action_id and action_id not in action_ids, f"invalid/duplicate action id: {action_id!r}"
        action_ids.add(action_id)
        assert action.get("name"), f"{action_id}: missing name"
        assert action.get("damageClass") in {"physical", "special", "none"}, f"{action_id}: invalid damageClass"
        assert 0 <= float(action.get("accuracy", 0)) <= 100, f"{action_id}: invalid accuracy"
        assert int(action.get("spCost", -1)) >= 0, f"{action_id}: invalid spCost"
        assert float(action.get("recoveryCost", 0)) > 0, f"{action_id}: invalid recoveryCost"
        range_data = action.get("range", {})
        assert isinstance(range_data, dict), f"{action_id}: range must be object"
        assert int(range_data.get("min", 0)) <= int(range_data.get("max", 0)), f"{action_id}: invalid range"
        assert isinstance(action.get("targets", []), list) and action["targets"], f"{action_id}: missing targets"
        assert isinstance(action.get("effects", []), list) and action["effects"], f"{action_id}: missing effects"

    status_ids: set[str] = set()
    for status in statuses:
        status_id = str(status.get("id", "")).strip()
        assert status_id and status_id not in status_ids, f"invalid/duplicate status id: {status_id!r}"
        status_ids.add(status_id)
        assert int(status.get("duration", 0)) > 0, f"{status_id}: invalid duration"

    for action in techniques:
        for effect in action.get("effects", []):
            if effect.get("type") == "status":
                assert effect.get("status") in status_ids, f"{action['id']}: unknown status {effect.get('status')}"

    species_seen: set[str] = set()
    for learnset in learnsets:
        species = str(learnset.get("species", "")).strip().lower()
        assert species and species not in species_seen, f"invalid/duplicate learnset species: {species!r}"
        species_seen.add(species)
        for entry in learnset.get("skills", []):
            assert entry.get("skill") in action_ids, f"{species}: unknown skill {entry.get('skill')}"
            assert int(entry.get("level", 0)) >= 1, f"{species}: invalid skill level"

    print(f"validated combat data: {len(action_ids)} techniques, {len(status_ids)} statuses, {len(species_seen)} learnsets")


if __name__ == "__main__":
    main()
