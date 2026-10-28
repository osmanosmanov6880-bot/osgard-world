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
	# WorldBuilder original quarter ix=0 / iz=2 (centre -182,-78),
	# n=0 is the actual physically colliding building at (-191,-87).
	# The urban skyline occupies a RING beginning around radius 248m;
	# earlier test cameras at radius 256-279 were INSIDE that skyscraper
	# geometry. Do not mistake an interior wall for a WebGL loading screen.
	shot_camera = Camera3D.new()
	shot_camera.name = "ActualOriginalPlayableRoadCornerCamera"
	shot_camera.position = Vector3(-156.0,13.0,-104.0)
	shot_camera.fov = 62.0
	shot_camera.near = 0.08
	shot_camera.far = 450.0
	add_child(shot_camera)
	shot_camera.look_at(Vector3(-191.0,5.0,-87.0),Vector3.UP)
	assert(Vector2(shot_camera.position.x,shot_camera.position.z).length() < 220.0,
		"WebGL visual-camera anchor must stay inside playable city, outside outer tower ring")
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
		KEY_7:
			# Actual street-level, source-native storefront at WorldBuilder
			# quarter ix=2, iz=2, building n=0 (centre -87,-87).
			# Its real road-facing entrance is the -X face, so the original
			# camera stays WEST of the facade to see correct plinth/doors/plants.
			# Safe radius ~150m avoids the entire 248m outer skyscraper ring.
			GameState.data["energy"] = 95
			GameState.data["day_clock"] = 16.0
			world.call("apply_visual_budget","cinematic")
			world.call("update_daynight",16.0)
			shot_camera.position = Vector3(-108.0,3.35,-104.0)
			shot_camera.look_at(Vector3(-87.0,2.78,-87.0),Vector3.UP)
			assert(Vector2(shot_camera.position.x,shot_camera.position.z).length() < 220.0,
				"Street-level actual 3D camera must stay clear of remote tower ring")
		KEY_8:
			# Return from detail review to the original valid road overview.
			shot_camera.position = Vector3(-156.0,13.0,-104.0)
			shot_camera.look_at(Vector3(-191.0,5.0,-87.0),Vector3.UP)
		_: return
	get_viewport().set_input_as_handled()
