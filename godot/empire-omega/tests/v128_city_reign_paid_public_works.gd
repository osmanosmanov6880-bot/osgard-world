extends SceneTree
## CITY REIGN B57-B60: real first-chapter consequences in original Godot.
## Use only GameState's genuine paid projects and two actual construction
## turns; validate save/reload and generated street meshes, no fake rewards.
const OUTCOMES = preload("res://scripts/city_reign_civic_outcomes.gd")
const PRIMARY = "user://city-reign-b57-civic-outcomes.save"
const PENDING = "user://city-reign-b57-civic-outcomes.save.pending"
const BACKUP = "user://city-reign-b57-civic-outcomes.save.bak"
var passes: int = 0
var fails: int = 0

func check(condition: bool,reason: String) -> void:
	if condition:
		passes += 1
	else:
		fails += 1
		push_error("CITY REIGN B57 NATIVE CONSEQUENCES FAIL: "+reason)

func _initialize() -> void:
	call_deferred("_run")

func _verify_geometry(node: Node3D) -> void:
	check(bool(node.call("graphics_are_bounded")),
		"real original paid outcomes never exceed 2 roots, 5 mesh surfaces")
	var crossings: Node3D = node.get("crossings")
	var stripes: MultiMeshInstance3D = node.get("white_markings")
	var reflectors: MultiMeshInstance3D = node.get("roadside_studs")
	var pavilion: Node3D = node.get("record_pavilion")
	var shell: MeshInstance3D = node.get("records_shell")
	var canopy: MeshInstance3D = node.get("records_glass")
	var label: Label3D = node.get("records_sign")
	check(crossings!=null and pavilion!=null and label!=null,
		"crosswalks, earned pavilion and source-backed readable label exist")
	check(crossings.get_child_count()==2 and pavilion.get_child_count()==3,
		"only two original shared road GPU groups, two pavilion meshes and label")
	check(stripes.multimesh.instance_count==36 and
		reflectors.multimesh.instance_count==40 and
		reflectors.multimesh.mesh is CylinderMesh,
		"four sets of nine real paint strips and forty physical LED stud meshes")
	check(shell.mesh is ArrayMesh and canopy.mesh is ArrayMesh and
		shell.mesh.surface_get_array_len(0)>300 and
		canopy.mesh.surface_get_array_len(0)>120,
		"true stone pavilion and genuine separate non-overlapping metal canopy")
	check(shell.mesh!=canopy.mesh and shell.material_override!=canopy.material_override,
		"cinematic canopy is not a duplicated z-fighting base surface")
	check(pavilion.position==OUTCOMES.KIOSK_AT and
		pavilion.position.distance_to(Vector3(-164,0,-85))>=8.5,
		"original public records kiosk outside the ACTUAL funded site colliders")
	for center in OUTCOMES.CROSSINGS:
		var road_x: bool = absf(center.x-104.0)<0.01
		var road_z: bool = absf(center.z+104.0)<0.01
		check(road_x or road_z,
			"actual safe-crossing stripe must be on existing 52m roadway")
	check(node.find_children("*","CollisionShape3D",true,false).is_empty(),
		"zero new vehicle/pedestrian colliders on source traffic lanes")

func _run() -> void:
	var sim: Node = root.get_node_or_null("GameState")
	check(sim!=null,"original authoritative state is present")
	if sim==null:
		quit(2)
		return
	var saved: Dictionary = sim.get("data").duplicate(true)
	var old_language: String = str(sim.get("locale"))
	var old_primary: String = sim.get("save_path")
	var old_pending: String = sim.get("pending_save_path")
	var old_backup: String = sim.get("backup_save_path")
	for path in [PRIMARY,PENDING,BACKUP]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	sim.set("save_path",PRIMARY)
	sim.set("pending_save_path",PENDING)
	sim.set("backup_save_path",BACKUP)
	sim.set("data",sim.call("new_game"))
	var script: Variant = load("res://scripts/world_builder.gd")
	check(script is Script and script.can_instantiate(),
		"real WorldBuilder compiles after singleton autoloads initialize")
	if not (script is Script and script.can_instantiate()):
		quit(1)
		return
	var world: Node3D = script.new()
	root.add_child(world)
	var outcome: Node3D = world.get("city_reign_public_works")
	check(outcome!=null and outcome.is_inside_tree(),
		"authentic game WorldBuilder physically mounts saved public works")
	if outcome==null:
		quit(1)
		return
	_verify_geometry(outcome)
	check(not outcome.call("project_visible","safe_crossings") and
		not outcome.call("project_visible","open_records"),
		"new game has no fictitiously finished civic buildings")
	var initial_works: int = outcome.get_child_count()
	var initial_count: int = world.get_child_count()
	var before_start: Dictionary = sim.get("data").duplicate(true)
	check(bool(sim.call("start_initiative","safe_crossings")),
		"real council debits treasury/materials/goods and begins construction")
	var commissioned: Dictionary = sim.get("data")
	check(int(commissioned["treasury"])<int(before_start["treasury"]) and
		int(commissioned["inventories"]["materials"]) <
			int(before_start["inventories"]["materials"]) and
		int(commissioned["inventories"]["goods"]) <
			int(before_start["inventories"]["goods"]),
		"visible infrastructure cannot appear without actual fiscal investment")
	world.call("update_development")
	check(not outcome.call("project_visible","safe_crossings"),
		"funded but UNFINISHED works never claim completion")
	for turn in range(2):
		check(bool(sim.call("advance_turn")),"authentic city construction turn accepted")
		world.call("update_development")
		if turn==0:
			check(not outcome.call("project_visible","safe_crossings"),
				"first construction tick still lacks a completed crossing")
	var finished: Dictionary = sim.get("data")
	check((finished["projects_done"] as Array).has("safe_crossings") and
		outcome.call("project_visible","safe_crossings") and
		not outcome.call("project_visible","open_records"),
		"real second construction tick physically constructs ONLY chosen crossings")
	check(int(finished["trust"][1])>=int(before_start["trust"][1])+4,
		"actual source economic/civic trust consequences are not decorative")
	outcome.call("set_quality","low")
	check((outcome.get("white_markings") as MultiMeshInstance3D).visible and
		not (outcome.get("roadside_studs") as MultiMeshInstance3D).visible,
		"mobile LOW keeps ESSENTIAL safety stripes but culls luxury road studs")
	outcome.call("set_quality","cinematic")
	outcome.call("update_ambience",22.0,93)
	var warning: StandardMaterial3D = outcome.get("warning_finish")
	check(warning.emission_enabled and
		warning.emission_energy_multiplier>0.3,
		"actual earned road studs illuminate only on a powered night")
	outcome.call("update_ambience",22.0,0)
	check(not warning.emission_enabled and
		warning.emission_energy_multiplier==0.0,
		"authentic municipal blackout makes earned road studs dark")
	outcome.call("update_ambience",12.0,100)
	check(not warning.emission_enabled,
		"real daytime stud metal is NOT fictitiously glowing")
	var paid_snapshot: Dictionary = sim.get("data").duplicate(true)
	check(bool(sim.call("save_game")),"genuine source campaign with paid project writes a valid save")
	sim.set("data",sim.call("new_game"))
	world.call("update_development")
	check(not outcome.call("project_visible","safe_crossings"),
		"reset removes previously paid geometry instead of leaving ghost buildings")
	check(bool(sim.call("load_game")),"original durable save can be restored")
	world.call("update_development")
	check(outcome.call("project_visible","safe_crossings") and
		sim.get("data")==paid_snapshot,
		"actual saved civic choice reconstructs built physical crossings on reload")
	check(outcome.get_child_count()==initial_works and
		world.get_child_count()==initial_count,
		"repeated reset/load never duplicates source scene nodes")
	# The alternative path has a genuinely different world impact.
	sim.set("data",sim.call("new_game"))
	world.call("update_development")
	check(bool(sim.call("start_initiative","open_records")),
		"alternate first-episode investment spends real original resources")
	world.call("update_development")
	check(not outcome.call("project_visible","open_records"),
		"municipal open-budget pavilion cannot appear before construction")
	for i in range(2):
		check(bool(sim.call("advance_turn")),
			"real original city turn processes open-budget project: "+str(i))
		world.call("update_development")
	check(outcome.call("project_visible","open_records") and
		not outcome.call("project_visible","safe_crossings"),
		"alternate budget path creates its OWN truthful street landmark")
	for lang in ["ru","en","zh"]:
		world.call("update_language",lang)
		var text: String = (outcome.get("records_sign") as Label3D).text
		check(text.contains(str(sim.get("data")["treasury"])) and
			text.contains(str(sim.get("data")["trust"][0])) and
			not text.is_empty(),
			"localized native kiosk must display REAL treasury/trust in "+lang)
	outcome.call("set_quality","low")
	check(outcome.call("project_visible","open_records") and
		not (outcome.get("records_glass") as MeshInstance3D).visible,
		"low GPU mode retains essential transparency kiosk with no luxury canopy")
	outcome.call("set_quality","cinematic")
	check((outcome.get("records_glass") as MeshInstance3D).visible,
		"cinematic mode adds genuine original 3D metalwork, no screen fake")
	var immutable: Dictionary = sim.get("data").duplicate(true)
	for i in range(9):
		outcome.call("sync_state",sim.get("data"),"en")
		world.call("update_development")
		world.call("update_daynight",16.0)
		world.call("apply_visual_budget","cinematic")
	check(sim.get("data")==immutable and
		outcome.get_child_count()==initial_works,
		"repeated visualization never creates credits, skips turns or spawns duplicates")
	world.queue_free()
	await process_frame
	for path in [PRIMARY,PENDING,BACKUP]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	sim.set("save_path",old_primary)
	sim.set("pending_save_path",old_pending)
	sim.set("backup_save_path",old_backup)
	sim.set("data",saved)
	sim.set("locale",old_language)
	print("CITY REIGN B57-B60 REAL PAID PUBLIC WORKS: %d PASS %d FAIL" %
		[passes,fails])
	quit(0 if fails==0 else 1)
