extends SceneTree
## Wave 4, must execute in real Godot; tests frame catch-up and safeguards.
const DYNAMICS = preload("res://scripts/driving_dynamics.gd")
var failures := 0
func require(ok: bool, description: String) -> void:
	if not ok:
		failures += 1
		push_error("V22: " + description)
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var whole: float = DYNAMICS.speed_step(0.0,1.0,1.0,1.0,29.0,9.0,9.5,10.5,2.4,false,0.4)
	var slices: float = 0.0
	for i in range(4):
		slices = DYNAMICS.speed_step(slices,1.0,1.0,1.0,29.0,9.0,9.5,10.5,2.4,false,0.1)
	require(absf(whole-slices) < 0.001,"0.4 second frame must equal four 0.1 second steps")
	var clamped: float = DYNAMICS.speed_step(0.0,1.0,1.0,1.0,29.0,9.0,9.5,10.5,2.4,false,5.0)
	var reference: float = DYNAMICS.speed_step(0.0,1.0,1.0,1.0,29.0,9.0,9.5,10.5,2.4,false,0.5)
	require(absf(clamped-reference)<0.001,"resume catch-up must be capped")
	require(DYNAMICS.speed_step(1.0,-1.0,1.0,1.0,29.0,9.0,9.5,10.5,2.4,false,0.1)>=0.0,"reverse first brakes")
	print("V22 native failures: %d" % failures)
	quit(1 if failures>0 else 0)
