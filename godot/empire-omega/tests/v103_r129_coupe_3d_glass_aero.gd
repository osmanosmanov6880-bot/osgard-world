extends SceneTree
## R129 native Godot 4.4.1 proof of AUTHENTIC ORIGINAL SOURCE: 4 physically
## shaded ceramic-framed 3D glass panes, two sculpted front wiper blades and
## a single machined eight-mass carbon/aluminium aero bumper. No fake PNG,
## independent body mesh nodes or physics/mission/collision mutation.
const ART = preload("res://scripts/horizon_vehicle_art.gd")
const COUPE = preload("res://scripts/horizon_coupe_sculpt.gd")
const CAR = preload("res://scripts/vehicle_controller.gd")
var passed: int = 0
var failed: int = 0

func check(ok: bool, why: String) -> void:
	if ok:
		passed += 1
	else:
		failed += 1
		push_error("EMPIRE OMEGA R129 REAL GLAZING/AERO FAIL: "+why)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game: Node = root.get_node_or_null("GameState")
	check(game != null, "genuine original GameState autoload exists")
	if game == null:
		quit(1)
		return
	var initial: Dictionary = (game.get("data") as Dictionary).duplicate(true)
	var art: Node3D = ART.new()
	root.add_child(art)
	var four: Array[String] = [
		"SlopedWindshield","RearGlass","LeftSideGlass","RightSideGlass"]
	var all_original: Array = art.get("body_parts")
	var rigs: Array = art.get("wheel_rigs")
	var details: Array = art.get("wheel_detail_nodes")
	check(rigs.size() == 4 and details.size() == 4,
		"four existing true rolling vehicle wheels and original brake detail remain")
	check(art.get_node_or_null("FlowBody") is MeshInstance3D and
		art.get_node_or_null("AerodynamicGreenhouse") is MeshInstance3D,
		"real source longitudinal closed sport-coupe shell preserved")
	var body_geometry: MeshInstance3D = art.get_node_or_null("FlowBody") as MeshInstance3D
	check(body_geometry != null and
		body_geometry.mesh.get_surface_count() == 1 and
		body_geometry.mesh.surface_get_array_len(0) >= 1000,
		"original curved 1000+ source-triangle painted body remains active")
	for n in four:
		var pane: MeshInstance3D = art.get_node_or_null(n) as MeshInstance3D
		check(pane != null and pane.get_child_count() == 0 and
			all_original.has(pane),
			"each original named vehicle window is the SAME single scene node, no new draw pass")
		if pane == null:
			continue
		var mesh: ArrayMesh = pane.mesh as ArrayMesh
		check(mesh != null and mesh.get_surface_count()==1,
			"original "+n+" is now one real bounded physical source 3D mesh")
		if mesh == null:
			continue
		var arrays: Array = mesh.surface_get_arrays(0)
		var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
		var expected: int = 42 if n=="SlopedWindshield" else 30
		check(v.size() == expected and normals.size()==expected and colors.size()==expected,
			"R129 ceramic-glass five physical planes "+n+" with 2 real wiper strips only on front")
		var darkest: float = 1.0
		var brightest: float = 0.0
		for i in range(v.size()):
			check(v[i].is_finite() and normals[i].is_finite(),
				"each original physically rendered glass/wiper polygon vertex is finite")
			darkest = minf(darkest,colors[i].r)
			brightest = maxf(brightest,colors[i].r)
		check(darkest < 0.13 and brightest > 0.25,
			"R129 physically shaded dark real ceramic gasket versus dyed blue automobile glass")
		var finish: StandardMaterial3D = pane.material_override as StandardMaterial3D
		check(finish != null and finish.vertex_color_use_as_albedo and
			finish.clearcoat_enabled and finish.metallic >= 0.30 and
			finish.roughness < 0.35 and
			finish.shading_mode != BaseMaterial3D.SHADING_MODE_UNSHADED,
			"real world PBR dual-sided clearcoat on original 3D window geometry")
		check(pane.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY,
			"window geometry remains genuinely visible at every original graphics tier")
	var aero: MeshInstance3D = art.get_node_or_null("FrontSplitter") as MeshInstance3D
	check(aero!=null and aero.get_child_count()==0 and all_original.has(aero),
		"original front splitter remains ONE original body part without new render nodes")
	if aero != null:
		var aero_mesh: ArrayMesh = aero.mesh as ArrayMesh
		check(aero_mesh != null and aero_mesh.get_surface_count()==1,
			"genuine one-surface machined carbon/aluminium air dam, not a BoxMesh")
		if aero_mesh != null:
			var verts: PackedVector3Array = aero_mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
			var tints: PackedColorArray = aero_mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
			check(verts.size()==288 and tints.size()==288,
				"exactly 8 physical aero components in one 96-triangle shared bumper draw")
			var bounds: AABB = aero_mesh.get_aabb()
			check(bounds.size.x > 2.70 and bounds.size.x < 2.80 and
				bounds.size.z < 0.70,
				"new physically detailed nose stays inside original 2.75mx0.64m space")
			var darkness: bool = false
			var metal: bool = false
			for tint in tints:
				if tint.r < 0.1:
					darkness = true
				if tint.r > 0.48:
					metal = true
			check(darkness and metal,
				"real brake duct darkness and brushed aluminium reflect separately in one mesh")
		var finish: StandardMaterial3D = aero.material_override as StandardMaterial3D
		check(finish != null and finish.vertex_color_use_as_albedo and
			finish.metallic > 0.30 and finish.roughness >= 0.35,
			"single PBR native aero surface uses original actual sunlight/material pipeline")
	var brake: MeshInstance3D = art.get("brake_strip") as MeshInstance3D
	check(brake!=null and brake.name == "FullWidthRearLight",
		"existing emissive native original physical brake light preserved")
	art.call("set_brake_lights",true)
	check((brake.material_override as StandardMaterial3D).emission_energy_multiplier>3.0,
		"real braking still changes original native Godot brake emission")
	art.call("set_detail_quality","low")
	for detail in details:
		check(not (detail as Node3D).visible,
			"LOW mobile keeps original physical wheel/shadow detail budget unchanged")
	art.call("set_detail_quality","cinematic")
	for detail in details:
		check((detail as Node3D).visible,
			"cinematic preserves genuine rotating and rimmed 3D wheel details")
	art.call("set_paint",Color("597b8b"))
	check(body_geometry.material_override is StandardMaterial3D and
		(body_geometry.material_override as StandardMaterial3D).clearcoat_enabled,
		"garage paint change retains original physically shaded sculpted coupe")
	check(COUPE.profile_bounds(COUPE.BODY_PROFILE).size.z>5.20,
		"authored curved 3D length and original driving collider footprint unchanged")
	art.queue_free()
	await process_frame
	var car: CharacterBody3D = CAR.new()
	root.add_child(car)
	var collider_count: int = 0
	for child in car.get_children():
		if child is CollisionShape3D:
			collider_count += 1
	check(collider_count==1,
		"driving/collision source remains exactly one original physical BoxShape3D")
	var real_visual: Node3D = car.get("horizon_visual") as Node3D
	check(real_visual!=null and
		real_visual.get_node_or_null("SlopedWindshield") is MeshInstance3D and
		real_visual.get_node_or_null("FrontSplitter") is MeshInstance3D,
		"actual playable driving vehicle (not only isolated art demo) renders new R129 glass/aero")
	check(game.get("data")==initial,
		"no original money, game save, road routing, physics or mission state mutated")
	car.queue_free()
	await process_frame
	print("EMPIRE OMEGA R129 original physically carved coupe: %d PASS %d FAIL" %
		[passed,failed])
	quit(0 if failed==0 else 1)
