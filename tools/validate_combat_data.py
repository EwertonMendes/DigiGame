#!/usr/bin/env python3
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def load(name: str):
    return json.loads((ROOT / "database" / name).read_text(encoding="utf-8"))


def iter_effect_specs(presentation: dict):
    for phase in ("start", "projectile", "impact"):
        specs = presentation.get(phase, [])
        assert isinstance(specs, list), f"presentation phase {phase} must be a list"
        for spec in specs:
            assert isinstance(spec, dict), f"presentation phase {phase} contains non-object entry"
            yield phase, spec


def res_path_exists(path_text: str) -> bool:
    if not path_text.startswith("res://"):
        return False
    return (ROOT / path_text.removeprefix("res://")).is_file()


def main() -> None:
    balance = load("battle-balance.json")
    techniques = load("techniques.json")
    learnsets = load("digimon-learnsets.json")
    records = load("technique-records.json")
    source_audit = load("technique-source-audit.json")
    species_database = load("base-digimon-list.json")
    statuses = load("statuses.json")
    vfx_library = load("vfx-library.json")
    presentations = load("combat-presentations.json")

    assert isinstance(balance, dict)
    for section in ("turnRecovery", "damage", "typeChart", "elementChart", "defend", "targeting"):
        assert section in balance, f"missing battle balance section: {section}"

    action_ids: set[str] = set()
    for action in techniques:
        action_id = str(action.get("id", "")).strip()
        assert action_id and action_id not in action_ids, f"invalid/duplicate action id: {action_id!r}"
        action_ids.add(action_id)
        assert action.get("name"), f"{action_id}: missing name"
        names = action.get("names", {})
        assert isinstance(names, dict) and names.get("en") and names.get("pt_BR"), f"{action_id}: missing localized names"
        assert isinstance(action.get("aliases", []), list), f"{action_id}: aliases must be a list"
        assert isinstance(action.get("sourceGames", []), list) and action["sourceGames"], f"{action_id}: missing source provenance"
        assert action.get("category") in {"damage", "healing", "support", "control", "mobility"}, f"{action_id}: invalid category"
        assert action.get("damageClass") in {"physical", "special", "none"}, f"{action_id}: invalid damageClass"
        assert action.get("element") in {"neutral", "fire", "plant", "water", "electric", "wind", "earth", "light", "dark"}, f"{action_id}: invalid element"
        assert action.get("masteryProfile") in {"efficient", "swift", "precise", "reliable_effect", "potent"}, f"{action_id}: invalid mastery profile"
        assert action.get("availability") in {"ready", "requires_digixros"}, f"{action_id}: invalid availability"
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
    species_seeds = {str(entry.get("seed", "")) for entry in species_database}
    level_rules = {
        "fresh": [3], "in-training": [5], "rookie": [8, 16], "champion": [10, 20],
        "ultimate": [12, 24], "mega": [15, 30], "ultra": [15, 30],
    }
    signature_ids: set[str] = set()
    for learnset in learnsets:
        species = str(learnset.get("species", "")).strip()
        seed = str(learnset.get("speciesSeed", "")).strip()
        assert seed in species_seeds and seed not in species_seen, f"invalid/duplicate learnset seed: {seed!r}"
        species_seen.add(seed)
        signatures = [entry for entry in learnset.get("skills", []) if entry.get("acquisition") == "signature"]
        inherited = [entry for entry in learnset.get("skills", []) if entry.get("acquisition") == "level"]
        assert len(signatures) == 1 and int(signatures[0].get("level", 0)) == 1, f"{species}: must have one level-1 signature"
        signature_ids.add(str(signatures[0].get("skill", "")))
        expected_levels = level_rules.get(str(learnset.get("rank", "")).lower(), [8, 16])
        assert [int(entry.get("level", 0)) for entry in inherited] == expected_levels, f"{species}: inherited levels must be {expected_levels}"
        for entry in learnset.get("skills", []):
            assert entry.get("skill") in action_ids, f"{species}: unknown skill {entry.get('skill')}"
            assert int(entry.get("level", 0)) >= 1, f"{species}: invalid skill level"
    assert species_seen == species_seeds and len(species_seen) == len(species_database), "every current species must have one learnset"

    record_ids: set[str] = set()
    costs = {"common": 300, "uncommon": 900, "rare": 2500, "legendary": 6000}
    for record in records:
        skill_id = str(record.get("skill", ""))
        assert skill_id in action_ids and skill_id not in record_ids, f"invalid/duplicate record: {skill_id}"
        record_ids.add(skill_id)
        level = str(record.get("recordLevel", ""))
        assert level in costs and int(record.get("bitsCost", -1)) == costs[level], f"{skill_id}: invalid record price"
        if not bool(record.get("teachable", False)):
            assert not record.get("unlockSources"), f"{skill_id}: unteachable record cannot have unlock sources"
    assert record_ids == action_ids, "every canonical technique must have record metadata"
    record_by_id = {str(record.get("skill", "")): record for record in records}
    for signature_id in signature_ids:
        assert not bool(record_by_id[signature_id].get("teachable", True)), f"signature {signature_id} cannot be teachable"

    assert len(source_audit) == 2260, f"source audit must contain 2260 rows, found {len(source_audit)}"
    assert all(str(row.get("sourceName", "")).strip() for row in source_audit), "source audit must not contain blank or advertisement rows"
    decisions = {"mapped", "requires_mechanic", "dummy_excluded", "alias"}
    dummy_count = 0
    for row in source_audit:
        assert row.get("decision") in decisions, f"invalid source decision: {row.get('decision')}"
        if row.get("decision") == "dummy_excluded":
            dummy_count += 1
            assert row.get("canonicalId") is None, "dummy source row cannot enter runtime database"
        else:
            assert row.get("canonicalId") in action_ids, f"broken canonical reference: {row.get('canonicalId')}"
    assert dummy_count == 54, f"source audit must exclude exactly 54 dummy rows, found {dummy_count}"

    dominance_groups: dict[tuple, list[dict]] = {}
    for action in techniques:
        effects_key = tuple(
            sorted((str(effect.get("type", "")), str(effect.get("status", ""))) for effect in action.get("effects", []))
        )
        key = (
            action.get("category"), action.get("element"), tuple(action.get("targets", [])),
            action.get("area", {}).get("shape"), action.get("range", {}).get("max"), effects_key,
        )
        dominance_groups.setdefault(key, []).append(action)
    for comparable in dominance_groups.values():
        for left_index, left in enumerate(comparable):
            for right in comparable[left_index + 1:]:
                left_values = (float(left.get("power", 0)), -float(left.get("spCost", 0)), -float(left.get("recoveryCost", 0)), float(left.get("accuracy", 0)))
                right_values = (float(right.get("power", 0)), -float(right.get("spCost", 0)), -float(right.get("recoveryCost", 0)), float(right.get("accuracy", 0)))
                left_dominates = all(a >= b for a, b in zip(left_values, right_values)) and any(a > b for a, b in zip(left_values, right_values))
                right_dominates = all(b >= a for a, b in zip(left_values, right_values)) and any(b > a for a, b in zip(left_values, right_values))
                assert not left_dominates and not right_dominates, f"direct dominance: {left['id']} versus {right['id']}"

    assert vfx_library.get("schema") == "digigame.vfx-library/1"
    effects = vfx_library.get("effects", {})
    assert isinstance(effects, dict) and len(effects) >= 71, "VFX library must contain the curated effect set"
    for effect_id, definition in effects.items():
        assert isinstance(definition, dict), f"{effect_id}: invalid VFX definition"
        atlas = str(definition.get("atlas", ""))
        assert res_path_exists(atlas), f"{effect_id}: missing local atlas {atlas}"
        frames = definition.get("frames", [])
        assert isinstance(frames, list) and frames, f"{effect_id}: missing frames"
        assert float(definition.get("fps", 0)) > 0, f"{effect_id}: invalid fps"
        for frame in frames:
            region = frame.get("region", [])
            assert isinstance(region, list) and len(region) == 4, f"{effect_id}: invalid frame region"
            assert int(region[2]) > 0 and int(region[3]) > 0, f"{effect_id}: empty frame region"

    assert presentations.get("schema") == "digigame.combat-presentations/1"
    presentation_actions = presentations.get("actions", {})
    assert isinstance(presentation_actions, dict)
    assert "basic_attack" in presentation_actions, "basic attack needs an explicit presentation"

    audio_profiles = presentations.get("audioProfiles", {})
    assert isinstance(audio_profiles, dict) and {"normal", "technique"}.issubset(audio_profiles)
    for profile_name, profile in audio_profiles.items():
        assert isinstance(profile, dict), f"audio profile {profile_name} must be an object"
        for phase in ("start", "impact"):
            path_text = str(profile.get(phase, ""))
            assert res_path_exists(path_text), f"audio profile {profile_name}: missing {phase} cue {path_text}"
    assert audio_profiles["normal"] != audio_profiles["technique"], "normal attack and technique audio must differ"

    signatures: dict[tuple[str, ...], str] = {}
    for action_id, presentation in presentation_actions.items():
        assert isinstance(presentation, dict), f"{action_id}: presentation must be an object"
        assert presentation.get("resolveOn", "damage") in {"damage", "status"}, f"{action_id}: invalid resolveOn"
        effect_ids: list[str] = []
        for phase, spec in iter_effect_specs(presentation):
            effect_id = str(spec.get("effect", ""))
            assert effect_id in effects, f"{action_id}/{phase}: unknown VFX {effect_id}"
            assert float(spec.get("scale", 1.0)) > 0, f"{action_id}/{phase}: invalid scale"
            effect_ids.append(effect_id)
        assert effect_ids, f"{action_id}: presentation has no VFX"
        if action_id != "basic_attack":
            signature = tuple(effect_ids)
            assert signature not in signatures, (
                f"{action_id} reuses the complete VFX signature of {signatures.get(signature)}; "
                "current techniques should remain visually distinct"
            )
            signatures[signature] = action_id

    fallbacks = presentations.get("elementFallbacks", {})
    assert isinstance(fallbacks, dict) and "neutral" in fallbacks
    for element, presentation in fallbacks.items():
        assert isinstance(presentation, dict), f"fallback {element}: must be an object"
        for phase, spec in iter_effect_specs(presentation):
            effect_id = str(spec.get("effect", ""))
            assert effect_id in effects, f"fallback {element}/{phase}: unknown VFX {effect_id}"

    print(
        f"validated combat data: {len(action_ids)} techniques, 2260 audited source rows, "
        f"{len(status_ids)} statuses, {len(species_seen)} learnsets, {len(effects)} VFX, "
        f"{len(presentation_actions)} curated presentations plus elemental fallbacks"
    )


if __name__ == "__main__":
    main()
