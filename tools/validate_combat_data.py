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
    expected_presentations = action_ids | {"basic_attack"}
    missing_presentations = expected_presentations - set(presentation_actions)
    assert not missing_presentations, f"missing explicit combat presentations: {sorted(missing_presentations)}"

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
        f"validated combat data: {len(action_ids)} techniques, {len(status_ids)} statuses, "
        f"{len(species_seen)} learnsets, {len(effects)} VFX, {len(presentation_actions)} presentations"
    )


if __name__ == "__main__":
    main()
