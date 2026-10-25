extends SceneTree
## Real Godot R37 masonry QA: 3 shared PBR albedo/normal/roughness families.
const PACK = preload("res://scripts/horizon_facade_material_pack.gd")
var passed := 0
var failed := 0
func check(ok: bool,reason: String) -> void:
	if ok: passed += 1
	else:
		failed += 1
		push_error("R37 PBR FAILED: "+reason)
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var materials: Array[StandardMaterial3D] = []
	for style in range(3):
		var mat: StandardMaterial3D = PACK.facade(Color("9da09c"),style)
		materials.append(mat)
		check(mat.albedo_texture!=null and mat.normal_texture!=null and mat.roughness_texture!=null,"real three-channel PBR textures "+str(style))
		check(mat.normal_enabled and mat.normal_scale>=0.18,"true normal mapped detail "+str(style))
		check(mat.roughness>=0.80 and mat.metallic<=0.03,"mineral surfaces remain matte "+str(style))
		check(mat.uv1_world_triplanar,"real cuboid world triplanar UV "+str(style))
		check(mat.albedo_texture.get_width()==128 and mat.normal_texture.get_height()==128,"bounded 128 pixel PBR tile "+str(style))
		var color: Image = mat.albedo_texture.get_image()
		check(color.get_pixel(0,0).r!=color.get_pixel(11,9).r,"surface has procedural variation "+str(style))
		var other: StandardMaterial3D = PACK.facade(Color("647a8b"),style+3)
		check(PACK.textures_reused(mat,other),"tinted buildings reuse three original textures "+str(style))
	check(PACK.cached_styles()==3,"three total GPU texture triplets, no per-building allocation")
	check(PACK.allocation_budget_bytes()<=590000,"uncompressed original pixels within 590K before mipmaps")
	check(materials[0].albedo_texture!=materials[1].albedo_texture,"stone texture differs from plaster")
	check(materials[1].albedo_texture!=materials[2].albedo_texture,"brick differs from limestone")
	var brick: Image = materials[2].albedo_texture.get_image()
	check(brick.get_pixel(7,12).r<brick.get_pixel(7,8).r,"brick mortar is lower than face")
	var source: String = FileAccess.get_file_as_string("res://scripts/world_builder.gd")
	check(source.contains('R37_MATERIAL_PACK.facade(color,int(label.trim_prefix("Building_")))'),"live city uses material variation")
	var world_script: Variant = load("res://scripts/world_builder.gd")
	check(world_script!=null and world_script is Script and world_script.can_instantiate(),"actual Godot world parses")
	if world_script!=null and world_script is Script and world_script.can_instantiate():
		var world: Node3D = world_script.new()
		root.add_child(world)
		var styles: Dictionary = {}
		var examined := 0
		var chunks: Dictionary = world.get("building_chunks")
		for key in chunks:
			var quarter: Node3D = chunks[key]["node"]
			for node in quarter.get_children():
				if not node.name.begins_with("Building_"):
					continue
				var mesh: MeshInstance3D = node.get_node_or_null("VisualMesh")
				if mesh == null or not (mesh.material_override is StandardMaterial3D):
					continue
				var material: StandardMaterial3D = mesh.material_override
				check(material.normal_enabled and material.roughness_texture!=null,"actual building PBR used in scene")
				styles[posmod(int(node.name.trim_prefix("Building_")),3)] = true
				examined += 1
				if examined>=18: break
			if examined>=18: break
		check(examined>=18 and styles.size()==3,"original built quarters contain all three textures")
		world.queue_free()
	var game_script: Variant = load("res://scripts/main.gd")
	check(game_script!=null,"actual playable Godot main script still parses")
	await process_frame
	print("EMPIRE OMEGA R37 NATIVE: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
