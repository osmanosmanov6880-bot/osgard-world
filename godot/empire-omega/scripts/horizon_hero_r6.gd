extends Node3D
## R6 optional higher-detail CC0 car visual only. Existing CharacterBody3D owns physics.
## Imported detailed 59+ object GLB has body, cockpit, brakes, tires and animations.
const PATH = "res://assets/r6/vehicles/spectral_gt_rs_game_ready.glb"
var car
var imported: Node3D
var enabled: bool = false
var profile: String = "standard"
var painted: Array[MeshInstance3D] = []
var rolling: Array[MeshInstance3D] = []
var legacy_meshes: Array[MeshInstance3D] = []
var previous_speed: float = 0.0
var imported_meshes: int = 0
var spinner_angle: float = 0.0
var target_paint: Color = Color("d45835")

func bind_car(vehicle) -> void:
	car = vehicle
	name = "R6HeroBody"
	if not ResourceLoader.exists(PATH):
		return
	var scene: PackedScene = load(PATH) as PackedScene
	if scene == null:
		return
	imported = scene.instantiate() as Node3D
	if imported == null:
		return
	imported.name = "SpectralGTHeroCC0"
	imported.rotation.y = PI * 0.5
	imported.position = Vector3(0,-.98,0)
	imported.scale = Vector3.ONE * 1.05
	add_child(imported)
	for candidate in imported.find_children("*","MeshInstance3D",true,false):
		var mesh: MeshInstance3D = candidate as MeshInstance3D
		if mesh == null:
			continue
		imported_meshes += 1
		var part_name: String = mesh.name.to_lower()
		if part_name.contains("tire") or part_name.contains("rim") or part_name.contains("spoke") or part_name.contains("hub"):
			if not part_name.contains("brake") and not part_name.contains("steering_wheel"):
				rolling.append(mesh)
		if mesh.mesh == null or mesh.mesh.get_surface_count() < 1:
			continue
		var finish: Material = mesh.mesh.surface_get_material(0)
		if finish != null and finish.resource_name.to_lower().contains("spectral blue"):
			painted.append(mesh)
		elif finish != null and finish.resource_name.to_lower().contains("shadow panels"):
			painted.append(mesh)
	for node in car.get_children():
		if node is MeshInstance3D and node.name in ["Headlight","Taillight"]:
			legacy_meshes.append(node)
	target_paint = car.horizon_visual.body_paint
	set_paint(target_paint)
	set_profile("standard")

func set_paint(color: Color) -> void:
	target_paint = color
	if imported == null:
		return
	for mesh in painted:
		if not is_instance_valid(mesh) or mesh.mesh == null:
			continue
		var base: StandardMaterial3D = mesh.mesh.surface_get_material(0) as StandardMaterial3D
		if base == null:
			continue
		var layer: StandardMaterial3D = base.duplicate() as StandardMaterial3D
		layer.albedo_color = color.darkened(.28) if base.resource_name.to_lower().contains("shadow panels") else color
		layer.metallic = .83
		layer.roughness = .20
		layer.clearcoat_enabled = true
		layer.clearcoat = .88
		layer.clearcoat_roughness = .105
		mesh.material_override = layer

func set_profile(mode: String) -> void:
	profile = mode
	# Strictly high-end hero when photogrammetry assets are present;
	# R4 original on Web and low/standard presets for frame-rate stability.
	enabled = imported != null and mode == "cinematic"
	if imported != null:
		imported.visible = enabled
	if car != null:
		if car.horizon_visual != null:
			car.horizon_visual.visible = not enabled
		for part in legacy_meshes:
			if is_instance_valid(part):
				part.visible = not enabled
	set_process(enabled)

func _process(delta: float) -> void:
	if car == null or not enabled:
		return
	var speed_mps: float = float(car.speed)
	var radians: float = speed_mps * delta / .42
	if absf(radians) > .00001:
		spinner_angle += radians
		for mesh in rolling:
			if is_instance_valid(mesh):
				# Original Blender axle axis is local Y, reoriented by GLB to -Z.
				mesh.rotate_object_local(Vector3.FORWARD,radians)

func diagnostic() -> Dictionary:
	return {"release":"R6","loaded":imported != null,"visible":enabled,
		"mesh_objects":imported_meshes,"rolling_wheel_pieces":rolling.size(),
		"repaintable_panels":painted.size(),"profile":profile,
		"source":"JaronKBragg7337 CC0 public domain"}
