from pathlib import Path
import re

lab_path = Path("src/ui/DigimonSpriteTestLab.gd")
text = lab_path.read_text(encoding="utf-8")

if 'const RESOURCE_ROOT := "res://assets/resources"' not in text:
    text = text.replace(
        'const INSPECT_SCALES: Array[float] = [1.0, 1.5, 2.0]\n',
        'const INSPECT_SCALES: Array[float] = [1.0, 1.5, 2.0]\n'
        'const RESOURCE_ROOT := "res://assets/resources"\n'
        'const RESOURCE_FALLBACKS: Array[String] = [\n'
        '\t"agumon.tres",\n'
        '\t"gabumon.tres",\n'
        '\t"greymon.tres",\n'
        '\t"koromon.tres",\n'
        '\t"metal greymon.tres",\n'
        '\t"tanemon.tres",\n'
        '\t"veemon.tres",\n'
        ']\n'
    )

replacements = {
    '"Temporary tool · production movement, animation, facing and transparency"': '"Temporary tool - production movement, animation, facing and transparency"',
    '"◀ PREV"': '"PREV"',
    '"NEXT ▶"': '"NEXT"',
    '"INSPECT 1.0×"': '"INSPECT 1.0x"',
    '"MOVE · HOLD"': '"MOVE - HOLD"',
    '"↖ UP LEFT"': '"UP LEFT"',
    '"UP RIGHT ↗"': '"UP RIGHT"',
    '"↙ DOWN LEFT"': '"DOWN LEFT"',
    '"DOWN RIGHT ↘"': '"DOWN RIGHT"',
    '"FACE · CLICK"': '"FACE - CLICK"',
    '"INSPECT %.1f×"': '"INSPECT %.1fx"',
    '"Facing: %s\\nLayout: %s · %dx%d\\nRuntime sprite scale: 1.5×\\nInspection multiplier: %.1f×"': '"Facing: %s\\nLayout: %s - %dx%d\\nRuntime sprite scale: 1.5x\\nInspection multiplier: %.1fx"',
    '\t_field_dark.z_index = -10\n': '\t_field_dark.z_index = 0\n',
    '\t_field_light.z_index = -10\n': '\t_field_light.z_index = 0\n',
}
for old, new in replacements.items():
    if old in text:
        text = text.replace(old, new)

new_loader = """func _load_entries() -> void:
\t_entries.clear()
\t_picker.clear()

\t# ResourceLoader.list_directory() is export-aware. DirAccess can expose only
\t# imported/remapped files inside Web PCKs, which made the lab empty in the
\t# playable PR preview even though the .tres resources were packaged.
\tvar filenames: Array[String] = []
\tfor raw_filename in ResourceLoader.list_directory(RESOURCE_ROOT):
\t\tfilenames.append(String(raw_filename))
\tif filenames.is_empty():
\t\t# Keep the current test roster usable even on platforms that cannot list
\t\t# the resource directory. Normal builds still auto-discover new .tres files.
\t\tfor fallback in RESOURCE_FALLBACKS:
\t\t\tfilenames.append(fallback)

\tfor filename in filenames:
\t\tif not filename.ends_with(".tres"):
\t\t\tcontinue
\t\tvar path := "%s/%s" % [RESOURCE_ROOT, filename]
\t\tif not ResourceLoader.exists(path):
\t\t\tcontinue
\t\tvar resource := ResourceLoader.load(path) as Digimon
\t\tif resource == null or resource.texture == null:
\t\t\tcontinue
\t\tvar key := filename.get_basename().to_lower().replace(" ", "")
\t\tvar display := resource.display_name.strip_edges()
\t\tif display.is_empty():
\t\t\tdisplay = key.capitalize()
\t\t_entries.append({"key": key, "name": display, "path": path})

\t_entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
\t\treturn String(a.get("name", "")) < String(b.get("name", ""))
\t)
\tvar metal := -1
\tfor i in range(_entries.size()):
\t\t_picker.add_item(String(_entries[i].get("name", "")))
\t\tif String(_entries[i].get("name", "")).to_lower() == "metal greymon":
\t\t\tmetal = i
\tif _entries.is_empty():
\t\t_name_label.text = "NO SPRITES FOUND"
\t\t_state_label.text = "No packaged Digimon field resources were discovered."
\t\treturn
\t_index = metal if metal >= 0 else 0
\t_picker.select(_index)


func get_testable_species_count() -> int:
\treturn _entries.size()


func get_testable_species_names() -> Array[String]:
\tvar names: Array[String] = []
\tfor entry in _entries:
\t\tnames.append(String(entry.get("name", "")))
\treturn names


"""

pattern = r'func _load_entries\(\) -> void:\n.*?(?=func _spawn_selected\(\) -> void:)'
text, count = re.subn(pattern, new_loader, text, flags=re.S)
if count != 1:
    raise SystemExit(f"expected one _load_entries block, replaced {count}")
lab_path.write_text(text, encoding="utf-8")

test_path = Path("tools/test_hub_foundation.gd")
test = test_path.read_text(encoding="utf-8")
anchor = '\tassert(party_followers != null, "Hub must create the overworld active-party follower system")\n'
addition = """\tvar sprite_debug := hub.get_node_or_null("SpriteTestDebug")
\tassert(sprite_debug != null, "Hub must create the temporary sprite-test controller")
\tvar sprite_lab := sprite_debug.get_node_or_null("SpriteTestDebugUI/DigimonSpriteTestLab")
\tassert(sprite_lab != null, "Sprite-test controller must create the lab UI")
\tassert(int(sprite_lab.call("get_testable_species_count")) >= 7, "Sprite test lab must discover packaged Digimon resources")
\tassert(Array(sprite_lab.call("get_testable_species_names")).has("Metal Greymon"), "Sprite test lab must include Metal Greymon")
\tsprite_lab.call("open_lab")
\tawait get_tree().process_frame
\tawait get_tree().process_frame
\tvar sprite_test_follower := sprite_lab.get("_follower") as Node2D
\tassert(sprite_test_follower != null, "Sprite test lab must spawn the selected Digimon")
\tvar sprite_test_visual := sprite_test_follower.get_node_or_null("Sprite2D") as Sprite2D
\tassert(sprite_test_visual != null and sprite_test_visual.texture != null, "Sprite test lab must render the selected field texture")
\tsprite_lab.call("close_lab")
"""
if addition not in test:
    if anchor not in test:
        raise SystemExit("hub test anchor not found")
    test = test.replace(anchor, anchor + addition)
test_path.write_text(test, encoding="utf-8")
