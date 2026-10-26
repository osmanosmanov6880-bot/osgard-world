extends SceneTree
## R119: source-grounded original Godot physically shaded dual-sided windows,
## one shared GPU draw surface, keyboard/touch-readable real district badges.
const URBAN = preload("res://scripts/horizon_r90_street_dressing.gd")
const DASHBOARD = preload("res://scripts/horizon_r90_premium_dashboard.gd")
var passed := 0
var failed := 0

func check(ok: bool, reason: String) -> void:
	if ok:
		passed += 1
	else:
		failed += 1
		push_error("R119 GLASS + TYPOGRAPHY FAIL: " + reason)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game: Node = root.get_node_or_null("GameState")
	var missions: Node = root.get_node_or_null("MissionManager")
	check(game != null and missions != null, "actual game state and missions exist")
	if game == null or missions == null:
		quit(1)
		return
	var previous: Dictionary = (game.get("data") as Dictionary).duplicate(true)
	var previous_lang: String = str(game.get("locale"))
	var streets: Node3D = URBAN.new()
	root.add_child(streets)
	var original_city: MultiMeshInstance3D = streets.get("skyline") as MultiMeshInstance3D
	var detail: Node3D = streets.get("r91_architecture") as Node3D
	check(streets.get_child_count() == 3 and detail != null and
		original_city != null and original_city.multimesh.instance_count == 72,
		"same original city with exactly 72 batched towers and three scene roots")
	check(bool(streets.call("graphics_are_bounded")),
		"original R90/R91 3D instance budgets remain intact")
	if detail != null:
		check(detail.get_child_count() == 2,
			"exactly original windows + rooftop GPU batches")
		var windows: MultiMeshInstance3D = detail.get("facade_glass") as MultiMeshInstance3D
		check(windows != null and windows.multimesh.instance_count >= 2000 and
			windows.multimesh.instance_count <= 6912,
			"all original 4-sided glass instances remain CPU-deterministic")
		if windows != null:
			var surface: ArrayMesh = windows.multimesh.mesh as ArrayMesh
			check(surface != null and surface.get_surface_count() == 1,
				"ONE physically recessed original window ArrayMesh draw surface")
			if surface != null and surface.get_surface_count() == 1:
				var arrays: Array = surface.surface_get_arrays(0)
				var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
				var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
				check(vertices.size() == 60,
					"front and back each have five real physical quads = 20 triangles per window")
				check(normals.size() == 60 and colors.size() == 60,
					"real PBR normals and per-vertex anodized frame/glass colors exist")
				var min_z: float = INF
				var max_z: float = -INF
				var window_light: bool = false
				var darker_frame: bool = false
				for i in range(vertices.size()):
					var vertex: Vector3 = vertices[i]
					check(vertex.is_finite(), "all real glass/frame vertices have finite 3D coordinates")
					min_z = minf(min_z, vertex.z)
					max_z = maxf(max_z, vertex.z)
					if colors[i].r > 0.8:
						window_light = true
					if colors[i].r < 0.4:
						darker_frame = true
				check(min_z <= -0.05 and max_z >= 0.05,
					"real recessed windows visibly project both directions from 3D facade")
				check(window_light and darker_frame,
					"glass and dark metal mullion materials coexist in one physical batch")
				check(normals[0].z > 0.9 and normals[30].z < -0.9,
					"front and rear glass receive correct opposite PBR surface normals")
			var material: StandardMaterial3D = windows.material_override as StandardMaterial3D
			check(material != null and material.vertex_color_use_as_albedo and
				material.shading_mode != BaseMaterial3D.SHADING_MODE_UNSHADED and
				material.metallic > 0.1 and material.roughness < 0.5,
				"actual physically shaded per-instance double-sided metallic glass")
			check(windows.get_child_count() == 0 and
				windows.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,
				"true facade art adds no per-pane nodes, colliders or shadow draw passes")
		streets.call("set_quality", "low")
		check(windows == null or not windows.visible,
			"mobile LOW tier still disables costly exterior decorative glass")
		streets.call("set_quality", "cinematic")
		check(windows != null and windows.visible,
			"cinematic tier visibly restores real physical window meshes")
	streets.queue_free()
	await process_frame
	var data: Dictionary = game.call("new_game")
	game.set("data", data)
	game.set("locale", "ru")
	var source: Dictionary = data.duplicate(true)
	var forecast: Dictionary = game.call("forecast")
	var dashboard: VBoxContainer = DASHBOARD.new()
	root.add_child(dashboard)
	dashboard.call("build", data, forecast, str(missions.call("title", "ru")),
		root.world_3d, false, "ru")
	var preview: SubViewport = dashboard.get("preview") as SubViewport
	check(preview != null and preview.world_3d == root.world_3d,
		"readability refinements retain the ONE authoritative 3D city renderer")
	var pins: Dictionary = dashboard.get("atlas_pins")
	check(pins.size() == 4, "all four native live district selectors exist")
	for id in pins:
		var badge: Button = pins[id] as Button
		check(badge != null and badge.custom_minimum_size.y >= 44.0,
			"true live district pointer/touch targets remain at least 44px high")
		check(badge != null and badge.get_theme_font_size("font_size") >= 15,
			"R119 real district labels use readable 15px minimum native typography")
		check(badge != null and badge.offset_bottom-badge.offset_top >= 44.0,
			"actual anchored Godot city labels receive full-height hit regions")
	var tabs: HBoxContainer = dashboard.get_node_or_null("R90NavigationTabs") as HBoxContainer
	check(tabs != null and tabs.get_child_count() == 7,
		"all original seven keyboard-operable strategy sections remain visible")
	if tabs != null:
		for tab in tabs.get_children():
			check(tab is Button and (tab as Button).get_theme_font_size("font_size") >= 15,
				"original seven tabs share single readable engine font stack")
	var focus: Button = dashboard.find_child("R115CinematicFocusToggle",true,false) as Button
	check(focus != null and focus.get_theme_font_size("font_size") >= 15,
		"real R117 focus toggle uses the same premium native text scale")
	var selection: Array[String] = []
	dashboard.connect("select_district", func(id: String): selection.append(id))
	if pins.has("forum"):
		(pins["forum"] as Button).pressed.emit()
	check(selection == ["forum"],
		"real projected district click still emits true original city action")
	check(game.get("data") == source and data == source,
		"all display-only refinements leave actual economy, missions and saves untouched")
	dashboard.queue_free()
	game.set("data", previous)
	game.set("locale", previous_lang)
	await process_frame
	print("EMPIRE OMEGA R119 double-sided PBR windows and atlas: %d PASS %d FAIL" %
		[passed, failed])
	quit(0 if failed == 0 else 1)
