#!/usr/bin/env python3
"""One-time repository migration for the Grass Agumon project-original pipeline."""
from pathlib import Path


# The branch bootstrap workflow may run again after the first materialization.
# Once all cross-cutting ownership markers are present, the migration is done;
# asset/data rebuilding remains deterministic and can continue normally.
_directional_text = Path("tools/validate_all_ds_directional_facings.py").read_text(encoding="utf-8")
_technique_text = Path("tools/build_technique_catalog.mjs").read_text(encoding="utf-8")
_combat_validation_text = Path("tools/validate_combat_data.py").read_text(encoding="utf-8")
if (
    "PROJECT_ORIGINAL_AUDIT_PATH" in _directional_text
    and '["grass agumon", "adhesive_bubble"]' in _technique_text
    and "len(species_database)" in _combat_validation_text
):
    print("Grass Agumon repository integration patches already applied")
    raise SystemExit(0)


def replace_once(path: str, old: str, new: str) -> None:
    file = Path(path)
    text = file.read_text(encoding="utf-8")
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f"{path}: expected patch marker exactly once, found {count}")
    file.write_text(text.replace(old, new, 1), encoding="utf-8")


# Keep the official/community DS rebuild strictly scoped to its 87 audited
# canonical sources while preserving project-original rows in the manifest.
replace_once(
    "tools/build_early_rank_ds_fields.py",
    'EARLY_RANKS = ("Fresh", "In-Training", "Rookie")\nDIRECTION_ORDER = ("down_left", "down_right", "up_left", "up_right")',
    'EARLY_RANKS = ("Fresh", "In-Training", "Rookie")\nPROJECT_ORIGINAL_MANIFEST = Path("database/project-original-playables.json")\nDIRECTION_ORDER = ("down_left", "down_right", "up_left", "up_right")',
)
replace_once(
    "tools/build_early_rank_ds_fields.py",
    '''def resource_filename(name: str) -> str:
    return f"{name.strip().lower()}.tres"


def fetch(url: str) -> bytes:''',
    '''def resource_filename(name: str) -> str:
    return f"{name.strip().lower()}.tres"


def project_original_names() -> set[str]:
    if not PROJECT_ORIGINAL_MANIFEST.is_file():
        return set()
    payload = json.loads(PROJECT_ORIGINAL_MANIFEST.read_text(encoding="utf-8"))
    return {
        str(item.get("name", ""))
        for item in payload.get("species", [])
        if isinstance(item, dict) and str(item.get("name", ""))
    }


def fetch(url: str) -> bytes:''',
)
replace_once(
    "tools/build_early_rank_ds_fields.py",
    '    rows = [entry for entry in json.loads(path.read_text(encoding="utf-8")) if str(entry.get("rank", "")) in EARLY_RANKS]',
    '    project_original = project_original_names()\n    rows = [entry for entry in json.loads(path.read_text(encoding="utf-8")) if str(entry.get("rank", "")) in EARLY_RANKS and str(entry.get("name", "")) not in project_original]',
)
replace_once(
    "tools/build_early_rank_ds_fields.py",
    '''    payload = {
        "ranks": list(EARLY_RANKS),''',
    '''    for project_name in sorted(project_original_names()):
        row = old_rows.get(project_name)
        if row is None:
            raise RuntimeError(f"Project-original early-rank row is missing from manifest: {project_name}")
        built.append(dict(row))

    payload = {
        "ranks": list(EARLY_RANKS),''',
)
replace_once(
    "tools/build_early_rank_ds_fields.py",
    '"counts_by_rank": {rank: sum(1 for entry in entries if str(entry.get("rank")) == rank) for rank in EARLY_RANKS},',
    '"counts_by_rank": {rank: sum(1 for row in built if str(row.get("rank")) == rank) for rank in EARLY_RANKS},',
)
replace_once(
    "tools/build_early_rank_ds_fields.py",
    '"field_sources": {"official_ds": official_count, "community_ds_style_exception": exception_count},',
    '"field_sources": {"official_ds": official_count, "community_ds_style_exception": exception_count, "project_original": sum(1 for row in built if str(row.get("field_source_kind", "")) == "project_original")},',
)

# The exact-registry reset owns the same 87 canonical DS species; custom species
# are rebuilt by build_project_original_playables.py instead.
replace_once(
    "tools/rebuild_ds_fields_from_exact_registry.py",
    '    rows = [row for row in rows if str(row.get("rank", "")) in EARLY_RANKS]',
    '''    project_manifest = Path("database/project-original-playables.json")
    project_original = set()
    if project_manifest.is_file():
        project_payload = json.loads(project_manifest.read_text(encoding="utf-8"))
        project_original = {
            str(item.get("name", ""))
            for item in project_payload.get("species", [])
            if isinstance(item, dict)
        }
    rows = [row for row in rows if str(row.get("rank", "")) in EARLY_RANKS and str(row.get("name", "")) not in project_original]''',
)

# A canonical upstream database refresh is followed by the local project-original
# builder so custom species and reciprocal evolution links survive the refresh.
replace_once(
    "tools/sync_digimon_database_assets.py",
    '''    write_manifest(entries, manifest_rows)


if __name__ == "__main__":''',
    '''    write_manifest(entries, manifest_rows)
    project_builder = Path("tools/build_project_original_playables.py")
    if project_builder.is_file():
        subprocess.run(["python3", str(project_builder)], check=True)


if __name__ == "__main__":''',
)

# Directional source coverage has a third, explicit project-original pipeline
# instead of pretending custom art came from the DS source archives.
replace_once(
    "tools/validate_all_ds_directional_facings.py",
    'ADDITIONAL_AUDIT_PATH = Path("database/additional-ds-playables.json")\nREPORT_PATH',
    'ADDITIONAL_AUDIT_PATH = Path("database/additional-ds-playables.json")\nPROJECT_ORIGINAL_AUDIT_PATH = Path("database/project-original-playables.json")\nREPORT_PATH',
)
replace_once(
    "tools/validate_all_ds_directional_facings.py",
    '\n\ndef main() -> None:',
    '''

def _project_original_names() -> set[str]:
    if not PROJECT_ORIGINAL_AUDIT_PATH.exists():
        return set()
    data = json.loads(PROJECT_ORIGINAL_AUDIT_PATH.read_text(encoding="utf-8"))
    if data.get("source_kind") != "project_original":
        raise RuntimeError("Project-original manifest source kind is invalid")
    names = _names(data.get("species"))
    if int(data.get("count", -1)) != len(names):
        raise RuntimeError("Project-original manifest count does not match its species")
    return names


def main() -> None:''',
)
replace_once(
    "tools/validate_all_ds_directional_facings.py",
    '''    additional = _additional_names()
    overlap = (preserved | rebuilt) & additional
    if overlap:
        raise RuntimeError("Directional species cannot be owned by two source pipelines: " + ", ".join(sorted(overlap)))
    covered = preserved | rebuilt | additional''',
    '''    additional = _additional_names()
    project_original = _project_original_names()
    overlap = ((preserved | rebuilt) & additional) | ((preserved | rebuilt | additional) & project_original)
    if overlap:
        raise RuntimeError("Directional species cannot be owned by two source pipelines: " + ", ".join(sorted(overlap)))
    covered = preserved | rebuilt | additional | project_original''',
)
replace_once(
    "tools/validate_all_ds_directional_facings.py",
    '"coverage": "additional_ds" if display_name in additional else "early_ds",',
    '"coverage": "project_original" if display_name in project_original else ("additional_ds" if display_name in additional else "early_ds"),',
)
replace_once(
    "tools/validate_all_ds_directional_facings.py",
    '        "additional_source_rebuilt_resource_count": len(additional),\n        "audited_resource_count"',
    '        "additional_source_rebuilt_resource_count": len(additional),\n        "project_original_resource_count": len(project_original),\n        "audited_resource_count"',
)
replace_once(
    "tools/validate_all_ds_directional_facings.py",
    'f"additional={len(additional)} audited={len(covered)} unknown={len(unknown)} missing={len(missing)}"',
    'f"additional={len(additional)} project_original={len(project_original)} audited={len(covered)} unknown={len(unknown)} missing={len(missing)}"',
)

# Keep the permanent technique catalogue generator deterministic for the custom
# Rookie. Regenerating the canonical catalogue after adding Grass Agumon must
# preserve the same signature/inherited techniques declared by this feature.
replace_once(
    "tools/build_technique_catalog.mjs",
    '''  const signatureOverrides = new Map([
    ["agumon", "pepper_breath"], ["gabumon", "blue_blaster"], ["greymon", "mega_flame"],
    ["koromon", "bubbles"], ["tanemon", "adhesive_bubble"], ["veemon", "vee_headbutt"],
  ]);''',
    '''  const signatureOverrides = new Map([
    ["agumon", "pepper_breath"], ["gabumon", "blue_blaster"], ["greymon", "mega_flame"],
    ["koromon", "bubbles"], ["tanemon", "adhesive_bubble"], ["veemon", "vee_headbutt"],
    ["grass agumon", "adhesive_bubble"],
  ]);''',
)
replace_once(
    "tools/build_technique_catalog.mjs",
    '''  const inheritedOverrides = new Map([
    ["agumon", ["guard_charge"]], ["gabumon", ["speed_charge"]],
    ["greymon", ["guard_charge"]], ["veemon", ["speed_charge"]],
  ]);''',
    '''  const inheritedOverrides = new Map([
    ["agumon", ["guard_charge"]], ["gabumon", ["speed_charge"]],
    ["greymon", ["guard_charge"]], ["veemon", ["speed_charge"]],
    ["grass agumon", ["guard_charge", "speed_charge"]],
  ]);''',
)

# The catalogue validator is count-driven rather than frozen to the original
# 408 upstream species because DigiGame owns project-original species too.
replace_once(
    "tools/validate_combat_data.py",
    '    assert species_seen == species_seeds and len(species_seen) == 408, "every current species must have one learnset"',
    '    assert species_seen == species_seeds and len(species_seen) == len(species_database), "every current species must have one learnset"',
)

print("Grass Agumon repository integration patches applied")
