extends SceneTree
## CITY REIGN B41-B44: source-native, actual Godot 4.4.1 street architecture.
## Tests real volumetric mesh data and real WorldBuilder integration, not text.
const KIT = preload("res://scripts/city_reign_street_architecture.gd")
# Load the real WorldBuilder only after SceneTree registers autoloads.
# Preloading before the native SceneTree exists makes GameState unresolved.
var passed: int = 0
var failed: int = 0

func check(ok: bool,reason: String) -> void:
	if ok:
		passed += 1
	else:
		failed += 1
		push_error("CITY REIGN B41 STREET QUALITY FAILED: "+reason)

func _initialize() -> void:
	call_deferred("_run")

func _batch(kit: Node3D,id: String) -> MultiMeshInstance3D:
	return kit.get_node_or_null(id) as MultiMeshInstance3D

func _run() -> void:
	var game: Node = root.get_node_or_null("GameState")
	check(game != null,"authoritative native GameState exists")
	if game == null:
		quit(1)
		return
	var saved: Dictionary = (game.get("data") as Dictionary).duplicate(true)
	var kit: Node3D = KIT.new()
	# Four representative world-space buildings, each with its actual
	# road-facing entrance yaw and real original widths/heights.
	var lots: Array[Dictionary] = [
		{"point":Vector3(-191.0,20.0,-191.0),"width":13.0,"height":40.0,"district":"forum","face":0},
		{"point":Vector3(-139.0,17.0,-139.0),"width":12.0,"height":34.0,"district":"housing","face":1},
		{"point":Vector3(69.0,11.0,69.0),"width":14.0,"height":22.0,"district":"lower","face":2},
		{"point":Vector3(173.0,18.0,173.0),"width":11.0,"height":36.0,"district":"aqueduct","face":3}
	]
	for lot in lots:
		kit.call("record",lot["point"],lot["width"],lot["height"],
			lot["district"],lot["face"])
	kit.call("finalize")
	root.add_child(kit)
	check(kit.get("building_count")==4,"one authentic source building => one GPU instance per batch")
	check(kit.get_child_count()==4 and (kit.get("batches") as Dictionary).size()==4,
		"all architectural elements use EXACTLY four shared draw batches")
	check(bool(kit.call("graphics_are_bounded")),"geometry and scene budgets strictly bounded")
	var total: int = int(kit.call("total_triangles"))
	check(total > 1000 and total <= KIT.MAX_TOTAL_TRIANGLES,
		"true geometric street relief exceeds base flat facade with bounded triangles")
	var original_poses: Array = kit.get("placements")
	check(original_poses.size()==4,"original CPU instance transforms stored, no GPU readback")
	var distinct: bool = true
	for i in range(4):
		var pose: Transform3D = original_poses[i]
		if not pose.origin.is_finite() or pose.origin.y != 0.0:
			distinct = false
		if i>0 and pose.origin.is_equal_approx(original_poses[i-1].origin):
			distinct = false
	check(distinct,"physical architecture aligns to four finite distinct road faces")
	for name in [
		"UrbanStonePortals","AnodizedStreetJoinery",
		"CinematicStreetFoliage","PoweredStreetLuminaires"
	]:
		var node: MultiMeshInstance3D = _batch(kit,name)
		check(node != null,"live draw batch exists: "+name)
		if node == null:
			continue
		check(node.multimesh != null and node.multimesh.instance_count==4,
			"four original lot transforms, no material node explosion: "+name)
		check(node.multimesh.mesh is ArrayMesh and node.get_child_count()==0,
			"native 3D ArrayMesh and no per-building nodes: "+name)
		check(node.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,
			"no additional per-instance shadow map: "+name)
		var faces: Mesh = node.multimesh.mesh
		check(faces.get_surface_count()==1 and
			faces.surface_get_array_len(0)>=36,
			"physically modelled triangle faces not fake 2D overlay: "+name)
	var stone := _batch(kit,"UrbanStonePortals")
	if stone != null:
		var stone_mat: StandardMaterial3D = stone.material_override as StandardMaterial3D
		check(stone_mat != null and stone_mat.normal_texture != null and
			stone_mat.roughness_texture != null and stone_mat.vertex_color_use_as_albedo,
			"authentic shared PBR color, normal and roughness on stone")
	kit.call("set_quality","low")
	check(not _batch(kit,"UrbanStonePortals").visible and
		not _batch(kit,"AnodizedStreetJoinery").visible and
		not _batch(kit,"CinematicStreetFoliage").visible,
		"low/mobile tier hides added street geometry")
	kit.call("set_quality","standard")
	check(_batch(kit,"UrbanStonePortals").visible and
		_batch(kit,"AnodizedStreetJoinery").visible and
		not _batch(kit,"CinematicStreetFoliage").visible,
		"standard keeps eye-level structure with foliage culled")
	kit.call("set_quality","cinematic")
	check(_batch(kit,"CinematicStreetFoliage").visible,
		"cinematic adds physically shaded living foliage")
	kit.call("update_ambience",12.0,100)
	check(not _batch(kit,"PoweredStreetLuminaires").visible,
		"real daylight switches off powered facade lighting")
	kit.call("update_ambience",22.0,100)
	var lights: MultiMeshInstance3D = _batch(kit,"PoweredStreetLuminaires")
	var lamps: StandardMaterial3D = lights.material_override as StandardMaterial3D
	check(lights.visible and lamps.emission_enabled and
		lamps.emission_energy_multiplier > 0.35,
		"night facade lamps respond to the authoritative city clock")
	kit.call("update_ambience",22.0,0)
	check(not lights.visible and not lamps.emission_enabled,
		"city electricity failure really darkens the facade")
	kit.call("update_ambience",22.0,10)
	check(lights.visible and lamps.emission_energy_multiplier < 0.20,
		"brownout visibly dims illumination instead of fake UI promise")
	check(bool(kit.call("graphics_are_bounded")),
		"quality and ambience changes do not allocate new scene nodes")
	kit.queue_free()
	await process_frame

	# Full real original level composition, not a stand-alone toy fixture.
	var world_source: Variant = load("res://scripts/world_builder.gd")
	check(world_source is Script and world_source.can_instantiate(),
		"original WorldBuilder GDScript compiles after GameState autoload")
	if not (world_source is Script and world_source.can_instantiate()):
		quit(1)
		return
	var world: Node3D = world_source.new()
	root.add_child(world)
	var integrated: Node3D = world.get("city_reign_street_architecture")
	var original_count: int = int(world.get("building_count"))
	check(integrated != null,"live world contains newly connected street architecture")
	check(original_count>0 and original_count<=KIT.MAX_BUILDINGS,
		"the same source world produced bounded existing buildings")
	if integrated != null:
		check(int(integrated.get("building_count"))==original_count,
			"every original real building has one authored street frontage")
		check(bool(integrated.call("graphics_are_bounded")),
			"integrated real game remains within the 250k triangle ceiling")
	var r90: Node3D = world.get("r90_urban")
	check(r90 != null and r90.get_child_count()==3,
		"original R90 three-root skyline scene contract remains intact")
	if r90 != null:
		var art: Node3D = r90.get("r91_architecture")
		check(art != null and art.get_child_count()==2,
			"original R91 window and rooftop batches remain intact")
	world.call("apply_visual_budget","low")
	if integrated != null:
		check(not _batch(integrated,"UrbanStonePortals").visible,
			"actual gameplay low graphics tier switches eye-level kit off")
	world.call("apply_visual_budget","standard")
	if integrated != null:
		check(_batch(integrated,"UrbanStonePortals").visible,
			"actual gameplay standard restores source geometry")
	world.call("apply_visual_budget","cinematic")
	world.call("update_daynight",22.0)
	if integrated != null:
		check(_batch(integrated,"CinematicStreetFoliage").visible and
			_batch(integrated,"PoweredStreetLuminaires").visible,
			"real playable world uses native night/cinematic street assets")
	world.call("update_weather","rain")
	if integrated != null:
		check(bool(integrated.call("graphics_are_bounded")),
			"rain and wet road materials never duplicate frontage meshes")
	world.queue_free()
	await process_frame
	check(game.get("data")==saved,
		"art update never changes campaign, purchased lots, money or missions")
	print("CITY REIGN B41-B44 REAL STREET WORLD: %d PASS %d FAIL" % [passed,failed])
	quit(0 if failed==0 else 1)
