extends SceneTree
## Native 4.4.1 gate: real Godot shaders, world binding, gameplay-safe instancing.
const WORLD = preload("res://scripts/world_builder.gd")
const R5 = preload("res://scripts/horizon_cinematic_r5.gd")
var tested: int = 0
var failed: int = 0
func expect(ok: bool, msg: String) -> void:
	tested += 1
	if not ok:
		failed += 1
		push_error("R5 CINEMATIC NATIVE FAIL: "+msg)
	else:
		print("R5 CINEMATIC NATIVE PASS: "+msg)

func _initialize() -> void:
	call_deferred("_test")

func _test() -> void:
	expect(load("res://shaders/horizon_r5_asphalt.gdshader") is Shader,"real native asphalt shader")
	expect(load("res://shaders/horizon_r5_wind.gdshader") is Shader,"real wind vertex shader")
	var world: Node3D = WORLD.new()
	root.add_child(world)
	var visual: Node3D = world.get_node_or_null("HorizonCinematicR5")
	expect(visual != null,"cinematic node is mounted into actual world")
	if visual != null:
		var initial: Dictionary = visual.call("diagnostic")
		expect(int(initial.get("batches",0)) >= 7,"GPU-batched architectural details")
		expect(int(initial.get("stone_mouldings",0)) >= 500,"dimensional curb edges")
		expect(int(initial.get("storm_grate_bars",0)) >= 1100,"physical storm drain teeth")
		expect(int(initial.get("road_meshes",0)) >= 18,"wet shader actually assigned to road mesh")
		visual.call("set_profile","cinematic")
		visual.call("set_weather","rain")
		for frame in range(7):
			await process_frame
		expect(float(visual.get("wetness")) > 0.0,"wetness responds to in-game rain")
		visual.call("set_profile","low")
		expect(str(visual.get("quality"))=="low","low graphics fallback retained")
		var surfaces: Dictionary = visual.get("original_surfaces")
		var restored := true
		for mesh in surfaces:
			if mesh.material_override != surfaces[mesh]:
				restored = false
		expect(restored,"legacy PBR road materials returned in low mode")
		visual.call("set_profile","standard")
		var upgraded := true
		for mesh in surfaces:
			if mesh.material_override != visual.get("wet_surface"):
				upgraded = false
		expect(upgraded,"wet material reinstalled in standard mode")
	world.queue_free()
	await process_frame
	print("R5 CINEMATIC NATIVE: %d/%d checks" % [tested-failed,tested])
	quit(0 if failed==0 else 1)
