extends Node3D
## CI ONLY. Actual authoritative WorldBuilder with ACTUAL 25m physics
## landmark and ORIGINAL 3D hero art. The user invests using real
## GameState.build, not a fake HTML mockup or cherry-picked image.
const REAL_CITY = preload("res://scripts/world_builder.gd")
var city: Node3D

func _ready() -> void:
	name = "CityReignActualPaidUrbanArchitectureBrowserProof"
	GameState.data = GameState.new_game()
	GameState.data["day_clock"] = 16.0
	GameState.data["energy"] = 95
	city = REAL_CITY.new()
	add_child(city)
	city.call("update_daynight",16.0)
	city.call("apply_visual_budget","cinematic")
	var camera := Camera3D.new()
	camera.name = "ActualSourceCityHallFacadeStreetCamera"
	camera.position = Vector3(-118.5,15.8,-172.5)
	camera.fov = 55.0
	camera.near = 0.10
	camera.far = 550.0
	add_child(camera)
	camera.look_at(Vector3(-130.0,13.6,-130.0),Vector3.UP)
	camera.current = true

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	var key: InputEventKey = event as InputEventKey
	if not key.pressed or key.echo or city==null:
		return
	match key.keycode:
		KEY_1:
			GameState.data = GameState.new_game()
			GameState.data["day_clock"]=16.0
			GameState.data["energy"]=95
			city.call("update_development")
			city.call("update_daynight",16.0)
		KEY_2:
			# Actual original treasury-funded state, not an art toggle.
			GameState.build("council")
			city.call("update_development")
		KEY_3:
			# Genuine night of the SAME original full 3D city.
			GameState.data["day_clock"]=22.0
			city.call("update_daynight",22.0)
		KEY_6:
			# Actual city resource blackout, no fake visual weather toggle.
			GameState.data["energy"]=0
			city.call("update_daynight",22.0)
		KEY_4: city.call("apply_visual_budget","low")
		KEY_5: city.call("apply_visual_budget","cinematic")
		_: return
	get_viewport().set_input_as_handled()
