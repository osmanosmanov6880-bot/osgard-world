extends SceneTree
## R189 native source light selection is bounded and cannot cause
## repeated per-frame allocations/spotlight growth on mobile Chromium.
const HEADLIGHTS=preload("res://scripts/city_reign_pooled_traffic_headlights.gd")
var passed: int=0
var failed: int=0
func check(ok: bool,why: String) -> void:
	if ok:passed+=1
	else:
		failed+=1
		push_error("R189 PHYSICAL NIGHT LIGHT BUDGET FAIL: "+why)
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var fixture:=Node3D.new()
	root.add_child(fixture)
	var sources: Array=[]
	for i in range(12):
		var car:=Node3D.new()
		car.position=Vector3(float(i)*9.0,0.8,0)
		fixture.add_child(car)
		sources.append(car)
	var pool=HEADLIGHTS.new()
	root.add_child(pool)
	pool.set_sources(sources)
	pool.sync_real_city(Vector3(0,0.8,0),23.0,"cinematic","clear",0.01)
	var initial: int=pool.selection_changes
	var original_beams: Array=pool.beams.duplicate()
	for i in range(29):
		pool.sync_real_city(Vector3(0,0.8,0),23.0,"cinematic","clear",0.01)
	check(pool.selection_changes==initial and
		pool.real_sync_frames>=30,
		"actual 60fps physical light positions update without 30 redundant nearest-car reallocations")
	check(pool.source_integrity() and pool.get_child_count()==6 and
		pool.beams==original_beams,
		"real three-pair native pool never creates new lights per physics frame")
	pool.sync_real_city(Vector3(120,0.8,0),23.0,"cinematic","clear",0.4)
	check(pool.selection_changes==initial+1 and
		pool.selected.size()>0 and
		pool.selected[0]==sources[11],
		"real source closest-car switch happens only at 0.6-second budgeted interval")
	for i in range(6):
		pool.sync_real_city(Vector3(120,0.8,0),12.0,"cinematic","clear",0.1)
	check(pool.active_physical_pairs==0 and pool.get_child_count()==6,
		"daylight never leaks active lights or grows game scene tree across repeated updates")
	pool.sync_real_city(Vector3(120,0.8,0),23.0,"standard","clear",0.1)
	check(pool.active_physical_pairs==1 and
		pool.beams.filter(func(l):return l.visible).size()==2,
		"original actual STANDARD one-pair budget recovers after day-to-night transition")
	check(HEADLIGHTS.MAX_NATIVE_BEAMS+2==8 and
		HEADLIGHTS.MAX_NATIVE_BEAMS<HEADLIGHTS.ORIGINAL_CARS*2,
		"original mobile GPU light budget is 8 including existing player, never all 26")
	pool.queue_free()
	fixture.queue_free()
	await process_frame
	print("CITY REIGN R189 60FPS LIGHT POOL BOUND: %d PASS %d FAIL" % [passed,failed])
	quit(0 if failed==0 else 1)
