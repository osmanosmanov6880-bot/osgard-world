extends SceneTree
## CITY REIGN B54 native real window frames and source-preserving LOD.
const REVEALS = preload("res://scripts/city_reign_window_reveal_geometry.gd")
var passed: int = 0
var failed: int = 0

func verify(ok: bool,why: String) -> void:
	if ok: passed += 1
	else:
		failed += 1
		push_error("CITY REIGN B54 REAL WINDOW SURFACE FAIL: "+why)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var sim: Node = root.get_node_or_null("GameState")
	verify(sim!=null,"native actual GameState autoload mounted")
	if sim==null:
		quit(2)
		return
	var before: Dictionary = (sim.get("data") as Dictionary).duplicate(true)
	var model: Mesh = REVEALS.cinematic_mesh()
	verify(bool(REVEALS.geometry_is_real_and_bounded(model)),
		"physical hollow window rails and real sill have finite normals/bounds")
	verify(int(model.surface_get_array_len(0))==REVEALS.MAX_VERTICES,
		"only five 3D rail volumes inside one original GPU source mesh")
	var source: Variant = load("res://scripts/world_builder.gd")
	verify(source is Script and source.can_instantiate(),
		"original real city world script still compiles")
	if not (source is Script and source.can_instantiate()):
		quit(1)
		return
	var city: Node3D = source.new()
	root.add_child(city)
	var glazing: MultiMeshInstance3D = city.get("facade_windows") as MultiMeshInstance3D
	var frames: MultiMeshInstance3D = city.get("facade_frames") as MultiMeshInstance3D
	verify(glazing!=null and frames!=null,
		"original native city has one glass and one metal frame global draw batch")
	if glazing==null or frames==null:
		quit(1)
		return
	var count: int = glazing.multimesh.instance_count
	var original_transforms: Array = city.get("window_points")
	verify(count>500 and count<=30000 and count==frames.multimesh.instance_count and
		count==original_transforms.size(),
		"authentic unchanged source window count, glass and frames co-located")
	var original_grid: MultiMesh = frames.multimesh
	var original_finish: Material = frames.material_override
	var cheap: Mesh = city.get("city_reign_standard_window_frame_mesh")
	var detailed: Mesh = city.get("city_reign_cinematic_window_frame_mesh")
	verify(cheap is BoxMesh and detailed==model and cheap!=detailed,
		"cache original BoxMesh alongside genuine new ArrayMesh")
	verify(frames.multimesh.mesh==cheap and frames.visible,
		"original STANDARD starts cheap and fully readable")
	for tier in ["cinematic","low","standard","cinematic","low","standard"]:
		city.call("apply_visual_budget",tier)
		var expected: Mesh = detailed if tier=="cinematic" else cheap
		verify(frames.multimesh==original_grid and frames.multimesh.mesh==expected and
			frames.multimesh.instance_count==count,
			"native LOD swaps only one shared original source mesh: "+tier)
		verify(frames.visible == (tier!="low"),
			"low/mobile hides optional metal frames, standard/cinematic show them")
		verify(frames.material_override==original_finish and frames.get_child_count()==0,
			"no additional textures or per-window scene/collider objects allocated")
		verify(glazing.multimesh.instance_count==count and glazing.get_child_count()==0,
			"true original glass remains authoritative and unobscured")
	city.call("update_daynight",22.0)
	city.call("update_weather","storm")
	city.call("apply_visual_budget","cinematic")
	verify(frames.multimesh.mesh==model and
		bool(REVEALS.geometry_is_real_and_bounded(frames.multimesh.mesh)),
		"source-night, wet road and energy do not replace authentic glass/frames")
	verify(sim.get("data")==before,
		"premium window art doesn't spend funds, buy property or advance missions")
	city.queue_free()
	await process_frame
	print("CITY REIGN WORLD B54 ORIGINAL 3D WINDOW LOD: %d PASS %d FAIL" %
		[passed,failed])
	quit(0 if failed==0 else 1)
