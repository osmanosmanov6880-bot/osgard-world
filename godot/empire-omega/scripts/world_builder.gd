extends Node3D
## Deterministic, art-free 3D city generator. Replace block meshes with licensed assets later.

signal location_entered(location_id: String)

const CITY_HALF = 224.0
const ROAD_INTERVAL = 52.0
const DISTRICT_NAMES = {"forum":"Сенатский форум", "housing":"Жилой квартал", "lower":"Нижний город", "aqueduct":"Акведуки"}
const DISTRICT_COLORS = {
	"forum":Color(0.38,0.40,0.43),
	"housing":Color(0.38,0.45,0.44),
	"lower":Color(0.45,0.42,0.39),
	"aqueduct":Color(0.39,0.45,0.49)
}
const LOCATION_DATA = {
	"cityhall":{"name":"Дворец правителя","position":Vector3(-130,0,-130),"district":"forum"},
	"market":{"name":"Торговая галерея","position":Vector3(130,0,-130),"district":"housing"},
	"depot":{"name":"Логистический терминал","position":Vector3(-130,0,130),"district":"lower"},
	"power":{"name":"Энергетическая станция","position":Vector3(130,0,130),"district":"aqueduct"}
}

var locations := {}
var markers := {}
var project_visuals := {}
var property_markers := {}
var weather_particles: GPUParticles3D
var weather_mode := "clear"
var visual_budget := "standard"
var rng := RandomNumberGenerator.new()
var ambience_time := 10.0
var daylight_brightness := 1.0
var sun: DirectionalLight3D
var sky_environment: WorldEnvironment
var city_root: Node3D
var building_count := 0
var building_chunks := {}
var active_chunk_count := 0
var window_points: Array[Transform3D] = []
var facade_windows: MultiMeshInstance3D
var facade_frames: MultiMeshInstance3D
var architecture_trim: MultiMeshInstance3D
var streetfront: Node3D
var facade_balconies: Node3D
var road_paint: Node3D
var road_puddles: MultiMeshInstance3D
var cityhall_gateway: Node3D
var last_window_mode := -1
var waypoint_marker: Node3D
var horizon_scenic: Node3D
var r90_urban: Node3D
var streetlight_focus: Vector3 = Vector3.ZERO
const ROAD_MATERIALS = preload("res://scripts/horizon_road_materials.gd")
const LIGHT_GRADE = preload("res://scripts/horizon_light_grade.gd")
const FACADE_MATERIALS = preload("res://scripts/horizon_facade_materials.gd")
const R37_MATERIAL_PACK = preload("res://scripts/horizon_facade_material_pack.gd")
const ARCHITECTURE_TRIM = preload("res://scripts/horizon_architecture_trim.gd")
const STREETFRONT_SCENE = preload("res://scripts/horizon_streetfront_details.gd")
const BALCONIES_SCENE = preload("res://scripts/horizon_facade_balconies.gd")
const CIVIC_GATEWAY = preload("res://scripts/horizon_civic_gateway.gd")
const ROAD_PAINT_SCENE = preload("res://scripts/horizon_road_paint_batches.gd")
const ROAD_PUDDLES = preload("res://scripts/horizon_rain_puddles.gd")
const R90_URBAN = preload("res://scripts/horizon_r90_street_dressing.gd")
var asphalt_pbr: StandardMaterial3D
var concrete_pbr: StandardMaterial3D
var r90_original_asphalt_albedo: Texture2D
var r90_original_asphalt_normal: Texture2D

func _ready() -> void:
	rng.seed = 428753
	asphalt_pbr = ROAD_MATERIALS.asphalt()
	concrete_pbr = ROAD_MATERIALS.concrete()
	# R90 approved urban palette: real PBR tint, not a photograph or
	# screen-space color overlay. All road wheel collision remains unchanged.
	asphalt_pbr.albedo_color = Color("a2a8ad")
	concrete_pbr.albedo_color = Color("bcb8b0")
	r90_original_asphalt_albedo = asphalt_pbr.albedo_texture
	r90_original_asphalt_normal = asphalt_pbr.normal_texture
	city_root = Node3D.new()
	city_root.name = "ProceduralDistricts"
	add_child(city_root)
	_create_environment()
	_create_terrain()
	road_paint = ROAD_PAINT_SCENE.new()
	_create_roads()
	road_paint.call("record_road_edges")
	road_paint.call("finish")
	city_root.add_child(road_paint)
	road_puddles = ROAD_PUDDLES.new()
	city_root.add_child(road_puddles)
	architecture_trim = ARCHITECTURE_TRIM.new()
	streetfront = STREETFRONT_SCENE.new()
	facade_balconies = BALCONIES_SCENE.new()
	_create_city()
	architecture_trim.call("finalize")
	city_root.add_child(architecture_trim)
	streetfront.call("finalize")
	city_root.add_child(streetfront)
	facade_balconies.call("finalize")
	city_root.add_child(facade_balconies)
	_create_window_batch()
	_create_landmarks()
	_create_waypoint_marker()
	_create_project_visuals()
	_create_property_markers()
	_create_weather_particles()
	# Original individual 85 cuboid TreeCrown/TreeTrunk decorations removed.
	# The 192 GPU-instanced R26 trees already provide real leaf and pine meshes.
	# GPU-instanced scenic art has no colliders and preserves all traffic/missions.
	horizon_scenic = preload("res://scripts/horizon_roadscape.gd").new()
	add_child(horizon_scenic)
	r90_urban = R90_URBAN.new()
	city_root.add_child(r90_urban)
	update_development()

func _material(color: Color, metallic: float = 0.0, roughness: float = 0.8, glow: bool = false) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = metallic
	mat.roughness = roughness
	if glow:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 1.8
	return mat

func _box(parent: Node3D, label: String, size: Vector3, position: Vector3, color: Color, solid: bool = false, glow: bool = false) -> Node3D:
	var holder: Node3D
	if solid:
		var static_body := StaticBody3D.new()
		var collision := CollisionShape3D.new()
		collision.name = 'CollisionShape3D'
		var shape := BoxShape3D.new()
		shape.size = size
		collision.shape = shape
		static_body.add_child(collision)
		holder = static_body
	else:
		holder = Node3D.new()
	holder.name = label
	holder.position = position
	parent.add_child(holder)
	var geometry := MeshInstance3D.new()
	geometry.name = "VisualMesh"
	var mesh := BoxMesh.new()
	mesh.size = size
	geometry.mesh = mesh
	if label == "EastWestRoad" or label == "NorthSouthRoad":
		geometry.material_override = asphalt_pbr
	elif label == "Sidewalk":
		geometry.material_override = concrete_pbr
	elif label.begins_with("Building_"):
		geometry.material_override = R37_MATERIAL_PACK.facade(color,int(label.trim_prefix("Building_")))
	else:
		geometry.material_override = _material(color, 0.12, 0.62, glow)
	holder.add_child(geometry)
	return holder

func _create_environment() -> void:
	sky_environment = WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var proc_sky := ProceduralSkyMaterial.new()
	proc_sky.sky_top_color = Color("638db2")
	proc_sky.sky_horizon_color = Color("e0b18f")
	proc_sky.ground_bottom_color = Color("354855")
	proc_sky.ground_horizon_color = Color("8396a1")
	sky.sky_material = proc_sky
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 1.0
	env.reflected_light_source = Environment.REFLECTION_SOURCE_BG
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	sky_environment.environment = env
	add_child(sky_environment)
	sun = DirectionalLight3D.new()
	sun.light_color = Color("ffe2b1")
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	sun.rotation_degrees = Vector3(-52,-35,0)
	add_child(sun)
	_apply_lighting()

func _create_terrain() -> void:
	_box(city_root,"Foundation",Vector3(460,1,460),Vector3(0,-0.6,0),Color("142b29"),true)
	for dx in [-1,1]:
		for dz in [-1,1]:
			var id := district_id(Vector3(dx,0,dz))
			var color: Color = DISTRICT_COLORS[id].darkened(0.43)
			_box(city_root,id + "_ground",Vector3(224,0.12,224),Vector3(dx*112,-0.035,dz*112),color)
	_box(city_root,"River",Vector3(460,0.1,22),Vector3(0,0.075,0),Color("153e4c"))
	for x in [-208,-156,-104,-52,0,52,104,156,208]:
		_box(city_root,"Bridge",Vector3(10,0.36,31),Vector3(x,0.24,0),Color("384451"))

func _create_roads() -> void:
	var asphalt := Color("43505a")
	for index in range(-4,5):
		var p := float(index) * ROAD_INTERVAL
		_box(city_root,"EastWestRoad",Vector3(454,0.16,10),Vector3(0,0.095,p),asphalt)
		_box(city_root,"NorthSouthRoad",Vector3(10,0.16,454),Vector3(p,0.1,0),asphalt)
		for step in range(-10,11):
			var q := float(step) * 21.0
			if absf(q) < 219:
				road_paint.call("record_dash",true,q,p)
				road_paint.call("record_dash",false,q,p)
	# Sidewalk lips provide visual read without blocking the character controller.
	for index in range(-4,5):
		var p := float(index) * ROAD_INTERVAL
		for offset in [-6.0,6.0]:
			_box(city_root,"Sidewalk",Vector3(454,0.18,1.8),Vector3(0,0.04,p+offset),Color("59616a"))
			_box(city_root,"Sidewalk",Vector3(1.8,0.18,454),Vector3(p+offset,0.04,0),Color("59616a"))

func district_id(world_position: Vector3) -> String:
	if world_position.x < 0 and world_position.z < 0: return "forum"
	if world_position.x >= 0 and world_position.z < 0: return "housing"
	if world_position.x < 0: return "lower"
	return "aqueduct"

func _create_city() -> void:
	for ix in range(8):
		for iz in range(8):
			var x := -182.0 + ix * 52.0
			var z := -182.0 + iz * 52.0
			var id := district_id(Vector3(x,0,z))
			if absf(x) == 130.0 and absf(z) == 130.0:
				continue
			if _is_project_plot(Vector3(x,0,z)):
				continue
			var base_color: Color = DISTRICT_COLORS[id]
			var chunk := Node3D.new()
			chunk.name = "Quarter_%d_%d" % [ix,iz]
			city_root.add_child(chunk)
			building_chunks[Vector2i(ix,iz)] = {"node":chunk,"center":Vector3(x,0,z),"active":true}
			for n in range(2):
				var offset := -9.0 if n == 0 else 9.0
				var height := rng.randf_range(8,35) * (1.1 if id == "forum" else 1.0)
				var width := rng.randf_range(11,15)
				var color := base_color.lightened(rng.randf_range(0.05,0.32)) if (ix + iz + n) % 3 == 0 else base_color.darkened(rng.randf_range(0.08,0.28))
				var pos := Vector3(x+offset,height*0.5,z+(offset if (ix + iz) % 2 == 0 else -offset))
				_box(chunk,"Building_%03d" % building_count,Vector3(width,height,width),pos,color,true)
				architecture_trim.call("record",pos,width,height)
				# Entrances and the ground-floor window gap must share the same
				# street-facing facade; never face an interior wall at random.
				var entrance_face: int = STREETFRONT_SCENE.road_facing_variant(
					pos,ROAD_INTERVAL,(ix+iz+n)%2==0)
				streetfront.call("record",pos,width,height,building_count,entrance_face)
				facade_balconies.call("record",pos,width,height,building_count,entrance_face)
				_record_windows(pos,width,height,entrance_face)
				building_count += 1
				# Emissive parapet gives an evening skyline without external textures.
				_box(chunk,"RoofLight",Vector3(width+0.35,0.27,width+0.35),Vector3(pos.x,height+0.15,pos.z),Color("69747d"),false,false)

func update_chunks(focus: Vector3, quality: String = "standard") -> void:
	# Grid-quarter visibility and physics activation. Unlike disk streaming,
	# chunks stay resident and can be activated without reallocating meshes.
	var range_limit: float = 115.0 if quality == "low" else (190.0 if quality == "standard" else 280.0)
	active_chunk_count = 0
	for key in building_chunks:
		var entry: Dictionary = building_chunks[key]
		var center: Vector3 = entry["center"]
		var visible_now: bool = absf(focus.x-center.x) < range_limit and absf(focus.z-center.z) < range_limit
		if visible_now:
			active_chunk_count += 1
		if visible_now == bool(entry["active"]):
			continue
		entry["active"] = visible_now
		var section: Node3D = entry["node"]
		section.visible = visible_now
		for block in section.get_children():
			if block is StaticBody3D:
				var collision: CollisionShape3D = block.get_node_or_null("CollisionShape3D") as CollisionShape3D
				if collision != null:
					collision.set_deferred("disabled",not visible_now)
		building_chunks[key] = entry
	# Update only when original world chunk culling runs, not every frame.
	if focus.is_finite():
		streetlight_focus = focus
	if horizon_scenic != null:
		horizon_scenic.call("update_streetlights",ambience_time,visual_budget,streetlight_focus)

func _record_windows(center: Vector3, width: float, height: float, entrance_variant: int = 0) -> void:
	# R27: each building has a real ground-floor storefront. Do not draw
	# the old ground-floor window THROUGH its chosen street-facing door.
	# Keep all three other facades and every upper-floor window intact.
	var floors: int = maxi(1,int(height / 4.5))
	for floor_index in range(floors):
		var y: float = 2.9 + float(floor_index) * 4.4
		if y > height - 1.1:
			continue
		for column in range(3):
			var offset: float = float(column-1) * width * 0.27
			var side_basis := Basis(Vector3.UP,PI*0.5)
			if STREETFRONT_SCENE.window_allowed(floor_index,0,entrance_variant):
				window_points.append(Transform3D(Basis(),Vector3(center.x+offset,y,center.z-width*0.5-0.08)))
			if STREETFRONT_SCENE.window_allowed(floor_index,1,entrance_variant):
				window_points.append(Transform3D(Basis(),Vector3(center.x+offset,y,center.z+width*0.5+0.08)))
			if STREETFRONT_SCENE.window_allowed(floor_index,2,entrance_variant):
				window_points.append(Transform3D(side_basis,Vector3(center.x-width*0.5-0.08,y,center.z+offset)))
			if STREETFRONT_SCENE.window_allowed(floor_index,3,entrance_variant):
				window_points.append(Transform3D(side_basis,Vector3(center.x+width*0.5+0.08,y,center.z+offset)))

func _create_window_batch() -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(1.05,1.38,0.10)
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = mesh
	multimesh.instance_count = window_points.size()
	for i in range(window_points.size()):
		multimesh.set_instance_transform(i,window_points[i])
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	facade_windows = MultiMeshInstance3D.new()
	facade_windows.name = "InstancedFacadeWindows"
	facade_windows.multimesh = multimesh
	facade_windows.material_override = mat
	city_root.add_child(facade_windows)
	# Instanced satin-metal perimeter behind each dark glass window.
	# One draw batch, rather than a new draw call per window.
	var frame_mesh := BoxMesh.new()
	frame_mesh.size = Vector3(1.27,1.60,0.055)
	var frame_grid := MultiMesh.new()
	frame_grid.transform_format = MultiMesh.TRANSFORM_3D
	frame_grid.mesh = frame_mesh
	frame_grid.instance_count = window_points.size()
	for i in range(window_points.size()):
		frame_grid.set_instance_transform(i,window_points[i])
	facade_frames = MultiMeshInstance3D.new()
	facade_frames.name = "InstancedMetalWindowFrames"
	facade_frames.multimesh = frame_grid
	var finish := StandardMaterial3D.new()
	finish.albedo_color = Color("9ba5ad")
	finish.metallic = 0.20
	finish.roughness = 0.64
	facade_frames.material_override = finish
	facade_frames.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	city_root.add_child(facade_frames)
	_update_windows(8.0,100)

func _update_windows(hour: float, electricity: int) -> void:
	if facade_windows == null: return
	var nighttime := hour < 6.5 or hour >= 18.0
	var mode: int = (1 if nighttime else 0) + (2 if electricity < 25 else 0)
	if mode == last_window_mode: return
	last_window_mode = mode
	var grid: MultiMesh = facade_windows.multimesh
	for i in range(window_points.size()):
		var lit := nighttime and ((i*7+13) % 10 < 7)
		if electricity < 25: lit = lit and i % 5 == 0
		grid.set_instance_color(i,Color("e8cb8d") if lit else Color("344a57"))

func _create_waypoint_marker() -> void:
	waypoint_marker = Node3D.new()
	waypoint_marker.name = "CurrentWaypoint"
	city_root.add_child(waypoint_marker)
	var shaft := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.6
	cylinder.bottom_radius = 2.2
	cylinder.height = 13.0
	shaft.mesh = cylinder
	shaft.material_override = _material(Color("e0b968",0.92),0.0,0.2,true)
	waypoint_marker.add_child(shaft)
	var halo := MeshInstance3D.new()
	var ball := SphereMesh.new()
	ball.radius = 2.7
	ball.height = 5.4
	halo.mesh = ball
	halo.position.y = 8.0
	halo.material_override = _material(Color("f2dba0"),0.0,0.2,true)
	waypoint_marker.add_child(halo)

func update_waypoint(target: Vector3, show_world_marker: bool = true) -> void:
	if waypoint_marker == null: return
	waypoint_marker.visible = show_world_marker
	if not show_world_marker: return
	var place_height := 50.0 if target.x > 0.0 or target.z > 0.0 else 48.0
	waypoint_marker.position = target + Vector3(0,place_height,0)
	waypoint_marker.rotate_y(0.005)

func _create_landmarks() -> void:
	for id in LOCATION_DATA:
		var info: Dictionary = LOCATION_DATA[id]
		var pos: Vector3 = info["position"]
		var district: String = info["district"]
		var color: Color = Color("354d5d") if id == "cityhall" else DISTRICT_COLORS[district].lightened(0.16)
		var h := 24.0 if id == "cityhall" else (24.0 if id == "power" else 16.0)
		_box(city_root,id + "_ground_plaza",Vector3(40,0.14,40),Vector3(pos.x,0.03,pos.z),Color("455158"))
		var landmark_body: Node3D = _box(city_root,id + "_landmark",Vector3(25,h,25),Vector3(pos.x,h/2.0,pos.z),color,true)
		if id == "cityhall":
			var wall: MeshInstance3D = landmark_body.get_node("VisualMesh") as MeshInstance3D
			wall.material_override = FACADE_MATERIALS.facade(Color("536a7a"))
		_box(city_root,id + "_spire",Vector3(6,8,6),Vector3(pos.x,h+4,pos.z),
			Color("7b8991") if id=="cityhall" else Color("9dcfca"),false,id!="cityhall")
		if id == "cityhall":
			# All first-screen PBR details are now just seven batched meshes.
			# The existing 25x24x25 collider is preserved, unchanged.
			cityhall_gateway = CIVIC_GATEWAY.new()
			cityhall_gateway.position = pos
			city_root.add_child(cityhall_gateway)

		var marker := Node3D.new()
		marker.name = "Marker_" + id
		marker.position = pos + Vector3(0,h+9,0)
		city_root.add_child(marker)
		var label := Label3D.new()
		label.text = info["name"]
		label.font_size = 45
		label.pixel_size = 0.008
		label.modulate = Color("dcebe6")
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		marker.add_child(label)
		markers[id] = marker
		locations[id] = {"name":info["name"],"position":pos,"district":district}

func _project_position(id: String) -> Vector3:
	var district: String = GameState.BUILDINGS[id]["district"]
	var base: Vector3 = GameState.LOCATIONS[district]
	var options := [
		Vector3(52.0 if base.x > 0 else -52.0,0,0),
		Vector3(0,0,52.0 if base.z > 0 else -52.0),
		Vector3(-52.0 if base.x > 0 else 52.0,0,0)
	]
	var index := 0
	for key in GameState.BUILDING_ORDER:
		if GameState.BUILDINGS[key]["district"] != district:
			continue
		if key == id: break
		index += 1
	return base + options[index % 3]

func _is_project_plot(point: Vector3) -> bool:
	for id in GameState.BUILDING_ORDER:
		if point.distance_to(_project_position(id)) < 0.5:
			return true
	return false

func _create_project_visuals() -> void:
	for id in GameState.BUILDING_ORDER:
		var pos := _project_position(id)
		var district: String = GameState.BUILDINGS[id]["district"]
		var holder := _box(city_root,"Project_" + id,Vector3(15,6,15),pos + Vector3(0,3,0),DISTRICT_COLORS[district].lightened(0.27),true)
		var roof := _box(holder,"RoofNeon",Vector3(15.5,0.2,15.5),Vector3(0,3.3,0),Color("84c4c6"),false,true)
		project_visuals[id] = {"root":holder,"roof":roof}
		holder.visible = false

func _create_property_markers() -> void:
	# Property ownership is represented on the same physical city map.
	for id in GameState.REAL_ESTATE.PROPERTY_IDS:
		var spec: Dictionary = GameState.REAL_ESTATE.PROPERTIES[id]
		var holder := Node3D.new()
		holder.name = "Property_" + id
		holder.position = spec["position"] + Vector3(0.0,19.0,0.0)
		city_root.add_child(holder)
		var halo := MeshInstance3D.new()
		var shape := SphereMesh.new()
		shape.radius = 1.25
		shape.height = 2.5
		halo.mesh = shape
		halo.material_override = _material(Color("e5bd72"),0.2,0.22,true)
		holder.add_child(halo)
		var tag := Label3D.new()
		tag.position = Vector3(0,2.6,0)
		tag.font_size = 42
		tag.pixel_size = 0.007
		tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		tag.no_depth_test = true
		holder.add_child(tag)
		property_markers[id] = {"node":holder,"label":tag}

func _create_weather_particles() -> void:
	weather_particles = GPUParticles3D.new()
	weather_particles.name = "LocalPrecipitation"
	weather_particles.amount = 300
	weather_particles.lifetime = 1.65
	weather_particles.visibility_aabb = AABB(Vector3(-34,-29,-34),Vector3(68,58,68))
	var process := ParticleProcessMaterial.new()
	process.direction = Vector3(0,-1,0)
	process.spread = 5.0
	process.gravity = Vector3(0,-30,0)
	process.initial_velocity_min = 2.0
	process.initial_velocity_max = 4.0
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(26,4,26)
	weather_particles.process_material = process
	var drop := QuadMesh.new()
	drop.size = Vector2(0.035,0.55)
	var visual := StandardMaterial3D.new()
	visual.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	visual.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	visual.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	visual.albedo_color = Color(0.65,0.81,0.98,0.55)
	drop.material = visual
	weather_particles.draw_pass_1 = drop
	weather_particles.emitting = false
	add_child(weather_particles)

func _apply_r90_offline_pbr() -> void:
	if asphalt_pbr == null: return
	var root_path: String = "res://assets/r90/"
	var diffuse: String = root_path+"aerial_asphalt_01_diff_1k.jpg"
	var normals: String = root_path+"aerial_asphalt_01_nor_gl_1k.jpg"
	var rough: String = root_path+"aerial_asphalt_01_rough_1k.jpg"
	var available: bool = ResourceLoader.exists(diffuse) and ResourceLoader.exists(normals) and ResourceLoader.exists(rough)
	if visual_budget == "cinematic" and available:
		asphalt_pbr.albedo_texture = load(diffuse) as Texture2D
		asphalt_pbr.normal_texture = load(normals) as Texture2D
		asphalt_pbr.roughness_texture = load(rough) as Texture2D
		asphalt_pbr.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
		asphalt_pbr.uv1_scale = Vector3(0.12,0.12,0.12)
	else:
		asphalt_pbr.albedo_texture = r90_original_asphalt_albedo
		asphalt_pbr.normal_texture = r90_original_asphalt_normal
		asphalt_pbr.roughness_texture = null
		asphalt_pbr.uv1_scale = Vector3(0.38,0.38,0.38)

func apply_visual_budget(mode: String) -> void:
	visual_budget = mode if ["low","standard","cinematic"].has(mode) else "standard"
	_apply_r90_offline_pbr()
	if weather_particles != null:
		weather_particles.amount_ratio = 0.25 if visual_budget == "low" else (0.65 if visual_budget == "standard" else 1.0)
	if r90_urban != null:
		r90_urban.call("set_quality",visual_budget)
	if horizon_scenic != null:
		horizon_scenic.visible = visual_budget != "low"
		horizon_scenic.call("set_intersection_quality",visual_budget)
		horizon_scenic.call("update_streetlights",ambience_time,visual_budget,streetlight_focus)
	if architecture_trim != null:
		architecture_trim.visible = visual_budget != "low"
	if streetfront != null:
		streetfront.visible = visual_budget != "low"
	if facade_balconies != null:
		facade_balconies.call("set_quality",visual_budget)
	if road_puddles != null:
		road_puddles.set_conditions(weather_mode,visual_budget)
	if cityhall_gateway != null:
		cityhall_gateway.visible = visual_budget != "low"
	if facade_frames != null:
		facade_frames.visible = visual_budget != "low"
	_apply_lighting()

func update_weather(kind: String) -> void:
	if not GameState.CITY_WEATHER.LABELS.has(kind):
		kind = "clear"
	weather_mode = kind
	if asphalt_pbr != null:
		ROAD_MATERIALS.apply_weather(asphalt_pbr,kind)
	if concrete_pbr != null:
		ROAD_MATERIALS.apply_weather(concrete_pbr,kind)
	if road_paint != null:
		road_paint.call("apply_weather",kind)
	if road_puddles != null:
		road_puddles.set_conditions(kind,visual_budget)
	if weather_particles != null:
		weather_particles.emitting = kind == "rain" or kind == "storm"
	_apply_lighting()

func _apply_lighting() -> void:
	if sky_environment == null or sky_environment.environment == null or sun == null:
		return
	var sky: Sky = sky_environment.environment.sky
	if sky == null:
		return
	var atmosphere: ProceduralSkyMaterial = sky.sky_material as ProceduralSkyMaterial
	if atmosphere == null:
		return
	LIGHT_GRADE.apply_to(sky_environment.environment,sun,atmosphere,weather_mode,visual_budget,daylight_brightness)
	LIGHT_GRADE.apply_night_overlay(sky_environment.environment,sun,atmosphere,ambience_time)
	# Authored golden-hour grade affects real Godot light only, never UI screenshots.
	if weather_mode == "clear" and visual_budget == "cinematic":
		var golden_hour: float = clampf(1.0-absf(ambience_time-18.0)/3.0,0.0,1.0)
		sun.light_color = sun.light_color.lerp(Color("ffd1a0"),0.35*golden_hour)
		sky_environment.environment.fog_light_color = sky_environment.environment.fog_light_color.lerp(
			Color("dca77f"),0.23*golden_hour)

func update_development() -> void:
	if not is_node_ready(): return
	var state: Dictionary = GameState.data
	for id in markers:
		var marker: Node3D = markers[id]
		var district: String = locations[id]["district"]
		var sum_level := 0
		for key in GameState.BUILDING_ORDER:
			if GameState.BUILDINGS[key]["district"] == district:
				sum_level += int(state["buildings"][key])
		marker.scale = Vector3.ONE * (1.0 + sum_level * 0.03)
	for id in project_visuals:
		var level: int = int(state["buildings"][id])
		var nodes: Dictionary = project_visuals[id]
		var root: Node3D = nodes["root"]
		root.visible = level > 0
		var project_collider: CollisionShape3D = root.get_node("CollisionShape3D") as CollisionShape3D
		project_collider.set_deferred("disabled",level == 0)
		if level > 0:
			var height: float = 6.0 + float(level) * 8.0
			root.position = _project_position(id) + Vector3(0,height*0.5,0)
			var body: MeshInstance3D = root.get_node("VisualMesh") as MeshInstance3D
			var box := BoxMesh.new()
			box.size = Vector3(15,height,15)
			body.mesh = box
			var collision: CollisionShape3D = root.get_node("CollisionShape3D")
			var shape := BoxShape3D.new()
			shape.size = Vector3(15,height,15)
			collision.shape = shape
			var roof: Node3D = nodes["roof"]
			roof.position.y = height*0.5 + 0.15
	_update_property_visuals()

func _update_property_visuals() -> void:
	var owned: Dictionary = GameState.data.get("properties",{})
	for id in property_markers:
		var visuals: Dictionary = property_markers[id]
		var holder: Node3D = visuals["node"]
		var level: int = int(owned.get(id,0))
		holder.visible = true
		holder.scale = Vector3.ONE * (0.80 + float(level) * 0.25)
		var orb: MeshInstance3D = holder.get_child(0) as MeshInstance3D
		orb.material_override = _material(Color("e5bd72") if level > 0 else Color("6e9db7"),0.2,0.25,true)

func update_language(lang: String) -> void:
	for id in markers:
		var marker: Node3D = markers[id]
		var label: Label3D = marker.get_child(0)
		label.text = str(ContractManager.LOCATION_NAMES.get(id,{}).get(lang,locations[id]["name"]))
	for id in property_markers:
		var label: Label3D = property_markers[id]["label"]
		var base_name: String = str(GameState.REAL_ESTATE.PROPERTIES[id]["name"].get(lang,GameState.REAL_ESTATE.PROPERTIES[id]["name"]["ru"]))
		var owned: bool = int(GameState.data.get("properties",{}).get(id,0)) > 0
		label.text = base_name + (" · Lv.%d" % int(GameState.data["properties"][id]) if owned else (" · F: КУПИТЬ" if lang == "ru" else (" · F: BUY" if lang == "en" else " · F: 购买")))

func closest_property(point: Vector3, max_distance: float = 18.0) -> String:
	var closest := ""
	var best: float = max_distance * max_distance
	for id in GameState.REAL_ESTATE.PROPERTY_IDS:
		var here: Vector3 = GameState.REAL_ESTATE.PROPERTIES[id]["position"]
		var horizontal: float = Vector2(point.x-here.x,point.z-here.z).length_squared()
		if horizontal < best:
			best = horizontal
			closest = id
	return closest

func closest_location(point: Vector3, max_distance: float = 23.0) -> String:
	var found := ""
	var best := max_distance
	for id in locations:
		var at: Vector3 = locations[id]["position"]
		var distance := point.distance_to(at)
		if distance < best:
			best = distance
			found = id
	return found

func closest_interior(point: Vector3, max_distance: float = 27.0) -> String:
	var found: String = closest_location(point,max_distance)
	var best: float = max_distance if found == "" else point.distance_to(locations[found]["position"])
	for project_id in ["council","clinic","academy","homes","school","gardens","factory","purifier"]:
		if int(GameState.data["buildings"].get(project_id,0)) < 1: continue
		var entrance: Vector3 = _project_position(project_id)
		var distance: float = point.distance_to(entrance)
		if distance < best:
			found = project_id
			best = distance
	return found

func objective_position() -> Vector3:
	if not GameState.data.get("driving_trial",{}).is_empty():
		return GameState.TRIALS.target(GameState.data)
	var local_goal: String = GameState.NEIGHBORHOOD.goal_location(GameState.data)
	if local_goal != "": return ContractManager.POSITIONS.get(local_goal,Vector3.ZERO)
	var service: Dictionary = GameState.data.get("service_active",{})
	if not service.is_empty():
		return GameState.SERVICE.LOCATIONS.get(str(service["destination"]),Vector3.ZERO)
	var stage: int = int(GameState.data["mission"])
	if stage == 36: return Vector3(-130,0,-130)
	if stage == 0: return Vector3(-120,0,-104)
	if stage == 1 or stage == 2: return Vector3(130,0,-130)
	if stage == 3 or stage == 6 or stage == 7: return Vector3(-130,0,-130)
	return ContractManager.destination()

func update_daynight(day_clock: float) -> void:
	ambience_time = fposmod(day_clock,24.0) if is_finite(day_clock) else 12.0
	var phase := (ambience_time - 7.0) / 24.0 * TAU
	sun.rotation_degrees.x = -55.0 + 70.0 * sin(phase)
	daylight_brightness = clampf(0.70 + 0.55 * maxf(0.0,cos(phase)),0.70,1.25)
	_apply_lighting()
	_update_windows(ambience_time,int(GameState.data["energy"]))
	if horizon_scenic != null:
		horizon_scenic.call("update_streetlights",ambience_time,visual_budget,streetlight_focus)
