#!/usr/bin/env python3
"""Verify every runtime directional Digimon is covered by a reproducible source pipeline.

The early-rank rebuild manifest covers the original normalized roster. Higher-rank
DS additions are covered by database/additional-ds-playables.json. Runtime code
must never gain species-specific facing fixes: every covered resource is already
a canonical directional_12 strip before Godot loads it.
"""
from __future__ import annotations

import json
import re
from pathlib import Path

EARLY_AUDIT_PATH = Path("database/ds-full-rebuild-manifest.json")
ADDITIONAL_AUDIT_PATH = Path("database/additional-ds-playables.json")
REPORT_PATH = Path("database/ds-directional-resource-audit.json")
RESOURCE_ROOT = Path("assets/resources")
DEFAULT_LAYOUT = "directional_12"


def _names(items: object) -> set[str]:
    if not isinstance(items, list):
        return set()
    result: set[str] = set()
    for item in items:
        if isinstance(item, str):
            result.add(item)
        elif isinstance(item, dict) and isinstance(item.get("name"), str):
            result.add(item["name"])
    return result


def _assignment(text: str, key: str) -> str | None:
    match = re.search(rf'^\s*{re.escape(key)}\s*=\s*"([^"]*)"\s*$', text, re.MULTILINE)
    return match.group(1) if match else None


def _additional_names() -> set[str]:
    if not ADDITIONAL_AUDIT_PATH.exists():
        return set()
    data = json.loads(ADDITIONAL_AUDIT_PATH.read_text(encoding="utf-8"))
    if data.get("canonical_runtime_order") != ["down_left", "down_right", "up_left", "up_right"]:
        raise RuntimeError("Additional DS manifest runtime direction order is not canonical")
    names = _names(data.get("species"))
    if int(data.get("count", -1)) != len(names):
        raise RuntimeError("Additional DS manifest count does not match its species")
    return names


def main() -> None:
    audit = json.loads(EARLY_AUDIT_PATH.read_text(encoding="utf-8"))
    if audit.get("canonical_reference") != "Agumon":
        raise RuntimeError("DS rebuild manifest must use Agumon as its canonical reference")
    if audit.get("canonical_runtime_order") != ["down_left", "down_right", "up_left", "up_right"]:
        raise RuntimeError("DS rebuild manifest runtime direction order is not canonical")
    if audit.get("existing_non_agumon_runtime_strips_allowed_as_input") is not False:
        raise RuntimeError("DS rebuild manifest permits reuse of an existing non-Agumon runtime strip")
    if audit.get("unresolved") != []:
        raise RuntimeError("DS rebuild manifest still contains unresolved sprites")

    preserved = _names(audit.get("preserved"))
    rebuilt = _names(audit.get("rebuilt"))
    expected_preserved = {"Agumon", "Greymon", "Metal Greymon"}
    if preserved != expected_preserved:
        raise RuntimeError(f"Expected preserved reviewed strips {sorted(expected_preserved)}, got: {sorted(preserved)}")
    if "Agumon" in rebuilt:
        raise RuntimeError("Agumon must not appear in rebuilt entries")
    if len(rebuilt) != 86:
        raise RuntimeError(f"Expected 86 source-rebuilt early directional sprites, got {len(rebuilt)}")

    additional = _additional_names()
    overlap = (preserved | rebuilt) & additional
    if overlap:
        raise RuntimeError("Directional species cannot be owned by two source pipelines: " + ", ".join(sorted(overlap)))
    covered = preserved | rebuilt | additional

    directional: dict[str, dict[str, str]] = {}
    duplicate_names: dict[str, list[str]] = {}
    missing_display_name: list[str] = []
    for path in sorted(RESOURCE_ROOT.glob("*.tres")):
        text = path.read_text(encoding="utf-8")
        layout = _assignment(text, "sprite_layout") or DEFAULT_LAYOUT
        if layout != "directional_12":
            continue
        display_name = _assignment(text, "display_name")
        if not display_name:
            missing_display_name.append(str(path))
            continue
        if display_name in directional:
            duplicate_names.setdefault(display_name, [directional[display_name]["resource"]]).append(str(path))
        directional[display_name] = {
            "resource": str(path),
            "layout_source": "explicit" if _assignment(text, "sprite_layout") else "Digimon.gd default",
            "coverage": "additional_ds" if display_name in additional else "early_ds",
        }

    directional_names = set(directional)
    unknown = sorted(directional_names - covered)
    missing = sorted(covered - directional_names)
    report = {
        "runtime_default_layout": DEFAULT_LAYOUT,
        "canonical_reference": "Agumon",
        "directional_resource_count": len(directional_names),
        "preserved_resource_count": len(preserved),
        "source_rebuilt_resource_count": len(rebuilt),
        "additional_source_rebuilt_resource_count": len(additional),
        "audited_resource_count": len(covered),
        "directional_resources": [{"name": name, **directional[name]} for name in sorted(directional)],
        "unknown_directional_resources": unknown,
        "audited_but_not_directional": missing,
        "missing_display_name": missing_display_name,
        "duplicate_display_names": duplicate_names,
    }
    REPORT_PATH.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(
        "directional source coverage: "
        f"runtime={len(directional_names)} early_preserved={len(preserved)} early_rebuilt={len(rebuilt)} "
        f"additional={len(additional)} audited={len(covered)} unknown={len(unknown)} missing={len(missing)}"
    )
    if len(directional_names) != len(covered):
        raise RuntimeError(f"Expected {len(covered)} covered runtime directional resources, got {len(directional_names)}")
    if unknown:
        raise RuntimeError("Unaudited directional resources: " + ", ".join(unknown))
    if missing:
        raise RuntimeError("Source-pipeline entries not using directional_12: " + ", ".join(missing))
    if missing_display_name:
        raise RuntimeError("Directional resources without display_name: " + ", ".join(missing_display_name))
    if duplicate_names:
        raise RuntimeError("Duplicate directional display_name values: " + ", ".join(sorted(duplicate_names)))


if __name__ == "__main__":
    main()
