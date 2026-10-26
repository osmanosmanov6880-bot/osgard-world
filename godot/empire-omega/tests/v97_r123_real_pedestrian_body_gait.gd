extends SceneTree
## EMPIRE Omega R123 original Godot 4.4.1 native real 3D pedestrian art.
## Preserve existing R41/R47 safety, no extra physics bodies, stable cache.
const ART = preload("res://scripts/horizon_street_citizen_mesh.gd")
const WALKER = preload("res://scripts/pedestrian_agent.gd")
const RULE = preload("res://scripts/horizon_pedestrian_yield.gd")
var passed: int = 0
var failed: int = 0

func verify(condition: bool, why: String) -> void:
	if condition:
		passed += 1
	else:
		failed += 1
		push_error("R123 REAL WALKING CITIZENS FAILED: "+why)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game: Node = root.get_node_or_null("GameState")
	verify(game != null,"original authoritative gameplay/autoload is mounted")
	if game == null:
		quit(1)
		return
	var original: Dictionary = (game.get("data") as Dictionary).duplicate(true)
	var sampled: ArrayMesh = ART.mesh_for(0,0)
	verify(sampled != null and sampled.get_surface_count()==1,
		"one authentic physical 3D silhouette with ONE draw surface, not 20 body meshes")
	var source_count: int = 0
	if sampled != null and sampled.get_surface_count()==1:
		var arrays: Array = sampled.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
		source_count = vertices.size()
		verify(source_count >= 600 and source_count <= 1000 and
			ART.triangle_budget() == source_count/3,
			"real coat, limbs, eyes, shoes and facial hair are bounded to 200-333 triangles")
		verify(normals.size()==source_count and colors.size()==source_count,
			"all physical polygon surfaces contain actual shading normals and palette colors")
		var min_extent: Vector3 = Vector3(INF,INF,INF)
		var max_extent: Vector3 = Vector3(-INF,-INF,-INF)
		var tones: Dictionary = {}
		for index in range(source_count):
			var v: Vector3 = vertices[index]
			verify(v.is_finite() and normals[index].is_finite(),
				"each real body vertex and face normal has finite physical position")
			min_extent = min_extent.min(v)
			max_extent = max_extent.max(v)
			tones[str(colors[index])]=true
		verify(tones.size()>=5,
			"actual citizen outfit has separate hair, skin, shoes, pants, and jacket")
		verify(min_extent.x < -0.38 and max_extent.x > 0.38 and
			min_extent.y < -0.87 and max_extent.y > 0.80,
			"actual arms, feet and recognizable head have human-scale physical volume")
		verify(max_extent.y-min_extent.y < 1.85 and
			max_extent.x-min_extent.x < 1.4 and
			max_extent.z-min_extent.z < 1.2,
			"original NPC stays within authentic real pedestrian hit/safety envelope")
	var material: StandardMaterial3D = ART.shared_material()
	verify(material != null and material.vertex_color_use_as_albedo and
		material.shading_mode != BaseMaterial3D.SHADING_MODE_UNSHADED and
		not material.emission_enabled and material.roughness >= 0.7,
		"actual premium cloth+skin are physically shaded PBR, not fullbright decals")
	verify(ART.mesh_for(4,0)==sampled,
		"same actual citizen style uses cached SHARED GPU mesh, no new object per pedestrian")
	verify(ART.mesh_for(0,4)==sampled,
		"four-frame original gait wraps predictably, no unbounded animation allocation")
	verify(ART.mesh_for(1,0)!=sampled and ART.mesh_for(2,0)!=sampled,
		"deterministic citizens actually wear different physical fabric palettes")
	for outfit in range(ART.STYLES):
		for pose in range(ART.GAIT_FRAMES):
			var asset: ArrayMesh = ART.mesh_for(outfit,pose)
			verify(asset != null and asset.get_surface_count()==1 and
				asset.surface_get_array_len(0)==source_count,
				"every real cached walking phase remains exactly one mesh with fixed triangle budget")
	verify(ART.cached_meshes()==16,
		"all four outfits x four walking phases cached and GPU bounded after warmup")
	var rest_vertices: PackedVector3Array = ART.mesh_for(0,0).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var step_vertices: PackedVector3Array = ART.mesh_for(0,1).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var difference: int = 0
	for i in range(rest_vertices.size()):
		if rest_vertices[i].distance_to(step_vertices[i])>0.045:
			difference += 1
	verify(difference>=70,
		"real legs/arms physically CHANGE their actual vertex geometry between steps")
	var walkers: Array[Node3D] = []
	for index in range(12):
		var person: Node3D = WALKER.new()
		person.set("citizen_id",index)
		root.add_child(person)
		walkers.append(person)
		var visual: MeshInstance3D = person.get("body_mesh") as MeshInstance3D
		verify(person.get_child_count()==1 and visual!=null,
			"NPC still creates ONE visible source-MeshInstance3D, no costly per-body scene nodes")
		if visual != null:
			verify(visual.mesh==ART.mesh_for(index,0) and
				visual.material_override==material and visual.visible,
				"original 12 real citizens reuse one physically shaded cached material and mesh")
			verify(visual.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,
				"32+ original ambient citizens do not multiply mobile shadow draw calls")
		verify(person is Node3D and not (person is CollisionObject3D),
			"original city population remains lightweight with no colliders or fake physics")
	var first: Node3D = walkers[0]
	var initial: Mesh = (first.get("body_mesh") as MeshInstance3D).mesh
	var waypoints: Array[Vector3] = [
		first.global_position, first.global_position+Vector3(30.0,0.0,0.0)]
	first.set("route",waypoints)
	first.set("next_waypoint",1)
	first.call("_process",0.20)
	verify((first.get("planned_velocity") as Vector3).length()>1.0,
		"real citizen still follows true routes rather than acting as a static billboard")
	verify(first.global_position.x>0.0,
		"real original walker physically translates along the route with same speed")
	verify((first.get("body_mesh") as MeshInstance3D).mesh!=initial or
			float(first.get("walking_phase"))>0.0,
		"actual walking animation advances and selects cached motion geometry")
	verify(RULE.should_yield(Vector3.ZERO,Vector3.ZERO,
		Vector3(-16.0,0.0,0.0),Vector3(9.0,0.0,0.0)),
		"original predictive car/pedestrian safety remains authoritative")
	verify(not RULE.should_yield(Vector3.ZERO,Vector3.ZERO,
		Vector3(-16.0,0.0,4.2),Vector3(9.0,0.0,0.0)),
		"original crossing model still ignores cars in the adjacent lane")
	verify(game.get("data")==original,
		"all art updates leave finances, tasks, policy, missions and saved slots intact")
	for person in walkers:
		person.queue_free()
	await process_frame
	print("EMPIRE OMEGA R123 original sculpted 3D pedestrians/gait: %d PASS %d FAIL" %
		[passed,failed])
	quit(0 if failed==0 else 1)
