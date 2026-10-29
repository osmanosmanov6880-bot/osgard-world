extends SceneTree
## R176 real native car cargo meshes + honest physical progress gauge.
const VISUAL=preload("res://scripts/cargo_visual.gd")
const CARGO=preload("res://scripts/cargo_logistics.gd")
var passed: int=0
var failed: int=0
func check(ok: bool,why: String) -> void:
	if ok: passed+=1
	else:
		failed+=1
		push_error("R176 ORIGINAL PHYSICAL CARGO HUD FAIL: "+why)
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var original_sim: Node=root.get_node("GameState")
	var original_state: Dictionary=(original_sim.get("data") as Dictionary).duplicate(true)
	var model: Node3D=VISUAL.new()
	root.add_child(model)
	check(model.visuals_are_source_bounded() and model.get_child_count()==6,
		"same three real car crates plus exactly two physical gauges and one label")
	check(not model.visible and model.display_is_authoritative(),
		"no cargo means no false progress display or unexpected work")
	var freight: Dictionary=CARGO.begin({"id":"test","cargo":"grain",
		"quantity":12,"pickup":"market","dropoff":"depot","reward":120},
		100.0,0.0,100.0,"compact",1)
	var local: Dictionary={"active_contract":freight}
	model.sync_state(local,"ru")
	check(model.visible and model.last_projection["meters"]==0 and
		not model.distance_fill.visible and model.distance_frame.visible,
		"original trip at 0 metres has an empty real native gauge")
	check((model.crates[0] as MeshInstance3D).mesh==(model.crates[2] as MeshInstance3D).mesh,
		"all three original crates share one authored 3D mesh GPU resource")
	CARGO.update(freight,20.0,93.0,true,"rain")
	model.sync_state(local,"en")
	check(model.distance_fill.visible and
		absf(model.distance_fill.scale.x-0.2)<0.005 and
		model.cargo_text.text.contains("20/100"),
		"true source-driven odometer and cargo damage reflect immediately in 3D")
	model.set_quality("low")
	check(model.visible and not model.distance_frame.visible and
		not model.distance_fill.visible and model.crates[0].mesh==model.low_case,
		"LOW/mobile removes all optional GPU meter and retains old 3 crate boxes")
	model.set_quality("cinematic")
	check(model.crates[0].mesh==model.native_case and
		model.distance_fill.visible and model.visuals_are_source_bounded(),
		"cinematic restores real sculpted physical cargo with same original cases")
	model.sync_state({},"ru")
	check(not model.visible and model.cargo_text.text=="",
		"completed/absent contract clears stale gauge rather than inventing delivery")
	check(original_sim.get("data")==original_state,
		"genuine physical art/label changes cannot alter original save, wallet or mission")
	model.queue_free()
	await process_frame
	print("CITY REIGN R176 REAL CAR HUD GPU: %d PASS %d FAIL" % [passed,failed])
	quit(0 if failed==0 else 1)
