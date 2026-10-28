extends SceneTree
## R28 actual Godot 4.4.1 civic hub, PBR shell, non-neon details and LOW GPU.
const GATEWAY = preload("res://scripts/horizon_civic_gateway.gd")
var passed := 0
var failed := 0

func verify(ok: bool, label: String) -> void:
	if ok:
		passed += 1
	else:
		failed += 1
		push_error("HORIZON R28 FAILURE: "+label)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var civic: Node3D = GATEWAY.new()
	root.add_child(civic)
	verify(int(civic.get("batches"))==GATEWAY.MAX_BATCHES,"civic details use seven bounded MultiMeshes")
	verify(civic.get_child_count()==7,"no per-column or per-window draw calls")
	verify(int(civic.get("pieces"))==58,"PBR palace has 58 batched pieces, not hundreds of independent nodes")
	var expected: Dictionary = {
		"CivicStonePillars":6,
		"CivicCapitals":6,
		"CivicWindowFrames":20,
		"CivicDarkGlass":20,
		"CivicCornices":4,
		"CivicPortico":1,
		"CivicPortal":1
	}
	for key in expected:
		var part: MultiMeshInstance3D = civic.get_node_or_null(key) as MultiMeshInstance3D
		verify(part!=null,"native visual architecture includes "+str(key))
		if part!=null:
			verify(part.multimesh.instance_count==int(expected[key]),"instanced count for "+str(key))
			verify(part.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,"mobile shadow budget remains capped for "+str(key))
			var mat: StandardMaterial3D = part.material_override as StandardMaterial3D
			verify(mat!=null and mat.vertex_color_use_as_albedo,"PBR material uses individual instance colors for "+str(key))
			verify(mat!=null and not mat.emission_enabled,"no fluorescent fake-neon palace: "+str(key))
	var columns: MultiMeshInstance3D = civic.get_node("CivicStonePillars")
	var physical_stone: ArrayMesh = columns.multimesh.mesh as ArrayMesh
	verify(physical_stone != null and physical_stone.get_surface_count()==1,
		"R130 replaces simple cylinder with one actual authored fluted limestone 3D surface")
	if physical_stone != null:
		verify(physical_stone.surface_get_array_len(0)==GATEWAY.R130_COLUMN_TRIANGLES*3,
			"R130 12 physical flutes and real entasis improve original 6 shared columns")
	var capital_mesh: ArrayMesh = (civic.get_node("CivicCapitals") as MultiMeshInstance3D).multimesh.mesh as ArrayMesh
	verify(capital_mesh != null and capital_mesh.surface_get_array_len(0)==GATEWAY.R130_CAPITAL_TRIANGLES*3,
		"original six shared stone capitals now use 4 real carved profiles, not one pale box")
	var stone_finish: StandardMaterial3D = columns.material_override as StandardMaterial3D
	verify(stone_finish.normal_enabled and stone_finish.normal_texture!=null,"columns have actual PBR normal-textured stone finish")
	var glass: StandardMaterial3D = (civic.get_node("CivicDarkGlass") as MultiMeshInstance3D).material_override as StandardMaterial3D
	verify(glass.roughness<0.35 and glass.metallic<0.25,"dark facade glazing stays physically bounded")
	var collisions:=0
	for part in civic.get_children():
		if part is CollisionObject3D:
			collisions+=1
	verify(collisions==0,"decorative civic gateway adds zero physics bodies")
	var scene: Variant = load("res://scripts/world_builder.gd")
	verify(scene!=null,"original playable full city can load")
	if scene!=null:
		var world: Node3D = scene.new()
		root.add_child(world)
		var installed: Node3D = world.get("cityhall_gateway")
		verify(installed!=null and installed.is_inside_tree(),"real playable city instantiates R28 gateway at level entry")
		verify(installed.position==Vector3(-130.0,0.0,-130.0),"PBR gateway is placed on the actual opening landmark")
		verify(int(installed.get("batches"))==7,"real full world preserves single-batch PBR details")
		var shell: StaticBody3D = world.get_node_or_null("ProceduralDistricts/cityhall_landmark") as StaticBody3D
		verify(shell!=null,"original cityhall collision body is still present")
		if shell!=null:
			var old_shape: CollisionShape3D = shell.get_node_or_null("CollisionShape3D") as CollisionShape3D
			verify(old_shape!=null and old_shape.shape is BoxShape3D,"original 25m landmark collision volume retained")
			var finish: StandardMaterial3D = (shell.get_node("VisualMesh") as MeshInstance3D).material_override as StandardMaterial3D
			verify(finish!=null and finish.normal_enabled and finish.roughness>0.7,"real major facade now has matte normal-textured masonry")
		verify(world.get_node_or_null("ProceduralDistricts/CivicGlazing")==null,"old unbatched expensive glazing removed")
		verify(world.get_node_or_null("ProceduralDistricts/CivicLightRibbon")==null,"harsh neon palace ribbon removed")
		world.apply_visual_budget("low")
		verify(not installed.visible,"LOW graphics hides 58 optional architectural details")
		world.apply_visual_budget("cinematic")
		verify(installed.visible,"cinematic tier restores opening PBR civic architecture")
		verify(world.get("streetfront")!=null,"R27 street-facing shops remain intact")
		world.queue_free()
	civic.queue_free()
	print("HORIZON R28 NATIVE: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
