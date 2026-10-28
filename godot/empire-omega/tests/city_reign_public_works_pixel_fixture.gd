extends Node3D
## CITY REIGN B61: private CI-only camera for original saved civic choice.
## Each switch performs a GENUINE GameState.start_initiative() and 2 genuine
## city turns. This is neither the shipped main scene nor a pre-rendered image.
const REAL_WORLD = preload("res://scripts/world_builder.gd")
var world: Node3D
var shot: Camera3D
var selected: String = "safe_crossings"

func _ready() -> void:
	name = "CityReignSourceNativePaidCityBeforeAfterWorld"
	GameState.data = GameState.new_game()
	GameState.data["day_clock"] = 16.0
	GameState.data["energy"] = 93
	world = REAL_WORLD.new()
	add_child(world)
	world.call("apply_visual_budget","cinematic")
	world.call("update_daynight",16.0)
	shot = Camera3D.new()
	shot.name = "ActualSourcePlayRouteCrosswalkCamera"
	shot.fov = 64.0
	shot.near = 0.08
	shot.far = 390.0
	add_child(shot)
	show_crossings()
	shot.current = true

func show_crossings() -> void:
	selected = "safe_crossings"
	# ORIGINAL x=104 road artery, outside real tower colliders.
	shot.position = Vector3(104.0,8.5,-150.0)
	shot.look_at(Vector3(104.0,0.0,-102.0),Vector3.UP)

func show_budget() -> void:
	selected = "open_records"
	# Original road at x=-156; safe camera 23m south of the earned pavilion.
	shot.position = Vector3(-156.0,7.2,-117.0)
	shot.look_at(Vector3(-164.0,2.1,-94.0),Vector3.UP)

func _actual_build(id: String) -> void:
	if not ["safe_crossings","open_records"].has(id):
		return
	GameState.data = GameState.new_game()
	if not GameState.start_initiative(id):
		push_error("Real original civic payment was rejected: "+id)
		return
	for i in range(2):
		if not GameState.advance_turn():
			push_error("Real city turn was rejected: "+str(i))
			return
	if not GameState.data["projects_done"].has(id):
		push_error("Original city did not complete real construction: "+id)
		return
	world.call("update_development")
	world.call("update_language","en")
	world.call("apply_visual_budget","cinematic")
	world.call("update_daynight",16.0)

func _reset_real_game() -> void:
	GameState.data = GameState.new_game()
	world.call("update_development")
	world.call("update_language","en")
	world.call("apply_visual_budget","cinematic")
	world.call("update_daynight",16.0)

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	var key: InputEventKey = event
	if not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_1:
			_reset_real_game()
		KEY_2:
			_actual_build("safe_crossings")
		KEY_3:
			_actual_build("open_records")
		KEY_4:
			GameState.data["energy"] = 93
			GameState.data["day_clock"] = 22.0
			world.call("update_daynight",22.0)
		KEY_5:
			GameState.data["energy"] = 0
			GameState.data["day_clock"] = 22.0
			world.call("update_daynight",22.0)
		KEY_6:
			world.call("apply_visual_budget","low")
		KEY_7:
			show_crossings()
		KEY_8:
			show_budget()
		KEY_9:
			world.call("apply_visual_budget","cinematic")
		_:
			return
	get_viewport().set_input_as_handled()
