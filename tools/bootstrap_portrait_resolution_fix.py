#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def replace_once(rel: str, old: str, new: str) -> None:
    path = ROOT / rel
    text = path.read_text(encoding="utf-8")
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f"{rel}: expected one patch anchor, found {count}: {old[:80]!r}")
    path.write_text(text.replace(old, new, 1), encoding="utf-8")


def write(rel: str, content: str) -> None:
    path = ROOT / rel
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")


RESOLVER = '''extends RefCounted
class_name DigimonPortraitResolver

const PORTRAIT_ROOT := "res://assets/characters"


static func resolve_key(species_or_key: String) -> String:
\tvar normalized := species_or_key.strip_edges().to_lower()
\tif normalized.is_empty():
\t\treturn ""
\tvar candidates: Array[String] = []
\tfor raw_candidate in [
\t\tnormalized,
\t\tnormalized.replace(" ", ""),
\t\tnormalized.replace(" ", "_"),
\t\tnormalized.replace("-", "").replace(" ", ""),
\t\tcompact_key(normalized),
\t]:
\t\tvar candidate := String(raw_candidate)
\t\tif not candidate.is_empty() and not candidates.has(candidate):
\t\t\tcandidates.append(candidate)
\tfor candidate: String in candidates:
\t\tif has_portrait(candidate):
\t\t\treturn candidate
\treturn ""


static func compact_key(value: String) -> String:
\tvar regex := RegEx.new()
\tif regex.compile("[^a-z0-9]+") != OK:
\t\treturn value.to_lower().replace(" ", "").replace("-", "")
\treturn regex.sub(value.to_lower(), "", true)


static func has_portrait(key: String) -> bool:
\tif key.is_empty():
\t\treturn false
\treturn FileAccess.file_exists(metadata_path(key)) and ResourceLoader.exists(strip_path(key))


static func metadata_path(key: String) -> String:
\treturn "%s/%s/portrait_frames.json" % [PORTRAIT_ROOT, key]


static func strip_path(key: String) -> String:
\treturn "%s/%s/portrait_frames.png" % [PORTRAIT_ROOT, key]
'''

write("src/ui/DigimonPortraitResolver.gd", RESOLVER)

replace_once(
    "src/ui/DigimonPortraitPreview.gd",
    'const PORTRAIT_ROOT := "res://assets/characters"\n',
    'const PortraitResolver = preload("res://src/ui/DigimonPortraitResolver.gd")\n',
)
replace_once(
    "src/ui/DigimonPortraitPreview.gd",
    '''\tvar key := _resolve_portrait_key(species_name)\n\tif key.is_empty():\n\t\treturn\n\tvar metadata_path := "%s/%s/portrait_frames.json" % [PORTRAIT_ROOT, key]\n\tvar strip_path := "%s/%s/portrait_frames.png" % [PORTRAIT_ROOT, key]\n''',
    '''\tvar key := PortraitResolver.resolve_key(species_name)\n\tif key.is_empty():\n\t\treturn\n\tvar metadata_path := PortraitResolver.metadata_path(key)\n\tvar strip_path := PortraitResolver.strip_path(key)\n''',
)
replace_once(
    "src/ui/DigimonPortraitPreview.gd",
    '''func _resolve_portrait_key(species_name: String) -> String:\n\tvar normalized := species_name.strip_edges().to_lower()\n\tif normalized.is_empty():\n\t\treturn ""\n\tvar candidates: Array[String] = []\n\tfor raw_candidate in [\n\t\tnormalized,\n\t\tnormalized.replace(" ", ""),\n\t\tnormalized.replace(" ", "_"),\n\t\tnormalized.replace("-", "").replace(" ", ""),\n\t\t_compact_portrait_key(normalized),\n\t]:\n\t\tvar candidate := String(raw_candidate)\n\t\tif not candidate.is_empty() and not candidates.has(candidate):\n\t\t\tcandidates.append(candidate)\n\tfor candidate: String in candidates:\n\t\tvar metadata_path := "%s/%s/portrait_frames.json" % [PORTRAIT_ROOT, candidate]\n\t\tvar strip_path := "%s/%s/portrait_frames.png" % [PORTRAIT_ROOT, candidate]\n\t\tif FileAccess.file_exists(metadata_path) and ResourceLoader.exists(strip_path):\n\t\t\treturn candidate\n\treturn ""\n\n\nfunc _compact_portrait_key(value: String) -> String:\n\tvar regex := RegEx.new()\n\tif regex.compile("[^a-z0-9]+") != OK:\n\t\treturn value.replace(" ", "").replace("-", "")\n\treturn regex.sub(value.to_lower(), "", true)\n\n\n''',
    "",
)

for rel in ("src/TurnOrderHUD.gd", "src/BattleHUD.gd"):
    replace_once(
        rel,
        'const PORTRAIT_ROOT := "res://assets/characters"\n',
        'const PortraitResolver = preload("res://src/ui/DigimonPortraitResolver.gd")\n',
    )
    replace_once(
        rel,
        '''func _load_portrait(digimon_key: String) -> Texture2D:\n\tif digimon_key.is_empty():\n\t\treturn null\n\tvar metadata_path := "%s/%s/portrait_frames.json" % [PORTRAIT_ROOT, digimon_key]\n\tvar strip_path := "%s/%s/portrait_frames.png" % [PORTRAIT_ROOT, digimon_key]\n''',
        '''func _load_portrait(digimon_key: String) -> Texture2D:\n\tvar portrait_key := PortraitResolver.resolve_key(digimon_key)\n\tif portrait_key.is_empty():\n\t\treturn null\n\tvar metadata_path := PortraitResolver.metadata_path(portrait_key)\n\tvar strip_path := PortraitResolver.strip_path(portrait_key)\n''',
    )

replace_once(
    "src/DigimonInfoPanel.gd",
    'const PORTRAIT_ROOT := "res://assets/characters"\n',
    'const PortraitResolver = preload("res://src/ui/DigimonPortraitResolver.gd")\n',
)
replace_once(
    "src/DigimonInfoPanel.gd",
    '''\tif digimon_key.is_empty():\n\t\treturn\n\tvar metadata_path: String = "%s/%s/portrait_frames.json" % [PORTRAIT_ROOT, digimon_key]\n\tvar strip_path: String = "%s/%s/portrait_frames.png" % [PORTRAIT_ROOT, digimon_key]\n''',
    '''\tvar portrait_key := PortraitResolver.resolve_key(digimon_key)\n\tif portrait_key.is_empty():\n\t\treturn\n\tvar metadata_path: String = PortraitResolver.metadata_path(portrait_key)\n\tvar strip_path: String = PortraitResolver.strip_path(portrait_key)\n''',
)

replace_once(
    "tools/test_early_rank_playables.gd",
    'const DirectionalContractScript = preload("res://src/sprites/DirectionalSpriteContract.gd")\n',
    'const DirectionalContractScript = preload("res://src/sprites/DirectionalSpriteContract.gd")\nconst PortraitResolverScript = preload("res://src/ui/DigimonPortraitResolver.gd")\n',
)
replace_once(
    "tools/test_early_rank_playables.gd",
    '''\t\tassert(String(row.get("visual_mode", "")) == "directional_12", "%s manifest must expose directional_12 visual mode" % species_name)\n\t\tassert(String(row.get("field_sprite", "")).ends_with("/field.png"), "%s manifest must link its DS field sprite" % species_name)\n\n\t\tvar actor := runtime.instantiate_player_digimon(species_name, 1, 100)\n''',
    '''\t\tassert(String(row.get("visual_mode", "")) == "directional_12", "%s manifest must expose directional_12 visual mode" % species_name)\n\t\tassert(String(row.get("field_sprite", "")).ends_with("/field.png"), "%s manifest must link its DS field sprite" % species_name)\n\n\t\tvar portrait_key := PortraitResolverScript.resolve_key(species_name)\n\t\tassert(not portrait_key.is_empty(), "%s portrait must resolve through the shared battle/detail resolver" % species_name)\n\t\tvar portrait_meta_path := PortraitResolverScript.metadata_path(portrait_key)\n\t\tassert(FileAccess.file_exists(portrait_meta_path), "%s portrait metadata must be packaged" % species_name)\n\t\tassert(ResourceLoader.exists(PortraitResolverScript.strip_path(portrait_key)), "%s portrait strip must be packaged" % species_name)\n\t\tif species_name == "Grass Agumon":\n\t\t\tassert(portrait_key == "grassagumon", "Grass Agumon spaced runtime key must resolve to compact portrait assets")\n\t\t\tvar portrait_metadata = JSON.parse_string(FileAccess.get_file_as_string(portrait_meta_path))\n\t\t\tassert(portrait_metadata is Dictionary, "Grass Agumon portrait metadata must be valid")\n\t\t\tvar portrait_data := portrait_metadata as Dictionary\n\t\t\tassert(int(portrait_data.get("frame_width", 0)) == 160 and int(portrait_data.get("frame_height", 0)) == 180, "Grass Agumon details must use profile frames rather than 48px walking frames")\n\t\t\tvar field_image := resource.texture.get_image()\n\t\t\tassert(field_image != null and field_image.get_width() > 0, "Grass Agumon field image must be readable")\n\t\t\tvar cell_width := field_image.get_width() / 12\n\t\t\tfor field_frame in range(12):\n\t\t\t\tvar left := field_frame * cell_width\n\t\t\t\tvar right := left + cell_width - 1\n\t\t\t\tassert(field_image.get_pixel(left, 0).a < 0.01 and field_image.get_pixel(right, 0).a < 0.01, "Grass Agumon field frame %d must have a transparent background" % field_frame)\n\n\t\tvar actor := runtime.instantiate_player_digimon(species_name, 1, 100)\n''',
)

replace_once(
    "tools/test_additional_ds_playables.gd",
    'const DirectionalContractScript = preload("res://src/sprites/DirectionalSpriteContract.gd")\n',
    'const DirectionalContractScript = preload("res://src/sprites/DirectionalSpriteContract.gd")\nconst PortraitResolverScript = preload("res://src/ui/DigimonPortraitResolver.gd")\n',
)
replace_once(
    "tools/test_additional_ds_playables.gd",
    '''\t\tvar portrait_key := _compact_key(species_name)\n\t\tassert(FileAccess.file_exists("res://assets/characters/%s/portrait_frames.json" % portrait_key), "%s portrait metadata must be packaged for detail menus" % species_name)\n\t\tassert(ResourceLoader.exists("res://assets/characters/%s/portrait_frames.png" % portrait_key), "%s portrait strip must be packaged for detail menus" % species_name)\n''',
    '''\t\tvar portrait_key := PortraitResolverScript.resolve_key(species_name)\n\t\tassert(not portrait_key.is_empty(), "%s spaced/canonical name must resolve through the shared portrait resolver" % species_name)\n\t\tassert(FileAccess.file_exists(PortraitResolverScript.metadata_path(portrait_key)), "%s portrait metadata must be packaged for detail menus" % species_name)\n\t\tassert(ResourceLoader.exists(PortraitResolverScript.strip_path(portrait_key)), "%s portrait strip must be packaged for detail menus" % species_name)\n''',
)
replace_once(
    "tools/test_additional_ds_playables.gd",
    '''\n\nfunc _compact_key(value: String) -> String:\n\tvar regex := RegEx.new()\n\tassert(regex.compile("[^a-z0-9]+") == OK)\n\treturn regex.sub(value.to_lower(), "", true)\n''',
    "",
)

print("patched shared Digimon portrait resolution and regression coverage")
