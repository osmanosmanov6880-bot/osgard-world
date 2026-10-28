extends Node3D
## TEST ONLY. Source-original real Godot 4.4.1 exported WebGL/Chromium
## traffic signal optics. The exact 16-junction game controller/LED meshes
## are used: this is not an HTML imitation, screenshot or marketing mockup.
const TRAFFIC = preload("res://scripts/traffic_signal_controller.gd")
var traffic: Node3D

func _ready() -> void:
	name = "CityReignActualSignalPixelScene"
	var environment := WorldEnvironment.new()
	var room := Environment.new()
	room.background_mode = Environment.BG_COLOR
	room.background_color = Color("0c1420")
	room.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	room.ambient_light_color = Color("bdcbd1")
	room.ambient_light_energy = 0.90
	environment.environment = room
	add_child(environment)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-45,30,0)
	key.light_energy = 1.30
	key.shadow_enabled = false
	add_child(key)
	var asphalt := MeshInstance3D.new()
	asphalt.name = "TestOnlyRoadBedNoPhysics"
	var floor := BoxMesh.new()
	floor.size = Vector3(36.0,0.14,36.0)
	asphalt.mesh = floor
	asphalt.position = Vector3(-156.0,-0.09,-156.0)
	var surf := StandardMaterial3D.new()
	surf.albedo_color = Color("252e38")
	surf.roughness = 0.72
	asphalt.material_override = surf
	add_child(asphalt)
	traffic = TRAFFIC.new()
	add_child(traffic)
	traffic.set_process(false)
	traffic.set("elapsed",0.0)
	traffic.call("_update_lights")
	traffic.call("set_quality","cinematic")
	var camera := Camera3D.new()
	camera.name = "RealSignalLensInspectionCamera"
	camera.position = Vector3(-156.8,5.45,-156.8)
	camera.fov = 33.0
	camera.far = 180
	camera.near = 0.1
	add_child(camera)
	camera.look_at(Vector3(-148.9,4.0,-148.9),Vector3.UP)
	camera.current = true

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo or traffic==null:
		return
	match key.keycode:
		KEY_1:
			traffic.set("elapsed",0.0)
			traffic.call("_update_lights")
		KEY_2:
			traffic.set("elapsed",12.2)
			traffic.call("_update_lights")
		KEY_3:
			traffic.set("elapsed",11.25)
			traffic.call("_update_lights")
		KEY_4: traffic.call("set_quality","low")
		KEY_5: traffic.call("set_quality","cinematic")
		_: return
	get_viewport().set_input_as_handled()
