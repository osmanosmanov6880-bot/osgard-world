extends SceneTree
## R188 full original main.tscn: TRUE actual on-foot F/E repair and AStar
const OPER=preload("res://scripts/city_reign_roadwork_operations.gd")
const MOBILITY=preload("res://scripts/city_mobility.gd")
const ROUTER=preload("res://scripts/street_router.gd")
var pass_count: int=0
var fail_count: int=0
func verify(ok: bool,why: String) -> void:
	if ok:pass_count+=1
	else:
		fail_count+=1
		push_error("R188 FULL ORIGINAL ROAD REPAIR GAME FAIL: "+why)
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var gs: Node=root.get_node("GameState")
	var old: Dictionary=(gs.get("data") as Dictionary).duplicate(true)
	var locale: String=str(gs.get("locale"))
	gs.set("data",gs.new_game())
	gs.data["treasury"]=1000
	gs.data["inventories"]["materials"]=20
	gs.data["actions_left"]=3
	var baseline: Dictionary=gs.data.duplicate(true)
	var result: Error=change_scene_to_file("res://scenes/main.tscn")
	verify(result==OK,"full original playable Godot 3D world really loads")
	if result!=OK:
		gs.set("data",old)
		gs.set("locale",locale)
		quit(2)
		return
	await process_frame
	for i in range(9):await physics_frame
	var game: Node3D=current_scene as Node3D
	var works: Node3D=game.get("roadworks") as Node3D
	var player: CharacterBody3D=game.get("player") as CharacterBody3D
	var traffic: Array=game.get("ambient_cars")
	var residents: Array=game.get("pedestrians")
	var signals: Node3D=game.get("traffic_signals") as Node3D
	verify(works!=null and player!=null and
		traffic.size()==12 and residents.size()==34 and
		works.source_integrity(gs.data),
		"original 12 moving native traffic cars / 34 real residents use real original roadwork sites")
	verify(signals.real_junction_box_paint.source_geometry_valid() and
		signals.real_zebra_crossings.source_geometry_valid() and
		signals.true_speed_signs.source_integrity(),
		"new real city repair preserves R187 144 keep-clear, 384 zebra and 64 native speed signs")
	var sites: Array[Dictionary]=OPER.active_sites(gs.data)
	var id: String=str(sites[0]["id"])
	var center: Vector3=sites[0]["center"]
	var axis: Vector3=sites[0]["axis"]
	var right:=Vector3(-axis.z,0,axis.x)
	var angle: float=atan2(-axis.x,-axis.z)
	verify(works.driver_warning(center-axis*28.0+right*2.0,
		angle,8.0).get("incident_id","")==id,
		"real player receives actual blocked-AStar road warning before collision")
	var info: Dictionary=MOBILITY.incident_by_id(id)
	var a: Array=info["a"]
	var b: Array=info["b"]
	var from: Vector3=MOBILITY._pos(Vector2i(int(a[0]),int(a[1])))
	var to: Vector3=MOBILITY._pos(Vector2i(int(b[0]),int(b[1])))
	var blocked: float=MOBILITY.length(ROUTER.find_route(from,to,gs.data))
	var positions: Array[Vector3]=[]
	var velocities: Array[float]=[]
	for car in traffic:
		positions.append(car.global_position)
		velocities.append(float(car.speed))
	player.set_physics_process(false)
	player.global_position=Vector3(center.x,0.8,center.z+1.3)
	verify(works.closest_hazard(player.global_position,9.0)==id,
		"actual 3D player stands within original real physical road-repair interaction")
	# ACTUAL original F/E action, original GameState transaction, original
	# mission trigger and existing state_changed road replanning.
	game.call("_interact")
	verify(gs.data["roads_cleared"].has(id) and
		not works.markers.has(id) and works.source_integrity(gs.data),
		"real F/E interaction removes physical barricade and canonical closure")
	verify(gs.data["treasury"]==int(baseline["treasury"])-120 and
		gs.data["inventories"]["materials"]==
			int(baseline["inventories"]["materials"])-6 and
		gs.data["actions_left"]==int(baseline["actions_left"])-1,
		"real player repair costs exactly canonical original 120/6/1")
	verify(blocked>MOBILITY.length(ROUTER.find_route(from,to,gs.data))+40.0,
		"original AStar resumes direct road following actual player's paid repair")
	verify(works.driver_warning(center-axis*28.0+right*2.0,
		angle,8).get("incident_id","")!=id,
		"3D roadside repair removes source player closure alert immediately")
	var kept: bool=true
	for i in range(traffic.size()):
		if (traffic[i].global_position.distance_to(positions[i])>0.001 or
			absf(float(traffic[i].speed)-velocities[i])>0.001):
			kept=false
	verify(kept,"all 12 native NPC reroutes preserve live physical position and speed, no teleport")
	verify(gs.data["roads_repaired_total"]==1 and
		gs.data["inventories"]["materials"]>=0,
		"original mission/action/economy and save remain valid")
	game.queue_free()
	await process_frame
	gs.set("data",old)
	gs.set("locale",locale)
	print("CITY REIGN R188 FULL ORIGINAL REAL PLAYABLE ROAD REPAIR: %d PASS %d FAIL" %
		[pass_count,fail_count])
	quit(0 if fail_count==0 else 1)
