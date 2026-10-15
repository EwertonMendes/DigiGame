@tool
extends Node2D

const CityAtlas = preload("res://experiments/darkmoon_sandbox/CityAtlas.gd")
const TEMPLATE = preload("res://experiments/darkmoon_sandbox/palette.svg")


func _ready() -> void:
	if Engine.is_editor_hint():
		CityAtlas.preview_in_editor(self)


func _notification(what: int) -> void:
	if not Engine.is_editor_hint():
		return
	if what == NOTIFICATION_EDITOR_PRE_SAVE:
		# Never serialize the live private ImageTexture into a scene resource.
		CityAtlas.set_palette(self,TEMPLATE)
	elif what == NOTIFICATION_EDITOR_POST_SAVE:
		CityAtlas.preview_in_editor(self)
