extends SceneTree
## CITY REIGN A17–A18: the REAL player's traffic law and its ACTUAL
## sculpted three-lens 3D direction-specific visible source signage.
## Full playable city, original 12 NPC cars/34 citizens and money preserved.
const ART = preload("res://scripts/city_reign_signal_art.gd")
const SIGNALS = preload("res://scripts/traffic_signal_controller.gd")
var passed: int = 0
var failed: int = 0

func check(ok: bool,reason: String) -> void:
	if ok:
		passed += 1
	else:
		failed += 1
		push_error("CITY REIGN REAL SIGNAL FAIL: "+reason)

func _initialize() -> void:
	call_deferred("_run")

func _assert_light_pair(art: Node3D,phase: int,warning: bool) -> void:
	art.call("sync_phase",phase,warning)
	var record: Dictionary = art.get("lamp_state")
	var mats: Dictionary = art.get("finishes")
	for axis in ["x","z"]:
		var green_route: bool = (axis=="x" and phase==0) or (axis=="z" and phase==1)
		for lamp in ["red","amber","green"]:
			var name: String = axis+"_"+lamp
			var expected_on: bool = (lamp=="red" and not green_route) or (
				lamp=="amber" and green_route and warning) or (
				lamp=="green" and green_route and not warning)
			check(bool(record[name])==expected_on,
				"real "+name+" LED agrees with original traffic direction phase")
			var mat: StandardMaterial3D = mats[name]
			check(mat.emission_enabled and
				is_equal_approx(mat.emission_energy_multiplier,ART.ACTIVE_LED_RADIANCE if expected_on else 0.0),
				"real "+name+" 3D material switches emissive light without spawning")
	check(not (bool(record["x_green"]) and bool(record["z_green"])),
		"perpendicular roads never both display green")
	check(not (bool(record["x_amber"]) and bool(record["z_amber"])),
		"perpendicular roads never both display amber")

func _run() -> void:
	var state: Node = root.get_node_or_null("GameState")
	check(state!=null,"actual original authoritative save singleton exists")
	if state==null:
		quit(2)
		return
	var data_before: Dictionary = state.data.duplicate(true)
	var render: Node3D = ART.new()
	root.add_child(render)
	check(render.name=="CityReignOriginalSignalNetwork" and
		bool(render.call("geometry_is_bounded")),
		"actual 9 GPU MultiMesh signals built on source street grid")
	var all_batches: Dictionary = render.get("batches")
	var sources: Dictionary = render.get("placements")
	check(all_batches.size()==9 and render.get_child_count()==9,
		"only 9 real GPU draw batches cover all original 16 junctions")
	var sum_lens: int = 0
	for direction in ["x","z"]:
		for color_id in ["red","amber","green"]:
			var id: String = direction+"_"+color_id
			var node: MultiMeshInstance3D = all_batches[id]
			check(node.multimesh.instance_count==16 and sources[id].size()==16,
				"16 original direction-specific signal LEDs reuse ONE GPU surface")
			sum_lens+=node.multimesh.instance_count
	check(sum_lens==ART.TOTAL_LENS_INSTANCES,
		"96 genuine individual light-source positions in only 6 GPU batches")
	var pole_mesh: ArrayMesh = all_batches["post"].multimesh.mesh as ArrayMesh
	var head_mesh: ArrayMesh = all_batches["x_body"].multimesh.mesh as ArrayMesh
	var z_mesh: ArrayMesh = all_batches["z_body"].multimesh.mesh as ArrayMesh
	var lamp_mesh: ArrayMesh = all_batches["x_red"].multimesh.mesh as ArrayMesh
	check(pole_mesh!=null and pole_mesh.surface_get_array_len(0)==180,
		"real source pole plus two cantilever arms, single physical mesh")
	check(head_mesh!=null and head_mesh.surface_get_array_len(0)==540 and
		head_mesh==z_mesh,
		"three sculpted lens hoods per two facing directions, no duplicate geometry")
	if head_mesh!=null:
		var head_verts: PackedVector3Array = head_mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var hood_min: float = INF
		var hood_max: float = -INF
		var protrusions: int = 0
		for vertex in head_verts:
			if vertex.z < -0.595:
				hood_min = minf(hood_min,vertex.y)
				hood_max = maxf(hood_max,vertex.y)
				protrusions += 1
		check(protrusions==72 and hood_min > -0.525 and hood_max > 0.80,
			"all 3 actual 3D sun hoods sit ABOVE their LED lens, never inverted below")
	check(lamp_mesh!=null and lamp_mesh.surface_get_array_len(0)==60,
		"real radial 20-facet convex 3D LED lens, not an emissive rectangle")
	for id in all_batches:
		var mesh: MultiMeshInstance3D = all_batches[id]
		check(mesh.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,
			"original street signals add ZERO per-light real-time shadows")
		check(mesh.multimesh.instance_count==16,
			"same 16 junctions, no invented extra traffic intersections")
	var xfront: Transform3D = sources["x_body"][0]
	var zfront: Transform3D = sources["z_body"][0]
	check(xfront.origin.distance_to(Vector3(-148.5,4.03,-149.6))<0.001 and
		zfront.origin.distance_to(Vector3(-149.6,4.03,-148.5))<0.001,
		"two original physical signal heads are off the 10m roadbed on actual corner")
	check((xfront.basis*Vector3(0,0,-1)).distance_to(Vector3(-1,0,0))<0.001 and
		(zfront.basis*Vector3(0,0,-1)).distance_to(Vector3(0,0,-1))<0.001,
		"X lamp faces -X approaching drivers, Z lamp faces -Z approaching drivers")
	for group in sources:
		for pose in sources[group]:
			var t: Transform3D = pose
			check(t.origin.is_finite() and absf(t.origin.x)<224.0 and
				absf(t.origin.z)<224.0 and t.origin.y>=0.0 and t.origin.y<=5.0,
				"physical 3D steel/lens source stays within original four districts")
	for phase in [0,1]:
		for warning in [false,true]:
			_assert_light_pair(render,phase,warning)
	var materials: Dictionary = render.get("finishes")
	var xred: StandardMaterial3D = materials["x_red"]
	render.call("sync_phase",0,false)
	var original_red: StandardMaterial3D = materials["x_red"]
	check(xred==original_red,"time-of-day/signal updates never allocate a GPU material")
	render.call("set_quality","low")
	check(not render.visible and bool(render.call("geometry_is_bounded")),
		"phone LOW quality uses ZERO new 3D traffic signal passes")
	render.call("set_quality","cinematic")
	check(render.visible and render.get_child_count()==9,
		"cinematic reuses exact cached sculpted signs without adding draw calls")
	check(render.find_children("*","CollisionShape3D",true,false).is_empty(),
		"3D signal art cannot introduce traffic or pedestrian collisions")
	render.queue_free()
	await process_frame
	# The original traffic permission function is the ONLY source of legal
	# movement, even during the last 1.5s amber visual warning.
	var signals: Node3D = SIGNALS.new()
	root.add_child(signals)
	signals.set_process(false)
	var real_art: Node3D = signals.get("cinematic_art") as Node3D
	check(real_art!=null and bool(signals.call("visual_state_is_consistent")),
		"sculpted lights are wired to the original real traffic controller")
	check((signals.get("lights") as Array).size()==16 and
		(signals.get("legacy_signal_roots") as Array).size()==16,
		"existing original junction records and LOW legacy materials preserved")
	var point := Vector3(52,0,52)
	var xway := Vector3(1,0,0)
	var zway := Vector3(0,0,1)
	for pair in [[0.0,true,false,false],[11.0,true,false,true],
		[12.2,false,true,false],[23.0,false,true,true],
		[24.2,true,false,false]]:
		signals.set("elapsed",float(pair[0]))
		signals.call("_update_lights")
		check(signals.call("permitted",point,xway)==pair[1] and
			signals.call("permitted",point,zway)==pair[2],
			"exact original 24s AI X/Z permission matches physical directional LEDs")
		check(signals.call("_warning")==pair[3] and
			bool(signals.call("visual_state_is_consistent")),
			"actual amber countdown and red/green do NOT contradict traffic law")
	var preserved: MeshInstance3D = signals.get("lights")[0]["green"]
	var original_box: Mesh = preserved.mesh
	signals.call("set_quality","low")
	check(not real_art.visible and
		(signals.get("legacy_signal_roots") as Array)[0].visible,
		"mobile LOW restores original full signal geometry/visibility")
	check(preserved.mesh==original_box,
		"original low-quality fallback source mesh has same identity")
	signals.call("set_quality","standard")
	check(real_art.visible and
		not (signals.get("legacy_signal_roots") as Array)[0].visible,
		"standard visual identity hides basic boxes and shows real 3D metalwork")
	check(bool(signals.call("visual_state_is_consistent")),
		"low/standard switches cannot contradict traffic law")
	signals.queue_free()
	await process_frame
	# Real shipped city includes original World, original 34 residents,
	# original 12 cars, meaningful original money/save state and new signs.
	var before: Dictionary = state.data.duplicate(true)
	var error: Error = change_scene_to_file("res://scenes/main.tscn")
	check(error==OK,"real original driving city Godot scene compiles")
	if error==OK:
		await process_frame
		await physics_frame
		var game: Node3D = current_scene as Node3D
		var live: Node3D = game.get("traffic_signals") as Node3D
		check(live!=null and live.get("cinematic_art")!=null and
			bool(live.call("visual_state_is_consistent")),
			"city driving road has real source-authored 16 directional 3D signals")
		check((game.get("ambient_cars") as Array).size()==12 and
			(game.get("pedestrians") as Array).size()==34,
			"original 12 native traffic physics cars and 34 residents retained")
		var game_art: Node3D = live.get("cinematic_art") as Node3D
		var view_count: int = game_art.get_child_count()
		live.call("set_quality","low")
		check(not game_art.visible,
			"real city phone low mode never draws the extra 3D signal bodies")
		live.call("set_quality","standard")
		check(game_art.visible and game_art.get_child_count()==view_count and
			bool(game_art.call("geometry_is_bounded")),
			"switching actual city quality restores same bounded 9 GPU batch nodes")
		check(int(state.data["wallet"])==int(before["wallet"]) and
			int(state.data["treasury"])==int(before["treasury"]) and
			int(state.data["mission"])==int(before["mission"]),
			"source-only AAA traffic art does not grant credits or advance missions")
		current_scene.queue_free()
		await process_frame
	state.data = data_before
	print("CITY REIGN AAA real street signals: %d PASS %d FAIL" % [passed,failed])
	quit(0 if failed==0 else 1)
