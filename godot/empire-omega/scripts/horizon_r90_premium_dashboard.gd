extends VBoxContainer
## R90: functional Godot control room. The city image comes from a live
## SubViewport of the SAME authoritative World3D, never a reference PNG.
## All numbers and actions come from GameState / MissionManager.
signal navigate(section: String)
signal select_vehicle(id: String)
signal select_district(id: String)

const REFERENCE = preload("res://scripts/horizon_r90_reference_style.gd")
const CIVIC_KPIS = preload("res://scripts/horizon_r93_real_civic_kpis.gd")
const GOLD = Color("eac482")
const WHITE = Color("f6f3ed")
const MUTED = Color("a8b1bd")
var preview: SubViewport

static func local(ru: String,en: String,zh: String,lang: String) -> String:
	if lang == "en": return en
	if lang == "zh": return zh
	return ru

func _label(parent: Node, value: String, size: int = 16, accent: bool = false) -> Label:
	var item := Label.new()
	item.text = value
	item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	item.add_theme_font_size_override("font_size",size)
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
	content.add_theme_constant_override("separation",7)
	panel.add_child(content)
	return content

func _action(parent: Node, title: String, section: String) -> Button:
	var button := Button.new()
	button.text = title
	button.tooltip_text = title
	button.custom_minimum_size.y = 38
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_size_override("font_size",14)
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
	_label(content,caption,12,true)
	_label(content,amount,20)
	_label(content,small,12)

func build(state: Dictionary, forecast: Dictionary, mission: String,
		world: World3D, compact: bool, lang: String) -> void:
	name = "R90LiveOperationsCabinet"
	add_theme_constant_override("separation",12)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var branding := HBoxContainer.new()
	branding.add_theme_constant_override("separation",12)
	add_child(branding)
	_label(branding,local("◆  OSGARD · ИМПЕРИЯ Ω","◆  OSGARD · EMPIRE Ω","◆  奥斯加德 · 帝国 Ω",lang),23,true)
	var selected: String = str(state.get("selected","forum"))
	var clock: float = fposmod(float(state.get("day_clock",8.0)),24.0)
	var hour: int = floori(clock)
	var minute: int = floori((clock-float(hour))*60.0)
	var time_value: String = "%02d:%02d" % [hour,minute]
	var clock_text: String = "%s %d · %s · %s %d/100" % [local("ТАКТ","TURN","回合",lang),int(state.get("turn",1)),time_value,local("РЕПУТАЦИЯ","REPUTATION","声望",lang),int(state.get("reputation",0))]
	var micro := _label(branding,clock_text,12)
	micro.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	micro.visible = not compact

	# Seven functional top-level tabs from the signed-off reference.
	# Every tab jumps into the original actionable strategy sections.
	if not compact:
		var tabs := HBoxContainer.new()
		tabs.name = "R90NavigationTabs"
		tabs.add_theme_constant_override("separation",5)
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
			tab.custom_minimum_size.y = 39
			tab.add_theme_font_size_override("font_size",12)

	var stats: Container = GridContainer.new() if compact else HBoxContainer.new()
	if stats is GridContainer:
		(stats as GridContainer).columns = 2
	else:
		(stats as HBoxContainer).add_theme_constant_override("separation",7)
	add_child(stats)
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
	columns.add_theme_constant_override("separation",12)
	columns.custom_minimum_size.y = 420 if not compact else 0
	add_child(columns)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation",10)
	left.custom_minimum_size.x = 230 if not compact else 0
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(left)

	var missions := _card(left,0,true)
	_label(missions,local("ТЕКУЩАЯ МИССИЯ","CURRENT MISSION","当前任务",lang),15,true)
	_label(missions,mission,17)
	_label(missions,local("ГЛАВА · %d / 40" % (int(state.get("mission",0))+1),
		"MISSION · %d / 40" % (int(state.get("mission",0))+1),
		"任务 · %d / 40" % (int(state.get("mission",0))+1),lang),13,true)
	_action(missions,local("ОТКРЫТЬ ЗАДАНИЯ","MISSIONS","任务",lang),"overview")

	var fleet := _card(left,0,false)
	_label(fleet,local("ВАШ ТРАНСПОРТ","YOUR FLEET","您的车队",lang),15,true)
	var owned: Dictionary = state.get("vehicle_owned",{})
	var shown := 0
	for id in GameState.VEHICLE_CATALOG.ORDER:
		if not bool(owned.get(id,false)): continue
		var spec: Dictionary = GameState.VEHICLE_CATALOG.VEHICLES[id]
		var item := Button.new()
		item.text = "◆ " + str(spec.get(lang,spec.get("ru",id)))
		item.tooltip_text = local("Выбрать этот транспорт","Select this vehicle","选择车辆",lang)
		item.alignment = HORIZONTAL_ALIGNMENT_LEFT
		item.custom_minimum_size.y = 34
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
		middle.add_theme_constant_override("separation",8)
		columns.add_child(middle)
		_city_view(middle,world,forecast,lang)
		var hint := _card(middle,0)
		_label(hint,local("ЖИВОЙ 3D-ГОРОД · ТА ЖЕ СЦЕНА, ЧТО В ИГРЕ",
			"LIVE 3D CITY · SAME SCENE AS GAMEPLAY",
			"实时三维城市 · 与游戏相同场景",lang),13,true)
		_label(hint,local("Вид с командной камеры, без поддельного фонового изображения.",
			"Command camera — not a pre-rendered background.",
			"实时摄像机画面，非预渲染背景。",lang),12)
	else:
		var brief := _card(left,0)
		_label(brief,local("ГОРОД НА ЭКРАНЕ ИГРЫ","CITY IN GAME WORLD","城市位于游戏世界",lang),13,true)
		_label(brief,local("На телефоне второй 3D-проход отключён для производительности.",
			"The second 3D render pass is disabled on phones.",
			"为保证手机性能，关闭第二个 3D 渲染通道。",lang),12)

	var right := VBoxContainer.new()
	right.custom_minimum_size.x = 234 if not compact else 0
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation",10)
	columns.add_child(right)
	var atlas := _card(right)
	_label(atlas,local("АТЛАС ГОРОДА","CITY ATLAS","城市地图集",lang),16,true)
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
		section_button.custom_minimum_size.y = 32
		REFERENCE.style_button(section_button)
		section_button.pressed.connect(Callable(self,"_request_district").bind(id))
		atlas.add_child(section_button)

	# All five progress bars are computed from the same forecast/state as
	# the city simulation. No arbitrary economy or public-safety percentages.
	var metrics := _card(right,0,false)
	metrics.name = "R93CityIndicatorsCard"
	_label(metrics,local("ГОРОДСКИЕ ПОКАЗАТЕЛИ","CITY INDICATORS","城市指标",lang),15,true)
	var indicators: VBoxContainer = CIVIC_KPIS.new()
	metrics.add_child(indicators)
	indicators.call("configure",state,forecast,lang)
	var actions := _card(right,0,true)
	_label(actions,local("СТРАТЕГИЧЕСКИЕ ДЕЙСТВИЯ","STRATEGIC ACTIONS","战略行动",lang),15,true)
	_action(actions,local("◆ ГОРОДСКОЙ СОВЕТ","◆ CITY COUNCIL","◆ 市政议会",lang),"council")
	_action(actions,local("◆ ЭКОНОМИКА / ЛОГИСТИКА","◆ ECONOMY / LOGISTICS","◆ 经济物流",lang),"economy")
	_action(actions,local("◆ РАЗВИТИЕ РАЙОНОВ","◆ DISTRICT DEVELOPMENT","◆ 街区开发",lang),"district")
	_label(actions,local("Решения доступны ниже через рабочий список действий.",
		"Real actions are available in the sections below.",
		"以下区域可执行实际决策。",lang),12)

	var selected_card := _card(self,0,true)
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

func _city_view(parent: Node, world: World3D, forecast: Dictionary, lang: String) -> void:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size.y = 410
	panel.add_theme_stylebox_override("panel",REFERENCE.card_style(true))
	parent.add_child(panel)
	var stage := Control.new()
	stage.custom_minimum_size = Vector2(420,394)
	stage.clip_contents = true
	panel.add_child(stage)
	var host := SubViewportContainer.new()
	host.name = "ActualGodotWorldViewport"
	host.set_anchors_preset(Control.PRESET_FULL_RECT)
	host.stretch = true
	host.stretch_shrink = 2
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(host)
	preview = SubViewport.new()
	preview.name = "SharedWorldPreview"
	preview.world_3d = world
	preview.size = Vector2i(640,400)
	preview.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	host.add_child(preview)
	var camera := Camera3D.new()
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
	_label(pin,local("◆ АТЛАС · ЖИВАЯ СЦЕНА","◆ ATLAS · LIVE SCENE","◆ 城市 · 实时场景",lang),14,true)
	# Actual district scores are projected as informational touch targets
	# over the live render, not fabricated economic statistics.
	var scores: Dictionary = forecast.get("district_scores",{})
	var pins: Dictionary = {
		"forum":Vector2(0.21,0.34),
		"housing":Vector2(0.71,0.34),
		"lower":Vector2(0.23,0.72),
		"aqueduct":Vector2(0.71,0.72)}
	var titles: Dictionary = {
		"forum":local("СЕНАТСКИЙ ФОРУМ","SENATE FORUM","元老院广场",lang),
		"housing":local("ЖИЛОЙ КВАРТАЛ","HOUSING","住宅区",lang),
		"lower":local("НИЖНИЙ ГОРОД","LOWER CITY","下城区",lang),
		"aqueduct":local("АКВЕДУКИ","AQUEDUCTS","高架水道",lang)}
	for id in GameState.DISTRICTS:
		var badge := Button.new()
		badge.name = "R90DistrictPin_"+str(id)
		badge.text = "◆ %s · %d/100" % [str(titles[id]),int(scores.get(id,0))]
		badge.tooltip_text = local("Выбрать район","Select district","选择城区",lang)
		badge.custom_minimum_size = Vector2(100,32)
		badge.anchor_left = pins[id].x
		badge.anchor_right = pins[id].x
		badge.anchor_top = pins[id].y
		badge.anchor_bottom = pins[id].y
		badge.offset_left = -65.0
		badge.offset_right = 85.0
		badge.offset_top = -16.0
		badge.offset_bottom = 16.0
		badge.add_theme_font_size_override("font_size",11)
		REFERENCE.style_button(badge)
		badge.pressed.connect(Callable(self,"_request_district").bind(id))
		stage.add_child(badge)
