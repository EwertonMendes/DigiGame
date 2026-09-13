#!/usr/bin/env python3
"""Hard rebuild all non-Agumon DS runtime sprites using the reviewed registry.

This intentionally reuses only low-level source/cropping/composition helpers from
rebuild_all_ds_fields_from_source.py. Semantic facing selection is replaced by
an explicit per-species registry and therefore cannot silently regress to a
row-position heuristic.
"""
from __future__ import annotations

import hashlib
import json
from pathlib import Path

import rebuild_all_ds_fields_from_source as base
from ds_direction_registry import REGISTRY_PATH, load_registry, select_registered_left_groups


def _sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _validate_generated_metadata(registry: dict) -> None:
    by_name = registry["entries"]
    entries = base._load_early_database()
    failures: list[str] = []
    for entry in entries:
        name = str(entry["name"])
        if name == base.GOLDEN_NAME or name not in base.WTW_IDS:
            continue
        key = base.portrait_key(entry)
        meta_path = Path("assets/characters") / key / "field.json"
        if not meta_path.exists():
            failures.append(f"{name}: missing generated field.json")
            continue
        meta = json.loads(meta_path.read_text(encoding="utf-8"))
        registered = by_name[name]
        expected_groups = {key: int(value) for key, value in registered["groups"].items()}
        if meta.get("registered_direction_groups") != expected_groups:
            failures.append(f"{name}: generated metadata does not match reviewed direction groups")
        if meta.get("semantic_mapping_source") != str(REGISTRY_PATH):
            failures.append(f"{name}: generated metadata is not registry-backed")
        if meta.get("source_archive_file") != registered["source_archive_file"]:
            failures.append(
                f"{name}: source archive member changed: {meta.get('source_archive_file')!r} != {registered['source_archive_file']!r}"
            )
    if failures:
        raise RuntimeError("Generated DS metadata validation failed:\n- " + "\n- ".join(failures))


def _enrich_manifest(registry: dict) -> None:
    manifest = json.loads(base.MANIFEST.read_text(encoding="utf-8"))
    manifest["semantic_direction_registry"] = str(REGISTRY_PATH)
    manifest["semantic_direction_registry_sha256"] = _sha256(REGISTRY_PATH)
    manifest["semantic_direction_registry_entries"] = len(registry["entries"])
    manifest["semantic_direction_policy"] = (
        "explicit per-species reviewed G0..G3 mapping; semantic directions are never inferred from source row/group position"
    )
    base.MANIFEST.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")


def main() -> None:
    registry = load_registry()

    # Replace the old heuristic selector before any source is downloaded or any
    # field is rebuilt. The base rebuild still hard-deletes every non-Agumon
    # runtime strip and downloads the WtW archive afresh.
    def registry_selector(image, sprite_id):
        return select_registered_left_groups(image, sprite_id, registry)

    base._select_authored_left_groups = registry_selector
    base.main()
    _validate_generated_metadata(registry)
    _enrich_manifest(registry)
    print(
        f"registry-driven DS rebuild complete: {len(registry['entries'])}/82 WtW sources have explicit semantic mappings"
    )


if __name__ == "__main__":
    main()
