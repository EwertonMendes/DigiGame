#!/usr/bin/env python3
"""Verify every runtime directional Digimon is covered by the source-only rebuild.

`Digimon.gd` defaults sprite_layout to directional_12, so a resource that omits
that assignment (legacy Greymon is one example) is still directional at runtime.
The authoritative coverage source is `database/ds-full-rebuild-manifest.json`:
Agumon is the only preserved golden strip; every other DS directional runtime
asset must be rebuilt from source.
"""
from __future__ import annotations

import json
import re
from pathlib import Path

AUDIT_PATH = Path("database/ds-full-rebuild-manifest.json")
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


def main() -> None:
    audit = json.loads(AUDIT_PATH.read_text(encoding="utf-8"))
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
    if preserved != {"Agumon"}:
        raise RuntimeError(f"Only Agumon may be preserved, got: {sorted(preserved)}")
    if "Agumon" in rebuilt:
        raise RuntimeError("Agumon must not appear in rebuilt entries")
    if len(rebuilt) != 88:
        raise RuntimeError(f"Expected 88 source-rebuilt directional sprites, got {len(rebuilt)}")
    covered = preserved | rebuilt

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
        "audited_resource_count": len(covered),
        "directional_resources": [
            {"name": name, **directional[name]}
            for name in sorted(directional)
        ],
        "unknown_directional_resources": unknown,
        "audited_but_not_directional": missing,
        "missing_display_name": missing_display_name,
        "duplicate_display_names": duplicate_names,
    }
    REPORT_PATH.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(
        "directional source-rebuild coverage: "
        f"runtime={len(directional_names)} preserved={len(preserved)} rebuilt={len(rebuilt)} "
        f"audited={len(covered)} unknown={len(unknown)} missing={len(missing)}"
    )
    if len(directional_names) != 89:
        raise RuntimeError(f"Expected 89 runtime directional resources, got {len(directional_names)}")
    if unknown:
        raise RuntimeError("Unaudited directional resources: " + ", ".join(unknown))
    if missing:
        raise RuntimeError("Rebuild manifest entries not using directional_12: " + ", ".join(missing))
    if missing_display_name:
        raise RuntimeError("Directional resources without display_name: " + ", ".join(missing_display_name))
    if duplicate_names:
        raise RuntimeError("Duplicate directional display_name values: " + ", ".join(sorted(duplicate_names)))


if __name__ == "__main__":
    main()
