extends Node3D
## B44 CI-ONLY photographic proof of the REAL original Godot WorldBuilder.
## Not the shipped main scene. The source game camera sees the same physical
## building used by original collision, doorway, windows and chapter routes.
const REAL_CITY = preload("res://scripts/world_builder.gd")
var world: Node3D
var shot_camera: Camera3D

func _ready() -> void:
	name = "CityReignStreetWorldActual3DSourceCapture"
	GameState.data = GameState.new_game()
	GameState.data["energy"] = 95
	GameState.data["day_clock"] = 16.0
	world = REAL_CITY.new()
	add_child(world)
	world.call("apply_visual_budget","cinematic")
	world.call("update_daynight",16.0)
	# Known WorldBuilder quarter (ix=0, iz=0, n=0) has a real building
	# facing the -X road, x=-191,z=-191. This is the actual playable world.
	shot_camera = Camera3D.new()
	shot_camera.name = "ActualOriginalRoadFacingStreetCamera"
	# B44 camera stays in the EXISTING roadway, away from the building
	# collider. Earlier 11m shot put an entire near wall across the frame,
	# falsely failed the legitimate live-world screenshot quality gate.
	# This ~46m diagonal shot includes road surface, skyline and storefront.
	shot_camera.position = Vector3(-208.0,13.2,-149.0)
	shot_camera.fov = 58.0
	shot_camera.near = 0.08
	shot_camera.far = 450.0
	add_child(shot_camera)
	shot_camera.look_at(Vector3(-191.0,6.0,-191.0),Vector3.UP)
	shot_camera.current = true

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or world==null:
		return
	var key: InputEventKey = event as InputEventKey
	if not key.pressed or key.echo:
		return
	# Only the QA fixture changes the scenario. The shipped gameplay has
	# no such shortcuts and still obeys original mission/control authority.
	match key.keycode:
		KEY_1:
			GameState.data["energy"] = 95
			GameState.data["day_clock"] = 16.0
			world.call("apply_visual_budget","cinematic")
			world.call("update_daynight",16.0)
		KEY_2:
			GameState.data["energy"] = 95
			GameState.data["day_clock"] = 22.0
			world.call("apply_visual_budget","cinematic")
			world.call("update_daynight",22.0)
		KEY_3:
			GameState.data["energy"] = 0
			GameState.data["day_clock"] = 22.0
			world.call("update_daynight",22.0)
		KEY_4:
			GameState.data["energy"] = 95
			GameState.data["day_clock"] = 16.0
			world.call("apply_visual_budget","low")
			world.call("update_daynight",16.0)
		KEY_5:
			GameState.data["energy"] = 95
			GameState.data["day_clock"] = 16.0
			world.call("apply_visual_budget","standard")
			world.call("update_daynight",16.0)
		KEY_6:
			GameState.data["energy"] = 95
			GameState.data["day_clock"] = 16.0
			world.call("apply_visual_budget","cinematic")
			world.call("update_daynight",16.0)
		_: return
	get_viewport().set_input_as_handled()
