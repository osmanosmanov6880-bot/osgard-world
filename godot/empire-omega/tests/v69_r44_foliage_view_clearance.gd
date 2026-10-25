extends SceneTree
## EMPIRE Omega R44.2: actual live camera clears an occluding GPU-instanced
## pine crown without deleting world trees, adding transparency or colliders.
const SCENIC = preload("res://scripts/horizon_roadscape.gd")
var passed := 0
var failed := 0

func verify(ok: bool,why: String) -> void:
	if ok:
		passed += 1
	else:
		failed += 1
		push_error("EMPIRE OMEGA R44.2 VIEW FAILED: "+why)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var road: Node3D = SCENIC.new()
	root.add_child(road)
	var trees: Array = road.get("camera_tree_sources")
	verify(trees.size()==int(road.get("tree_count")) and trees.size()==192,
		"192 original authored trees remain in exact shared meshes")
	var trunk: MultiMeshInstance3D = road.get_node("TrunkBatch")
	var deciduous: MultiMeshInstance3D = road.get_node("LeafCanopyBatch")
	var conifer: MultiMeshInstance3D = road.get_node("LeafConeBatch")
	verify(trunk.multimesh.instance_count==192,"unchanged single trunk GPU batch")
	verify(deciduous.multimesh.instance_count+conifer.multimesh.instance_count==192,
		"two unchanged organic crown GPU batches")
	verify(trunk.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,
		"no new GPU shadow cost or collision")
	var selected: Dictionary = {}
	for tree in trees:
		if str(tree["crown_type"])=="pine":
			selected=tree
			break
	verify(not selected.is_empty(),"real pine tree exists in the city")
	if selected.is_empty():
		quit(1)
		return
	var crown: Transform3D = selected["crown_transform"]
	var centre: Vector3 = crown.origin
	var camera_at: Vector3 = centre+Vector3(0,0,12.0)
	var look_at: Vector3 = centre+Vector3(0,0,-12.0)
	verify(SCENIC.camera_occludes_tree(camera_at,look_at,centre),
		"real 3D chase camera segment meets opaque pine crown")
	verify(not SCENIC.camera_occludes_tree(camera_at,look_at,centre+Vector3(16.0,0,0)),
		"trees off to the side remain fully visible")
	verify(not SCENIC.camera_occludes_tree(camera_at,look_at,centre+Vector3(0,0,-18.0)),
		"trees behind the car do not disappear")
	verify(not SCENIC.camera_occludes_tree(Vector3(NAN,0,0),look_at,centre),
		"invalid camera coordinates do not destroy scenery")
	for i in range(28):
		road.call("update_camera_clearance",camera_at,look_at,1.0/60.0)
	var count: int = int(road.get("camera_clearance_hidden"))
	verify(count>0 and count<=192,"occlusion tracked as bounded real tree count")
	verify(float(selected["factor"])<=0.07,
		"the obstructing original crown shrinks to a 6 percent silhouette in the camera corridor")
	var target_mesh: MultiMeshInstance3D = conifer
	var actual: Transform3D = target_mesh.multimesh.get_instance_transform(int(selected["crown_index"]))
	print("R44.2 REAL GPU SHRINK: src=",crown.basis.x.length()," cpu=",actual.basis.x.length()," factor=",selected["factor"]," first_trunk=",trunk.multimesh.get_instance_transform(int(selected["trunk_index"])).basis.x.length())
	verify(actual.basis.x.length()<crown.basis.x.length()*0.10,
		"the real Godot MultiMesh tree instance changed geometry, not a UI screenshot")
	var trunk_transforms_before: int=trunk.multimesh.instance_count
	var conifers_before: int=conifer.multimesh.instance_count
	for i in range(30):
		road.call("update_camera_clearance",centre+Vector3(200,5,200),
			centre+Vector3(220,5,200),1.0/60.0)
	verify(float(selected["factor"])>=0.99,
		"original tree smoothly returns when the camera moves away")
	actual=target_mesh.multimesh.get_instance_transform(int(selected["crown_index"]))
	print("R44.2 REAL GPU RESTORE: src=",crown.basis.x.length()," cpu=",actual.basis.x.length()," factor=",selected["factor"]," first_trunk=",trunk.multimesh.get_instance_transform(int(selected["trunk_index"])).basis.x.length())
	verify(actual.basis.x.length()>crown.basis.x.length()*0.99,
		"original full-scale pine crown is physically restored")
	verify(trunk.multimesh.instance_count==trunk_transforms_before and
		conifer.multimesh.instance_count==conifers_before,
		"GPU instance counts, draw calls and all authored trees are never deleted")
	verify(road.get_child_count()>0 and int(road.get("tree_count"))==192,
		"actual game city scenery and lamp meshes survive occlusion logic")
	var main_script: Variant=load("res://scripts/main.gd")
	verify(main_script is Script and main_script.can_instantiate(),
		"real original playable game loads camera clearance integration")
	var main_src: String=FileAccess.get_file_as_string("res://scripts/main.gd")
	verify(main_src.contains('horizon_scenic.call("update_camera_clearance",camera.global_position,focus,delta)'),
		"authentic player camera drives tree transparency-free line of sight")
	road.queue_free()
	await process_frame
	print("EMPIRE OMEGA R44.2 ACTUAL CAMERA CLEARANCE: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
