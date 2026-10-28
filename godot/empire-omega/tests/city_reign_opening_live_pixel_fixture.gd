extends Node3D
## TEST-ONLY source original Godot city, original two street proposal
## monuments, original municipal building/scaffold and REAL paid city turns.
## Never a detached HTML/PNG object, fake camera or invented source city.
const WORLD = preload("res://scripts/world_builder.gd")
const LANDMARKS = preload("res://scripts/project_landmarks.gd")
const PROPOSALS = preload("res://scripts/city_reign_promise_markers.gd")
const DIRECTOR = preload("res://scripts/city_reign_opening_director.gd")
var world: Node3D
var civic: Node3D
var proposal: Node3D
var director: Node3D

func _ready() -> void:
	name = "CityReignActualPromiseStreetChromiumSource"
	GameState.data=GameState.new_game()
	GameState.data["mission"]=4
	GameState.data["day_clock"]=16.0
	GameState.data["energy"]=95
	world=WORLD.new()
	add_child(world)
	world.call("update_daynight",16.0)
	world.call("apply_visual_budget","cinematic")
	civic=LANDMARKS.new()
	add_child(civic)
	proposal=PROPOSALS.new()
	add_child(proposal)
	director=DIRECTOR.new()
	add_child(director)
	_sync_civic()
	var camera:=Camera3D.new()
	camera.name="OriginalPrologueStreetEye"
	camera.position=Vector3(-150.0,10.8,-114.0)
	camera.fov=52.0
	camera.near=0.1
	camera.far=500.0
	add_child(camera)
	camera.look_at(Vector3(-164.0,5.8,-85.0),Vector3.UP)
	camera.current=true

func _sync_civic() -> void:
	civic.call("sync_projects",GameState.data.get("projects_done",[]),
		GameState.data.get("projects_active",{}))
	civic.call("update_language","en")
	proposal.call("sync_state",GameState.data,"en")
	director.call("sync_state",GameState.data,"en")
	director.call("set_quality","cinematic")
	director.call("set_view",Vector3(-164.0,1.0,-82.0),false,false)
	world.call("update_development")

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	var key: InputEventKey = event as InputEventKey
	if not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_1:
			GameState.data=GameState.new_game()
			GameState.data["mission"]=4
			GameState.data["day_clock"]=16.0
			_sync_civic()
		KEY_2:
			if GameState.start_initiative("open_records"):
				_sync_civic()
		KEY_3:
			if GameState.advance_turn():
				_sync_civic()
		KEY_4:
			if GameState.advance_turn():
				_sync_civic()
		KEY_5:
			director.call("set_quality","low")
		KEY_6:
			director.call("set_quality","cinematic")
		_: return
	get_viewport().set_input_as_handled()
