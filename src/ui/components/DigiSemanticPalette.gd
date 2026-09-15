extends RefCounted
class_name DigiSemanticPalette

const V2 = preload("res://src/ui/components/DigiUiTheme.gd")


static func data_attribute_color(attribute: String) -> Color:
	match attribute.strip_edges().to_lower():
		"vaccine":
			return V2.BLUE
		"virus":
			return V2.RED
		"data":
			return V2.GREEN
		"free", "variable", "unknown":
			return V2.PURPLE
		_:
			return V2.CYAN


static func family_color(_family: String) -> Color:
	# Families/types are informational rather than advantage-state data, so they
	# intentionally use one stable neutral accent while Vaccine/Virus/Data keep
	# their own gameplay-significant colors.
	return V2.CYAN
