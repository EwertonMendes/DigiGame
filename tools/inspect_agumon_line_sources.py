#!/usr/bin/env python3
"""Inspect the requested Agumon-line DS sources from the pinned WtW archive."""
from __future__ import annotations

import json
from pathlib import Path

from PIL import Image

from build_early_rank_ds_fields import _components, _group_by_y, load_wtw_archive

TARGETS = {
    "Geo Greymon": 139,
    "Skull Greymon": 197,
    "Rize Greymon": 256,
    "War Greymon": 309,
    "Shine Greymon": 374,
}
OUT = Path("/tmp/agumon-line-source-audit")


def source_member(archive, sprite_id: int) -> str:
    prefix = f"sprite thread/{sprite_id:03d}_"
    matches = [name for name in archive.namelist() if name.startswith(prefix) and name.lower().endswith((".png", ".gif"))]
    if len(matches) != 1:
        raise RuntimeError(f"{sprite_id:03d}: expected one source, got {matches}")
    return matches[0]


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    archive = load_wtw_archive()
    report = {}
    for name, sprite_id in TARGETS.items():
        member = source_member(archive, sprite_id)
        payload = archive.read(member)
        target = OUT / f"{sprite_id:03d}_{name.replace(' ', '')}.png"
        target.write_bytes(payload)
        with Image.open(target) as image:
            rgba = image.convert("RGBA")
            background, components = _components(rgba)
            candidates = [item for item in components if 6 <= item["w"] <= 80 and 6 <= item["h"] <= 96 and item["area"] >= 50]
            groups = _group_by_y(candidates, tolerance=8.0)
            report[name] = {
                "source_id": sprite_id,
                "member": member,
                "size": list(rgba.size),
                "background": list(background),
                "components": len(components),
                "candidate_groups": [
                    {
                        "mean_y": round(sum(item["cy"] for item in group) / len(group), 2),
                        "count": len(group),
                        "items": [
                            {k: round(float(item[k]), 2) for k in ("x", "y", "w", "h", "area", "cx", "cy")}
                            for item in sorted(group, key=lambda value: value["cx"])
                        ],
                    }
                    for group in groups
                ],
            }
            print(f"{sprite_id:03d} {name}: {member} size={rgba.size} candidate_groups={[len(group) for group in groups]}")
    (OUT / "report.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
