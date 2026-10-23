extends Node
## R6 desktop photoreal material bridge: uses real Poly Haven CC0 scanned maps.
## The Web build without downloaded assets retains the procedural R4/R5 fallback.
## Affects ONLY presentation; no save file, economy, vehicle physics or collisions.
const SCANNED_ROAD = preload("res://shaders/horizon_r6_scanned_asphalt.gdshader")
const ROOT = "res://assets/r6/polyhaven/"
var world
var previous
var car
var spray: GPUParticles3D
var hero: Node3D
var bundles: Dictionary = {}
var originals: Dictionary = {}
var enhanced_road: bool = false
var surface_count: int = 0
var photo_count: int = 0
var quality: String = "standard"
var weather: String = "clear"
var cinematic: bool = false

func _map(slug: String, kind: String) -> Texture2D:
	for extension in ["jpg","png"]:
		var resource: String = ROOT + slug + "/" + kind + "." + extension
		if ResourceLoader.exists(resource):
			return load(resource) as Texture2D
	return null

func _surface(slug: String, meters: float, normal_depth: float) -> StandardMaterial3D:
	var color: Texture2D = _map(slug,"diffuse")
	var bump: Texture2D = _map(slug,"nor_gl")
	var rough: Texture2D = _map(slug,"rough")
	if color == null or bump == null or rough == null:
		return null
	var material := StandardMaterial3D.new()
	material.resource_name = "CC0 Photo Surface " + slug
	material.albedo_color = Color.WHITE
	material.albedo_texture = color
	material.normal_enabled = true
	material.normal_texture = bump
	material.normal_scale = normal_depth
	material.roughness_texture = rough
	material.roughness = 1.0
	material.metallic = 0.0
	material.uv1_triplanar = true
	material.uv1_world_triplanar = true
	material.uv1_scale = Vector3.ONE * (1.0 / meters)
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return material

func bind_world(game_world, r5) -> void:
	world = game_world
	previous = r5
	var asphalt: StandardMaterial3D = _surface("asphalt_05",2.0,.62)
	var sidewalk: StandardMaterial3D = _surface("concrete_floor_02",2.1,.42)
	var facade: StandardMaterial3D = _surface("painted_plaster_wall",2.2,.35)
	if asphalt != null: bundles["asphalt"] = asphalt
	if sidewalk != null: bundles["sidewalk"] = sidewalk
	if facade != null: bundles["facade"] = facade
	photo_count = bundles.size()
	for holder in world.city_root.get_children():
		if not holder is Node3D:
			continue
		var candidate: MeshInstance3D = holder.get_node_or_null("VisualMesh") as MeshInstance3D
		if candidate == null:
			continue
		if holder.name == "Sidewalk" and sidewalk != null:
			originals[candidate] = candidate.material_override
			candidate.material_override = sidewalk
		elif holder.name in ["CivicStoneBand","CivicColumn","CivicCapital","CivicPortico","CivicPortal"] and facade != null:
			originals[candidate] = candidate.material_override
			candidate.material_override = facade
	surface_count = originals.size()
	set_profile("standard")

func _bind_photo_asphalt() -> void:
	enhanced_road = false
	if previous == null or previous.wet_surface == null:
		return
	if not bundles.has("asphalt") or quality == "low":
		previous.wet_surface.shader = preload("res://shaders/horizon_r5_asphalt.gdshader")
		return
	var photo: StandardMaterial3D = bundles["asphalt"]
	previous.wet_surface.shader = SCANNED_ROAD
	previous.wet_surface.set_shader_parameter("aggregate_albedo",photo.albedo_texture)
	previous.wet_surface.set_shader_parameter("aggregate_normal",photo.normal_texture)
	previous.wet_surface.set_shader_parameter("roughness_map",photo.roughness_texture)
	previous.wet_surface.set_shader_parameter("tile_meters",2.0)
	previous.wet_surface.set_shader_parameter("micro_strength",.46 if quality == "standard" else .78)
	enhanced_road = true

func set_profile(mode: String) -> void:
	quality = mode if mode in ["low","standard","cinematic"] else "standard"
	cinematic = quality == "cinematic"
	for node in originals.keys():
		if not is_instance_valid(node):
			continue
		if quality == "low":
			node.material_override = originals[node]
		elif node.get_parent().name == "Sidewalk" and bundles.has("sidewalk"):
			node.material_override = bundles["sidewalk"]
		elif bundles.has("facade"):
			node.material_override = bundles["facade"]
	_bind_photo_asphalt()
	if hero != null:
		hero.call("set_profile",quality)
	_apply_cinematic()
	_update_spray()

func set_weather(kind: String) -> void:
	weather = kind
	_apply_cinematic()
	_update_spray()

func _apply_cinematic() -> void:
	if world == null or world.sky_environment == null:
		return
	var env: Environment = world.sky_environment.environment
	var forward_plus: bool = RenderingServer.get_current_rendering_method() == "forward_plus"
	# Only true Forward+ supports SSR, SSIL and volumetric fog in Godot 4.4.
	var allow: bool = forward_plus and cinematic
	var rain: bool = weather == "rain" or weather == "storm"
	env.volumetric_fog_enabled = allow and rain
	env.volumetric_fog_density = .008 if rain else .003
	env.volumetric_fog_length = 78.0
	env.volumetric_fog_albedo = Color("86949a")
	env.ssao_enabled = allow
	env.ssil_enabled = allow
	env.ssr_enabled = allow and rain
	env.glow_enabled = allow
	env.glow_intensity = .19
	env.adjustment_enabled = quality != "low"
	env.adjustment_contrast = 1.04 if allow else 1.015
	env.adjustment_saturation = .94 if rain else .99

func bind_car(drivable) -> void:
	car = drivable
	if car == null or car.horizon_visual == null:
		return
	# Keep original garage paint: set_paint duplicates these same materials later.
	for mesh in car.horizon_visual.painted_parts:
		if mesh is MeshInstance3D and mesh.material_override is StandardMaterial3D:
			var coating: StandardMaterial3D = mesh.material_override as StandardMaterial3D
			coating.clearcoat_enabled = true
			coating.clearcoat = .78
			coating.clearcoat_roughness = .13
			coating.metallic = .69
			coating.roughness = .22
	var aerodynamic: MeshInstance3D = car.horizon_visual.get_node_or_null("AerodynamicGreenhouse") as MeshInstance3D
	if aerodynamic != null:
		var tint: StandardMaterial3D = aerodynamic.material_override as StandardMaterial3D
		if tint != null:
			tint.clearcoat_enabled = true
			tint.clearcoat = .38
			tint.clearcoat_roughness = .07
	# One GPU particle system for rain tire spray, no shadow casting or collision.
	spray = GPUParticles3D.new()
	spray.name = "R6WeatherTireSpray"
	spray.amount = 52
	spray.lifetime = .58
	spray.explosiveness = 0.0
	spray.position = Vector3(0.0,-.48,2.34)
	var spawn := ParticleProcessMaterial.new()
	spawn.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	spawn.emission_box_extents = Vector3(1.18,.09,.09)
	spawn.direction = Vector3(0,1,1)
	spawn.spread = 42.0
	spawn.initial_velocity_min = 1.9
	spawn.initial_velocity_max = 4.5
	spawn.gravity = Vector3(0,-3.8,0)
	spawn.scale_min = .06
	spawn.scale_max = .2
	spray.process_material = spawn
	var quad := QuadMesh.new()
	quad.size = Vector2(.19,.19)
	var vapor := StandardMaterial3D.new()
	vapor.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	vapor.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	vapor.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	vapor.albedo_color = Color(.80,.86,.88,.27)
	vapor.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	quad.material = vapor
	spray.draw_pass_1 = quad
	spray.emitting = false
	car.add_child(spray)
	_update_spray()
	# Optional high-detail imported CC0 GT replaces only the visible R4 mesh.
	hero = preload("res://scripts/horizon_hero_r6.gd").new()
	car.add_child(hero)
	hero.call("bind_car",car)
	hero.call("set_profile",quality)

func _update_spray() -> void:
	if spray == null or car == null:
		return
	spray.emitting = quality != "low" and car.driving and absf(car.speed)>5.0 and (weather == "rain" or weather == "storm")

func _process(_delta: float) -> void:
	if spray != null:
		_update_spray()

func diagnostic() -> Dictionary:
	return {"release":"R6","photo_asset_sets":photo_count,
		"photo_asphalt_active":enhanced_road,
		"photogrammetry_from_polyhaven":photo_count>0,
		"scanned_facade_and_sidewalk_meshes":surface_count,
		"quality":quality,"weather":weather,
		"spray_installed":spray != null,"hero_model":hero.call("diagnostic") if hero != null else {},"actual_target_gpu_fps":"NOT_MEASURED"}
