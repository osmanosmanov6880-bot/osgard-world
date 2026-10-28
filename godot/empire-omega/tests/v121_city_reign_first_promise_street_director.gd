extends SceneTree
## CITY REIGN B34–B36 source-native Godot 4.4.1 acceptance:
## Real car -> real market -> real funded civic construction -> real
## physical built city milestone. Never invent fake mission completion,
## treasury grants or a new save field.
const DIRECTOR = preload("res://scripts/city_reign_opening_director.gd")
var passed: int = 0
var failed: int = 0

func check(ok: bool,reason: String) -> void:
	if ok:
		passed+=1
	else:
		failed+=1
		push_error("CITY REIGN OPENING DIRECTOR FAIL: "+reason)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var sim: Node = root.get_node_or_null("GameState")
	if sim==null:
		push_error("Missing real GameState autoload")
		quit(2)
		return
	var original: Dictionary = sim.data.duplicate(true)
	var previous_locale: String = str(sim.locale)
	sim.data=sim.new_game()
	var save: Dictionary = sim.data.duplicate(true)
	var state: Dictionary = save.duplicate(true)
	for lang in ["ru","en","zh"]:
		var intro: Dictionary = DIRECTOR.objective(state,lang)
		check(str(intro.get("id",""))=="car" and
			str(intro.get("stage",""))=="arrival",
			"initial REAL vehicle objective is keyed to actual first mission: "+lang)
		check(not str(intro.get("title","")).is_empty() and
			(intro.get("position",Vector3.ZERO) as Vector3).distance_to(
			Vector3(-120.0,0,-104.0))<0.01,
			"three-language initial car uses saved true vehicle position "+lang)
	state["mission"]=1
	check(DIRECTOR.display_position(DIRECTOR.objective(state,"en"))==
		Vector3(130,0,-149),"delivery gate stands at real market frontage, not INSIDE a 25m building")
	check(DIRECTOR.objective(state,"en")["id"]=="market" and
		DIRECTOR.objective(state,"en")["position"]==Vector3(130.0,0,-130.0),
		"original first delivery correctly leads to actual City Market")
	for stage in [2,3]:
		state["mission"]=stage
		check(DIRECTOR.objective(state,"ru").is_empty(),
			"menu-only company/city turn does not create fake road quest "+str(stage))
	state["mission"]=4
	var decision: Dictionary = DIRECTOR.objective(state,"ru")
	check(decision["id"]=="open_records" and
		decision["position"]==DIRECTOR.PROJECTS.POSITIONS["open_records"],
		"real physical first promise proposal exists at AUTHENTIC street location")
	for key in ["active_contract","service_active","neighborhood_active"]:
		var busy: Dictionary = state.duplicate(true)
		busy[key]={"id":"original_playable_task"}
		check(DIRECTOR.objective(busy,"ru").is_empty(),
			"actual urgent gameplay takes precedence over optional civic guidance "+key)
	var inside: Dictionary = state.duplicate(true)
	inside["interior"]="cityhall"
	check(DIRECTOR.objective(inside,"en").is_empty(),
		"optional street art never appears in real city interior")
	var building: Dictionary = state.duplicate(true)
	building["projects_active"]={"open_records":{"remaining":2}}
	check(DIRECTOR.objective(building,"en")["stage"]=="building" and
		DIRECTOR.objective(building,"en")["id"]=="open_records",
		"actual funded project only displays REAL under-construction site")
	building["projects_active"]={}
	building["projects_done"]=["open_records"]
	check(DIRECTOR.objective(building,"zh")["stage"]=="delivered",
		"only actual completed civic project gets completed 3D milestone")
	building["mission"]=25
	check(DIRECTOR.objective(building,"en").is_empty(),
		"epilogue guidance does not replay stale first-chapter promise")
	check(sim.data==save,"all independent presentation choices leave real save identical")
	var guide: Node3D = DIRECTOR.new()
	root.add_child(guide)
	check(bool(guide.call("geometry_is_bounded")) and
		guide.get_child_count()==2 and not guide.visible,
		"one ORIGINAL source metal 3D mesh and one Label3D, no extra renderer")
	var mesh: MeshInstance3D = guide.get("marker") as MeshInstance3D
	var label: Label3D = guide.get("caption") as Label3D
	check(mesh.scale==Vector3(1.22,1.25,1.22) and
		(label as Label3D).font_size==46,
		"actual grown 3D street gate and taller short localized label improve street readability")
	check(mesh.mesh is ArrayMesh and
		mesh.mesh.surface_get_array_len(0)==792,
		"precisely 792 original 3D physical bevel+arch vertices, never screenshot")
	check(mesh.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF and
		guide.find_children("*","CollisionShape3D",true,false).is_empty(),
		"original city guide creates zero new shadow/traffic/walking collision")
	guide.call("sync_state",state,"ru")
	guide.call("set_view",Vector3(-120,1.3,-104),false,false)
	check(guide.visible and guide.get("chosen")=="open_records" and
		guide.get("last_position")==DIRECTOR.PROJECTS.POSITIONS["open_records"] and
		guide.position==DIRECTOR.PROJECTS.POSITIONS["open_records"]+Vector3(0,0,10.0),
		"original gate stands at the real selected site but does not cover paid proposal board")
	guide.call("set_quality","low")
	check(not guide.visible and guide.get_child_count()==2,
		"phone LOW removes all new 3D guide GPU work without deleting nodes")
	guide.call("set_quality","cinematic")
	check(guide.visible and guide.get_child_count()==2,
		"standard/cinematic reuse same original source architecture")
	guide.call("set_view",Vector3(220,0,220),false,false)
	check(not guide.visible,"far away source goal does not increase visual noise")
	guide.call("set_view",DIRECTOR.PROJECTS.POSITIONS["open_records"],true,false)
	check(not guide.visible,"real interior never sees urban proposal guidance")
	guide.call("set_view",DIRECTOR.PROJECTS.POSITIONS["open_records"],false,true)
	check(not guide.visible,"real governance cabinet never has a competing 3D prompt")
	guide.call("set_view",DIRECTOR.PROJECTS.POSITIONS["open_records"],false,false)
	check(guide.visible,"road perspective immediately restores original 3D art")
	var physical_mesh: Mesh = mesh.mesh
	for lang in ["ru","en","zh"]:
		guide.call("sync_state",state,lang)
		check(label.text==str(DIRECTOR.objective(state,lang)["title"]),
			"native local 3D objective is RU/EN/ZH and never machine-mangled "+lang)
	for i in range(25):
		guide.call("sync_state",state,"ru")
		guide.call("set_quality","standard")
	check(guide.get_child_count()==2 and mesh.mesh==physical_mesh and
		bool(guide.call("geometry_is_bounded")),
		"repeated save/load/quality frames never instantiate more 3D mesh or labels")
	guide.call("update_ambience",22.0,0)
	var material: StandardMaterial3D = guide.get("paint") as StandardMaterial3D
	check(is_equal_approx(material.emission_energy_multiplier,0.0),
		"actual electricity blackout extinguishes original LED landmark")
	guide.call("update_ambience",22.0,90)
	check(material.emission_energy_multiplier<=0.33 and
		material.emission_energy_multiplier>0.1,
		"night beacon is subdued and uses actual municipal power")
	guide.queue_free()
	await process_frame
	# REAL playable City Reign WORLD state, not substitute event UI.
	state=save.duplicate(true)
	state["mission"]=4
	sim.data=state
	var error: Error = change_scene_to_file("res://scenes/main.tscn")
	check(error==OK,"original source 3D playable city loads with new chapter director")
	if error!=OK:
		sim.data=original
		sim.locale=previous_locale
		quit(1)
		return
	await process_frame
	await physics_frame
	var game: Node3D = current_scene as Node3D
	var live: Node3D = game.get("city_reign_opening_director") as Node3D
	check(live!=null and bool(live.call("geometry_is_bounded")) and
		live.get("chosen")=="open_records",
		"real player controller / physical city actually installs original 3D guide")
	check((game.get("ambient_cars") as Array).size()==12 and
		(game.get("pedestrians") as Array).size()==34,
		"drivable original city traffic and 34 authored citizens remain unaffected")
	var treasury: int = int(sim.data["treasury"])
	var materials: int = int(sim.data["inventories"]["materials"])
	check(bool(sim.call("start_initiative","open_records")),
		"actual player starts the first genuinely paid source civic project")
	check(int(sim.data["treasury"])==treasury-380 and
		int(sim.data["inventories"]["materials"])==materials-12,
		"first chapter spends REAL resources once, not display-only fiction")
	check(live.get("current_stage")=="building" and
		live.get("chosen")=="open_records",
		"real saved state_changed event changes the actual player 3D beacon to worksite")
	check(not sim.call("start_initiative","open_records"),
		"repeated player approval cannot mint a second identical project")
	check(sim.call("advance_turn"),"original first construction city turn advances")
	check(sim.call("advance_turn"),"original second construction city turn advances")
	check(sim.data["projects_done"].has("open_records") and
		live.get("current_stage")=="delivered",
		"actual two-turn initiative reveals delivered 3D milestone without fake score")
	var built: Dictionary = (game.get("landmarks") as Node3D).get("created")
	check(built.has("open_records") and
		(built["open_records"] as Node3D).is_inside_tree(),
		"promised original public archive building appears in the real city street")
	check((game.get("city_reign_proposals") as Node3D).get("boards").has("open_records")==false,
		"the original initial promise board is removed after real construction")
	check(sim.data["mission"]==4,
		"visual director has not fabricated any previously gated career mission step")
	var saved_before: Dictionary = sim.data.duplicate(true)
	live.call("sync_state",sim.data,"en")
	live.call("set_quality","low")
	live.call("set_quality","cinematic")
	check(sim.data==saved_before,
		"visual localization, save/load and graphics cannot modify real treasury or XP")
	current_scene.queue_free()
	await process_frame
	sim.data=original
	sim.locale=previous_locale
	print("CITY REIGN AAA actual first-chapter street direction: %d PASS %d FAIL" % [passed,failed])
	quit(0 if failed==0 else 1)
