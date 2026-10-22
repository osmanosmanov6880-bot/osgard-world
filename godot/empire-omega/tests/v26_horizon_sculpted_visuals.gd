extends SceneTree
## Actual Godot 4.4.1 validation for the procedural R4 sports car and roadside.
const SCULPT = preload("res://scripts/horizon_coupe_sculpt.gd")
const CAR = preload("res://scripts/vehicle_controller.gd")
const SCENERY = preload("res://scripts/horizon_scenery_r4.gd")
const ROAD = preload("res://scripts/horizon_roadscape.gd")
var passes := 0
var failures := 0

func expect(ok: bool, msg: String) -> void:
	if ok: passes += 1
	else:
		failures += 1
		push_error("HORIZON R4 FAILED: "+msg)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var bounds: AABB = SCULPT.profile_bounds(SCULPT.BODY_PROFILE)
	expect(bounds.size.z>5.0 and bounds.size.x>2.3,"sculpt profile spans a full-sized car")
	var car: CharacterBody3D = CAR.new()
	root.add_child(car)
	var art: Node3D = car.get_node_or_null("HorizonCoupe")
	expect(art!=null,"swept body wired into driveable car")
	if art!=null:
		var shell := art.get_node_or_null("FlowBody") as MeshInstance3D
		var canopy := art.get_node_or_null("AerodynamicGreenhouse") as MeshInstance3D
		expect(shell!=null and canopy!=null,"replaced blocky chassis with two curved shells")
		if shell!=null and shell.mesh!=null:
			expect(shell.mesh is ArrayMesh and shell.mesh.surface_get_array_len(0)>=800,"actual mesh has many real triangles")
			expect(shell.visible,"sports body rendered, not merely generated")
		if canopy!=null and canopy.mesh!=null:
			expect(canopy.mesh.surface_get_array_len(0)>300,"roof has sloping mesh profile")
		for old_name in ["FrontNose","RearDeck","Cabin","Roof","HoodHighlight"]:
			var block := art.get_node_or_null(old_name) as MeshInstance3D
			expect(block!=null and not block.visible,"legacy cuboid "+old_name+" is hidden")
		var rims: Array = art.get("wheel_rigs")
		expect(rims.size()==4,"four independent wheels retained")
		for rig in rims:
			var roller: Node3D = rig.get_node("RollingWheel")
			expect(roller.get_node_or_null("MachinedSpoke_0")!=null and roller.get_node_or_null("MachinedSpoke_4")!=null,"real five-spoke rims")
		car.apply_variant("compact")
		var coating: StandardMaterial3D = shell.material_override as StandardMaterial3D if shell!=null else null
		expect(coating!=null and coating.metallic>=0.6,"garage repaint affects visible metallic mesh")
		art.call("simulate_chassis",21.0,0.4,-7.0,0.9,true,[0.1,0.0,0.1,0.0],0.016)
		expect(absf(float(art.get("roll_angle")))>0.0,"curved body responds to suspension")
	var detail: Node3D = SCENERY.new()
	root.add_child(detail)
	expect(int(detail.get("shrub_count"))>=250,"parks contain original GPU shrub meshes")
	expect(int(detail.get("sign_count"))>=16,"wayfinding signs are built")
	expect(int(detail.get("reflector_count"))>=270,"outer road guardrails have reflectors")
	expect(int(detail.get("batch_count"))>=9,"roadside meshes use GPU instancing")
	var rails := detail.get_node_or_null("RoadGuardrailBeams") as MultiMeshInstance3D
	expect(rails!=null and rails.multimesh.instance_count>=250,"physical guardrail geometry instantiated")
	var flowers := detail.get_node_or_null("WildflowerPetals") as MultiMeshInstance3D
	expect(flowers!=null and flowers.multimesh.instance_count>=500,"flowers are actual separate meshes")
	var world: Node3D = ROAD.new()
	root.add_child(world)
	expect(world.get_node_or_null("HorizonSceneryR4")!=null,"R4 environment connected to existing scenery")
	expect(int(world.get("tree_count"))>=190,"existing forest survives")
	detail.queue_free()
	world.queue_free()
	car.queue_free()
	print("HORIZON R4 NATIVE: %d PASS, %d FAIL" % [passes,failures])
	quit(0 if failures==0 else 1)
