extends SceneTree
## R188 physical Godot roadwork barriers, no rebuild on unrelated actions
const SITE=preload("res://scripts/roadworks_visual.gd")
const OPER=preload("res://scripts/city_reign_roadwork_operations.gd")
var pass_count: int=0
var fail_count: int=0
func verify(ok: bool,why: String) -> void:
	if ok:pass_count+=1
	else:
		fail_count+=1
		push_error("R188 NATIVE PHYSICAL ROADWORK FAIL: "+why)
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var gs: Node=root.get_node("GameState")
	var saved: Dictionary=(gs.get("data") as Dictionary).duplicate(true)
	var locale: String=str(gs.get("locale"))
	gs.set("data",gs.new_game())
	var works: Node3D=SITE.new()
	root.add_child(works)
	var active: Array[Dictionary]=OPER.active_sites(gs.data)
	verify(active.size()>0 and works.markers.size()==active.size() and
		works.source_integrity(gs.data),"actual original active roads own real physical 3D hazards")
	var id: String=str(active[0]["id"])
	var marker: Node3D=works.markers[id]
	var collider: CollisionShape3D=marker.get_node(
		"RoadClosureCollider/OriginalPhysicalRoadClosure")
	verify(collider.shape is BoxShape3D and not collider.disabled and
		is_equal_approx((collider.shape as BoxShape3D).size.x,9.8),
		"real original road blockade uses ONLY one 9.8m static physical collider")
	verify(marker.get_child_count()==5 and works.batches[id].size()==4 and
		works.batches[id]["beam"].multimesh.instance_count==2 and
		works.batches[id]["reflectors"].multimesh.instance_count==7 and
		works.batches[id]["braces"].multimesh.instance_count==2 and
		works.batches[id]["cones"].multimesh.instance_count==12,
		"authored 2 beams,7 reflectors,2 braces,12 actual cones share four GPU batches")
	verify(works.find_children("*","OmniLight3D",true,false).is_empty(),
		"no costly per-roadwork point lights or excessive shadow passes")
	var before: int=int(works.actual_site_creations)
	works.sync_state(gs.data)
	works.sync_state(gs.data)
	verify(works.actual_site_creations==before and
		works.markers[id]==marker and works.unchanged_syncs>=2,
		"original GameState no-op event preserves SAME true mesh, collider and GPU buffer")
	works.sync_city({"energy":100,"day_clock":22.0})
	verify(works.materials[id]["reflectors"].emission_enabled,
		"true city nighttime supplies subtle amber source hazard reflectance")
	works.set_quality("low")
	verify(works.batches[id]["beam"].visible and
		not works.batches[id]["cones"].visible and
		not works.materials[id]["reflectors"].emission_enabled and
		works.source_integrity(gs.data),
		"LOW retains visible full collision and mandatory 3D reflector barrier")
	works.set_quality("cinematic")
	verify(works.batches[id]["cones"].visible and
		works.materials[id]["reflectors"].emission_enabled and
		is_equal_approx(float(works.hour),22.0),
		"real original time preserved across dynamic mobile quality changes")
	works.sync_city({"energy":0,"day_clock":22.0})
	verify(not works.materials[id]["reflectors"].emission_enabled,
		"actual municipal blackout disables road warning emission, not physical geometry")
	var center: Vector3=active[0]["center"]
	verify(works.closest_hazard(center,9.0)==id and
		works.closest_hazard(Vector3(900,0,900),9.0)=="",
		"real player's existing original on-foot interaction radius survives")
	gs.data["treasury"]=1000
	gs.data["inventories"]["materials"]=20
	gs.data["actions_left"]=0
	verify(not gs.repair_road(id) and works.markers.has(id),
		"no free city repair without real original action")
	gs.data["actions_left"]=3
	verify(gs.repair_road(id),"original authorized 120/6/1 road repair transaction succeeds")
	works.sync_state(gs.data)
	verify(not works.markers.has(id) and works.actual_site_removals==1 and
		works.source_integrity(gs.data),
		"repaired original AStar segment instantly loses its hazard and physical object")
	verify(gs.data["treasury"]==880 and
		gs.data["inventories"]["materials"]==14 and
		gs.data["actions_left"]==2 and
		gs.data["roads_repaired_total"]==1,
		"real original treasury, material, action and road quality accounting")
	verify(not gs.repair_road(id) and gs.data["treasury"]==880,
		"original city cannot award a repeated repair transaction")
	await process_frame
	verify(not is_instance_valid(marker),
		"former physical StaticBody3D correctly freed, never leaves a hidden blocker")
	works.queue_free()
	await process_frame
	gs.set("data",saved)
	gs.set("locale",locale)
	print("CITY REIGN R188 REAL NATIVE ROADWORK: %d PASS %d FAIL" %
		[pass_count,fail_count])
	quit(0 if fail_count==0 else 1)
