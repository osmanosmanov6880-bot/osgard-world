extends SceneTree
## R97 native acceptance: genuine same-world cinematic UI, legible control
## hierarchy, original live simulation data and keyboard navigation.
const STYLE = preload("res://scripts/horizon_r90_reference_style.gd")
var passed := 0
var failed := 0

func verify(ok: bool, why: String) -> void:
	if ok:
		passed += 1
	else:
		failed += 1
		push_error("R97 CINEMATIC COMMAND FAIL: " + why)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game: Node = root.get_node_or_null("GameState")
	var missions: Node = root.get_node_or_null("MissionManager")
	verify(game != null and missions != null, "real gameplay autoloads exist")
	if game == null or missions == null:
		quit(1)
		return
	var original_state: Dictionary = (game.get("data") as Dictionary).duplicate(true)
	var original_locale: String = str(game.get("locale"))
	var live: Dictionary = game.call("new_game")
	game.set("data", live)
	game.set("locale", "ru")
	var forecast: Dictionary = game.call("forecast")
	var pristine: Dictionary = live.duplicate(true)
	var panel: Variant = load("res://scripts/horizon_r90_premium_dashboard.gd")
	verify(panel is Script and panel.can_instantiate(), "current R97 dashboard compiles")
	if not (panel is Script and panel.can_instantiate()):
		game.set("data", original_state)
		game.set("locale", original_locale)
		quit(1)
		return
	var desktop: VBoxContainer = panel.new()
	root.add_child(desktop)
	desktop.call("build", live, forecast, str(missions.call("title","ru")), root.world_3d, false, "ru")
	var hero: Node = desktop.get_node_or_null("R97CommandColumns")
	var summary: Node = desktop.get_node_or_null("R97ExecutiveSummary")
	verify(hero != null and summary != null, "named Godot hero and executive summary exist")
	if hero != null and summary != null:
		verify(hero.get_index() < summary.get_index(),
			"genuine 3D atlas comes before large financial KPI row")
	verify(summary != null and summary.get_child_count() == 6,
		"all six real financial/political cards remain available")
	verify(desktop.get("preview") is SubViewport and
		(desktop.get("preview") as SubViewport).world_3d == root.world_3d,
		"same live World3D, no static reference image")
	verify(desktop.find_child("ActualGodotWorldViewport",true,false) != null,
		"interactive main city camera remains in the central hero")
	var district: Node = desktop.find_child("R97SelectedDistrictCard",true,false)
	verify(district != null and hero != null and hero.is_ancestor_of(district),
		"selected district score is located next to real city indicators")
	var kpis: Node = desktop.find_child("R93ActualCityKPIs",true,false)
	verify(kpis != null, "source-bound five-indicator panel preserved")
	if kpis != null:
		var values: Dictionary = kpis.get("metric_values")
		verify(values.size() == 5 and
			values["energy"] == clampi(int(forecast.get("energy",0)),0,100),
			"real forecast is preserved after visual restructuring")
	var tabs: Node = desktop.get_node_or_null("R90NavigationTabs")
	verify(tabs != null and tabs.get_child_count() == 7,
		"all seven original navigation choices remain functional")
	if tabs != null:
		var tab: Button = tabs.get_child(0) as Button
		verify(tab != null and tab.get_theme_font_size("font_size") >= 14,
			"premium navigation is legible without tiny 11px text")
		verify(tab != null and tab.focus_mode == Control.FOCUS_ALL,
			"keyboard and gamepad focus are enabled on real Godot buttons")
		verify(tab != null and tab.get_theme_stylebox("focus") is StyleBoxFlat,
			"focus has a visible 2px style instead of an empty decoration")
	var active: StyleBoxFlat = STYLE.card_style(true)
	verify(active.content_margin_left >= 16.0 and active.content_margin_top >= 14.0,
		"cards use spacious editorial insets")
	verify(active.border_color.a > 0.5 and active.get_corner_radius(CORNER_TOP_LEFT) <= 5,
		"quiet premium brass frame has an intentional geometry")
	verify(desktop.find_child("R90FakeBackground",true,false) == null,
		"no concept image is substituted for engine rendering")
	var signals: Array[String] = []
	desktop.connect("navigate",func(id: String): signals.append(id))
	desktop.call("_request_navigation","economy")
	verify(signals == ["economy"], "button actions still reach original economy")
	verify(live == pristine, "layout does not mutate any saved game finances or missions")
	desktop.queue_free()
	var compact: VBoxContainer = panel.new()
	root.add_child(compact)
	compact.call("build", live, forecast, str(missions.call("title","ru")), root.world_3d, true, "ru")
	var phone_summary: Node = compact.get_node_or_null("R97ExecutiveSummary")
	verify(phone_summary is GridContainer and phone_summary.get_child_count() == 6,
		"compact screen keeps authoritative state in a readable two-column grid")
	verify(compact.get("preview") == null,
		"compact phone avoids a second costly live 3D rendering pass")
	verify(compact.find_child("R93ActualCityKPIs",true,false) != null,
		"small screen still provides real municipal metrics")
	compact.queue_free()
	game.set("data", original_state)
	game.set("locale", original_locale)
	await process_frame
	print("EMPIRE OMEGA R97 true cinematic hierarchy: %d PASS %d FAIL" % [passed,failed])
	quit(0 if failed == 0 else 1)
