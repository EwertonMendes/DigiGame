#!/usr/bin/env python3
from __future__ import annotations

import base64
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def replace_once(path: Path, old: str, new: str) -> None:
    text = path.read_text(encoding="utf-8")
    if old not in text:
        raise RuntimeError(f"patch marker not found in {path}: {old[:100]!r}")
    path.write_text(text.replace(old, new, 1), encoding="utf-8")


def decode_parts(prefix: str, output: Path) -> str:
    parts = sorted((ROOT / "tools/bootstrap-assets").glob(f"{prefix}.part*"))
    if not parts:
        raise RuntimeError(f"missing bootstrap parts for {prefix}")
    payload = base64.b64decode("".join(p.read_text(encoding="ascii").strip() for p in parts))
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_bytes(payload)
    return hashlib.sha256(payload).hexdigest()


field_path = ROOT / "assets/characters/grassagumon/source/sheet.png"
portrait_source_path = ROOT / "assets/characters/grassagumon/source/portrait.png"
field_sha = decode_parts("field.b64", field_path)
portrait_sha = decode_parts("portrait.b64", portrait_source_path)

manifest_path = ROOT / "database/project-original-playables.json"
manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
spec = next(row for row in manifest["species"] if row.get("name") == "Grass Agumon")
spec["source_sha256"] = field_sha
spec["portrait_source_sheet"] = "res://assets/characters/grassagumon/source/portrait.png"
spec["portrait_source_sha256"] = portrait_sha
spec["portrait"] = {
    "source_boxes": [[0, 0, 160, 180], [160, 0, 160, 180], [320, 0, 160, 180]],
    "frame_width": 160,
    "frame_height": 180,
    "max_sprite_width": 150,
    "max_sprite_height": 170,
    "durations_ms": [220, 140, 220],
}
manifest_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")

builder = ROOT / "tools/build_project_original_playables.py"
replace_once(
    builder,
    '    portrait = dict(spec["portrait"])\n    portrait_frames = [_crop_box(keyed, box) for box in portrait["source_boxes"]]\n',
    '    portrait = dict(spec["portrait"])\n'
    '    portrait_source_path = _res_path_to_local(str(spec.get("portrait_source_sheet", spec["source_sheet"])))\n'
    '    if not portrait_source_path.is_file():\n'
    '        raise RuntimeError(f"{name}: missing portrait source {portrait_source_path.relative_to(ROOT)}")\n'
    '    portrait_actual_sha = _sha256(portrait_source_path)\n'
    '    portrait_expected_sha = str(spec.get("portrait_source_sha256", expected_sha))\n'
    '    if portrait_actual_sha != portrait_expected_sha:\n'
    '        raise RuntimeError(f"{name}: portrait source SHA-256 mismatch: {portrait_actual_sha} != {portrait_expected_sha}")\n'
    '    portrait_source = Image.open(portrait_source_path).convert("RGBA")\n'
    '    portrait_keyed = _key_background(portrait_source, list(spec["background_rgb"]))\n'
    '    portrait_frames = [_crop_box(portrait_keyed, box) for box in portrait["source_boxes"]]\n',
)
replace_once(
    builder,
    '        "source": Path(str(spec["source_sheet"])).name,\n        "source_path": "source/sheet.png",\n',
    '        "source": portrait_source_path.name,\n        "source_path": str(portrait_source_path.relative_to(directory)).replace("\\\\", "/"),\n',
)
replace_once(
    builder,
    '        "source_sha256": actual_sha,\n    }\n    (directory / "portrait_frames.json")',
    '        "source_sha256": portrait_actual_sha,\n    }\n    (directory / "portrait_frames.json")',
)

for relative in ["src/TurnOrderHUD.gd", "src/BattleHUD.gd"]:
    path = ROOT / relative
    replace_once(
        path,
        'const UI = preload("res://src/ui/TacticalTheme.gd")\n',
        'const UI = preload("res://src/ui/TacticalTheme.gd")\nconst PortraitResolver = preload("res://src/ui/DigimonPortraitResolver.gd")\n',
    )
    replace_once(
        path,
        '\tif digimon_key.is_empty():\n\t\treturn null\n\tvar metadata_path := "%s/%s/portrait_frames.json" % [PORTRAIT_ROOT, digimon_key]\n',
        '\tif digimon_key.is_empty():\n\t\treturn null\n\tvar resolved_key := PortraitResolver.resolve_key(digimon_key)\n\tif resolved_key.is_empty():\n\t\treturn null\n\tdigimon_key = resolved_key\n\tvar metadata_path := "%s/%s/portrait_frames.json" % [PORTRAIT_ROOT, digimon_key]\n',
    )

info = ROOT / "src/DigimonInfoPanel.gd"
replace_once(
    info,
    'const UI = preload("res://src/ui/TacticalTheme.gd")\n',
    'const UI = preload("res://src/ui/TacticalTheme.gd")\nconst PortraitResolver = preload("res://src/ui/DigimonPortraitResolver.gd")\n',
)
replace_once(
    info,
    '\tif digimon_key.is_empty():\n\t\treturn\n\tvar metadata_path: String = "%s/%s/portrait_frames.json" % [PORTRAIT_ROOT, digimon_key]\n',
    '\tif digimon_key.is_empty():\n\t\treturn\n\tvar resolved_key := PortraitResolver.resolve_key(digimon_key)\n\tif resolved_key.is_empty():\n\t\treturn\n\tdigimon_key = resolved_key\n\tvar metadata_path: String = "%s/%s/portrait_frames.json" % [PORTRAIT_ROOT, digimon_key]\n',
)

for relative in ["tools/test_early_rank_playables.gd", "tools/test_additional_ds_playables.gd"]:
    path = ROOT / relative
    replace_once(
        path,
        'const DirectionalContractScript = preload("res://src/sprites/DirectionalSpriteContract.gd")\n',
        'const DirectionalContractScript = preload("res://src/sprites/DirectionalSpriteContract.gd")\nconst PortraitResolver = preload("res://src/ui/DigimonPortraitResolver.gd")\n',
    )

replace_once(
    ROOT / "tools/test_early_rank_playables.gd",
    '\t\tassert(String(actor.get("digimon_key")) == species_name.to_lower(), "%s must keep its canonical battle key" % species_name)\n',
    '\t\tassert(String(actor.get("digimon_key")) == species_name.to_lower(), "%s must keep its canonical battle key" % species_name)\n\t\tassert(not PortraitResolver.resolve_key(species_name).is_empty(), "%s battle UI portrait must resolve from the canonical species name" % species_name)\n',
)
replace_once(
    ROOT / "tools/test_additional_ds_playables.gd",
    '\t\tvar portrait_key := _compact_key(species_name)\n',
    '\t\tassert(not PortraitResolver.resolve_key(species_name).is_empty(), "%s battle UI portrait must resolve from the canonical species name" % species_name)\n\t\tvar portrait_key := _compact_key(species_name)\n',
)

print("Grass Agumon visual fix sources and code patches applied")
