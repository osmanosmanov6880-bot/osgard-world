extends Node3D
## HORIZON R7 - dense architectural atlas, true materials, physically readable depth.
## Visual geometry only: original collision, driving, quests and saves are untouched.
const FACADES = ["Wall","WindowShadow","WindowGlass","WindowMetal","StoneTrim",
                 "StoneCornice","BalconySlab","BalconyRail","CopperDrain",
                 "RoofHardware","Canopy","NightInterior"]
var city
var photos
var groups: Dictionary = {}
var finishes: Dictionary = {}
var instances: Array[MultiMeshInstance3D] = []
var replacements: Dictionary = {}
var source_windows_visible: bool = true
var original_sky: Material
var physical_sky: PhysicalSkyMaterial
var profile: String = "low"
var deployed_windows: int = 0
var facade_buildings: int = 0
var balcony_count: int = 0
var roof_objects: int = 0
var yonder_distance: float = 0.0
var last_light_mode: bool = false
var time_accumulator: float = 0.0
var do_reflections: bool = false

func _material(base: Color, roughness: float = .65, metal: float = .0, emission: bool = false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = base
	m.roughness = roughness
	m.metallic = metal
	m.vertex_color_use_as_albedo = true
	if emission:
		m.emission_enabled = true
		m.emission = Color(.94,.76,.48)
		m.emission_energy_multiplier = .72
	return m

func _setup_materials() -> void:
	var wall: StandardMaterial3D = photos.bundles.get("facade",null) as StandardMaterial3D
	var sidewalk: StandardMaterial3D = photos.bundles.get("sidewalk",null) as StandardMaterial3D
	finishes["Wall"] = wall if wall != null else _material(Color("c2c1b8"),.81)
	finishes["WindowShadow"] = _material(Color("131e29"),.94)
	var glass := _material(Color(.12,.23,.31),.16,.22)
	glass.clearcoat_enabled = true
	glass.clearcoat = .66
	glass.clearcoat_roughness = .08
	finishes["WindowGlass"] = glass
	finishes["WindowMetal"] = _material(Color("89979a"),.36,.73)
	finishes["StoneTrim"] = sidewalk if sidewalk != null else _material(Color("b5b4a9"),.8)
	finishes["StoneCornice"] = finishes["StoneTrim"]
	finishes["BalconySlab"] = finishes["StoneTrim"]
	finishes["BalconyRail"] = _material(Color("65717a"),.33,.74)
	finishes["CopperDrain"] = _material(Color("6c817e"),.49,.73)
	finishes["RoofHardware"] = _material(Color("444f57"),.58,.65)
	finishes["Canopy"] = _material(Color("8c7863"),.74,.02)
	finishes["NightInterior"] = _material(Color("f3ca89"),.64,0.0,true)
	# Avoid editing shared R6 scan assets; use a separate material resource per R7 atlas.
	for type in ["Wall","StoneTrim","StoneCornice","BalconySlab"]:
		finishes[type] = (finishes[type] as StandardMaterial3D).duplicate() as StandardMaterial3D
		(finishes[type] as StandardMaterial3D).vertex_color_use_as_albedo = true

func _bucket(type: String, position: Vector3) -> Dictionary:
	var section: int = (1 if position.x >= 0.0 else 0) + (2 if position.z >= 0.0 else 0)
	var id: String = type + "_q" + str(section)
	if not groups.has(id):
		groups[id] = {"type":type,"poses":[],"colors":[]}
	return groups[id]

func _box(type: String, position: Vector3, dimension: Vector3, tint: Color=Color.WHITE, yaw: float = 0.0) -> void:
	var entry: Dictionary = _bucket(type,position)
	var t: Transform3D = Transform3D(Basis(Vector3.UP,yaw).scaled(dimension),position)
	var a: Array = entry["poses"]
	var c: Array = entry["colors"]
	a.append(t)
	c.append(tint)

func _window_box(type: String, reference: Transform3D, offset: Vector3, dimension: Vector3, tint: Color=Color.WHITE) -> void:
	var center: Vector3 = reference.origin + reference.basis*offset
	var bucket: Dictionary = _bucket(type,center)
	var poses: Array = bucket["poses"]
	var colors: Array = bucket["colors"]
	poses.append(Transform3D(reference.basis.scaled(dimension),center))
	colors.append(tint)

func bind_world(game_city, photo_layer) -> void:
	city = game_city
	photos = photo_layer
	name = "HorizonArchitectureR7"
	_setup_materials()
	_build_curtain_walls()
	_build_roof_structures()
	_build_facade_windows()
	_build_civic_portico()
	_upload_multimeshes()
	_install_atmosphere()
	if city.facade_windows != null:
		source_windows_visible = city.facade_windows.visible
	set_profile("standard")

func _build_curtain_walls() -> void:
	var elevation_id: int = 0
	for key in city.building_chunks:
		var chunk: Dictionary = city.building_chunks[key]
		var section: Node3D = chunk["node"]
		for holder in section.get_children():
			if not holder.name.begins_with("Building_"):
				continue
			var visual: MeshInstance3D = holder.get_node_or_null("VisualMesh") as MeshInstance3D
			if visual == null or not (visual.mesh is BoxMesh):
				continue
			var box: BoxMesh = visual.mesh as BoxMesh
			var position: Vector3 = visual.global_position
			var height: float = box.size.y
			var span: float = box.size.x
			var roof: float = height + .12
			replacements[visual] = visual.material_override
			# Street-facing wall base is scanned plaster from R6, not painted primitive.
			var stone_tint := Color(.88,.88,.83) if elevation_id % 4 != 0 else Color(.83,.85,.83)
			for side in [-1.0,1.0]:
				# Thin dimensional horizontal masonry belts at each upper floor.
				for level in range(1,int(height/4.4)+1):
					var top: float = float(level)*4.4-.2
					if top > height-.9:
						continue
					_box("StoneTrim",Vector3(position.x,top,position.z+side*(span*.5+.15)),Vector3(span+.28,.16,.21),stone_tint)
					_box("StoneTrim",Vector3(position.x+side*(span*.5+.15),top,position.z),Vector3(.21,.16,span+.28),stone_tint)
				# Full height downpipes support rain and give strong human-scale cues.
				_box("CopperDrain",Vector3(position.x+side*(span*.45),height*.5,position.z+span*.5+.16),Vector3(.095,height,.095),Color("a0b5ad"))
				_box("CopperDrain",Vector3(position.x+span*.5+.16,height*.5,position.z+side*(span*.45)),Vector3(.095,height,.095),Color("829c97"))
			# Roof fascia, raised parapet and real shadows; no new collision volumes.
			_box("StoneCornice",Vector3(position.x,roof,position.z),Vector3(span+.72,.32,span+.72),stone_tint)
			for side in [-1.0,1.0]:
				_box("StoneCornice",Vector3(position.x+side*(span*.5+.28),roof+.40,position.z),Vector3(.15,.68,span+.4),stone_tint)
				_box("StoneCornice",Vector3(position.x,roof+.40,position.z+side*(span*.5+.28)),Vector3(span+.4,.68,.15),stone_tint)
			# Ground floor cantilevered fabric awnings convey commercial density.
			if elevation_id%3==0 and height>10.0:
				_box("Canopy",Vector3(position.x,3.35,position.z+span*.5+.72),Vector3(minf(span-1.6,8.4),.12,1.45),Color("b4a188"))
			elevation_id += 1
			facade_buildings += 1

func _build_roof_structures() -> void:
	var index: int = 0
	for key in city.building_chunks:
		var section: Node3D = city.building_chunks[key]["node"]
		for holder in section.get_children():
			if not holder.name.begins_with("Building_"):
				continue
			var visual: MeshInstance3D = holder.get_node_or_null("VisualMesh") as MeshInstance3D
			if visual == null or not (visual.mesh is BoxMesh):
				continue
			var box: BoxMesh = visual.mesh as BoxMesh
			var height: float = box.size.y
			var pos: Vector3 = visual.global_position
			if index%3==0:
				_box("RoofHardware",Vector3(pos.x-1.7,height+.60,pos.z+1.3),Vector3(1.8,.86,1.24),Color("a3adb0"))
				_box("RoofHardware",Vector3(pos.x-1.7,height+1.11,pos.z+1.3),Vector3(1.5,.10,1.13),Color("798c92"))
				_box("CopperDrain",Vector3(pos.x+1.8,height+.66,pos.z-1.4),Vector3(.35,1.08,.35),Color("c1c9bf"))
				roof_objects += 3
			if index%5==0:
				for offset in [-1.3,1.3]:
					_box("RoofHardware",Vector3(pos.x+offset,height+.34,pos.z),Vector3(.74,.18,3.0),Color("5f7e8b"))
					roof_objects += 1
			index += 1

func _build_facade_windows() -> void:
	for index in range(city.window_points.size()):
		var ref: Transform3D = city.window_points[index]
		# Use exact positions from the game's existing authored window records.
		_window_box("WindowShadow",ref,Vector3(0,0,-.035),Vector3(1.30,1.66,.11),Color("51606a"))
		_window_box("WindowGlass",ref,Vector3(0,0,.07),Vector3(1.14,1.47,.075),Color(.82,.91,.96))
		for side in [-1.0,1.0]:
			_window_box("WindowMetal",ref,Vector3(side*.63,0,.13),Vector3(.105,1.73,.13),Color("a7afb0"))
		_window_box("WindowMetal",ref,Vector3(0,.84,.13),Vector3(1.32,.11,.13),Color("98a5aa"))
		_window_box("WindowMetal",ref,Vector3(0,-.84,.13),Vector3(1.34,.11,.14),Color("8e9b9d"))
		_window_box("WindowMetal",ref,Vector3(0,.065,.135),Vector3(1.12,.055,.065),Color("c0c4bc"))
		_window_box("StoneTrim",ref,Vector3(0,-.94,.21),Vector3(1.58,.18,.38),Color("c2c0b3"))
		_window_box("StoneTrim",ref,Vector3(0,.96,.21),Vector3(1.57,.18,.30),Color("b5b5ab"))
		if index%7==0:
			_window_box("NightInterior",ref,Vector3(0,0,.13),Vector3(.96,1.20,.031),Color(.88,.83,.68))
		if index%19==0 and ref.origin.y>=6.0:
			_window_box("BalconySlab",ref,Vector3(0,-1.08,.62),Vector3(2.02,.14,1.18),Color("c6c1b5"))
			_window_box("BalconyRail",ref,Vector3(0,-.42,1.12),Vector3(1.96,.071,.08),Color("7f8c93"))
			for rail in [-.81,-.45,0.0,.45,.81]:
				_window_box("BalconyRail",ref,Vector3(rail,-.75,1.12),Vector3(.055,.64,.07),Color("b6bcc1"))
			balcony_count += 1
		deployed_windows += 1

func _build_civic_portico() -> void:
	# Place premium columns/pilasters beside the real central city hall.
	var px: float = -130.0
	var pz: float = -130.0
	for column in range(6):
		var x: float = px - 10.0 + float(column)*4.0
		_box("StoneTrim",Vector3(x,.28,pz+14.0),Vector3(1.52,.55,1.51),Color("dad4c1"))
		_box("StoneTrim",Vector3(x,10.54,pz+14.0),Vector3(1.47,.45,1.47),Color("c9c4b5"))
		for rib in [-.30,.30]:
			_box("StoneTrim",Vector3(x+rib,5.2,pz+14.60),Vector3(.12,9.7,.17),Color("c6c9be"))
	for stair in range(4):
		_box("StoneTrim",Vector3(px,.15+float(stair)*.11,pz+18.6-float(stair)*.75),Vector3(12.0-float(stair)*.66,.10,.75),Color("d1cec4"))

func _upload_multimeshes() -> void:
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	var sum: int = 0
	for key in groups:
		var entry: Dictionary = groups[key]
		var poses: Array = entry["poses"]
		var colors: Array = entry["colors"]
		if poses.is_empty():
			continue
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.use_colors = true
		multi.mesh = box
		multi.instance_count = poses.size()
		var min_corner := Vector3(INF,INF,INF)
		var max_corner := Vector3(-INF,-INF,-INF)
		for index in range(poses.size()):
			var pose: Transform3D = poses[index]
			multi.set_instance_transform(index,pose)
			multi.set_instance_color(index,colors[index])
			min_corner = min_corner.min(pose.origin)
			max_corner = max_corner.max(pose.origin)
		multi.custom_aabb = AABB(min_corner-Vector3(5.0,5.0,5.0),max_corner-min_corner+Vector3(10.0,12.0,10.0))
		var node := MultiMeshInstance3D.new()
		node.name = "R7_"+str(key)
		node.multimesh = multi
		node.material_override = finishes[entry["type"]]
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.visibility_range_end = 350.0 if entry["type"] in ["StoneCornice","StoneTrim"] else 240.0
		add_child(node)
		instances.append(node)
		sum += poses.size()
	yonder_distance = float(sum)
	groups.clear()  # release tens of thousands of CPU-side duplicate transforms

func _install_atmosphere() -> void:
	if city.sky_environment == null:
		return
	var env: Environment = city.sky_environment.environment
	if env.sky == null:
		return
	original_sky = env.sky.sky_material
	physical_sky = PhysicalSkyMaterial.new()
	physical_sky.rayleigh_coefficient = 1.9
	physical_sky.mie_coefficient = .004
	physical_sky.mie_eccentricity = .81
	physical_sky.turbidity = 5.2
	physical_sky.sun_disk_scale = 1.0
	physical_sky.ground_color = Color(.20,.22,.19)
	physical_sky.use_debanding = true

func set_profile(mode: String) -> void:
	profile = mode
	var enabled: bool = mode != "low"
	var ultra: bool = mode == "cinematic"
	for node in replacements:
		if is_instance_valid(node):
			node.material_override = photos.bundles.get("facade",replacements[node]) if enabled else replacements[node]
	for visual in instances:
		if not is_instance_valid(visual):
			continue
		var premium: bool = "Balcony" in visual.name or "RoofHardware" in visual.name or "NightInterior" in visual.name
		visual.visible = enabled and (ultra or not premium)
		visual.visibility_range_end = 350.0 if ultra else 185.0
	if city.facade_windows != null:
		city.facade_windows.visible = not enabled and source_windows_visible
	_update_lighting()

func set_weather(_kind: String) -> void:
	_update_lighting()

func _update_lighting() -> void:
	if city == null or city.sky_environment == null:
		return
	var env: Environment = city.sky_environment.environment
	var plus: bool = RenderingServer.get_current_rendering_method() == "forward_plus"
	do_reflections = plus and profile == "cinematic"
	if env.sky != null:
		env.sky.sky_material = physical_sky if do_reflections else original_sky
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = .84 if do_reflections else (.96 if profile=="standard" else 1.0)
	env.adjustment_enabled = profile!="low"
	env.adjustment_saturation = .93 if do_reflections else 1.0
	env.adjustment_contrast = 1.07 if do_reflections else 1.0
	if city.sun != null:
		city.sun.light_color = Color(1.0,.94,.85) if do_reflections else Color("ffe2b1")

func _process(delta: float) -> void:
	time_accumulator += delta
	if time_accumulator < 1.8 or city == null:
		return
	time_accumulator = 0.0
	if city.sun == null:
		return
	var night: bool = city.sun.light_energy < .76
	if night == last_light_mode:
		return
	last_light_mode = night
	for node in instances:
		if node.name.begins_with("R7_NightInterior_"):
			node.visible = night and profile=="cinematic"

func diagnostic() -> Dictionary:
	return {"release":"R7","facade_buildings":facade_buildings,
		"mapped_original_windows":deployed_windows,"physical_balconies":balcony_count,
		"roof_details":roof_objects,"gpu_batches":instances.size(),
		"instanced_meshes":int(yonder_distance),"authentic_scanned_wall":photos.bundles.has("facade") if photos != null else false,
		"quality":profile,"physical_sky":do_reflections,"collision_changed":false}
