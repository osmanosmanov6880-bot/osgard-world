extends SceneTree
## CITY REIGN C3 - actual original Godot 3D mesh structures, not image mocks.
var passed: int = 0
var failed: int = 0

func check(value: bool, reason: String) -> void:
	if value:
		passed += 1
	else:
		failed += 1
		push_error("CITY REIGN C3 FAIL: " + reason)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var original: Script = load("res://scripts/project_landmarks.gd") as Script
	var catalog: Script = load("res://scripts/civic_initiatives.gd") as Script
	check(original != null and catalog != null and original.can_instantiate(),
		"original Godot 3D source files load")
	if original == null or catalog == null or not original.can_instantiate():
		quit(2)
		return
	var scene: Node3D = original.new()
	root.add_child(scene)
	var signatures := {}
	for project_id in catalog.ORDER:
		scene.sync_projects([project_id],{})
		check((scene.get("created") as Dictionary).size() == 1,
			"one completed civic project creates exactly one landmark: " + project_id)
		var node: Node3D = (scene.get("created") as Dictionary).get(project_id) as Node3D
		check(node != null,"real 3D landmark exists in world for " + project_id)
		if node == null:
			continue
		var signature: Node3D = node.get_node_or_null("Signature_" + project_id) as Node3D
		check(signature != null,"project-specific native shape: " + project_id)
		if signature != null:
			check(signature.get_child_count() >= 5,"real multi-mesh facility silhouette for " + project_id)
			var mesh_count: int = 0
			for child in signature.get_children():
				if child is MeshInstance3D:
					mesh_count += 1
			check(mesh_count >= 5,"real original MeshInstance3D geometry for " + project_id)
			check(signature.find_children("*","CollisionShape3D",true,false).is_empty(),
				"new decorative assets never interfere with player or vehicle physics")
			signatures[project_id] = signature.get_child(0).name
		for lang in ["ru","en","zh"]:
			scene.update_language(lang)
			var sign: Label3D = node.get_node_or_null("ProjectNameLabel") as Label3D
			check(sign != null and sign.text == str(catalog.PROJECTS[project_id][lang]),
				"real native street sign matches catalog in " + lang + " for " + project_id)
	check(signatures.size() == 8,"eight distinct functional projects are represented")
	var signature_names: Dictionary = {}
	for project_id in signatures:
		signature_names[str(signatures[project_id])] = true
	check(signature_names.size() >= 7,"different finished buildings have different identifying geometry")
	scene.sync_projects([],{})
	check((scene.get("created") as Dictionary).is_empty() and
		(scene.get("construction") as Dictionary).is_empty(),
		"reloading an empty save removes all eight municipal improvements")
	scene.queue_free()
	await process_frame
	print("CITY REIGN C3 distinct civic 3D: %d PASS %d FAIL" % [passed,failed])
	quit(0 if failed == 0 else 1)
