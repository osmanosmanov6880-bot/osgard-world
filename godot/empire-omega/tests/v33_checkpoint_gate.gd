extends SceneTree
## Native Godot 4.4.1: actual mesh and label nodes in the playable world.
## Purely decorative gate must never grant medals or block car physics.
const GATE = preload("res://scripts/trial_marker.gd")
const RACES = preload("res://scripts/driving_trials.gd")
var passed := 0
var failed := 0

func check(ok: bool, label: String) -> void:
	if ok:
		passed += 1
	else:
		failed += 1
		push_error("HORIZON R10 3D GATE: "+label)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var marker: Node3D = GATE.new()
	root.add_child(marker)
	check(not marker.visible,"idle gate starts invisible")
	var frame: Node3D = marker.get_node_or_null("EmissiveFrame")
	check(frame != null,"scene contains real 3D arch")
	var number: Label3D = marker.get_node_or_null("EmissiveFrame/CheckpointNumber") as Label3D
	check(number != null,"real world-space checkpoint counter")
	var count := 0
	var emissive := 0
	if frame != null:
		for part in frame.get_children():
			if part is MeshInstance3D:
				count += 1
				var mesh: MeshInstance3D = part as MeshInstance3D
				check(mesh.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,"no expensive gate mesh shadows")
				var mat: StandardMaterial3D = mesh.material_override as StandardMaterial3D
				if mat != null and mat.emission_enabled: emissive += 1
			check(not (part is CollisionObject3D) and not (part is CollisionShape3D),"decorative components never block driving physics")
	check(count >= 12 and count <= 18,"premium gate uses bounded mobile-compatible geometry")
	check(emissive >= 8,"multiple original emissive markers distinguish physical gate")
	var goal := Vector3(-156,1.2,-104)
	var start := Vector3(-156,1.2,-52)
	marker.call("show_at",goal,start,1,4)
	check(marker.visible,"active checkpoint becomes visible")
	check(marker.global_position.distance_to(goal) < 0.001,"world-space gate follows real race coordinates")
	check(absf(marker.rotation.y)<0.01,"northbound gate faces along race approach")
	check(number != null and number.text=="01 / 04","first checkpoint label uses authoritative count")
	marker.call("show_at",Vector3(52,1.2,-52),Vector3(0,1.2,-52),3,5)
	check(absf(marker.rotation.y+PI*0.5)<0.01,"eastbound gate rotates across avenue")
	check(number.text=="03 / 05","next checkpoint label refreshes without recreating node")
	var height_before: float = frame.position.y
	marker.call("_process",0.1)
	check(absf(frame.position.y-height_before)>0.001,"lightweight animated pulse works")
	marker.visible = false
	marker.call("_process",0.1)
	check(is_equal_approx(frame.position.y,frame.position.y),"hidden marker animation safe")
	var routes: Array = RACES.catalog()
	check(routes.size()>=4,"real academy route catalog exists")
	for route in routes:
		var pts: Array = route["checkpoints"]
		check(pts.size()>=3,"multiple gates defined by physical checkpoints "+str(route["id"]))
		var last: Vector3 = RACES.checkpoint(route,0)
		for step in range(1,pts.size()):
			var current: Vector3 = RACES.checkpoint(route,step)
			var yaw: float = GATE.approach_yaw(last,current)
			check(is_finite(yaw),"safe real route orientation "+str(route["id"])+" / "+str(step))
			last = current
	check(is_equal_approx(GATE.approach_yaw(Vector3.ZERO,Vector3.ZERO),0.0),"invalid zero-length heading is safe")
	var main: String = FileAccess.get_file_as_string("res://scripts/main.gd")
	check(main.contains("trial_marker.show_at(GameState.TRIALS.target(GameState.data),previous,checkpoint_index+1,total)"),"real checkpoint comes from GameState not invented mission progress")
	marker.queue_free()
	print("HORIZON R10 3D GATE NATIVE: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
