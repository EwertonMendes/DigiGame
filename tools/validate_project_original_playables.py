#!/usr/bin/env python3
"""Validate project-original Digimon data, transparent sources and runtime assets."""
from __future__ import annotations

import hashlib
import json
import re
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MANIFEST_PATH = ROOT / "database/project-original-playables.json"
DATABASE_PATH = ROOT / "database/base-digimon-list.json"
EARLY_MANIFEST_PATH = ROOT / "database/early-rank-playables.json"
LEARNSETS_PATH = ROOT / "database/digimon-learnsets.json"
TECHNIQUES_PATH = ROOT / "database/techniques.json"
CANONICAL_DIRECTIONS = ["down_left", "down_right", "up_left", "up_right"]


def fail(message: str) -> None:
    raise RuntimeError(message)


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def png_info(path: Path) -> tuple[int, int, int]:
    data = path.read_bytes()
    if len(data) < 33 or data[:8] != b"\x89PNG\r\n\x1a\n" or data[12:16] != b"IHDR":
        fail(f"{path.relative_to(ROOT)} is not a valid PNG")
    return (*struct.unpack(">II", data[16:24]), data[25])


def assignment(text: str, key: str) -> str | None:
    match = re.search(rf"^{re.escape(key)}\s*=\s*(.+)$", text, re.MULTILINE)
    return match.group(1).strip() if match else None


def local_res(value: str) -> Path:
    if not value.startswith("res://"):
        fail(f"Expected res:// source path, got {value!r}")
    return ROOT / value.removeprefix("res://")


def main() -> int:
    manifest = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
    database = json.loads(DATABASE_PATH.read_text(encoding="utf-8"))
    early = json.loads(EARLY_MANIFEST_PATH.read_text(encoding="utf-8"))
    learnsets = json.loads(LEARNSETS_PATH.read_text(encoding="utf-8"))
    techniques = json.loads(TECHNIQUES_PATH.read_text(encoding="utf-8"))

    if int(manifest.get("schema_version", 0)) != 2 or manifest.get("source_kind") != "project_original":
        fail("project-original manifest schema/source kind is invalid")
    specs = manifest.get("species", [])
    if not isinstance(specs, list) or not specs or int(manifest.get("count", -1)) != len(specs):
        fail("project-original manifest species/count is invalid")

    db_by_seed = {str(row.get("seed", "")): row for row in database}
    early_by_name = {str(row.get("name", "")): row for row in early.get("species", [])}
    learnsets_by_name = {str(row.get("species", "")): row for row in learnsets}
    technique_ids = {str(row.get("id", "")) for row in techniques}

    for spec in specs:
        name = str(spec["name"])
        seed = str(spec["seed"])
        key = str(spec["portrait_key"])
        entry = db_by_seed.get(seed)
        if entry is None or entry != spec.get("database_entry"):
            fail(f"{name}: database entry drifted from project-original manifest")

        parent_seed = str(spec["evolves_from_seed"])
        parent = db_by_seed.get(parent_seed)
        if parent is None or seed not in parent.get("digiEvolutionSeedList", []):
            fail(f"{name}: parent evolution route is missing")
        if parent_seed not in entry.get("degenerateSeedList", []):
            fail(f"{name}: degeneration route back to parent is missing")
        if entry.get("digiEvolutionSeedList") != [] or entry.get("rank") != "Rookie":
            fail(f"{name}: expected terminal project-original Rookie")
        if entry.get("element") != "plant":
            fail(f"{name}: expected plant element")

        field_source = local_res(str(spec["field_source"]))
        portrait_source = local_res(str(spec["portrait_source"]))
        for source in (field_source, portrait_source):
            if not source.is_file() or source.stat().st_size <= 0:
                fail(f"{name}: missing source {source.relative_to(ROOT)}")

        field_cfg = spec["field"]
        portrait_cfg = spec["portrait"]
        fw, fh, fct = png_info(field_source)
        if (fw, fh) != (int(field_cfg["cell_width"]) * 12, int(field_cfg["cell_height"])):
            fail(f"{name}: normalized field source dimensions are invalid")
        if fct not in {4, 6}:
            fail(f"{name}: normalized field source must preserve alpha")
        pw, ph, pct = png_info(portrait_source)
        if (pw, ph) != (
            int(portrait_cfg["frame_width"]) * int(portrait_cfg["frame_count"]),
            int(portrait_cfg["frame_height"]),
        ):
            fail(f"{name}: normalized portrait source dimensions are invalid")
        if pct not in {4, 6}:
            fail(f"{name}: normalized portrait source must preserve alpha")
        if int(portrait_cfg["frame_width"]) <= int(field_cfg["cell_width"]):
            fail(f"{name}: profile portrait must be distinct from the walking sprite")

        char_dir = ROOT / "assets/characters" / key
        field_path = char_dir / "field.png"
        field_meta_path = char_dir / "field.json"
        portrait_path = char_dir / "portrait_frames.png"
        portrait_meta_path = char_dir / "portrait_frames.json"
        resource_path = ROOT / "assets/resources" / f"{name.lower()}.tres"
        for path in (field_path, field_meta_path, portrait_path, portrait_meta_path, resource_path):
            if not path.is_file() or path.stat().st_size == 0:
                fail(f"{name}: missing runtime asset {path.relative_to(ROOT)}")

        if field_path.read_bytes() != field_source.read_bytes():
            fail(f"{name}: runtime field strip must reproduce the transparent normalized source byte-for-byte")
        if portrait_path.read_bytes() != portrait_source.read_bytes():
            fail(f"{name}: runtime portrait strip must reproduce the profile source byte-for-byte")

        field_meta = json.loads(field_meta_path.read_text(encoding="utf-8"))
        if field_meta.get("source_kind") != "project_original":
            fail(f"{name}: field metadata lost project-original provenance")
        if field_meta.get("source_sheet") != spec["field_source"] or field_meta.get("source_sha256") != sha256(field_source):
            fail(f"{name}: field metadata source provenance mismatch")
        if field_meta.get("directions") != CANONICAL_DIRECTIONS:
            fail(f"{name}: field directions do not match runtime contract")
        if field_meta.get("canonical_runtime_phases") != ["idle", "step_a", "step_b"]:
            fail(f"{name}: field phase order is invalid")
        if field_meta.get("runtime_frame_indices") != list(range(12)):
            fail(f"{name}: normalized field strip must already be canonical")

        portrait_meta = json.loads(portrait_meta_path.read_text(encoding="utf-8"))
        if portrait_meta.get("source_kind") != "project_original" or portrait_meta.get("source_sha256") != sha256(portrait_source):
            fail(f"{name}: portrait metadata provenance mismatch")
        if int(portrait_meta.get("frame_width", 0)) != int(portrait_cfg["frame_width"]) or int(portrait_meta.get("frame_height", 0)) != int(portrait_cfg["frame_height"]):
            fail(f"{name}: portrait frame dimensions drifted")
        if int(portrait_meta.get("frame_count", 0)) != int(portrait_cfg["frame_count"]):
            fail(f"{name}: portrait frame count drifted")

        text = resource_path.read_text(encoding="utf-8")
        if assignment(text, "display_name") != json.dumps(name):
            fail(f"{name}: runtime resource name mismatch")
        if assignment(text, "sprite_layout") != '"directional_12"':
            fail(f"{name}: runtime resource must use directional_12")
        if assignment(text, "sprite_hframes") != "12" or assignment(text, "sprite_vframes") != "1":
            fail(f"{name}: runtime resource frame grid mismatch")
        if f"res://assets/characters/{key}/field.png" not in text:
            fail(f"{name}: runtime resource is not linked to field strip")

        early_row = early_by_name.get(name)
        if not early_row or early_row.get("field_source_kind") != "project_original":
            fail(f"{name}: early-rank playable manifest entry is missing")
        if early_row.get("portrait_source") != spec["portrait_source"]:
            fail(f"{name}: early-rank manifest profile source mismatch")

        learnset = learnsets_by_name.get(name)
        expected_skills = spec.get("learnset", [])
        if not learnset or learnset.get("skills") != expected_skills:
            fail(f"{name}: permanent technique learnset mismatch")
        signatures = [skill for skill in expected_skills if skill.get("acquisition") == "signature"]
        inherited = [skill for skill in expected_skills if skill.get("acquisition") == "level"]
        if len(signatures) != 1 or int(signatures[0].get("level", 0)) != 1:
            fail(f"{name}: Rookie must have exactly one level-1 signature")
        if [int(skill.get("level", 0)) for skill in inherited] != [8, 16]:
            fail(f"{name}: Rookie inherited technique levels must be 8 and 16")
        for skill in expected_skills:
            if str(skill.get("skill", "")) not in technique_ids:
                fail(f"{name}: learnset references unknown technique {skill}")

    print("project-original playable validation passed: " + ", ".join(str(spec["name"]) for spec in specs))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
