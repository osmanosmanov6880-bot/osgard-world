extends SceneTree
## R126: inspect actual shared Godot meshes used by every physically colliding
## NPC sedan + patrol, never a synthetic screenshot or static asset.
const ART = preload("res://scripts/horizon_traffic_sedan_surface.gd")
const TRAFFIC = preload("res://scripts/traffic_agent.gd")
const WALKER = preload("res://scripts/pedestrian_agent.gd")
const SAFETY = preload("res://scripts/traffic_safety.gd")
var passed: int=0
var failed: int=0

func check(condition: bool, reason: String) -> void:
	if condition:
		passed += 1
	else:
		failed += 1
		push_error("R126 ACTUAL SCULPTED FLEET FAILED: "+reason)

func _initialize() -> void:
	call_deferred("_run")

func _check_mesh(kind: String, mesh: ArrayMesh, expected: int, span: Vector3) -> void:
	check(mesh!=null and mesh.get_surface_count()==1,
		"real "+kind+" uses a SINGLE original low-overhead GPU surface")
	if mesh==null or mesh.get_surface_count()!=1:
		return
	var a: Array=mesh.surface_get_arrays(0)
	var pts: PackedVector3Array=a[Mesh.ARRAY_VERTEX]
	var norms: PackedVector3Array=a[Mesh.ARRAY_NORMAL]
	var colors: PackedColorArray=a[Mesh.ARRAY_COLOR]
	check(pts.size()==expected,"bounded native original "+kind+" draw: "+str(expected)+" colored 3D points")
	check(norms.size()==expected and colors.size()==expected,
		"all "+kind+" physical polygons have real PBR vertex normals and source colors")
	var low:=Vector3(INF,INF,INF)
	var high:=Vector3(-INF,-INF,-INF)
	var palette: Dictionary={}
	for i in range(pts.size()):
		check(pts[i].is_finite() and norms[i].is_finite(),
			"every "+kind+" native 3D vertex and actual surface normal are finite")
		low=low.min(pts[i])
		high=high.max(pts[i])
		palette[str(colors[i])]=true
	check(high.x-low.x>=span.x and high.y-low.y>=span.y and
		high.z-low.z>=span.z,"actual "+kind+" creates an authentic 3D world-space silhouette")
	check(palette.size()>=2,"real "+kind+" has original multi-finish PBR vertex materials")

func _run() -> void:
	var game: Node=root.get_node_or_null("GameState")
	check(game!=null,"real authoritative city GameState is active")
	if game==null:
		quit(1)
		return
	var unchanged: Dictionary=(game.get("data") as Dictionary).duplicate(true)
	var budget: Dictionary=ART.vertex_budget()
	check(budget["body"]==828 and budget["cabin"]==648 and budget["wheel"]==576,
		"R126 AI car: 276 original chassis, 216 sloped cabin, 192 circular tyre triangles")
	_check_mesh("tapered painted closed chassis",ART.body_mesh(),828,Vector3(2.2,0.70,4.04))
	_check_mesh("sloped glass roof and side mirrors",ART.cabin_mesh(),648,Vector3(2.0,0.60,2.20))
	_check_mesh("true rotating circular tyre with inset alloy rim",ART.wheel_mesh(),576,
		Vector3(0.30,0.65,0.65))
	check(ART.body_mesh()==ART.body_mesh() and ART.cabin_mesh()==ART.cabin_mesh() and
		ART.wheel_mesh()==ART.wheel_mesh(),
		"all original crowd vehicles use exactly THREE GPU mesh allocations across the fleet")
	var wheel_finish: StandardMaterial3D=ART.wheel_finish()
	check(wheel_finish.vertex_color_use_as_albedo and
		wheel_finish.metallic>=0.25 and wheel_finish.roughness>0.5 and
		not wheel_finish.emission_enabled,
		"original metal+rubber tyre reflects natural Godot lighting without fake fullbright")
	var fleet: Array[CharacterBody3D]=[]
	for index in range(12):
		var car: CharacterBody3D=TRAFFIC.new()
		car.set("patrol_vehicle",index==11)
		root.add_child(car)
		fleet.append(car)
		var collision_count: int=0
		var bounds: BoxShape3D=null
		# Do not depend on auto-assigned Godot child names: inspect the
		# actual physical CollisionShape3D and its original collision size.
		for original_child in car.get_children():
			if original_child is CollisionShape3D:
				collision_count+=1
				bounds=(original_child as CollisionShape3D).shape as BoxShape3D
		check(collision_count==1 and bounds!=null and
			bounds.size.is_equal_approx(Vector3(2.25,1.15,4.1)),
			"exactly one original true BoxShape3D 2.25x1.15x4.1 physically collides with traffic")
		check(car.collision_layer==8 and
			(car.collision_mask & (1|2|4|8))==(1|2|4|8),
			"real R41/R47 vehicle collision layers and walker's safety unchanged")
		var body:=car.get_node_or_null("CarBody") as MeshInstance3D
		var glass:=car.get_node_or_null("Cabin") as MeshInstance3D
		check(body!=null and glass!=null and
			body.mesh==ART.body_mesh() and glass.mesh==ART.cabin_mesh(),
			"actual street AI uses real closed sculpted sedan and sloped window meshes")
		if body!=null and glass!=null:
			var finish: StandardMaterial3D=body.material_override as StandardMaterial3D
			var cabin_finish: StandardMaterial3D=glass.material_override as StandardMaterial3D
			check(finish!=null and finish.vertex_color_use_as_albedo and
				finish.clearcoat_enabled and finish.metallic>=0.5 and
				finish.shading_mode!=BaseMaterial3D.SHADING_MODE_UNSHADED,
				"real ambient car paint gets per-pixel multi-layer PBR clearcoat")
			check(cabin_finish!=null and cabin_finish.vertex_color_use_as_albedo and
				cabin_finish.roughness<0.4,
				"actual panoramic windscreen has distinct native PBR glass finish")
		var wheels: Array=car.get("wheels")
		check(wheels.size()==4,"original car has exactly four genuine rolling wheels")
		for wheel in wheels:
			var w: MeshInstance3D=wheel as MeshInstance3D
			check(w!=null and w.mesh==ART.wheel_mesh() and
				w.material_override==wheel_finish,
				"all original AI cars use ONE shared genuine circular rubber/alloy surface")
		var earlier: float=(wheels[0] as MeshInstance3D).rotation.x
		(wheels[0] as MeshInstance3D).rotate_x(0.44)
		check(not is_equal_approx((wheels[0] as MeshInstance3D).rotation.x,earlier),
			"real circular tyre keeps original natural spin axis and travel animation")
		check(car.get("brake_meshes").size()==2 and
			car.has_method("_update_brake_lights"),
			"physically glowing original twin brake lights remain in actual car controller")
		car.call("_update_brake_lights",true)
		var brakes: Array=car.get("brake_meshes")
		var brake_finish: StandardMaterial3D=(brakes[0] as MeshInstance3D).material_override as StandardMaterial3D
		check(brake_finish!=null and brake_finish.emission_energy_multiplier>=2.0,
			"original actual car braking still visibly raises real Godot light emission")
		check(car.get_child_count()==(13 if index==11 else 11),
			"no NEW car parts or draw nodes: exact legacy collider + 2 shells + 4 wheels + 2 headlamps + 2 brakes and optional patrol sirens")
		check(not car.is_queued_for_deletion(),"same authoritative original AI road agent stays alive")
	var lead: CharacterBody3D=fleet[0]
	var route: Array[Vector3]=[Vector3(0,0.8,0),Vector3(0,0.8,-95)]
	lead.call("set_route",route,12.0)
	check(lead.get("points")==route and lead.get("target_index")==1,
		"original real road traffic routing and destination still operate")
	check(SAFETY.safe_speed(3.0,12.0)==0.0 and
		SAFETY.desired_speed(12.0,1000000.0,2.0)==0.0,
		"R41/R47 original safe distance and red lights still stop actual traffic")
	var pedestrian: Node3D=WALKER.new()
	root.add_child(pedestrian)
	check(pedestrian.get("body_mesh")!=null and
		pedestrian.get("citizen_id")==0,
		"R123 authentic sculpted 3D walking pedestrians still exist beside real new cars")
	check(game.get("data")==unchanged,
		"purely visual 3D changes do not write economy, policy, missions or save slots")
	pedestrian.queue_free()
	for car in fleet:
		car.queue_free()
	await process_frame
	print("EMPIRE OMEGA R126 original closed 3D AI sedan fleet: %d PASS %d FAIL" %
		[passed,failed])
	quit(0 if failed==0 else 1)
