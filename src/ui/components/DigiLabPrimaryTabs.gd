extends RefCounted
class_name DigiLabPrimaryTabs


static func specs() -> Array[Dictionary]:
	return [
		{
			"id": "convert",
			"label": "Convert Digi Data",
			"compact_label": "Digi Data",
			"icon": "database",
			"enabled": true,
			"angled": true,
			"min_width": 202.0,
		},
		{
			"id": "party",
			"label": "Party / Storage",
			"compact_label": "Party",
			"icon": "party",
			"enabled": true,
			"angled": true,
			"min_width": 194.0,
		},
		{
			"id": "fusion",
			"label": "Fusion",
			"compact_label": "Fusion",
			"icon": "evolution",
			"enabled": true,
			"angled": true,
			"min_width": 148.0,
		},
		{
			"id": "ascension",
			"label": "Ascension / Expansion",
			"compact_label": "Ascension",
			"icon": "evolution",
			"enabled": true,
			"angled": true,
			"min_width": 236.0,
		},
	]
