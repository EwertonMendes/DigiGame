#!/usr/bin/env python3
"""One-shot source migration: move legacy static BattleHUD portrait to shared animated preview."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PATH = ROOT / "src/BattleHUD.gd"


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f"{label}: expected exactly one match, found {count}")
    return text.replace(old, new, 1)


def main() -> None:
    text = PATH.read_text(encoding="utf-8")
    text = replace_once(
        text,
        'const PortraitResolver = preload("res://src/ui/DigimonPortraitResolver.gd")',
        'const PortraitPreviewScript = preload("res://src/ui/DigimonPortraitPreview.gd")',
        "portrait preload",
    )
    text = replace_once(text, 'var _portrait: TextureRect = null', 'var _portrait: DigimonPortraitPreview = null', "portrait type")
    text = replace_once(
        text,
        '''\t_portrait = TextureRect.new()\n\t_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE\n\t_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED\n\t_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST\n\t_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE\n\t_portrait_frame.add_child(_portrait)''',
        '''\t_portrait = PortraitPreviewScript.new() as DigimonPortraitPreview\n\t_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE\n\t_portrait_frame.add_child(_portrait)''',
        "portrait construction",
    )
    text = replace_once(
        text,
        '\t\t_portrait.texture = _load_portrait(actor_key)',
        '\t\t_portrait.set_species(actor_key)',
        "actor portrait update",
    )
    old_loader = '''func _load_portrait(digimon_key: String) -> Texture2D:\n\tvar portrait_key := PortraitResolver.resolve_key(digimon_key)\n\tif portrait_key.is_empty():\n\t\treturn null\n\tvar metadata_path := PortraitResolver.metadata_path(portrait_key)\n\tvar strip_path := PortraitResolver.strip_path(portrait_key)\n\tif not FileAccess.file_exists(metadata_path) or not ResourceLoader.exists(strip_path):\n\t\treturn null\n\tvar metadata = JSON.parse_string(FileAccess.get_file_as_string(metadata_path))\n\tif not metadata is Dictionary:\n\t\treturn null\n\tvar strip := load(strip_path) as Texture2D\n\tif strip == null:\n\t\treturn null\n\tvar frame_width := float(metadata.get("frame_width", 0))\n\tvar frame_height := float(metadata.get("frame_height", 0))\n\tif frame_width <= 0.0 or frame_height <= 0.0:\n\t\treturn null\n\tvar atlas := AtlasTexture.new()\n\tatlas.atlas = strip\n\tatlas.region = Rect2(0.0, 0.0, frame_width, frame_height)\n\treturn atlas\n\n\n'''
    text = replace_once(text, old_loader, "", "legacy static portrait loader")
    PATH.write_text(text, encoding="utf-8")
    print("BattleHUD now uses the shared animated DigimonPortraitPreview")


if __name__ == "__main__":
    main()
