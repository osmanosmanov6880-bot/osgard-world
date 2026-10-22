extends Node3D
## Deterministic, art-free 3D city generator. Replace block meshes with licensed assets later.

signal location_entered(location_id: String)

const CITY_HALF = 224.0
const ROAD_INTERVAL = 52.0
const DISTRICT_NAMES = {"forum":"Сенатский форум", "housing":"Жилой квартал", "lower":"Нижний город", "aqueduct":"Акведуки"}
const DISTRICT_COLORS = {
	"forum":Color(0.37,0.48,0.63),
	"housing":Color(0.36,0.57,0.49),
	"lower":Color(0.49,0.44,0.38),
	"aqueduct":Color(0.33,0.54,0.59)
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
var rng := RandomNumberGenerator.new()
var ambience_time := 10.0
var sun: DirectionalLight3D
var sky_environment: WorldEnvironment
var city_root: Node3D
var building_count := 0
var building_chunks := {}
var active_chunk_count := 0
var window_points: Array[Transform3D] = []
var facade_windows: MultiMeshInstance3D
var last_window_mode := -1
var waypoint_marker: Node3D
var horizon_scenic: Node3D

func _ready() -> void:
	rng.seed = 428753
	city_root = Node3D.new()
	city_root.name = "ProceduralDistricts"
	add_child(city_root)
	_create_environment()
	_create_terrain()
	_create_roads()
	_create_city()
	_create_window_batch()
	_create_landmarks()
	_create_waypoint_marker()
	_create_project_visuals()
	_create_property_markers()
	_create_weather_particles()
	_create_trees()
	# GPU-instanced scenic art has no colliders and preserves all traffic/missions.
	horizon_scenic = preload("res://scripts/horizon_roadscape.gd").new()
	add_child(horizon_scenic)
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
	env.ambient_light_energy = 1.45
	env.reflected_light_source = Environment.REFLECTION_SOURCE_BG
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	sky_environment.environment = env
	add_child(sky_environment)
	sun = DirectionalLight3D.new()
	sun.light_color = Color("ffe2b1")
	sun.light_energy = 1.9
	sun.shadow_enabled = true
	sun.rotation_degrees = Vector3(-52,-35,0)
	add_child(sun)

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
				_box(city_root,"RoadDash",Vector3(7,0.03,0.19),Vector3(q,0.19,p),Color("dec99b"))
				_box(city_root,"RoadDash",Vector3(0.19,0.03,7),Vector3(p,0.195,q),Color("dec99b"))
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
				_record_windows(pos,width,height)
				building_count += 1
				# Emissive parapet gives an evening skyline without external textures.
				_box(chunk,"RoofLight",Vector3(width+0.35,0.27,width+0.35),Vector3(pos.x,height+0.15,pos.z),Color("95b7b7"),false,true)

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

func _record_windows(center: Vector3, width: float, height: float) -> void:
	# Facade windows are a SINGLE GPU-instanced mesh (instead of thousands of nodes).
	var floors: int = maxi(1,int(height / 4.5))
	for floor_index in range(floors):
		var y: float = 2.9 + float(floor_index) * 4.4
		if y > height - 1.1: continue
		for column in range(3):
			var offset: float = float(column-1) * width * 0.27
			window_points.append(Transform3D(Basis(),Vector3(center.x+offset,y,center.z-width*0.5-0.08)))
			window_points.append(Transform3D(Basis(),Vector3(center.x+offset,y,center.z+width*0.5+0.08)))
			var side_basis := Basis(Vector3.UP,PI*0.5)
			window_points.append(Transform3D(side_basis,Vector3(center.x-width*0.5-0.08,y,center.z+offset)))
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

func update_waypoint(target: Vector3) -> void:
	if waypoint_marker == null: return
	var place_height := 50.0 if target.x > 0.0 or target.z > 0.0 else 48.0
	waypoint_marker.position = target + Vector3(0,place_height,0)
	waypoint_marker.rotate_y(0.005)

func _create_landmarks() -> void:
	for id in LOCATION_DATA:
		var info: Dictionary = LOCATION_DATA[id]
		var pos: Vector3 = info["position"]
		var district: String = info["district"]
		var color: Color = DISTRICT_COLORS[district].lightened(0.25)
		var h := 30.0 if id == "cityhall" else (24.0 if id == "power" else 16.0)
		_box(city_root,id + "_ground_plaza",Vector3(40,0.14,40),Vector3(pos.x,0.03,pos.z),Color("455158"))
		_box(city_root,id + "_landmark",Vector3(25,h,25),Vector3(pos.x,h/2.0,pos.z),color,true)
		_box(city_root,id + "_spire",Vector3(6,8,6),Vector3(pos.x,h+4,pos.z),Color("9dcfca"),false,true)
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

func update_weather(kind: String) -> void:
	if not GameState.CITY_WEATHER.LABELS.has(kind):
		kind = "clear"
	weather_mode = kind
	if weather_particles != null:
		weather_particles.emitting = kind == "rain" or kind == "storm"
	if sky_environment == null:
		return
	var sky: Sky = sky_environment.environment.sky
	var material: ProceduralSkyMaterial = sky.sky_material as ProceduralSkyMaterial
	if material != null:
		material.sky_top_color = Color("30445c") if kind == "storm" else (Color("577995") if kind == "rain" or kind == "cloudy" else Color("638db2"))
		material.sky_horizon_color = Color("83909d") if kind == "storm" else Color("e0b18f")

func _create_trees() -> void:
	for i in range(85):
		var pos := Vector3(rng.randf_range(-220,220),0,rng.randf_range(-220,220))
		if absf(fposmod(pos.x+26.0,52.0)-26.0) < 9.0 or absf(fposmod(pos.z+26.0,52.0)-26.0) < 9.0:
			continue
		if pos.distance_to(Vector3(-130,0,-130)) < 30.0: continue
		_box(city_root,"TreeTrunk",Vector3(0.75,4.0,0.75),Vector3(pos.x,2,pos.z),Color("56483a"))
		_box(city_root,"TreeCrown",Vector3(6.0,6.0,6.0),Vector3(pos.x,6,pos.z),Color("246257"))

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
	var phase := (day_clock - 7.0) / 24.0 * TAU
	sun.rotation_degrees.x = -55.0 + 70.0 * sin(phase)
	var brightness: float = clampf(0.65 + 0.9 * maxf(0.0,cos(phase)),0.65,1.55)
	sun.light_energy = brightness * 1.6 * (0.65 if weather_mode == "storm" else (0.85 if weather_mode == "rain" or weather_mode == "cloudy" else 1.0))
	if sky_environment != null:
		sky_environment.environment.ambient_light_energy = 0.95 + brightness * 0.45
	_update_windows(day_clock,int(GameState.data["energy"]))
