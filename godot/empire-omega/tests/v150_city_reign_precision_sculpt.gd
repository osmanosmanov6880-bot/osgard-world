extends SceneTree
## R167 native test of true bound-preserving PBR body/roof mesh quality.
## Four original garage silhouettes, same physical player car and save.
const SCULPT=preload("res://scripts/horizon_coupe_sculpt.gd")
const GARAGE=preload("res://scripts/city_reign_player_vehicle_profiles.gd")
const CAR=preload("res://scripts/vehicle_controller.gd")
var passed:=0
var failed:=0

func check(ok: bool,reason: String) -> void:
	if ok: passed+=1
	else:
		failed+=1
		push_error("CITY REIGN R167 SURFACE FAIL: "+reason)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for use_roof in [false,true]:
		var original: Array=SCULPT.CANOPY_PROFILE if use_roof else SCULPT.BODY_PROFILE
		var refined: Array[Vector4]=SCULPT.refined_profile(original)
		check(refined.size()==(original.size()-1)*SCULPT.PROFILE_SUBDIVISIONS+1,
			"source Hermite profile inserts three stable genuine longitudinal subdivisions")
		for i in range(refined.size()):
			var p: Vector4=refined[i]
			check(is_finite(p.x) and is_finite(p.y) and is_finite(p.z) and is_finite(p.w),
				"original sculpt never creates invalid vertex profile")
			if i>0:
				check(p.x>refined[i-1].x,
					"authored shell stays strictly ordered along original z axis")
		var low: MeshInstance3D=SCULPT.sculpt("OriginalLow",original,StandardMaterial3D.new(),1)
		var high: MeshInstance3D=SCULPT.sculpt("R167TruePBR",original,StandardMaterial3D.new())
		var high_mesh: ArrayMesh=high.mesh as ArrayMesh
		var low_mesh: ArrayMesh=low.mesh as ArrayMesh
		var verts: PackedVector3Array=high_mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var norms: PackedVector3Array=high_mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]
		var tangents: PackedFloat32Array=high_mesh.surface_get_arrays(0)[Mesh.ARRAY_TANGENT]
		check(high_mesh.get_surface_count()==1 and high_mesh.surface_get_array_len(0)>low_mesh.surface_get_array_len(0)*2,
			"smoother authentic 3D curvature remains ONE original GPU source surface")
		check(verts.size()<=SCULPT.MAX_VERTEX_BUDGET and verts.size()>1500,
			"strict triangle budget prevents exploding WebGL/GPU allocations")
		check(norms.size()==verts.size() and tangents.size()==verts.size()*4,
			"Godot 4 actual PBR vertex normals and tangents are present for reflections")
		for index in range(0,verts.size(),maxi(1,verts.size()/24)):
			check(verts[index].is_finite() and norms[index].is_finite(),
				"interpolated real PBR vertices/normals are finite")
		var old_bounds: AABB=SCULPT.profile_bounds(original)
		var new_bounds: AABB=high_mesh.get_aabb()
		check(new_bounds.size.x<=old_bounds.size.x+0.04 and
			new_bounds.size.z<=old_bounds.size.z+0.04 and
			new_bounds.position.y>=old_bounds.position.y-0.04 and
			new_bounds.end.y<=old_bounds.end.y+0.04,
			"original car external dimensions and collision silhouette stay unchanged")
		low.free()
		high.free()
	var state: Node=root.get_node_or_null("GameState")
	var saved: Dictionary=(state.get("data") as Dictionary).duplicate(true)
	var car: CharacterBody3D=CAR.new()
	root.add_child(car)
	var art: Node3D=car.horizon_visual
	var shell: MeshInstance3D=art.get_node("FlowBody")
	var roof: MeshInstance3D=art.get_node("AerodynamicGreenhouse")
	var base_parts: int=(art.get("body_parts") as Array).size()
	var bodymesh: Mesh=shell.mesh
	for style in GARAGE.STYLES:
		car.apply_variant(style)
		check(shell.mesh!=null and roof.mesh!=null and
			shell.mesh.get_surface_count()==1 and roof.mesh.get_surface_count()==1,
			"real garage variant "+style+" continues to use only original 2 physical sculpt surfaces")
		check(shell.mesh.surface_get_array_len(0)>=1500 and
			roof.mesh.surface_get_array_len(0)>=1500,
			"real player "+style+" uses improved 3D profile density")
		check((art.get("body_parts") as Array).size()==base_parts,
			"garage switching cannot create extra scene nodes or body draws")
	car.apply_variant("compact")
	check(shell.mesh==bodymesh,
		"original compact car mesh reused, no gameplay frame allocations")
	check(GARAGE.cache_count()<=GARAGE.MAX_CACHED_NEW_MESHES and GARAGE.bounded(),
		"all noncompact 3D variants reuse six cached original bounded source meshes")
	check(state.get("data")==saved,
		"visual smoothing cannot change player progression, wallet, missions or saved city")
	car.queue_free()
	await process_frame
	print("CITY REIGN R167 PHYSICAL PBR SCULPT: %d PASS %d FAIL" % [passed,failed])
	quit(0 if failed==0 else 1)
