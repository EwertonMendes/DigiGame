extends RefCounted
class_name DigiLabPrimaryTabs


static func specs() -> Array[Dictionary]:
	return [
		{
			"id": "convert",
			"label": "Convert Digi Data",
			"compact_label": "Convert",
			"icon": "database",
			"enabled": true,
			"min_width": 176.0,
		},
		{
			"id": "party",
			"label": "Party / Storage",
			"compact_label": "Party",
			"icon": "party",
			"enabled": true,
			"min_width": 166.0,
		},
		{
			"id": "ascension",
			"label": "Ascension / Expansion",
			"compact_label": "Ascension",
			"icon": "evolution",
			"enabled": true,
			"min_width": 214.0,
		},
	]
