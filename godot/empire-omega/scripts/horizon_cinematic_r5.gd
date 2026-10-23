extends Node3D
## HORIZON R5: physically legible near-field details, weather shader and restrained grading.
## Every detail is collision-free. Existing roads, missions, saves and driving remain authoritative.
const ASPHALT = preload("res://shaders/horizon_r5_asphalt.gdshader")
const WIND = preload("res://shaders/horizon_r5_wind.gdshader")
var world
var wet_surface: ShaderMaterial
var original_surfaces: Dictionary = {}
var near_details: Array[GeometryInstance3D] = []
var batch_count: int = 0
var drain_count: int = 0
var fastener_count: int = 0
var curb_count: int = 0
var foliage_count: int = 0
var weather_kind: String = "clear"
var quality: String = "standard"
var wetness: float = 0.0
var last_grading: float = 0.0
var wind_surface: ShaderMaterial
var exterior_light: Array[OmniLight3D] = []

func _ready() -> void:
	name = "HorizonCinematicR5"
	_build_road_infrastructure()
	_build_green_strips()
	_build_facade_accents()

func _material(tint: Color, metal: float = 0.0, rough: float = 0.8, emissive: bool = false) -> StandardMaterial3D:
	var finish := StandardMaterial3D.new()
	finish.albedo_color = tint
	finish.metallic = metal
	finish.roughness = rough
	finish.vertex_color_use_as_albedo = true
	if emissive:
		finish.emission_enabled = true
		finish.emission = tint
		finish.emission_energy_multiplier = 0.55
	return finish

func _batch(label: String, mesh: Mesh, poses: Array[Transform3D], palette: Array[Color], mat: Material, far_limit: float = 320.0) -> void:
	if poses.is_empty():
		return
	assert(poses.size() == palette.size())
	var gpu := MultiMesh.new()
	gpu.transform_format = MultiMesh.TRANSFORM_3D
	gpu.use_colors = true
	gpu.mesh = mesh
	gpu.instance_count = poses.size()
	for index in range(poses.size()):
		gpu.set_instance_transform(index,poses[index])
		gpu.set_instance_color(index,palette[index])
	var instance := MultiMeshInstance3D.new()
	instance.name = label
	instance.multimesh = gpu
	instance.material_override = mat
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.visibility_range_end = far_limit
	add_child(instance)
	near_details.append(instance)
	batch_count += 1

func _build_road_infrastructure() -> void:
	# 52 m avenue grid; all geometry sits above the existing road but below tire axles.
	var RNG := RandomNumberGenerator.new()
	RNG.seed = 20261023
	var chrome: StandardMaterial3D = _material(Color("8d9da1"),0.72,0.31)
	var tar: StandardMaterial3D = _material(Color("30343a"),0.03,0.91)
	var amber: StandardMaterial3D = _material(Color("ecbf69"),0.24,0.32,true)
	var stone: StandardMaterial3D = _material(Color("a3a49a"),0.05,0.83)
	var iron: StandardMaterial3D = _material(Color("586672"),0.76,0.47)
	var repair_mesh := BoxMesh.new()
	repair_mesh.size = Vector3.ONE
	var grating_mesh := BoxMesh.new()
	grating_mesh.size = Vector3.ONE
	var bolt_mesh := CylinderMesh.new()
	bolt_mesh.top_radius = .5
	bolt_mesh.bottom_radius = .5
	bolt_mesh.height = 1.0
	bolt_mesh.radial_segments = 8
	var repair_poses: Array[Transform3D] = []
	var repair_colors: Array[Color] = []
	var grate_poses: Array[Transform3D] = []
	var grate_colors: Array[Color] = []
	var curb_poses: Array[Transform3D] = []
	var curb_colors: Array[Color] = []
	var bolt_poses: Array[Transform3D] = []
	var bolt_colors: Array[Color] = []
	var reflections: Array[Transform3D] = []
	var reflection_colors: Array[Color] = []
	for grid in range(-4,5):
		var axis: float = float(grid)*52.0
		for step in range(-10,11):
			var along: float = float(step)*20.0
			var x_patch: float = along+RNG.randf_range(-2.7,2.7)
			var z_patch: float = axis+RNG.randf_range(-2.5,2.5)
			var width: float = RNG.randf_range(1.1,2.5)
			var depth: float = RNG.randf_range(1.3,4.2)
			repair_poses.append(Transform3D(Basis().scaled(Vector3(width,.013,depth)),Vector3(x_patch,.202,z_patch)))
			repair_colors.append(Color("858a8a") if step%3==0 else Color("747b7c"))
			repair_poses.append(Transform3D(Basis().scaled(Vector3(depth,.013,width)),Vector3(z_patch,.204,x_patch)))
			repair_colors.append(Color("858a8a"))
			for side in [-1.0,1.0]:
				var edge: float = axis+side*4.92
				# Two grate cheeks and dark opening; old road still owns collision.
				for tooth in range(3):
					var z: float = along+float(tooth-1)*.27
					grate_poses.append(Transform3D(Basis().scaled(Vector3(.68,.028,.052)),Vector3(along,.219,edge+float(tooth-1)*.25)))
					grate_colors.append(Color("9dabae"))
					grate_poses.append(Transform3D(Basis().scaled(Vector3(.052,.028,.68)),Vector3(edge+float(tooth-1)*.25,.219,along)))
					grate_colors.append(Color("8f9fa4"))
				curb_poses.append(Transform3D(Basis().scaled(Vector3(.17,.075,2.3)),Vector3(along,.163,axis+side*6.9)))
				curb_colors.append(Color("91968d"))
				curb_poses.append(Transform3D(Basis().scaled(Vector3(2.3,.075,.17)),Vector3(axis+side*6.9,.163,along)))
				curb_colors.append(Color("9ba49b"))
				var seat: float = axis+side*6.6
				bolt_poses.append(Transform3D(Basis().scaled(Vector3(.09,.04,.09)),Vector3(along,.202,seat)))
				bolt_colors.append(Color("a6b5b8"))
				bolt_poses.append(Transform3D(Basis().scaled(Vector3(.09,.04,.09)),Vector3(seat,.202,along)))
				bolt_colors.append(Color("a6b5b8"))
				reflections.append(Transform3D(Basis().scaled(Vector3(.12,.04,.36)),Vector3(along,.213,axis+side*4.64)))
				reflection_colors.append(Color("d9b775") if step%2==0 else Color("d8e4d4"))
				reflections.append(Transform3D(Basis().scaled(Vector3(.36,.04,.12)),Vector3(axis+side*4.64,.213,along)))
				reflection_colors.append(Color("d9b775"))
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	_batch("R5AsphaltPatches",repair_mesh,repair_poses,repair_colors,tar,230.0)
	_batch("R5StormDrainTeeth",grating_mesh,grate_poses,grate_colors,iron,165.0)
	_batch("R5KerbStoneMouldings",box,curb_poses,curb_colors,stone,230.0)
	_batch("R5GuardrailBoltHeads",bolt_mesh,bolt_poses,bolt_colors,chrome,135.0)
	_batch("R5RoadCatEyeMarkers",box,reflections,reflection_colors,amber,260.0)
	drain_count = grate_poses.size()
	fastener_count = bolt_poses.size()
	curb_count = curb_poses.size()

func _build_green_strips() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 907234
	wind_surface = ShaderMaterial.new()
	wind_surface.shader = WIND
	var leaf := QuadMesh.new()
	leaf.size = Vector2(.57,1.0)
	var transforms: Array[Transform3D] = []
	var colors: Array[Color] = []
	for col in range(9):
		for row in range(9):
			var bx: float = float(col-4)*52.0
			var bz: float = float(row-4)*52.0
			for blade in range(12):
				var dx: float = rng.randf_range(-19.0,19.0)
				var dz: float = rng.randf_range(-19.0,19.0)
				var x: float = bx+dx
				var z: float = bz+dz
				# No plants inside car lanes; isolate ornamental park-edge patches.
				if absf(dx)<8.0 or absf(dz)<8.0:
					continue
				var h: float = rng.randf_range(.24,.71)
				var scale := Vector3(rng.randf_range(.62,1.4),h,1.0)
				var basis := Basis(Vector3.UP,rng.randf_range(0.0,TAU)).scaled(scale)
				transforms.append(Transform3D(basis,Vector3(x,h*.48,z)))
				colors.append(Color("749c75"))
	_batch("R5WindAnimatedCoastalGrass",leaf,transforms,colors,wind_surface,160.0)
	foliage_count = transforms.size()

func _build_facade_accents() -> void:
	# Dimensional stone ledges, eaves, canopy hardware around four known landmarks.
	var columns: Array[Transform3D] = []
	var colors: Array[Color] = []
	var crown: Array[Transform3D] = []
	var metals: Array[Color] = []
	for px in [-130.0,130.0]:
		for pz in [-130.0,130.0]:
			for story in range(3):
				var h: float = 3.4+float(story)*4.4
				columns.append(Transform3D(Basis().scaled(Vector3(25.8,.22,.28)),Vector3(px,h,pz+12.62)))
				colors.append(Color("b4b9ab"))
				for bay in range(6):
					var x: float = px-10.2+float(bay)*4.08
					crown.append(Transform3D(Basis().scaled(Vector3(.12,2.4,.17)),Vector3(x,h+1.1,pz+12.7)))
					metals.append(Color("657c83"))
	var unit := BoxMesh.new()
	unit.size = Vector3.ONE
	_batch("R5ArchitecturalStoneLedges",unit,columns,colors,_material(Color.WHITE,.04,.80),400.0)
	_batch("R5FacadeStructuralRibs",unit,crown,metals,_material(Color.WHITE,.70,.35),400.0)

func bind_world(game_world) -> void:
	world = game_world
	wet_surface = ShaderMaterial.new()
	wet_surface.shader = ASPHALT
	wet_surface.set_shader_parameter("aggregate_albedo",world.asphalt_pbr.albedo_texture)
	wet_surface.set_shader_parameter("aggregate_normal",world.asphalt_pbr.normal_texture)
	for holder in world.city_root.get_children():
		if holder.name != "EastWestRoad" and holder.name != "NorthSouthRoad":
			continue
		var mesh: MeshInstance3D = holder.get_node_or_null("VisualMesh") as MeshInstance3D
		if mesh == null:
			continue
		original_surfaces[mesh] = mesh.material_override
	set_profile("standard")

func set_profile(mode: String) -> void:
	quality = mode if mode in ["low","standard","cinematic"] else "standard"
	for mesh in original_surfaces.keys():
		if is_instance_valid(mesh):
			mesh.material_override = original_surfaces[mesh] if quality == "low" else wet_surface
	for detail in near_details:
		detail.visible = quality != "low"
	if wind_surface != null:
		wind_surface.set_shader_parameter("wind_strength",.24 if quality == "standard" else .50)
	if wet_surface != null:
		wet_surface.set_shader_parameter("micro_strength",.40 if quality == "standard" else .67)
	_update_postfx()

func set_weather(kind: String) -> void:
	weather_kind = kind
	_update_postfx()

func _update_postfx() -> void:
	if world == null or world.sky_environment == null:
		return
	var env: Environment = world.sky_environment.environment
	if env == null:
		return
	var desktop: bool = RenderingServer.get_current_rendering_method() == "forward_plus"
	var high: bool = quality == "cinematic"
	var rain: bool = weather_kind == "rain" or weather_kind == "storm"
	env.adjustment_enabled = quality != "low"
	env.adjustment_saturation = .92 if rain else 1.01
	env.adjustment_contrast = 1.045 if high else 1.015
	env.glow_enabled = high and desktop
	env.glow_intensity = .23
	env.ssao_enabled = high and desktop
	env.ssil_enabled = high and desktop
	env.ssr_enabled = high and desktop and rain
	env.fog_enabled = rain
	env.fog_density = .0019 if rain else .0008

func _process(delta: float) -> void:
	if wet_surface != null:
		var rain: bool = weather_kind == "rain" or weather_kind == "storm"
		wetness = move_toward(wetness,1.0 if rain else 0.0,delta*.32)
		wet_surface.set_shader_parameter("rain_wetness",wetness)

func diagnostic() -> Dictionary:
	return {"release":"R5","batches":batch_count,"storm_grate_bars":drain_count,"metal_fasteners":fastener_count,"stone_mouldings":curb_count,"wind_grass":foliage_count,"road_meshes":original_surfaces.size(),"profile":quality,"wetness":wetness}
