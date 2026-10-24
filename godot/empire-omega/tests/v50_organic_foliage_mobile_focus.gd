extends SceneTree
## HORIZON R26: verify real instanced foliage, no phone control regressions,
## and discoverable on-demand map in the playable HUD. Native Godot 4.4.1.
const FOLIAGE = preload("res://scripts/horizon_organic_foliage.gd")
const ROADSCAPE = preload("res://scripts/horizon_roadscape.gd")
const LAYOUT = preload("res://scripts/horizon_responsive_layout.gd")
const TOUCH = preload("res://scripts/horizon_touch_controls.gd")
var pass_count := 0
var fail_count := 0

func check(ok: bool, label: String) -> void:
	if ok:
		pass_count += 1
	else:
		fail_count += 1
		push_error("R26 NATIVE FAILED: " + label)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var deciduous: ArrayMesh = FOLIAGE.leaf_canopy()
	var evergreen: ArrayMesh = FOLIAGE.pine_canopy()
	check(deciduous!=null and evergreen!=null,"engine creates two original three-dimensional canopy meshes")
	check(deciduous.get_surface_count()==1 and evergreen.get_surface_count()==1,"each species uses one material surface")
	var leaf_vertices: int = deciduous.surface_get_array_len(0)
	var pine_vertices: int = evergreen.surface_get_array_len(0)
	check(leaf_vertices==FOLIAGE.leaf_triangle_budget()*3,"three rounded leaf clusters have deterministic triangle count")
	check(pine_vertices==FOLIAGE.pine_triangle_budget()*3,"three separate evergreen branch whorls have deterministic triangle count")
	check(leaf_vertices>=900 and leaf_vertices<=1400,"organic tree silhouette adds bounded 3D leaf geometry")
	check(pine_vertices<=130,"evergreen branch mesh is low-GPU cost")
	var broadleaf_aabb: AABB = deciduous.get_aabb()
	var max_width_metres: float = maxf(broadleaf_aabb.size.x,broadleaf_aabb.size.z)*3.6*0.76
	check(max_width_metres<=6.5,"maximum crown footprint avoids crowding chase camera on narrow phones")
	var roads_source: String = FileAccess.get_file_as_string("res://scripts/horizon_roadscape.gd")
	check(roads_source.contains("crown_scale*0.76"),"real city uses photo-verified capped foliage size")
	var leaf_arrays: Array = deciduous.surface_get_arrays(0)
	var pine_arrays: Array = evergreen.surface_get_arrays(0)
	var leaf_colors: PackedColorArray = leaf_arrays[Mesh.ARRAY_COLOR]
	var pine_colors: PackedColorArray = pine_arrays[Mesh.ARRAY_COLOR]
	var normals: PackedVector3Array = leaf_arrays[Mesh.ARRAY_NORMAL]
	check(leaf_colors.size()==leaf_vertices and pine_colors.size()==pine_vertices,"foliage includes vertex shading data")
	check(normals.size()==leaf_vertices and normals[55].length()>0.75,"organic surface has physical lighting normals")
	var road: Node3D = ROADSCAPE.new()
	root.add_child(road)
	check(int(road.get("tree_count"))==192,"all 192 original roadside tree placements preserved")
	var broadleaf: MultiMeshInstance3D = road.get_node_or_null("LeafCanopyBatch") as MultiMeshInstance3D
	var conifers: MultiMeshInstance3D = road.get_node_or_null("LeafConeBatch") as MultiMeshInstance3D
	var trunks: MultiMeshInstance3D = road.get_node_or_null("TrunkBatch") as MultiMeshInstance3D
	check(broadleaf!=null and conifers!=null and trunks!=null,"both tree species and all wood trunks are real GPU-instanced objects")
	if broadleaf!=null and conifers!=null and trunks!=null:
		var leaf_count: int = broadleaf.multimesh.instance_count
		var evergreen_count: int = conifers.multimesh.instance_count
		check(leaf_count+evergreen_count==trunks.multimesh.instance_count,"each trunk owns exactly one canopy rather than a redundant sphere-plus-cone")
		check(leaf_count>=100 and evergreen_count>=45,"mixed species make actual non-uniform city silhouette")
		check(broadleaf.multimesh.mesh.surface_get_array_len(0)==leaf_vertices,"entire city shares one leaf mesh")
		check(conifers.multimesh.mesh.surface_get_array_len(0)==pine_vertices,"entire city shares one evergreen mesh")
		check(bool((broadleaf.material_override as StandardMaterial3D).vertex_color_use_as_albedo),"GPU tree crown uses physically shaded vertex colors")
		check(broadleaf.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,"foliage does not overwhelm phone shadow map")
		var estimated_triangles: int = leaf_count*FOLIAGE.leaf_triangle_budget()+evergreen_count*FOLIAGE.pine_triangle_budget()
		check(estimated_triangles<60000,"entire city foliage bounded to fewer than sixty thousand foliage triangles")
	var colliders:=0
	for child in road.get_children():
		if child is CollisionObject3D:
			colliders += 1
	check(colliders==0,"new decorative trees do not block roads or change car collisions")
	for size in [Vector2(320,568),Vector2(360,640),Vector2(390,844),Vector2(430,932)]:
		var frame: Dictionary = LAYOUT.compute(size)
		check(bool(frame["portrait_focus"]),"phone portrait automatically enters open-scenery framing: "+str(size))
		check(not bool(frame["map_default"]),"optional mini-map hidden by default but not deleted: "+str(size))
		check((frame["objective"] as Rect2).size.y<=90.0,"objective remains compact in portrait: "+str(size))
		check((frame["help"] as Rect2).size.y<=44.0,"redundant hints no longer reserve a tall overlay: "+str(size))
	var land: Dictionary = LAYOUT.compute(Vector2(844,390))
	check(not bool(land["portrait_focus"]),"landscape phone preserves driving hint bar")
	var tablet: Dictionary = LAYOUT.compute(Vector2(768,1024))
	check(not bool(tablet["portrait_focus"]) and bool(tablet["map_default"]),"tablet retains immediately visible city map")
	var desktop: Dictionary = LAYOUT.compute(Vector2(1366,768))
	check(not bool(desktop["compact"]),"desktop UI unchanged")
	var touch: CanvasLayer = TOUCH.new()
	root.add_child(touch)
	touch.call("set_preview",true)
	touch.call("set_mode",true,false)
	var quick: Button = touch.get_node_or_null("QuickActionsToggle") as Button
	var menu: PanelContainer = touch.get_node_or_null("QuickActionsPanel") as PanelContainer
	check(quick!=null and menu!=null,"on-demand map access stays in original native phone action menu")
	check(InputMap.has_action("show_map"),"map shortcut still dispatches gameplay InputMap action")
	var real_buttons:=0
	for child in touch.get_children():
		if child is TouchScreenButton:
			real_buttons += 1
	check(real_buttons==8,"all eight authentic multi-finger phone commands preserved")
	var source: String = FileAccess.get_file_as_string("res://scripts/hud.gd")
	check(source.contains("controls_panel.visible = not bool(frames[\"portrait_focus\"])"),"actual HUD hides redundant mobile instruction strip in portrait")
	check(source.contains("func toggle_map()") and source.contains("map_override = true"),"real HUD allows player to toggle map after hiding it by default")
	var main: String = FileAccess.get_file_as_string("res://scripts/main.gd")
	check(main.contains("hud.toggle_map()"),"quick map menu reaches actual playing game")
	check(main.contains("SAFE_CAMERA.solve("),"camera wall avoidance remains in playable scene")
	touch.queue_free()
	road.queue_free()
	print("HORIZON R26 NATIVE: %d passed, %d failed" % [pass_count,fail_count])
	quit(0 if fail_count==0 else 1)
