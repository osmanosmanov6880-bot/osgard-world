extends VBoxContainer
## R90: functional Godot control room. The city image comes from a live
## SubViewport of the SAME authoritative World3D, never a reference PNG.
## All numbers and actions come from GameState / MissionManager.
signal navigate(section: String)
signal select_vehicle(id: String)
signal select_district(id: String)

const REFERENCE = preload("res://scripts/horizon_r90_reference_style.gd")
const CIVIC_KPIS = preload("res://scripts/horizon_r93_real_civic_kpis.gd")
const PROJECTIVE_PINS = preload("res://scripts/horizon_r92_projective_districts.gd")
const GOLD = Color("d9bb83")
const WHITE = Color("eeeae3")
const MUTED = Color("c3c2bd")
var preview: SubViewport
var atlas_camera: Camera3D
var atlas_mode: String = "overview"
var atlas_pins: Dictionary = {}
var atlas_view_buttons: Dictionary = {}
var city_focus_active: bool = false
var focus_language: String = "ru"
var focus_left: Control
var focus_center: Control
var focus_columns: BoxContainer
var focus_stage: Control
var focus_right: Control
var focus_summary: Control
var focus_button: Button

static func local(ru: String,en: String,zh: String,lang: String) -> String:
	if lang == "en": return en
	if lang == "zh": return zh
	return ru

func _label(parent: Node, value: String, size: int = 16, accent: bool = false) -> Label:
	var item := Label.new()
	item.text = value
	item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	item.add_theme_font_size_override("font_size",maxi(15,size))
	item.add_theme_color_override("font_color",GOLD if accent else WHITE)
	item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(item)
	return item

func _card(parent: Node, min_width: float = 0.0, accent: bool = false) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size.x = min_width
	panel.add_theme_stylebox_override("panel",REFERENCE.card_style(accent))
	parent.add_child(panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation",10)
	panel.add_child(content)
	return content

func _action(parent: Node, title: String, section: String) -> Button:
	var button := Button.new()
	button.text = title
	button.tooltip_text = title
	button.custom_minimum_size.y = 44
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_size_override("font_size",15)
	REFERENCE.style_button(button)
	button.pressed.connect(Callable(self,"_request_navigation").bind(section))
	parent.add_child(button)
	return button

func _request_navigation(section: String) -> void:
	navigate.emit(section)

func _request_vehicle(id: String) -> void:
	select_vehicle.emit(id)

func _request_district(id: String) -> void:
	select_district.emit(id)

func _metric(parent: Node, caption: String, amount: String, small: String, accent: bool = false) -> void:
	var content := _card(parent,0.0,accent)
	_label(content,caption,14,true)
	_label(content,amount,24)
	_label(content,small,14)

func build(state: Dictionary, forecast: Dictionary, mission: String,
		world: World3D, compact: bool, lang: String) -> void:
	name = "R90LiveOperationsCabinet"
	city_focus_active = false
	focus_language = lang
	add_theme_constant_override("separation",16)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var branding := HBoxContainer.new()
	branding.add_theme_constant_override("separation",16)
	add_child(branding)
	_label(branding,local("OSGARD  ·  ИМПЕРИЯ Ω","OSGARD  ·  EMPIRE Ω","OSGARD  ·  帝国 Ω",lang),26,true)
	var selected: String = str(state.get("selected","forum"))
	var clock: float = fposmod(float(state.get("day_clock",8.0)),24.0)
	var hour: int = floori(clock)
	var minute: int = floori((clock-float(hour))*60.0)
	var time_value: String = "%02d:%02d" % [hour,minute]
	var clock_text: String = "%s %d · %s · %s %d/100" % [local("ТАКТ","TURN","回合",lang),int(state.get("turn",1)),time_value,local("РЕПУТАЦИЯ","REPUTATION","声望",lang),int(state.get("reputation",0))]
	var micro := _label(branding,clock_text,14)
	micro.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	micro.visible = not compact

	# Seven functional top-level tabs from the signed-off reference.
	# Every tab jumps into the original actionable strategy sections.
	if not compact:
		var tabs := HBoxContainer.new()
		tabs.name = "R90NavigationTabs"
		tabs.add_theme_constant_override("separation",7)
		add_child(tabs)
		var tabs_data: Array = [
			[local("КАБИНЕТ","OVERVIEW","概览",lang),"overview"],
			[local("ГОРОД","CITY","城市",lang),"district"],
			[local("ЭКОНОМИКА","ECONOMY","经济",lang),"economy"],
			[local("РАЙОНЫ","DISTRICTS","城区",lang),"district"],
			[local("ЛОГИСТИКА","LOGISTICS","物流",lang),"economy"],
			[local("ЗАДАНИЯ","MISSIONS","任务",lang),"overview"],
			[local("СТРАТЕГИЯ","STRATEGY","战略",lang),"council"]]
		for index in range(tabs_data.size()):
			var tab: Button = _action(tabs,str(tabs_data[index][0]),str(tabs_data[index][1]))
			tab.name = "R90Tab%d" % index
			tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			tab.custom_minimum_size.y = 45
			tab.add_theme_font_size_override("font_size",15)

	var stats: Container = GridContainer.new() if compact else HBoxContainer.new()
	stats.name = "R97ExecutiveSummary"
	if stats is GridContainer:
		(stats as GridContainer).columns = 2
	else:
		(stats as HBoxContainer).add_theme_constant_override("separation",7)
	# Hero-first composition: financial cards follow the live 3D command view.
	var politics: Dictionary = state.get("politics",{})
	_metric(stats,local("ЛИЧНЫЕ ДЕНЬГИ","PERSONAL FUNDS","个人资产",lang),
		"%d кр." % int(state.get("wallet",0)),local("ЛИЧНЫЙ БАЛАНС","CURRENT BALANCE","当前资金",lang))
	_metric(stats,local("КАЗНА ГОРОДА","CITY TREASURY","城市国库",lang),
		"%d кр." % int(state.get("treasury",0)),local("ГОРОДСКОЙ БЮДЖЕТ","CITY BUDGET","城市预算",lang))
	_metric(stats,local("ДОХОД / ТАКТ","NET / TURN","每回合净收入",lang),
		"%+d кр." % int(forecast.get("net",0)),local("РЕАЛЬНЫЙ ПРОГНОЗ","LIVE FORECAST","实时预测",lang))
	_metric(stats,local("НАСЕЛЕНИЕ","POPULATION","人口",lang),
		str(state.get("population",0)),local("ЖИТЕЛИ","RESIDENTS","居民",lang))
	_metric(stats,local("ПОДДЕРЖКА","APPROVAL","支持率",lang),
		"%d%%" % GameState.POLITICS.current_poll(state),local("ОПРОСЫ","CURRENT POLLS","最新民调",lang))
	_metric(stats,local("МАНДАТ","MANDATE","执政授权",lang),
		"%d%%" % int(politics.get("mandate",0)),local("ПОЛИТИЧЕСКИЙ РЕСУРС","PUBLIC MANDATE","执政支持",lang))

	var columns: BoxContainer = VBoxContainer.new() if compact else HBoxContainer.new()
	columns.name = "R97CommandColumns"
	columns.add_theme_constant_override("separation",14)
	columns.custom_minimum_size.y = 450 if not compact else 0
	add_child(columns)
	focus_columns = columns
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation",13)
	left.custom_minimum_size.x = 248 if not compact else 0
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 0.78
	columns.add_child(left)
	focus_left = left

	var missions := _card(left,0,true)
	_label(missions,local("ТЕКУЩАЯ МИССИЯ","CURRENT MISSION","当前任务",lang),16,true)
	_label(missions,mission,20)
	_label(missions,local("ГЛАВА · %d / 40" % (int(state.get("mission",0))+1),
		"MISSION · %d / 40" % (int(state.get("mission",0))+1),
		"任务 · %d / 40" % (int(state.get("mission",0))+1),lang),14,true)
	_action(missions,local("ОТКРЫТЬ ЗАДАНИЯ","MISSIONS","任务",lang),"overview")

	var fleet := _card(left,0,false)
	_label(fleet,local("ВАШ ТРАНСПОРТ","YOUR FLEET","您的车队",lang),15,true)
	var owned: Dictionary = state.get("vehicle_owned",{})
	var shown := 0
	for id in GameState.VEHICLE_CATALOG.ORDER:
		if not bool(owned.get(id,false)): continue
		var spec: Dictionary = GameState.VEHICLE_CATALOG.VEHICLES[id]
		var item := Button.new()
		item.text = str(spec.get(lang,spec.get("ru",id)))
		item.tooltip_text = local("Выбрать этот транспорт","Select this vehicle","选择车辆",lang)
		item.alignment = HORIZONTAL_ALIGNMENT_LEFT
		item.custom_minimum_size.y = 40
		REFERENCE.style_button(item)
		item.pressed.connect(Callable(self,"_request_vehicle").bind(id))
		fleet.add_child(item)
		shown += 1
		if shown == 3: break
	if shown == 0:
		_label(fleet,local("Пока нет транспорта","No vehicles yet","暂无车辆",lang),13)
	_action(fleet,local("ГАРАЖ И ПОКУПКИ","GARAGE & PURCHASES","车库",lang),"economy")

	if not compact and world != null:
		var middle := VBoxContainer.new()
		middle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		middle.size_flags_stretch_ratio = 1.72
		middle.add_theme_constant_override("separation",8)
		columns.add_child(middle)
		focus_center = middle
		_city_view(middle,world,forecast,lang)
	else:
		var brief := _card(left,0)
		_label(brief,local("ГОРОД НА ЭКРАНЕ ИГРЫ","CITY IN GAME WORLD","城市位于游戏世界",lang),13,true)
		_label(brief,local("На телефоне второй 3D-проход отключён для производительности.",
			"The second 3D render pass is disabled on phones.",
			"为保证手机性能，关闭第二个 3D 渲染通道。",lang),12)

	var right := VBoxContainer.new()
	right.custom_minimum_size.x = 284 if not compact else 0
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_stretch_ratio = 0.93
	right.add_theme_constant_override("separation",13)
	columns.add_child(right)
	focus_right = right
	var atlas := _card(right)
	_label(atlas,local("АТЛАС ГОРОДА","CITY ATLAS","城市地图集",lang),17,true)
	var discovered: Array = state.get("discovered_sites",[])
	_label(atlas,local("ОТКРЫТО","DISCOVERED","已发现",lang)+"  %d / 12" % discovered.size(),14)
	var scores: Dictionary = forecast.get("district_scores",{})
	for id in GameState.DISTRICTS:
		var regions: Dictionary = {
			"forum":["Сенатский форум","Senate Forum","元老院广场"],
			"housing":["Жилой квартал","Housing District","住宅区"],
			"lower":["Нижний город","Lower City","下城区"],
			"aqueduct":["Акведуки","Aqueducts","高架水道"]}
		var variants: Array = regions.get(id,[id,id,id])
		var region: String = local(str(variants[0]),str(variants[1]),str(variants[2]),lang)
		var section_button := Button.new()
		section_button.text = "%s · %d / 100%s" % [region,int(scores.get(id,0)),"  ◆" if id==selected else ""]
		section_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		section_button.custom_minimum_size.y = 40
		section_button.add_theme_font_size_override("font_size",14)
		REFERENCE.style_button(section_button)
		section_button.pressed.connect(Callable(self,"_request_district").bind(id))
		atlas.add_child(section_button)

	# All five progress bars are computed from the same forecast/state as
	# the city simulation. No arbitrary economy or public-safety percentages.
	var metrics := _card(right,0,false)
	metrics.name = "R93CityIndicatorsCard"
	_label(metrics,local("ГОРОДСКИЕ ПОКАЗАТЕЛИ","CITY INDICATORS","城市指标",lang),16,true)
	var indicators: VBoxContainer = CIVIC_KPIS.new()
	metrics.add_child(indicators)
	indicators.call("configure",state,forecast,lang)
	var actions := _card(right,0,true)
	_label(actions,local("СТРАТЕГИЧЕСКИЕ ДЕЙСТВИЯ","STRATEGIC ACTIONS","战略行动",lang),16,true)
	_action(actions,local("ГОРОДСКОЙ СОВЕТ","CITY COUNCIL","市政议会",lang),"council")
	_action(actions,local("ЭКОНОМИКА / ЛОГИСТИКА","ECONOMY / LOGISTICS","经济物流",lang),"economy")
	_action(actions,local("РАЗВИТИЕ РАЙОНОВ","DISTRICT DEVELOPMENT","街区开发",lang),"district")

	var selected_card := _card(right,0,true)
	selected_card.name = "R97SelectedDistrictCard"
	_label(selected_card,local("ВЫБРАННЫЙ РАЙОН","SELECTED DISTRICT","选定城区",lang),13,true)
	var district_scores: Dictionary = forecast.get("district_scores",{})
	var chosen: int = clampi(int(district_scores.get(selected,0)),0,100)
	var district_names: Dictionary = {
		"forum":["Сенатский форум","Senate Forum","元老院广场"],
		"housing":["Жилой квартал","Housing District","住宅区"],
		"lower":["Нижний город","Lower City","下城区"],
		"aqueduct":["Акведуки","Aqueducts","高架水道"]}
	var localized_name: Array = district_names.get(selected,[selected,selected,selected])
	_label(selected_card,"%s · %d/100" % [
		local(str(localized_name[0]),str(localized_name[1]),str(localized_name[2]),lang),chosen],16)
	_label(selected_card,local("Показатель рассчитан из текущего прогноза города.",
		"District score comes from the actual current city forecast.",
		"区域评分来自实时城市预测。",lang),12)
	var nav: Container = GridContainer.new() if compact else HBoxContainer.new()
	if compact:
		(nav as GridContainer).columns = 2
	else:
		(nav as HBoxContainer).add_theme_constant_override("separation",8)
	selected_card.add_child(nav)
	for section in ["overview","council","economy","district"]:
		_action(nav,local({"overview":"КАБИНЕТ","council":"СОВЕТ","economy":"ЭКОНОМИКА","district":"РАЙОНЫ"}[section],
			{"overview":"OVERVIEW","council":"COUNCIL","economy":"ECONOMY","district":"DISTRICTS"}[section],
			{"overview":"总览","council":"议会","economy":"经济","district":"城区"}[section],lang),section)

	# The six real authoritative figures remain available directly after the
	# immersive command stage; no static KPI placeholders or lost controls.
	add_child(stats)
	focus_summary = stats

func _unhandled_key_input(event: InputEvent) -> void:
	# F9 is scoped to the actual visible governance cabinet. It never alters
	# driving controls, state, camera allocations or mobile layout.
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or key.echo or key.keycode != KEY_F9:
		return
	if focus_button == null or not is_visible_in_tree():
		return
	_toggle_city_focus()
	get_viewport().set_input_as_handled()

func _toggle_city_focus() -> void:
	# Original data cards and action handlers are never freed/replaced.
	# Full-width stage uses the same ONE live preview World3D as before.
	if focus_left == null or focus_right == null or focus_center == null:
		return
	if focus_button == null or preview == null:
		return
	city_focus_active = not city_focus_active
	focus_left.visible = not city_focus_active
	focus_right.visible = not city_focus_active
	if focus_summary != null:
		focus_summary.visible = not city_focus_active
	focus_center.size_flags_stretch_ratio = 1.0 if city_focus_active else 1.72
	if focus_columns != null:
		focus_columns.custom_minimum_size.y = 565 if city_focus_active else 450
	if focus_stage != null:
		focus_stage.custom_minimum_size.y = 548.0 if city_focus_active else 436.0
	# The SubViewportContainer already owns the live pixel size (stretch=true,
	# stretch_shrink=1). Do NOT force preview.size: Godot immediately replaces it
	# with the actual screen-space stage size when the control tree lays out.
	# Preserve the real viewport/camera and simply reproject source-world pins.
	_switch_atlas_mode(atlas_mode)
	focus_button.text = local("ВЕРНУТЬ ПАНЕЛИ","SHOW PANELS","显示面板",focus_language) if city_focus_active else local("ФОКУС НА ГОРОДЕ","FOCUS ON CITY","聚焦城市",focus_language)
	focus_button.tooltip_text = local("Показать данные и действия" if city_focus_active else "Развернуть реальный 3D-атлас",
		"Restore original controls" if city_focus_active else "Expand live 3D atlas",
		"恢复面板" if city_focus_active else "展开三维地图",focus_language)

func _on_city_atlas_render_size_changed() -> void:
	# True host-driven viewport resize: camera projection changes even without
	# a camera move. Keep four real source district anchors in sync.
	if preview != null and atlas_camera != null:
		_switch_atlas_mode(atlas_mode)

func _switch_atlas_mode(mode: String) -> void:
	# No extra World3D, no preview image or second GPU pass: change the
	# one existing native Camera3D in the already-active SubViewport.
	if not ["overview","architecture"].has(mode):
		return
	if atlas_camera == null or preview == null:
		return
	atlas_mode = mode
	if mode == "architecture":
		atlas_camera.fov = 52.0
		atlas_camera.position = Vector3(118.0,104.0,158.0)
		atlas_camera.look_at(Vector3(0.0,31.0,0.0),Vector3.UP)
	else:
		atlas_camera.fov = 62.0
		atlas_camera.position = Vector3(205.0,170.0,215.0)
		atlas_camera.look_at(Vector3(0.0,6.0,0.0),Vector3.UP)
	for id in atlas_pins:
		var badge: Button = atlas_pins[id] as Button
		if badge == null:
			continue
		var projected: Dictionary = PROJECTIVE_PINS.project_district(
			atlas_camera,str(id),Vector2(preview.size))
		badge.visible = bool(projected.get("visible",false))
		var anchor: Vector2 = projected.get("anchor",Vector2(0.5,0.5))
		badge.anchor_left = anchor.x
		badge.anchor_right = anchor.x
		badge.anchor_top = anchor.y
		badge.anchor_bottom = anchor.y
	for id in atlas_view_buttons:
		var button: Button = atlas_view_buttons[id] as Button
		if button != null:
			button.disabled = str(id) == atlas_mode

func _city_view(parent: Node, world: World3D, forecast: Dictionary, lang: String) -> void:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size.y = 456
	panel.add_theme_stylebox_override("panel",REFERENCE.card_style(true))
	parent.add_child(panel)
	var stage := Control.new()
	stage.custom_minimum_size = Vector2(450,436)
	stage.clip_contents = true
	focus_stage = stage
	panel.add_child(stage)
	var host := SubViewportContainer.new()
	host.name = "ActualGodotWorldViewport"
	host.set_anchors_preset(Control.PRESET_FULL_RECT)
	host.stretch = true
	host.stretch_shrink = 1
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(host)
	preview = SubViewport.new()
	preview.name = "SharedWorldPreview"
	preview.world_3d = world
	preview.size = Vector2i(640,400)
	preview.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	host.add_child(preview)
	var camera := Camera3D.new()
	atlas_camera = camera
	atlas_mode = "overview"
	atlas_pins.clear()
	atlas_view_buttons.clear()
	camera.name = "AerialCommandCamera"
	camera.fov = 62.0
	camera.far = 1000.0
	preview.add_child(camera)
	# View from the city edge, not a tiny top-down toy map.
	camera.position = Vector3(205,170,215)
	camera.look_at(Vector3(0.0,6.0,0.0),Vector3.UP)
	var cinema_sky := ProceduralSkyMaterial.new()
	cinema_sky.sky_top_color = Color("24374d")
	cinema_sky.sky_horizon_color = Color("a68669")
	cinema_sky.ground_bottom_color = Color("263341")
	cinema_sky.ground_horizon_color = Color("645966")
	var sky := Sky.new()
	sky.sky_material = cinema_sky
	var feed_grade := Environment.new()
	feed_grade.background_mode = Environment.BG_SKY
	feed_grade.sky = sky
	feed_grade.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	feed_grade.ambient_light_energy = 0.74
	feed_grade.reflected_light_source = Environment.REFLECTION_SOURCE_BG
	feed_grade.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	feed_grade.adjustment_enabled = true
	feed_grade.adjustment_brightness = 0.90
	feed_grade.adjustment_contrast = 1.16
	feed_grade.adjustment_saturation = 0.95
	# Local camera grade, never change authoritative gameplay day/weather.
	camera.environment = feed_grade
	camera.current = true
	var pin := PanelContainer.new()
	pin.anchor_left = 0.02
	pin.anchor_right = 0.52
	pin.anchor_top = 0.03
	pin.anchor_bottom = 0.03
	pin.offset_top = 0.0
	pin.offset_bottom = 48.0
	pin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pin.add_theme_stylebox_override("panel",REFERENCE.card_style(true))
	stage.add_child(pin)
	_label(pin,local("АТЛАС · ЖИВАЯ СЦЕНА","ATLAS · LIVE SCENE","城市 · 实时场景",lang),15,true)
	# Actual district scores are projected as informational touch targets
	# over the live render, not fabricated economic statistics.
	var scores: Dictionary = forecast.get("district_scores",{})
	# Project true district points with the real active 3D command camera.
	var titles: Dictionary = {
		"forum":local("СЕНАТСКИЙ ФОРУМ","SENATE FORUM","元老院广场",lang),
		"housing":local("ЖИЛОЙ КВАРТАЛ","HOUSING","住宅区",lang),
		"lower":local("НИЖНИЙ ГОРОД","LOWER CITY","下城区",lang),
		"aqueduct":local("АКВЕДУКИ","AQUEDUCTS","高架水道",lang)}
	for id in GameState.DISTRICTS:
		var badge := Button.new()
		badge.name = "R90DistrictPin_"+str(id)
		badge.text = "%s · %d/100" % [str(titles[id]),int(scores.get(id,0))]
		badge.tooltip_text = local("Выбрать район","Select district","选择城区",lang)
		badge.custom_minimum_size = Vector2(192,44)
		var projected: Dictionary = PROJECTIVE_PINS.project_district(camera,id,Vector2(preview.size))
		badge.visible = bool(projected.get("visible",false))
		var point: Vector2 = projected.get("anchor",Vector2(0.5,0.5))
		badge.anchor_left = point.x
		badge.anchor_right = point.x
		badge.anchor_top = point.y
		badge.anchor_bottom = point.y
		badge.offset_left = -96.0
		badge.offset_right = 96.0
		badge.offset_top = -22.0
		badge.offset_bottom = 22.0
		badge.add_theme_font_size_override("font_size",15)
		REFERENCE.style_button(badge)
		badge.pressed.connect(Callable(self,"_request_district").bind(id))
		stage.add_child(badge)
		atlas_pins[id] = badge
	# Functional two-mode cinematic inspection. Both choices keep the SAME
	# live Godot World3D and reproject the real district markers after move.
	var controls := HBoxContainer.new()
	controls.name = "R112AtlasCameraControls"
	controls.anchor_left = 0.53
	controls.anchor_right = 0.98
	controls.anchor_top = 0.03
	controls.anchor_bottom = 0.03
	controls.offset_bottom = 43.0
	controls.add_theme_constant_override("separation",5)
	stage.add_child(controls)
	for mode in ["overview","architecture"]:
		var button := Button.new()
		button.name = "R112AtlasView_" + mode
		button.text = local("ОБЗОР","OVERVIEW","总览",lang) if mode == "overview" else local("ДЕТАЛИ","DETAIL","细节",lang)
		button.tooltip_text = local("Реальная камера города","Live city camera","实时城市镜头",lang)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size.y = 38
		button.add_theme_font_size_override("font_size",15)
		REFERENCE.style_button(button)
		button.pressed.connect(Callable(self,"_switch_atlas_mode").bind(mode))
		controls.add_child(button)
		atlas_view_buttons[mode] = button
	_switch_atlas_mode("overview")
	# R115: one accessible full-width real camera view. Keep the separate
	# R112 overview/details control at EXACTLY two original buttons.
	focus_button = Button.new()
	focus_button.name = "R115CinematicFocusToggle"
	focus_button.text = local("ФОКУС НА ГОРОДЕ","FOCUS ON CITY","聚焦城市",lang)
	focus_button.tooltip_text = local("Развернуть 3D-атлас · F9",
		"Expand live city · F9","展开三维地图 · F9",lang)
	# Place below R112 mode buttons inside VISIBLE 3D header, never below
	# the screen fold of 960x540 browser or smaller laptop viewports.
	focus_button.anchor_left = 0.60
	focus_button.anchor_right = 0.98
	focus_button.anchor_top = 0.17
	focus_button.anchor_bottom = 0.17
	focus_button.offset_top = 0.0
	focus_button.offset_bottom = 42.0
	focus_button.custom_minimum_size.y = 44
	focus_button.add_theme_font_size_override("font_size",15)
	REFERENCE.style_button(focus_button)
	focus_button.pressed.connect(Callable(self,"_toggle_city_focus"))
	stage.add_child(focus_button)
	# Driven by the actual Godot viewport size, NOT a hard-coded 2D overlay.
	preview.size_changed.connect(Callable(self,"_on_city_atlas_render_size_changed"))
