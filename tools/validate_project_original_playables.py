#!/usr/bin/env python3
"""Validate project-original Digimon data, profile art and transparent runtime sprites."""
from __future__ import annotations

import hashlib
import json
import re
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
MANIFEST_PATH = ROOT / "database/project-original-playables.json"
DATABASE_PATH = ROOT / "database/base-digimon-list.json"
EARLY_MANIFEST_PATH = ROOT / "database/early-rank-playables.json"
LEARNSETS_PATH = ROOT / "database/digimon-learnsets.json"
TECHNIQUES_PATH = ROOT / "database/techniques.json"
CANONICAL_DIRECTIONS = ["down_left", "down_right", "up_left", "up_right"]
CANONICAL_PHASES = ["idle", "step_a", "step_b"]


def fail(message: str) -> None:
    raise RuntimeError(message)


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def assignment(text: str, key: str) -> str | None:
    match = re.search(rf"^{re.escape(key)}\s*=\s*(.+)$", text, re.MULTILINE)
    return match.group(1).strip() if match else None


def local_res(value: str) -> Path:
    if not value.startswith("res://"):
        fail(f"Expected res:// source path, got {value!r}")
    return ROOT / value.removeprefix("res://")


def assert_transparent_field(path: Path, cell_width: int, cell_height: int, name: str) -> None:
    try:
        image = Image.open(path).convert("RGBA")
        image.load()
    except Exception as exc:
        fail(f"{name}: runtime field PNG cannot be decoded: {exc}")
    if image.size != (cell_width * 12, cell_height):
        fail(f"{name}: runtime field size {image.size} is invalid")
    alpha = image.getchannel("A")
    lo, hi = alpha.getextrema()
    if lo >= 255 or hi <= 0:
        fail(f"{name}: runtime field must contain visible sprites over transparency")
    for index in range(12):
        x0 = index * cell_width
        frame = image.crop((x0, 0, x0 + cell_width, cell_height))
        frame_alpha = frame.getchannel("A")
        transparent = sum(1 for value in frame_alpha.getdata() if value == 0)
        if transparent < int(cell_width * cell_height * 0.45):
            fail(f"{name}: field frame {index} still contains an opaque background")
        for point in ((0, 0), (cell_width - 1, 0), (0, cell_height - 1), (cell_width - 1, cell_height - 1)):
            if frame.getpixel(point)[3] != 0:
                fail(f"{name}: field frame {index} edge background is not transparent")


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
        if entry is None:
            fail(f"{name}: canonical database entry is missing")

        parent_seed = str(spec["evolves_from_seed"])
        parent = db_by_seed.get(parent_seed)
        if parent is None or seed not in parent.get("digiEvolutionSeedList", []):
            fail(f"{name}: parent evolution route is missing")
        if parent_seed not in entry.get("degenerateSeedList", []):
            fail(f"{name}: degeneration route back to parent is missing")
        if entry.get("digiEvolutionSeedList") != [] or entry.get("rank") != "Rookie" or entry.get("element") != "plant":
            fail(f"{name}: expected terminal plant Rookie")

        field_cfg = dict(spec["field"])
        portrait_cfg = dict(spec["portrait"])
        if field_cfg.get("directions") != CANONICAL_DIRECTIONS or field_cfg.get("phases") != CANONICAL_PHASES:
            fail(f"{name}: field direction/phase contract drifted")
        boxes = field_cfg.get("source_boxes", [])
        order = field_cfg.get("runtime_frame_indices", [])
        if len(boxes) != 12 or sorted(int(value) for value in order) != list(range(12)):
            fail(f"{name}: field source boxes/order are invalid")

        field_source = local_res(str(spec["field_source"]))
        portrait_source = local_res(str(spec["portrait_source"]))
        for source in (field_source, portrait_source):
            if not source.is_file() or source.stat().st_size <= 0:
                fail(f"{name}: missing source {source.relative_to(ROOT)}")
        try:
            source_sheet = Image.open(field_source)
            source_sheet.load()
        except Exception as exc:
            fail(f"{name}: source sheet cannot be decoded: {exc}")
        for box in boxes:
            x, y, w, h = map(int, box)
            if x < 0 or y < 0 or w <= 0 or h <= 0 or x + w > source_sheet.width or y + h > source_sheet.height:
                fail(f"{name}: source box outside source sheet: {box}")

        try:
            profile = Image.open(portrait_source).convert("RGBA")
            profile.load()
        except Exception as exc:
            fail(f"{name}: profile source cannot be decoded: {exc}")
        expected_profile_size = (int(portrait_cfg["frame_width"]) * int(portrait_cfg["frame_count"]), int(portrait_cfg["frame_height"]))
        if profile.size != expected_profile_size:
            fail(f"{name}: profile source size {profile.size} != {expected_profile_size}")
        lo, hi = profile.getchannel("A").getextrema()
        if lo >= 255 or hi <= 0:
            fail(f"{name}: profile portrait must use transparency")
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

        assert_transparent_field(field_path, int(field_cfg["cell_width"]), int(field_cfg["cell_height"]), name)
        if portrait_path.read_bytes() != portrait_source.read_bytes():
            fail(f"{name}: runtime portrait strip must reproduce the dedicated profile source")

        field_meta = json.loads(field_meta_path.read_text(encoding="utf-8"))
        if field_meta.get("source_kind") != "project_original" or field_meta.get("source_sheet") != spec["field_source"] or field_meta.get("source_sha256") != sha256(field_source):
            fail(f"{name}: field metadata provenance mismatch")
        if field_meta.get("directions") != CANONICAL_DIRECTIONS or field_meta.get("canonical_runtime_phases") != CANONICAL_PHASES:
            fail(f"{name}: field metadata contract mismatch")
        if field_meta.get("runtime_frame_indices") != order:
            fail(f"{name}: field runtime order drifted")
        if field_meta.get("background_policy") != "edge_connected_near_black_only":
            fail(f"{name}: field background removal policy is not explicit")

        portrait_meta = json.loads(portrait_meta_path.read_text(encoding="utf-8"))
        if portrait_meta.get("source_kind") != "project_original" or portrait_meta.get("source_sha256") != sha256(portrait_source):
            fail(f"{name}: portrait metadata provenance mismatch")
        if int(portrait_meta.get("frame_width", 0)) != int(portrait_cfg["frame_width"]) or int(portrait_meta.get("frame_height", 0)) != int(portrait_cfg["frame_height"]):
            fail(f"{name}: portrait frame dimensions drifted")
        if int(portrait_meta.get("frame_count", 0)) != int(portrait_cfg["frame_count"]):
            fail(f"{name}: portrait frame count drifted")

        text = resource_path.read_text(encoding="utf-8")
        if assignment(text, "display_name") != json.dumps(name) or assignment(text, "sprite_layout") != '"directional_12"':
            fail(f"{name}: runtime resource identity/layout mismatch")
        if assignment(text, "sprite_hframes") != "12" or assignment(text, "sprite_vframes") != "1":
            fail(f"{name}: runtime resource frame grid mismatch")
        if f"res://assets/characters/{key}/field.png" not in text:
            fail(f"{name}: runtime resource is not linked to field strip")

        early_row = early_by_name.get(name)
        if not early_row or early_row.get("field_source_kind") != "project_original" or early_row.get("portrait_source") != spec["portrait_source"]:
            fail(f"{name}: early-rank manifest integration drifted")

        learnset = learnsets_by_name.get(name)
        expected_skills = spec.get("learnset", [])
        if not learnset or learnset.get("skills") != expected_skills:
            fail(f"{name}: permanent technique learnset mismatch")
        signatures = [skill for skill in expected_skills if skill.get("acquisition") == "signature"]
        inherited = [skill for skill in expected_skills if skill.get("acquisition") == "level"]
        if len(signatures) != 1 or int(signatures[0].get("level", 0)) != 1 or [int(skill.get("level", 0)) for skill in inherited] != [8, 16]:
            fail(f"{name}: Rookie learnset levels are invalid")
        for skill in expected_skills:
            if str(skill.get("skill", "")) not in technique_ids:
                fail(f"{name}: learnset references unknown technique {skill}")

    print("project-original playable validation passed: " + ", ".join(str(spec["name"]) for spec in specs))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
