extends RefCounted
class_name DigiLabPrimaryTabs


static func specs() -> Array[Dictionary]:
	return [
		{
			"id": "convert",
			"label": "Convert Digi Data",
			"compact_label": "Digi Data",
			"force_label": true,
			"icon": "database",
			"enabled": true,
			"angled": true,
			"min_width": 202.0,
		},
		{
			"id": "party",
			"label": "Party / Storage",
			"compact_label": "Party",
			"force_label": true,
			"icon": "party",
			"enabled": true,
			"angled": true,
			"min_width": 194.0,
		},
		{
			"id": "ascension",
			"label": "Ascension / Expansion",
			"compact_label": "Ascension",
			"force_label": true,
			"icon": "evolution",
			"enabled": true,
			"angled": true,
			"min_width": 236.0,
		},
	]
