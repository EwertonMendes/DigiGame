#!/usr/bin/env python3
"""Verify that every runtime directional Digimon resource is in the facing audit.

This is intentionally repository-wide rather than rank-scoped. Any new
`directional_12` resource must be classified by the facing audit before it can
silently enter Sprite Test, overworld followers, or battle runtime.
"""
from __future__ import annotations

import json
import re
from pathlib import Path

AUDIT_PATH = Path("database/ds-facing-audit.json")
REPORT_PATH = Path("database/ds-directional-resource-audit.json")
RESOURCE_ROOT = Path("assets/resources")


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
    covered: set[str] = set()
    for key in (
        "corrected_from_reviewed_specs",
        "corrected_from_reviewed_wtw_grids",
        "corrected_from_reviewed_project_extractors",
        "trusted_explicit_wtw_four_facing",
        "community_synthetic_four_facing",
        "already_reviewed_outside_early_rank",
    ):
        covered.update(_names(audit.get(key)))

    directional: dict[str, str] = {}
    duplicate_names: dict[str, list[str]] = {}
    missing_display_name: list[str] = []
    for path in sorted(RESOURCE_ROOT.glob("*.tres")):
        text = path.read_text(encoding="utf-8")
        if _assignment(text, "sprite_layout") != "directional_12":
            continue
        display_name = _assignment(text, "display_name")
        if not display_name:
            missing_display_name.append(str(path))
            continue
        if display_name in directional:
            duplicate_names.setdefault(display_name, [directional[display_name]]).append(str(path))
        directional[display_name] = str(path)

    directional_names = set(directional)
    unknown = sorted(directional_names - covered)
    missing = sorted(covered - directional_names)
    report = {
        "directional_resource_count": len(directional_names),
        "audited_resource_count": len(covered),
        "directional_resources": [
            {"name": name, "resource": directional[name]}
            for name in sorted(directional)
        ],
        "unknown_directional_resources": unknown,
        "audited_but_not_directional": missing,
        "missing_display_name": missing_display_name,
        "duplicate_display_names": duplicate_names,
    }
    REPORT_PATH.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(
        "directional facing coverage: "
        f"runtime={len(directional_names)} audited={len(covered)} "
        f"unknown={len(unknown)} missing={len(missing)}"
    )
    if unknown:
        raise RuntimeError("Unaudited directional resources: " + ", ".join(unknown))
    if missing:
        raise RuntimeError("Facing audit entries not using directional_12: " + ", ".join(missing))
    if missing_display_name:
        raise RuntimeError("Directional resources without display_name: " + ", ".join(missing_display_name))
    if duplicate_names:
        raise RuntimeError("Duplicate directional display_name values: " + ", ".join(sorted(duplicate_names)))


if __name__ == "__main__":
    main()
