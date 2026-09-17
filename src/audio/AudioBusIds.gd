extends RefCounted
class_name AudioBusIds

## Canonical semantic audio bus names used by playback systems and settings.
## Keep routing identifiers here so gameplay code never relies on string literals.

const MASTER: StringName = &"Master"
const MUSIC: StringName = &"Music"
const SFX: StringName = &"SFX"
const BATTLE: StringName = &"Battle"
const UI: StringName = &"UI"

const SETTING_MASTER := "master"
const SETTING_MUSIC := "music"
const SETTING_SFX := "sfx"
const SETTING_BATTLE := "battle"
const SETTING_UI := "ui"

const VOLUME_SETTING_KEYS: Array[String] = [
	SETTING_MASTER,
	SETTING_MUSIC,
	SETTING_SFX,
	SETTING_BATTLE,
	SETTING_UI,
]


static func bus_for_setting(setting_key: String) -> StringName:
	match setting_key:
		SETTING_MUSIC:
			return MUSIC
		SETTING_SFX:
			return SFX
		SETTING_BATTLE:
			return BATTLE
		SETTING_UI:
			return UI
		_:
			return MASTER
