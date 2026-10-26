extends SceneTree
## R127: actual original Godot volumetric street shelters in live R90 city.
## B2 ART source/physics regression only, NOT AAA reference sign-off.
const KIT = preload("res://scripts/horizon_r127_street_shelters.gd")
var passed: int = 0
var failed: int = 0

func check(ok: bool, message: String) -> void:
	if ok:
		passed += 1
	else:
		failed += 1
		push_error("R127 REAL STREET ART FAIL: "+message)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var state: Node = root.get_node_or_null("GameState")
	check(state!=null,"the original GameState autoload is present")
	if state == null:
		quit(1)
		return
	var original: Dictionary = (state.get("data") as Dictionary).duplicate(true)
	# R124 pattern: load full WorldBuilder only after the authoritative
	# GameState singleton is mounted. This proves a real rendered city origin.
	var world_source: Variant = load("res://scripts/world_builder.gd")
	check(world_source is Script and world_source.can_instantiate(),
		"actual authoritative WorldBuilder compiles after genuine autoload")
	if not (world_source is Script and world_source.can_instantiate()):
		quit(1)
		return
	var world: Node3D = world_source.new()
	root.add_child(world)
	var city: Node3D = world.get("r90_urban") as Node3D
	var shelter: MultiMeshInstance3D = world.get("r127_shelters") as MultiMeshInstance3D
	check(city!=null,"the real original WorldBuilder still owns R90 skyline")
	if city==null:
		world.queue_free()
		await process_frame
		quit(1)
		return
	var skyline: MultiMeshInstance3D = city.get("skyline") as MultiMeshInstance3D
	var bollards: MultiMeshInstance3D = city.get("bollards") as MultiMeshInstance3D
	var architecture: Node3D = city.get("r91_architecture") as Node3D
	check(city.get_child_count()==3,"three original R90 root batches are retained, without replacement")
	check(skyline!=null and skyline.multimesh.instance_count==72,"72 exact R90 tower instances remain")
	check(bollards!=null and bollards.multimesh.instance_count==144,"144 existing bollards remain")
	check(architecture!=null and architecture.get_child_count()==2,"R91 original window and roof GPU batches remain")
	check(shelter!=null,"real R127 street furniture is mounted in the actual urban scene")
	if shelter == null:
		world.queue_free()
		await process_frame
		quit(1)
		return
	check(shelter.get_parent()==world.get("city_root") and
		(architecture.get("facade_glass") as MultiMeshInstance3D).get_child_count()==0,
		"extra independent 3D batch lives in original WorldBuilder WITHOUT touching R119 windows")
	check(shelter.get_child_count()==0,
		"no per-shelter children or new physics bodies alter mission roads")
	check(shelter.multimesh.instance_count==KIT.SHELTER_COUNT and KIT.SHELTER_COUNT==24,
		"24 original deterministic roadside structures share one GPU draw source")
	check(bool(shelter.call("bounded")) and bool(city.call("graphics_are_bounded")),
		"R90+R127 source geometry is fully bounded")
	var mesh: ArrayMesh = shelter.multimesh.mesh as ArrayMesh
	check(mesh!=null and mesh.get_surface_count()==1,
		"one original actual volumetric mesh surface, no 2D sprite or billboard")
	if mesh != null and mesh.get_surface_count()==1:
		var arrays: Array = mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
		check(vertices.size()>=400 and vertices.size()<=1500,
			"authored bus shelter has bounded 3D panels, columns, bench and trim")
		check(normals.size()==vertices.size() and colors.size()==vertices.size(),
			"every original mesh face uses real native light normals and material color")
		var min_v := Vector3(INF,INF,INF)
		var max_v := Vector3(-INF,-INF,-INF)
		var palette: Dictionary = {}
		for i in range(vertices.size()):
			check(vertices[i].is_finite() and normals[i].is_finite(),
				"all actual shelter vertices and normals must remain finite")
			min_v=min_v.min(vertices[i])
			max_v=max_v.max(vertices[i])
			palette[str(colors[i])]=true
		check(max_v.x-min_v.x>1.6 and max_v.y-min_v.y>2.4 and max_v.z-min_v.z>3.8,
			"shelter is true 3D world geometry, not a front-facing concept image")
		check(palette.size()>=5,"metal, glass, brass, bench and transit accent are distinct")
	var finish: StandardMaterial3D = shelter.material_override as StandardMaterial3D
	check(finish!=null and finish.vertex_color_use_as_albedo and
		finish.shading_mode!=BaseMaterial3D.SHADING_MODE_UNSHADED and
		not finish.emission_enabled and finish.roughness>0.2,
		"real source material receives Godot world sun and environment shading")
	var positions: Dictionary = {}
	for i in range(KIT.SHELTER_COUNT):
		var position: Vector3 = KIT.position_for(i)
		var axis: float = float(-156+(i%6)*52)
		check(position.is_finite() and is_equal_approx(absf(position.x-axis),8.35),
			"every true 3D shelter remains outside the 10m-wide physics road corridor")
		check(absf(position.y)<0.01 and absf(position.z)<210.0,
			"all 3D furniture remains at ground height inside bounded city")
		positions[str(position)]=true
	check(positions.size()==KIT.SHELTER_COUNT,
		"all 24 deterministic shelter transforms occupy distinct real world positions")
	world.call("apply_visual_budget","low")
	check(not shelter.visible and not (architecture.get("facade_glass") as MultiMeshInstance3D).visible,
		"mobile LOW hides ornamental glass and shelter batch without source rewrites")
	world.call("apply_visual_budget","standard")
	check(shelter.visible and (architecture.get("facade_glass") as MultiMeshInstance3D).visible
		and not bollards.visible,"STANDARD adds live street texture while keeping bollard draw off")
	world.call("apply_visual_budget","cinematic")
	check(shelter.visible and skyline.visible and bollards.visible,
		"CINEMATIC retains original 3D city and all authored street detail")
	check(state.get("data")==original,
		"visual B2 never writes wallet, campaign, traffic law, physics or save state")
	world.queue_free()
	await process_frame
	print("EMPIRE OMEGA R127 ORIGINAL 3D STREET FURNITURE: %d PASS %d FAIL" % [passed,failed])
	quit(0 if failed==0 else 1)
