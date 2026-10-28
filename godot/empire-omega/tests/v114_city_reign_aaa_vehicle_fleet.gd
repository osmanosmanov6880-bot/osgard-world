extends SceneTree
## CITY REIGN AAA A5: four genuinely different cached closed 3D traffic
## silhouettes on existing original CharacterBody3D physics and road routes.
## This validates real Godot geometry, not a style guide screenshot.
const ART = preload("res://scripts/horizon_traffic_sedan_surface.gd")
const TRAFFIC = preload("res://scripts/traffic_agent.gd")
const STYLES = ["sedan","taxi","courier","executive"]
var passed: int = 0
var failed: int = 0

func check(ok: bool,why: String) -> void:
	if ok:
		passed += 1
	else:
		failed += 1
		push_error("CITY REIGN AAA VEHICLE FAIL: "+why)

func _initialize() -> void:
	call_deferred("_run")

func _check_native_mesh(mesh: ArrayMesh,part: String,style: String) -> void:
	check(mesh != null and mesh.get_surface_count()==1,
		"actual "+part+" "+style+" is one original real GPU source mesh")
	if mesh == null or mesh.get_surface_count()!=1: return
	var arrays: Array = mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	check(vertices.size() == colors.size() and vertices.size() == normals.size()
		and vertices.size()<=1550,
		"bounded per-model PBR color and normals, no uncontrolled geometry")
	var low := Vector3(INF,INF,INF)
	var high := Vector3(-INF,-INF,-INF)
	for i in range(vertices.size()):
		check(vertices[i].is_finite() and normals[i].is_finite(),
			"finite source geometry at "+part+"/"+style+"/"+str(i))
		low = low.min(vertices[i])
		high = high.max(vertices[i])
	check(high.x-low.x>1.75 and high.z-low.z>2.1 and high.y-low.y>0.28,
		"physically three-dimensional, not a camera facing sprite "+part+"/"+style)

func _run() -> void:
	var state: Node = root.get_node_or_null("GameState")
	check(state != null,"authentic city state autoload")
	if state == null:
		quit(2)
		return
	var old_state: Dictionary = state.data.duplicate(true)
	var old_lang: String = str(state.locale)
	var initial_budget: Dictionary = ART.vertex_budget()
	check(initial_budget["body"]==828 and initial_budget["cabin"]==648 and
		initial_budget["wheel"]==576,
		"R126 original base chassis/cabin/wheel source vertices remain EXACT")
	check(ART.body_mesh_for("sedan")==ART.body_mesh() and
		ART.cabin_mesh_for("sedan")==ART.cabin_mesh() and
		ART.body_mesh_for("invalid")==ART.body_mesh(),
		"original legacy sedan and unsupported style preserve exact original mesh")
	var names: Dictionary = {}
	var bodies: Dictionary = {}
	var roofs: Dictionary = {}
	var fleet: Array[CharacterBody3D] = []
	for i in range(12):
		var style: String = STYLES[i%STYLES.size()]
		var car: CharacterBody3D = TRAFFIC.new()
		car.set("visual_style",style)
		root.add_child(car)
		fleet.append(car)
		names[style] = int(names.get(style,0))+1
		var chassis: MeshInstance3D = car.get_node("CarBody") as MeshInstance3D
		var cabin: MeshInstance3D = car.get_node("Cabin") as MeshInstance3D
		check(chassis != null and cabin != null and car.get_child_count()==11,
			"real city car has exactly original 11 nodes, no extra GPU draw nodes")
		check(chassis.mesh==ART.body_mesh_for(style) and
			cabin.mesh==ART.cabin_mesh_for(style),
			"vehicle family actually changes source 3D geometry: "+style)
		check((car.get("wheels") as Array).size()==4 and
			(car.get("brake_meshes") as Array).size()==2,
			"four physical wheels and two brake lights retained: "+style)
		var collision_count: int = 0
		for node in car.get_children():
			if node is CollisionShape3D:
				collision_count += 1
				var box: BoxShape3D = (node as CollisionShape3D).shape as BoxShape3D
				check(box != null and box.size.is_equal_approx(Vector3(2.25,1.15,4.1)),
					"authoritative physical vehicle bounding box never changes")
		check(collision_count==1 and car.collision_layer==8 and
			(car.collision_mask & 15)==15,
			"exactly one unchanged traffic physics body with original road layer")
		if not bodies.has(style):
			bodies[style] = chassis.mesh
			roofs[style] = cabin.mesh
		else:
			check(bodies[style]==chassis.mesh and roofs[style]==cabin.mesh,
				"repeat instances of "+style+" share the exact same two GPU meshes")
		car.call("set_visual_quality","low")
		check(chassis.mesh==ART.body_mesh() and cabin.mesh==ART.cabin_mesh() and
			car.get_child_count()==11,
			"mobile low mode returns to the exact original shared meshes")
		car.call("set_visual_quality","cinematic")
		check(chassis.mesh==ART.body_mesh_for(style) and
			cabin.mesh==ART.cabin_mesh_for(style),
			"cinematic tier restores authored original source geometry")
		car.call("set_visual_quality","standard")
		check(chassis.mesh==ART.body_mesh_for(style) and
			cabin.mesh==ART.cabin_mesh_for(style),
			"standard tier retains differentiated cars with no new physics")
	for style in STYLES:
		check(int(names.get(style,0))==3,
			"fleet is precisely 3 "+style+" cars instead of 12 copies")
		_check_native_mesh(ART.body_mesh_for(style),"body",style)
		_check_native_mesh(ART.cabin_mesh_for(style),"cabin",style)
	check(ART.total_cached_variant_meshes()==6,
		"all 12 ambient vehicles share only 6 NEW cached art meshes")
	for style in ["taxi","courier","executive"]:
		check(ART.body_mesh_for(style)!=ART.body_mesh() and
			ART.cabin_mesh_for(style)!=ART.cabin_mesh(),
			"visible car variants have different original real 3D geometry")
		check(ART.body_mesh_for(style).surface_get_array_len(0)>
			ART.body_mesh().surface_get_array_len(0) and
			ART.cabin_mesh_for(style).surface_get_array_len(0)>
			ART.cabin_mesh().surface_get_array_len(0),
			"unique physical shaped grille, roof and panels are in source draw surface")
	check(ART.cabin_mesh_for("courier").get_aabb().size.y>
		ART.cabin_mesh().get_aabb().size.y,
		"courier genuinely has raised 3D service roof silhouette")
	# Existing police vehicle is specifically NOT a taxi or courier:
	# retain its verified original patrol body and 2 independent sirens.
	var patrol: CharacterBody3D = TRAFFIC.new()
	patrol.set("patrol_vehicle",true)
	patrol.set("visual_style","taxi")
	root.add_child(patrol)
	patrol.call("set_visual_quality","cinematic")
	check((patrol.get_node("CarBody") as MeshInstance3D).mesh==ART.body_mesh()
		and patrol.get_child_count()==13,
		"original police model and two real siren nodes remain unchanged")
	patrol.queue_free()
	for car in fleet:
		car.queue_free()
	await process_frame
	# Full ORIGINAL game scene: confirm the real 12-car city instantiates
	# differentiated models before production images/graphics are judged.
	state.data = state.new_game()
	var baseline: Dictionary = state.data.duplicate(true)
	var loaded: Error = change_scene_to_file("res://scenes/main.tscn")
	check(loaded==OK,"real shipped playable city scene imports with AAA traffic")
	if loaded != OK:
		state.data = old_state
		state.locale = old_lang
		quit(1)
		return
	await process_frame
	await physics_frame
	var scene: Node3D = current_scene as Node3D
	var actual_cars: Array = scene.get("ambient_cars")
	check(actual_cars.size()==12 and (scene.get("pedestrians") as Array).size()==34,
		"actual game retains all 12 cars and 34 physically located citizens")
	var distribution: Dictionary = {}
	for car in actual_cars:
		var style: String = str(car.get("visual_style"))
		distribution[style] = int(distribution.get(style,0))+1
		var mesh: MeshInstance3D = car.get_node("CarBody") as MeshInstance3D
		check(mesh != null,"scene fleet has actual physical chassis geometry")
		car.call("set_visual_quality","cinematic")
		check(mesh.mesh==ART.body_mesh_for(style),
			"actual city vehicle uses authored unique real 3D mesh in cinematic tier")
		var route: Array = car.get("points")
		check(route.size()>=2 and car.collision_layer==8,
			"actual car still drives along its original valid physical route")
	for style in STYLES:
		check(int(distribution.get(style,0))==3,
			"gameplay scene visibly contains 3 "+style+" source models")
	var city_wallet: int = int(state.data["wallet"])
	var treasury: int = int(state.data["treasury"])
	for car in actual_cars:
		var before_route: Array = car.get("points")
		var before_speed: float = float(car.get("cruising_speed"))
		car.call("set_visual_quality","low")
		check((car.get_node("CarBody") as MeshInstance3D).mesh==ART.body_mesh() and
			(car.get_node("Cabin") as MeshInstance3D).mesh==ART.cabin_mesh(),
			"low graphics immediately reuses original cheap 3D fleet materials")
		check(car.get("points")==before_route and
			is_equal_approx(float(car.get("cruising_speed")),before_speed),
			"visual tier has NO authority to change route or AI vehicle speed")
	check(int(state.data["wallet"])==city_wallet and
		int(state.data["treasury"])==treasury and
		int(state.data["mission"])==int(baseline["mission"]),
		"AAA vehicle design does not fabricate economic rewards or advance missions")
	current_scene.queue_free()
	await process_frame
	state.data = old_state
	state.locale = old_lang
	print("CITY REIGN AAA sculpted original fleet: %d PASS %d FAIL" % [passed,failed])
	quit(0 if failed==0 else 1)
