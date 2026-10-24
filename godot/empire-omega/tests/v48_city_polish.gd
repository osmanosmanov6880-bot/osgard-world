extends SceneTree
## HORIZON R25: verify actual premium-looking materials, GPU batches and touch UI.
## This is native scene QA; it is not an assertion of AAA photorealism.
const FACADE = preload("res://scripts/horizon_facade_materials.gd")
const TRIM = preload("res://scripts/horizon_architecture_trim.gd")
const LAYOUT = preload("res://scripts/horizon_responsive_layout.gd")
const TOUCH = preload("res://scripts/horizon_touch_controls.gd")
var passed := 0
var failed := 0

func check(ok: bool, message: String) -> void:
	if ok: passed+=1
	else:
		failed+=1
		push_error("HORIZON R25 FAILED: "+message)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var warm: StandardMaterial3D = FACADE.facade(Color("7b7d7f"))
	var cool: StandardMaterial3D = FACADE.facade(Color("5c7185"))
	check(warm.albedo_texture!=null and warm.normal_texture!=null,"facade has actual PBR albedo and normal maps")
	check(warm.normal_enabled and warm.normal_scale>0.0,"real textured walls include subtle normal bumps")
	check(warm.roughness>=0.70 and warm.metallic<0.1,"facade is matte plaster rather than neon metal")
	check(FACADE.textures_reused(warm,cool),"all different building colors reuse the same two GPU textures")
	check(warm.albedo_texture.get_width()==64 and warm.normal_texture.get_width()==64,"PBR texture allocations are bounded at 64px")
	var image: Image = warm.albedo_texture.get_image()
	check(image.get_pixel(4,4).r!=image.get_pixel(8,4).r,"wall texture contains real procedural surface variation")
	var trim: MultiMeshInstance3D = TRIM.new()
	trim.record(Vector3(15,7,22),12.0,14.0)
	trim.record(Vector3(-25,12,-30),15.0,24.0)
	trim.finalize()
	check(trim.source_buildings==2,"architectural cornices count distinct recorded buildings")
	check(trim.multimesh.instance_count==8,"two buildings need eight solid cornice beams in one draw batch")
	check(trim.material_override!=null and not (trim.material_override as StandardMaterial3D).emission_enabled,"trim is physically shaded without fake neon glow")
	check(trim.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,"extra geometry avoids shadow-map GPU work")
	trim.queue_free()
	for size in [Vector2(320,568),Vector2(390,844),Vector2(430,932),Vector2(860,540)]:
		var frame: Dictionary = LAYOUT.compute(size)
		var minimap: Rect2 = frame["map"]
		var quick: Rect2 = frame["quick_toggle"]
		check(minimap.size.x==136.0 and minimap.size.y==136.0,"mobile minimap remains compact: "+str(size))
		check(not minimap.intersects(quick),"minimap never covers native quick-action button: "+str(size))
		check(minimap.end.x<=size.x and minimap.end.y<size.y-150.0,"minimap leaves the driving control zone clear: "+str(size))
	var controls: CanvasLayer = TOUCH.new()
	root.add_child(controls)
	controls.call("set_preview",true)
	controls.call("set_mode",true,false)
	var actions: Array[String] = ["move_left","move_right","move_backward","move_forward","jump","enter_vehicle","interact","pause_game"]
	check(controls.get("_buttons").size()==8,"unchanged eight authentic mobile InputMap actions")
	for action in actions:
		var button: TouchScreenButton = controls.get_node("Touch_"+action) as TouchScreenButton
		var caption: Label = button.get_node("Caption") as Label
		check(caption.get_theme_font_size("font_size")>=18,"driving captions use readable, larger original font: "+action)
		check(button.action==action and button.texture_normal!=null and button.texture_pressed!=null,"real native touch button still has both visual states: "+action)
		check(not button.passby_press if ["enter_vehicle","interact","pause_game"].has(action) else button.passby_press,"one-shot gameplay commands keep safe touch delivery")
	controls.queue_free()
	var script: Variant = load("res://scripts/world_builder.gd")
	check(script!=null,"real world builder parses under Godot 4.4.1")
	if script!=null:
		var world: Node3D = script.new()
		root.add_child(world)
		var city_trim: MultiMeshInstance3D = world.get("architecture_trim")
		var windows: MultiMeshInstance3D = world.get("facade_windows")
		var frames: MultiMeshInstance3D = world.get("facade_frames")
		check(city_trim!=null and windows!=null and frames!=null,"real world contains glass, real metal frames and cornices")
		if city_trim!=null:
			check(city_trim.source_buildings==int(world.get("building_count")),"all real built quarters receive properly aligned roof trims")
			check(city_trim.multimesh.instance_count == int(world.get("building_count"))*4,"cornices stay GPU-batched rather than thousands of nodes")
		if frames!=null and windows!=null:
			check(frames.multimesh.instance_count==windows.multimesh.instance_count,"every existing window has one physical frame")
		var chunks: Dictionary = world.get("building_chunks")
		var first_material: StandardMaterial3D
		for key in chunks:
			var quarter: Node3D = chunks[key]["node"]
			for obj in quarter.get_children():
				if obj.name.begins_with("Building_"):
					var mesh: MeshInstance3D = obj.get_node_or_null("VisualMesh") as MeshInstance3D
					if mesh!=null:
						first_material = mesh.material_override as StandardMaterial3D
						break
			if first_material!=null:
				break
		check(first_material!=null and first_material.normal_enabled,"actual playable city buildings use PBR masonry")
		world.apply_visual_budget("low")
		if city_trim!=null and frames!=null:
			check(not city_trim.visible and not frames.visible,"LOW budget disables decorative geometry for phone GPU")
		world.apply_visual_budget("cinematic")
		if city_trim!=null and frames!=null:
			check(city_trim.visible and frames.visible,"cinematic restores real 3D facade detail")
		world.queue_free()
	var source: String = FileAccess.get_file_as_string("res://scripts/horizon_touch_controls.gd")
	check(source.contains("button.passby_press = not DISCRETE_ACTIONS.has(action)"),"one-shot touch safety unchanged")
	var main: String = FileAccess.get_file_as_string("res://scripts/main.gd")
	check(main.contains("SAFE_CAMERA.solve(focus,ideal,camera.global_position"),"collision-safe R20 driving camera retained")
	print("HORIZON R25 NATIVE: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
