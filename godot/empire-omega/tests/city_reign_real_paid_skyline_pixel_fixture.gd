extends Node3D
## TEST ONLY: actual original WorldBuilder, original physical 12 city plots,
## exact authoritative GameState.build("council") 230 treasury transaction.
## No standalone fake towers, no HTML renders, no published game entry changes.
const WORLD = preload("res://scripts/world_builder.gd")
var live_city: Node3D

func _ready() -> void:
	name = "CityReignActualPaidTwelveDistrictBuildings"
	GameState.data=GameState.new_game()
	GameState.data["day_clock"]=16.0
	live_city=WORLD.new()
	add_child(live_city)
	live_city.call("update_daynight",16.0)
	live_city.call("apply_visual_budget","cinematic")
	var camera := Camera3D.new()
	camera.name = "RealSourcePaidCouncilPlotRoadCamera"
	camera.position=Vector3(-177.8,10.9,-158.0)
	camera.fov=49.0
	camera.near=0.1
	camera.far=520.0
	add_child(camera)
	camera.look_at(Vector3(-182.0,8.5,-130.0),Vector3.UP)
	camera.current=true

func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var press: InputEventKey = event as InputEventKey
	if not press.pressed or press.echo or live_city==null:
		return
	match press.keycode:
		KEY_1:
			GameState.data=GameState.new_game()
			GameState.data["day_clock"]=16.0
			live_city.call("update_development")
			live_city.call("apply_visual_budget","cinematic")
		KEY_2:
			GameState.build("council")
			live_city.call("update_development")
		KEY_3: live_city.call("apply_visual_budget","low")
		KEY_4: live_city.call("apply_visual_budget","cinematic")
		_: return
	get_viewport().set_input_as_handled()
