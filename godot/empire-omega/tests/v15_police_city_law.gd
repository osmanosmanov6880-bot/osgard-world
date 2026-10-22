extends SceneTree
## Native verification: law ledger, legacy migration and physical police scene.
## This test is only meaningful when executed by the real Godot 4.4.1 engine.
const LAW = preload("res://scripts/city_law.gd")
const PATROLS = preload("res://scripts/police_dispatch.gd")
const TRAFFIC = preload("res://scripts/traffic_agent.gd")
var total := 0
var failed := 0

func check(condition: bool, description: String) -> void:
	total += 1
	if not condition:
		failed += 1
		push_error("LAW FAILED: "+description)
	else:
		print("LAW OK: "+description)

func _initialize() -> void:
	call_deferred("run_checks")

func run_checks() -> void:
	var sim: Variant = root.get_node_or_null("GameState")
	if sim == null:
		push_error("GameState autoload is missing")
		quit(2)
		return
	var fresh: Dictionary = sim.new_game()
	check(LAW.valid(fresh["law"],1),"new game law record validates")
	check(LAW.register(fresh,"collision"),"collision creates first offence")
	check(int(fresh["law"]["fine"])==180,"collision fine recorded")
	check(not LAW.register(fresh,"collision"),"offence cooldown prevents duplicate penalty")
	for i in range(72):
		LAW.progress(fresh,0.25,true)
	check(LAW.register(fresh,"speeding"),"speeding escalates after cooldown")
	check(int(fresh["law"]["heat"])==2,"two-star pursuit")
	check(int(fresh["law"]["fine"])==360,"escalating fines")
	check(LAW.valid(fresh["law"],1),"escalated law state valid")
	var prior_treasury: int = int(fresh["treasury"])
	check(LAW.settle(fresh,true),"patrol stop issues settlement")
	check(int(fresh["law"]["heat"])==0,"pursuit stops after fine")
	check(int(fresh["treasury"])==prior_treasury+360,"fine transfers into municipal budget")
	check(not LAW.settle(fresh,true),"no duplicate settlement")
	var legacy: Dictionary = sim.new_game()
	legacy.erase("law")
	check(sim._valid_state(legacy),"prior v4 save still accepted")
	var upgraded: Dictionary = sim._upgrade_state(legacy)
	check(LAW.valid(upgraded["law"],1),"prior v4 save upgraded to new law record")
	var json_copy: Variant = JSON.parse_string(JSON.stringify(fresh))
	check(json_copy is Dictionary and sim._valid_state(json_copy),"Godot JSON round-trip preserves integral number fields")
	var broken: Dictionary = upgraded.duplicate(true)
	broken["law"]["fine"] = -1
	check(not sim._valid_state(broken),"malformed law save rejected")
	var city := Node3D.new()
	root.add_child(city)
	var patrols = PATROLS.new()
	city.add_child(patrols)
	check(patrols.vehicles.size()==3,"three physically-instanced patrols")
	check(patrols.vehicles[0] is CharacterBody3D,"patrol uses real collidable car")
	patrols.tick(Vector3(-100,1,-100),sim.new_game(),2,0.016,1.0)
	check(patrols.active_level==2,"two-star wanted activates two patrols")
	check(patrols.vehicles[0].visible and patrols.vehicles[1].visible,"active police units visible")
	check(patrols.vehicles[0].points.size()>=2,"police receives road routing")
	var original_position: Vector3 = patrols.vehicles[0].global_position
	var change_route: Array[Vector3] = [original_position,original_position+Vector3(12.0,0,0)]
	patrols.vehicles[0].retarget(change_route)
	check(patrols.vehicles[0].global_position.distance_to(original_position)<0.01,"pursuit replanning never teleports")
	patrols.reset_patrols()
	check(patrols.active_level==0 and not patrols.vehicles[0].visible,"patrol resets cleanly")
	city.queue_free()
	print("City law native acceptance: %d checks, %d failed" % [total,failed])
	quit(0 if failed==0 else 1)
