extends SceneTree
## R91 source-grounded native architecture QA without any generated art.
const URBAN = preload("res://scripts/horizon_r90_street_dressing.gd")
var passed := 0
var failed := 0

func check(ok: bool,why: String) -> void:
	if ok:
		passed+=1
	else:
		failed+=1
		push_error("R91 ARCHITECTURE FAIL: "+why)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var streets: Node3D = URBAN.new()
	root.add_child(streets)
	check(streets.get_child_count()==3,"three scene roots: tower, bollard, batched architecture")
	check(bool(streets.call("graphics_are_bounded")),"only bounded instanced draw batches")
	var towers: MultiMeshInstance3D = streets.get("skyline")
	var bollards: MultiMeshInstance3D = streets.get("bollards")
	var art: Node3D = streets.get("r91_architecture")
	check(art!=null,"separate live 3D skyline architecture module")
	if towers!=null and bollards!=null and art!=null:
		var glass: MultiMeshInstance3D = art.get("facade_glass")
		var caps: MultiMeshInstance3D = art.get("rooftop_crowns")
		check(glass!=null and caps!=null,"actual native window and rooftop meshes")
		if glass!=null and caps!=null:
			check(towers.multimesh.instance_count==72 and caps.multimesh.instance_count==72,
				"every physical tower has one physical roof")
			var towers_plan: Array = art.get("original_tower_transforms")
			var crowns_plan: Array = art.get("original_rooftop_transforms")
			check(towers_plan.size()==72 and crowns_plan.size()==72,
				"actual source CPU draw transforms stored for all original tower instances")
			for i in [0,17,35,71]:
				var tower: Transform3D = towers_plan[i]
				var crown: Transform3D = crowns_plan[i]
				check(is_equal_approx(tower.origin.x,crown.origin.x) and
					is_equal_approx(tower.origin.z,crown.origin.z) and
					absf(crown.origin.y-
						(tower.origin.y+tower.basis.y.length()*0.5+0.38)) < 0.005,
					"rooftop physically coincides with authoritative tower transform")
				print("R91 actual source body height=",tower.basis.y.length(),
					" planned roof height=",crown.origin.y,
					" GPU-reported roof height=",caps.multimesh.get_instance_transform(i).origin.y)
			check(glass.multimesh.instance_count>=2000 and glass.multimesh.instance_count<=6912,
				"original four-sided façade windows stay within GPU budget")
			check((glass.material_override as StandardMaterial3D).vertex_color_use_as_albedo,
				"actual per-instance glass tint prevents blank white geometry")
			check(glass.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,
				"extra geometry does not multiply shadow draw cost")
			check(art.get_child_count()==2,"two bounded detail draw batches")
			for child in art.get_children():
				check(child is MultiMeshInstance3D,"no per-window node explosion")
				check(not (child is CollisionObject3D),"decorations never modify physics")
			streets.call("set_quality","low")
			check(not towers.visible and not bollards.visible and not glass.visible and not caps.visible,
				"LOW disables architecture on phone")
			streets.call("set_quality","standard")
			check(towers.visible and not bollards.visible and glass.visible and caps.visible,
				"STANDARD retains architecture, suppresses decorative bollards")
			streets.call("set_quality","cinematic")
			check(towers.visible and bollards.visible and glass.visible and caps.visible,
				"CINEMATIC shows all real meshes")
	streets.queue_free()
	await process_frame
	print("EMPIRE Omega R91 original native architecture: %d PASS, %d FAIL" % [passed,failed])
	quit(0 if failed==0 else 1)
