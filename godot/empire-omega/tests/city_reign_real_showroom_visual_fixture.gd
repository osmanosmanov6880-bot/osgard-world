extends Control
## Test-only real Godot 4.4.1 WebGL entry scene. This source fixture is
## never selected in the shipped project's project.godot. The vehicle
## model/lighting source is exactly the main game's actual 3D showroom.
const SHOWROOM = preload("res://scripts/city_reign_hero_showroom.gd")
var panel: VBoxContainer

func _ready() -> void:
	var backdrop := ColorRect.new()
	backdrop.name = "TestOnlyOriginalViewportBackdrop"
	backdrop.color = Color("09121a")
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	panel = SHOWROOM.new()
	panel.name = "CinematicSourceShowroom"
	panel.position = Vector2(52,44)
	panel.size = Vector2(690,530)
	panel.custom_minimum_size = Vector2(690,530)
	add_child(panel)
	panel.call("build","en",false,true,"compact")
	var info := Label.new()
	info.text = "SOURCE-ONLY 3D QA  |  1-4: MODEL  ·  Q/E: ROTATE"
	info.position = Vector2(804,92)
	info.add_theme_font_size_override("font_size",17)
	info.add_theme_color_override("font_color",Color("d9bb83"))
	add_child(info)
	var provenance := Label.new()
	provenance.text = "CITY REIGN  |  REAL GODOT WEBGL TEST FIXTURE"
	provenance.position = Vector2(804,132)
	provenance.add_theme_font_size_override("font_size",13)
	provenance.add_theme_color_override("font_color",Color("bcc9d1"))
	add_child(provenance)

func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var pressed_key := event as InputEventKey
	if not pressed_key.pressed or pressed_key.echo or panel==null:
		return
	match pressed_key.keycode:
		KEY_1: panel.call("preview_vehicle","compact")
		KEY_2: panel.call("preview_vehicle","courier")
		KEY_3: panel.call("preview_vehicle","executive")
		KEY_4: panel.call("preview_vehicle","utility")
		KEY_Q: panel.call("rotate_model",-1)
		KEY_E: panel.call("rotate_model",1)
		KEY_L: panel.call("toggle_lighting")
		_: return
	get_viewport().set_input_as_handled()
