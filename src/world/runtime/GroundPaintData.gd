extends RefCounted
class_name GroundPaintData

# Legacy cells contain a material name. Colored cells keep that same material
# and an optional opaque base color, serialized as numbers for scene/bake data.
static func surface(value: Variant) -> String:
	return String(value.get("surface", "")) if value is Dictionary else String(value)


static func has_color(value: Variant) -> bool:
	return value is Dictionary and value.get("color") is Array and (value.get("color") as Array).size() == 3


static func color(value: Variant) -> Color:
	var components: Array = value.get("color", [1.0, 1.0, 1.0]) if value is Dictionary else [1.0, 1.0, 1.0]
	return Color(float(components[0]), float(components[1]), float(components[2]), 1.0)


static func entry(material: String, base_color: Color) -> Dictionary:
	return {"surface": material, "color": [base_color.r, base_color.g, base_color.b]}
