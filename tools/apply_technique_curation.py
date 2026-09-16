#!/usr/bin/env python3
"""Apply explicit, reviewed technique and learnset curation after source generation.

The source catalogue remains fully generated/auditable. This small second stage is for
canonical species moves or source defects that should not be encoded as runtime hacks.
It is deterministic and safe to run repeatedly after build_technique_catalog.mjs.
"""
from __future__ import annotations

import json
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
DATABASE = ROOT / "database"
CURATION_PATH = DATABASE / "technique-curation.json"
TECHNIQUES_PATH = DATABASE / "techniques.json"
LEARNSETS_PATH = DATABASE / "digimon-learnsets.json"
RECORDS_PATH = DATABASE / "technique-records.json"
SPECIES_PATH = DATABASE / "base-digimon-list.json"


def load(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def write(path: Path, payload: Any) -> None:
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def upsert(rows: list[dict[str, Any]], key: str, replacement: dict[str, Any]) -> None:
    value = str(replacement.get(key, "")).strip()
    if not value:
        raise RuntimeError(f"Curated row is missing {key}: {replacement!r}")
    matching = [index for index, row in enumerate(rows) if str(row.get(key, "")).strip() == value]
    if len(matching) > 1:
        raise RuntimeError(f"Generated data contains duplicate {key}={value!r}")
    clean = json.loads(json.dumps(replacement, ensure_ascii=False))
    if matching:
        rows[matching[0]] = clean
    else:
        rows.append(clean)


def main() -> None:
    curation = load(CURATION_PATH)
    if int(curation.get("schema_version", 0)) != 1:
        raise RuntimeError("Unsupported technique curation schema")

    techniques = load(TECHNIQUES_PATH)
    learnsets = load(LEARNSETS_PATH)
    records = load(RECORDS_PATH)
    species = load(SPECIES_PATH)
    if not all(isinstance(rows, list) for rows in (techniques, learnsets, records, species)):
        raise RuntimeError("Technique curation expects array-backed generated databases")

    for technique in curation.get("techniques", []):
        if not isinstance(technique, dict):
            raise RuntimeError("Curated techniques must be objects")
        upsert(techniques, "id", technique)

    action_ids = {str(row.get("id", "")) for row in techniques}
    species_by_seed = {str(row.get("seed", "")): row for row in species}
    for learnset in curation.get("learnsets", []):
        if not isinstance(learnset, dict):
            raise RuntimeError("Curated learnsets must be objects")
        seed = str(learnset.get("speciesSeed", "")).strip()
        canonical = species_by_seed.get(seed)
        if canonical is None:
            raise RuntimeError(f"Curated learnset references unknown species seed {seed!r}")
        if str(canonical.get("name", "")) != str(learnset.get("species", "")):
            raise RuntimeError(f"Curated learnset species identity does not match {seed}")
        if str(canonical.get("rank", "")) != str(learnset.get("rank", "")):
            raise RuntimeError(f"Curated learnset rank does not match {seed}")
        for skill in learnset.get("skills", []):
            skill_id = str(skill.get("skill", "")).strip()
            if skill_id not in action_ids:
                raise RuntimeError(f"Curated learnset {seed} references unknown technique {skill_id!r}")
        upsert(learnsets, "speciesSeed", learnset)

    for record in curation.get("records", []):
        if not isinstance(record, dict):
            raise RuntimeError("Curated technique records must be objects")
        skill_id = str(record.get("skill", "")).strip()
        if skill_id not in action_ids:
            raise RuntimeError(f"Curated record references unknown technique {skill_id!r}")
        upsert(records, "skill", record)

    records_by_skill = {str(row.get("skill", "")) for row in records}
    curated_ids = {str(row.get("id", "")) for row in curation.get("techniques", []) if isinstance(row, dict)}
    missing_records = sorted(curated_ids - records_by_skill)
    if missing_records:
        raise RuntimeError(f"Curated techniques are missing record metadata: {missing_records}")

    write(TECHNIQUES_PATH, techniques)
    write(LEARNSETS_PATH, learnsets)
    write(RECORDS_PATH, records)
    print(
        "applied technique curation: "
        f"{len(curation.get('techniques', []))} techniques, "
        f"{len(curation.get('learnsets', []))} learnsets, "
        f"{len(curation.get('records', []))} records"
    )


if __name__ == "__main__":
    main()
