extends CanvasLayer
const HORIZON_LAYOUT = preload("res://scripts/horizon_responsive_layout.gd")
## Russian-first accessible HUD. All controls use the same GameState as the 3D world.

signal strategy_changed(is_open: bool)
signal wants_save
signal wants_load
signal wants_reset
signal dialogue_changed(is_open: bool)

const BUILDS = {
	"council":["Городской совет","Council","市政议会"],
	"clinic":["Клиника","Clinic","诊所"],
	"academy":["Академия","Academy","学院"],
	"homes":["Жилые дома","Housing","住宅"],
	"gardens":["Городские сады","Gardens","花园"],
	"school":["Школа","School","学校"],
	"market":["Рынок","Market","市场"],
	"factory":["Фабрика","Factory","工厂"],
	"depot":["Склад","Depot","仓库"],
	"plant":["Электростанция","Power plant","发电站"],
	"purifier":["Очистка воды","Water treatment","净水厂"],
	"reservoir":["Резервуар","Reservoir","水库"]
}
const ESTATE_UI = {
	"ru":{"title":"НЕДВИЖИМОСТЬ И АРЕНДА","occupancy":"Заселение","rent":"Арендная прибыль","renovate":"УЛУЧШИТЬ","acquire":"КУПИТЬ","level":"Уровень","weather":"Погода","reputation":"Репутация","income_personal":"Личный доход/такт","private_debt":"Личный долг","repay":"ПОГАСИТЬ 250 кр. ДОЛГА"},
	"en":{"title":"PROPERTY AND RENTALS","occupancy":"Occupancy","rent":"Rental profit","renovate":"UPGRADE","acquire":"BUY","level":"Level","weather":"Weather","reputation":"Reputation","income_personal":"Private income/turn","private_debt":"Private debt","repay":"REPAY 250 кр. DEBT"},
	"zh":{"title":"房产与租赁","occupancy":"入住率","rent":"出租收益","renovate":"升级","acquire":"购买","level":"等级","weather":"天气","reputation":"声望","income_personal":"每回合个人收入","private_debt":"个人债务","repay":"偿还250卢布债务"}
}

const TECH_NAMES = {
	"grid":["Умная электросеть","Smart grid","智能电网"],
	"filtration":["Фильтрация","Filtration","过滤技术"],
	"councilAI":["ИИ-управление","AI administration","人工智能治理"],
	"commerce":["Логистика торговли","Commerce logistics","贸易物流"],
	"agronomy":["Агрономия","Agronomy","农学"],
	"automation":["Автоматизация","Automation","自动化"]
}
const CRISIS_NAMES = {
	"drought":["Засуха","Drought","干旱"],
	"strike":["Забастовка","Strike","罢工"],
	"blackout":["Отключение света","Blackout","停电"],
	"fire":["Пожар","Fire","火灾"],
	"epidemic":["Эпидемия","Epidemic","疫情"]
}
const BUSINESS_NAMES = {
	"market_stall":["Торговая галерея","Market Gallery","贸易中心"],
	"logistics":["Логистическая компания","Logistics Company","物流企业"],
	"workshop":["Промышленная мастерская","Industrial Workshop","工业车间"]
}
const DIST_NAMES = {
	"forum":["Сенатский форум","Senate Forum","元老院广场"],
	"housing":["Жилой квартал","Residential Quarter","住宅区"],
	"lower":["Нижний город","Lower City","下城区"],
	"aqueduct":["Акведуки","Aqueduct District","水道区"]
}
const TRANSLATIONS = {
	"ru":{
		"repair_hint":"Для ремонта автомобиля нужно %d игровых кр.",
		"condition":"Состояние","repaired":"Машина отремонтирована",
		"paused":"ПАУЗА · OSGARD Ω",
		"pause_description":"Время в городе остановлено. Продолжайте, сохраняйте игру или настройте управление.",
		"resume":"ПРОДОЛЖИТЬ ИГРУ",
		"preferences":"НАСТРОЙКИ",
		"back":"← НАЗАД",
		"pause_help":"Esc — закрыть · Tab — управление городом · мышь — камера",
		"volume":"Громкость",
		"mouse_sensitivity":"Чувствительность мыши",
		"visual_quality":"Качество графики",
		"low":"Низкое",
		"standard":"Стандартное",
		"cinematic":"Высокое",
		"reduced_motion":"Уменьшить эффекты движения",
		"language_label":"Язык интерфейса",
		"key_bindings":"НАЗНАЧЕНИЕ КЛАВИШ",
		"key_instructions":"Нажмите кнопку справа от действия, затем новую клавишу. Esc — отменить.",
		"reset_keys":"СБРОСИТЬ НАЗНАЧЕНИЯ",
		"keys_reset":"Управление сброшено",
		"press_key":"ОЖИДАНИЕ КЛАВИШИ",
		"bind_cancel":"Переназначение отменено",
		"bind_saved":"Клавиша назначена",
		"bind_conflict":"Эта клавиша уже используется или недоступна",
		"economy":"ПРОИЗВОДСТВО И ЗАНЯТОСТЬ",
		"grain":"Зерно",
		"materials":"Материалы",
		"goods":"Товары",
		"unemployment":"Безработица",
		"district_wellbeing":"Благополучие района",
		"shortages":"Дефицит ресурсов",
		"action_move_forward":"Вперёд",
		"action_move_backward":"Назад",
		"action_move_left":"Влево",
		"action_move_right":"Вправо",
		"action_jump":"Прыжок",
		"action_sprint":"Бег",
		"action_drive_trial":"Начать автозачёт (T)",
		"action_enter_vehicle":"Выйти/сесть в машину",
		"action_interact":"Взаимодействовать","action_talk_citizen":"Поговорить с жителем","action_city_case":"Районное событие",
		"action_governor":"Управление городом",
		"action_pause_game":"Пауза",
		"action_show_map":"Мини-карта","action_field_journal":"Полевой журнал",
		"action_enter_interior":"Войти / выйти из здания",
		"action_diagnostics":"Производительность (F3)",
		"action_buy_business":"Купить бизнес",
		"action_advance_turn":"Следующий такт",
		"action_save_game":"Сохранить",
		"action_load_game":"Загрузить",
		"action_language":"Сменить язык",
		"action_pay_traffic_fines":"Оплатить штраф у мэрии","brand":"OSGARD  ·  ИМПЕРИЯ Ω","market_hint":"B — купить торговый бизнес","budget_graph":"ИСТОРИЯ КАЗНЫ / ЛИЧНЫХ ДЕНЕГ","sub":"ОТКРЫТЫЙ МИР / ПРАВЛЕНИЕ",
		"cash":"Казна","wallet":"Личные деньги","business_income":"Доход бизнеса","invest":"ВЛОЖИТЬ 250 кр. В ГОРОД","contracts":"КОММЕРЧЕСКИЕ РЕЙСЫ","fuel":"Топливо","refueled":"Машина заправлена: −85 кр.","refuel_hint":"Для заправки нужно 85 кр. и неполный бак","accepted":"Груз принят: следуйте к пункту доставки","completed":"Доставка выполнена","unavailable":"Задания временно недоступны","population":"Население","stability":"Стабильность","energy":"Энергия","water":"Вода","food":"Продовольствие",
		"turn":"Такт","mission":"МИССИЯ","hint":"WASD — идти · E — авто · F — действие · J — житель · T — автошкола · C — события · R — помощь · I — здание · Tab — правление · F3 — FPS",
		"strategy":"КАБИНЕТ ПРАВИТЕЛЯ","close":"ЗАКРЫТЬ (Tab)","district":"РАЙОН","development":"СТРОИТЕЛЬСТВО","research":"ИССЛЕДОВАНИЯ",
		"business":"БИЗНЕС","tax":"Налог","tax_minus":"− 2%","tax_plus":"+ 2%","policy":"Курс политики","balance":"Баланс","industry":"Промышленность","energy_policy":"Энергетика","welfare":"Социальный курс",
		"forecast":"ПРОГНОЗ СЛЕДУЮЩЕГО ТАКТА","income":"Доходы","expenses":"Расходы","net":"Итог","science":"Наука","actions":"Действий осталось","start_turn":"ЗАВЕРШИТЬ ТАКТ (N)",
		"owned":"Куплено","buy":"Купить","max":"МАКС","unlocked":"Изучено","save":"СОХРАНИТЬ (F5)","load":"ЗАГРУЗИТЬ (F9)","import":"ИМПОРТ СОХРАНЕНИЯ v3","reset":"НОВАЯ ИГРА","restart_confirm":"Новая игра удалит текущий прогресс. Продолжить?",
		"crisis":"КРИЗИС","aid":"Помощь городу (175 кр.)","ignore":"Отложить (штраф)","need":"Недостаточно ресурсов или лимит действий","success":"Действие выполнено","bought":"Компания приобретена!","too_far":"Подойдите к объекту ближе","interact":"F: взаимодействие","drive":"E: автомобиль","free":"Свободная игра","speed":"Скорость","handbrake":"РУЧНИК","saved":"Игра сохранена","loaded":"Игра загружена","load_failed":"Не удалось загрузить сохранение","save_recovered":"Прогресс восстановлен из аварийной копии","autosave_failed":"Автосохранение не удалось: проверьте место на диске","save_failed":"Ошибка сохранения","imported":"Сохранение v3 импортировано","import_failed":"Импорт не выполнен: проверьте формат и версию","cancel":"ОТМЕНА","confirm":"ПОДТВЕРДИТЬ"},
	"en":{
		"repair_hint":"Vehicle repair costs %d game кр.",
		"condition":"Condition","repaired":"Vehicle repaired",
		"paused":"PAUSED · OSGARD Ω",
		"pause_description":"The city is paused. Resume, save your progress, or customize your controls.",
		"resume":"RESUME GAME",
		"preferences":"SETTINGS",
		"back":"← BACK",
		"pause_help":"Esc — close · Tab — city governance · mouse — camera",
		"volume":"Volume",
		"mouse_sensitivity":"Mouse sensitivity",
		"visual_quality":"Visual quality",
		"low":"Low",
		"standard":"Standard",
		"cinematic":"High",
		"reduced_motion":"Reduce motion effects",
		"language_label":"Interface language",
		"key_bindings":"KEYBOARD BINDINGS",
		"key_instructions":"Click a binding and press a new physical key. Esc cancels.",
		"reset_keys":"RESET KEY BINDINGS",
		"keys_reset":"Bindings restored",
		"press_key":"PRESS A KEY",
		"bind_cancel":"Rebinding cancelled",
		"bind_saved":"Binding updated",
		"bind_conflict":"Key is already in use or unavailable",
		"economy":"PRODUCTION AND EMPLOYMENT",
		"grain":"Grain",
		"materials":"Materials",
		"goods":"Goods",
		"unemployment":"Unemployment",
		"district_wellbeing":"District wellbeing",
		"shortages":"Supply shortages",
		"action_move_forward":"Forward",
		"action_move_backward":"Backward",
		"action_move_left":"Left",
		"action_move_right":"Right",
		"action_jump":"Jump",
		"action_sprint":"Sprint",
		"action_drive_trial":"Driving academy trial (T)",
		"action_enter_vehicle":"Enter/exit vehicle",
		"action_interact":"Interact","action_talk_citizen":"Talk to a resident","action_city_case":"District incident",
		"action_governor":"Govern city",
		"action_pause_game":"Pause",
		"action_show_map":"Mini-map","action_field_journal":"Field journal",
		"action_enter_interior":"Enter / exit building",
		"action_diagnostics":"Performance (F3)",
		"action_buy_business":"Buy business",
		"action_advance_turn":"Next turn",
		"action_save_game":"Save",
		"action_load_game":"Load",
		"action_language":"Change language",
		"action_pay_traffic_fines":"Pay city fine","brand":"OSGARD  ·  EMPIRE Ω","market_hint":"B — purchase market business","budget_graph":"TREASURY / WALLET HISTORY","sub":"OPEN WORLD / GOVERNANCE",
		"cash":"Treasury","wallet":"Your wallet","business_income":"Business income","invest":"INVEST 250 кр. INTO CITY","contracts":"COURIER CONTRACTS","fuel":"Fuel","refueled":"Refueled: −85 кр.","refuel_hint":"Refueling needs 85 кр. and a non-full tank","accepted":"Cargo collected: go to destination","completed":"Delivery completed","unavailable":"Contracts are unavailable","population":"Population","stability":"Stability","energy":"Energy","water":"Water","food":"Food",
		"turn":"Turn","mission":"MISSION","hint":"WASD — move · E — car · F — act · J — residents · T — academy · C — incidents · R — service · I — interior · Tab — govern · F3 — FPS",
		"strategy":"GOVERNOR'S CABINET","close":"CLOSE (Tab)","district":"DISTRICT","development":"CONSTRUCTION","research":"RESEARCH",
		"business":"BUSINESS","tax":"Tax","tax_minus":"− 2%","tax_plus":"+ 2%","policy":"Policy","balance":"Balance","industry":"Industry","energy_policy":"Energy","welfare":"Welfare",
		"forecast":"NEXT-TURN FORECAST","income":"Revenue","expenses":"Expenses","net":"Net","science":"Science","actions":"Actions left","start_turn":"ADVANCE TURN (N)",
		"owned":"Owned","buy":"Buy","max":"MAX","unlocked":"Researched","save":"SAVE (F5)","load":"LOAD (F9)","import":"IMPORT v3 SAVE","reset":"NEW GAME","restart_confirm":"New game replaces your current progress. Continue?",
		"crisis":"CRISIS","aid":"Emergency assistance (175 кр.)","ignore":"Defer (penalty)","need":"Insufficient resources or action limit","success":"Action completed","bought":"Business acquired!","too_far":"Move closer to the destination","interact":"F: interact","drive":"E: vehicle","free":"Free play","speed":"Speed","handbrake":"HANDBRAKE","saved":"Game saved","loaded":"Game loaded","load_failed":"Could not load saved game","save_recovered":"Progress recovered from a recovery file","autosave_failed":"Autosave failed: check available disk space","save_failed":"Save failed","imported":"v3 save imported","import_failed":"Import failed: check file version and format","cancel":"CANCEL","confirm":"CONFIRM"},
	"zh":{
		"repair_hint":"修车需要 %d 游戏卢布",
		"condition":"车况","repaired":"车辆已修好",
		"paused":"游戏暂停 · OSGARD Ω",
		"pause_description":"城市时间已暂停。可以继续游戏、保存进度或调整控制。",
		"resume":"继续游戏",
		"preferences":"设置",
		"back":"← 返回",
		"pause_help":"Esc 关闭 · Tab 城市管理 · 鼠标控制镜头",
		"volume":"音量",
		"mouse_sensitivity":"鼠标灵敏度",
		"visual_quality":"画面质量",
		"low":"低",
		"standard":"标准",
		"cinematic":"高",
		"reduced_motion":"减少动态效果",
		"language_label":"界面语言",
		"key_bindings":"键盘按键设置",
		"key_instructions":"点击按键设置，然后按下新按键。Esc 取消。",
		"reset_keys":"恢复默认按键",
		"keys_reset":"按键已重置",
		"press_key":"请按一个键",
		"bind_cancel":"已取消修改",
		"bind_saved":"按键更新完成",
		"bind_conflict":"按键已占用或不可用",
		"economy":"生产与就业",
		"grain":"粮食",
		"materials":"材料",
		"goods":"商品",
		"unemployment":"失业率",
		"district_wellbeing":"城区繁荣指数",
		"shortages":"资源短缺",
		"action_move_forward":"前进",
		"action_move_backward":"后退",
		"action_move_left":"向左",
		"action_move_right":"向右",
		"action_jump":"跳跃",
		"action_sprint":"奔跑",
		"action_drive_trial":"驾驶学院计时赛 (T)",
		"action_enter_vehicle":"上下车",
		"action_interact":"互动","action_talk_citizen":"与居民交谈","action_city_case":"地区事件",
		"action_governor":"城市管理",
		"action_pause_game":"暂停",
		"action_show_map":"小地图","action_field_journal":"任务日志",
		"action_enter_interior":"进入 / 离开建筑",
		"action_diagnostics":"性能 (F3)",
		"action_buy_business":"购买企业",
		"action_advance_turn":"下一回合",
		"action_save_game":"保存",
		"action_load_game":"读取",
		"action_language":"切换语言",
		"action_pay_traffic_fines":"在市政厅缴纳罚款","brand":"OSGARD · 帝国 Ω","market_hint":"按 B 购买市场商铺","budget_graph":"国库 / 钱包历史","sub":"开放世界 / 城市治理",
		"cash":"国库","wallet":"个人资金","business_income":"企业收入","invest":"向城市投资 250 кр.","contracts":"配送合同","fuel":"燃油","refueled":"加油成功：−85 кр.","refuel_hint":"加油需要 85 кр. 且油箱未满","accepted":"已接货：前往目的地","completed":"配送完成","unavailable":"暂无配送合同","population":"人口","stability":"稳定度","energy":"能源","water":"水资源","food":"粮食",
		"turn":"回合","mission":"任务","hint":"WASD 移动/驾驶 · E 汽车 · F 互动/维修 · J 居民 · T 驾考 · R 公共服务 · I 室内 · Tab 治理 · F3 性能 · L 语言",
		"strategy":"执政官办公室","close":"关闭 (Tab)","district":"城区","development":"建设","research":"研究",
		"business":"企业","tax":"税率","tax_minus":"− 2%","tax_plus":"+ 2%","policy":"政策方向","balance":"平衡","industry":"工业","energy_policy":"能源","welfare":"民生",
		"forecast":"下回合预测","income":"收入","expenses":"支出","net":"结余","science":"科研","actions":"剩余行动","start_turn":"结束回合 (N)",
		"owned":"已购买","buy":"购买","max":"最高级","unlocked":"已研究","save":"保存 (F5)","load":"读取 (F9)","import":"导入 v3 存档","reset":"新游戏","restart_confirm":"开始新游戏将清除当前进度，继续吗？",
		"crisis":"危机","aid":"紧急援助 (175 кр.)","ignore":"延后处理（惩罚）","need":"资源不足或行动次数不足","success":"操作成功","bought":"企业已购买！","too_far":"请靠近目标","interact":"F：交互","drive":"E：车辆","free":"自由游戏","speed":"速度","handbrake":"手刹","saved":"已保存","loaded":"游戏已加载","load_failed":"无法加载存档","save_recovered":"已从恢复文件还原进度","autosave_failed":"自动保存失败：请检查磁盘空间","save_failed":"保存失败","imported":"成功导入 v3 存档","import_failed":"导入失败：请检查文件格式和版本","cancel":"取消","confirm":"确认"}
}

var open := false
var root: Control
var header_panel: PanelContainer
var objective_panel: PanelContainer
var controls_panel: PanelContainer
var map_panel: PanelContainer
var strategy_window: PanelContainer
var pause_panel: PanelContainer
var compact_hud := false
var map_override := false
var header_value: Label
var meters_label: Label
var law_label: Label
var mission_label: Label
var contract_label: Label
var service_label: Label
var neighborhood_label: Label
var context_label: Label
var hint_label: Label
var speed_label: Label
var mission_distance_label: Label
var journal_panel: PanelContainer
var speed_panel: PanelContainer
var toast_panel: PanelContainer
var toast_label: Label
var toast_until_ms: int = 0
var map
var diagnostic_panel: PanelContainer
var diagnostic_label: Label
var diagnostic_visible := false
var overlay: ColorRect
var strategy_contents: VBoxContainer
var strategy_title: Label
var strategy_scroll: ScrollContainer
var importer: FileDialog
var confirm_reset: ConfirmationDialog
var city_case_popup: ConfirmationDialog
var city_case_button: Button
var city_case_label: Label
var citizen_popup: ConfirmationDialog
var listen_button: Button
var neighborhood_button: Button
var trial_label: Label
var active_citizen := -1
var active_citizen_district := ""
var locale_index := 0
var last_announcement := ""
var label_list: Array[Label] = []

# --- Accessible pause and preferences UI (runs when the simulation is paused) ---
var pause_open := false
var settings_page := false
var pause_overlay: ColorRect
var pause_contents: VBoxContainer
var pause_heading: Label
var awaiting_binding := ""
var status_binding := ""
const EDITABLE_ACTIONS = [
	"move_forward", "move_backward", "move_left", "move_right", "jump", "sprint",
	"enter_vehicle", "drive_trial", "interact", "talk_citizen", "city_case", "enter_interior", "governor", "pause_game", "show_map", "field_journal", "diagnostics",
	"buy_business", "advance_turn", "save_game", "load_game", "language", "pay_traffic_fines"
]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	root.name = "OverlayRoot"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_make_hud()
	_make_strategy()
	_make_dialogs()
	_make_pause_menu()
	get_viewport().size_changed.connect(_apply_responsive_layout)
	_apply_responsive_layout()
	GameState.state_changed.connect(_on_state_changed)
	MissionManager.mission_updated.connect(_on_mission_changed)
	_refresh()

func t(id: String) -> String:
	return str(TRANSLATIONS.get(GameState.locale,TRANSLATIONS["ru"]).get(id,id))

func translated(values: Array) -> String:
	var idx := 0 if GameState.locale == "ru" else (1 if GameState.locale == "en" else 2)
	return str(values[idx])

func estate_text(id: String) -> String:
	return str(ESTATE_UI.get(GameState.locale,ESTATE_UI["ru"]).get(id,id))

func property_name(id: String) -> String:
	var names: Dictionary = GameState.REAL_ESTATE.PROPERTIES[id]["name"]
	return str(names.get(GameState.locale,names["ru"]))

func incident_name(id: String) -> String:
	return translated(CRISIS_NAMES.get(id,[id,id,id]))

func _style(background: Color, edge: Color, corner: int = 12) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = edge
	style.set_border_width_all(1)
	style.set_corner_radius_all(corner)
	style.content_margin_left = 16
	style.content_margin_top = 12
	style.content_margin_right = 16
	style.content_margin_bottom = 12
	return style

func _panel(bounds: Rect2, anchor_right: float = 0.0, anchor_bottom: float = 0.0) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.anchor_left = anchor_right
	panel.anchor_right = anchor_right
	panel.anchor_top = anchor_bottom
	panel.anchor_bottom = anchor_bottom
	panel.offset_left = bounds.position.x
	panel.offset_top = bounds.position.y
	panel.offset_right = bounds.position.x + bounds.size.x
	panel.offset_bottom = bounds.position.y + bounds.size.y
	panel.add_theme_stylebox_override("panel",_style(Color("0a1929",0.86),Color("426476")))
	root.add_child(panel)
	return panel

func _label(parent: Node, text: String, font_size: int = 18, highlight: bool = false) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",Color("f3dca7") if highlight else Color("f4f8fc"))
	parent.add_child(label)
	return label

func _button(parent: Node, title: String, callable: Callable, disabled: bool = false) -> Button:
	var button := Button.new()
	button.text = title
	button.disabled = disabled
	button.custom_minimum_size.y = 40
	button.add_theme_color_override("font_color",Color("e6dcc7"))
	button.add_theme_color_override("font_hover_color",Color("ffffff"))
	button.pressed.connect(callable)
	parent.add_child(button)
	return button

func _separator(parent: Node) -> void:
	var line := HSeparator.new()
	line.modulate = Color("8294a6",0.3)
	parent.add_child(line)

func _make_hud() -> void:
	# AURORA CITY: show the city, not seven overlapping dashboards.
	header_panel = _panel(Rect2(24,20,420,86))
	var header := header_panel
	var brand_stack := VBoxContainer.new()
	brand_stack.add_theme_constant_override("separation",3)
	header.add_child(brand_stack)
	header_value = _label(brand_stack,"OSGARD EMPIRE",23,true)
	meters_label = _label(brand_stack,"",16)
	objective_panel = _panel(Rect2(-476,20,452,150),1.0)
	var objective := objective_panel
	var objective_stack := VBoxContainer.new()
	objective_stack.add_theme_constant_override("separation",7)
	objective.add_child(objective_stack)
	_label(objective_stack,_v08("ВАША ЦЕЛЬ","YOUR OBJECTIVE","当前目标"),15,true)
	mission_label = _label(objective_stack,"",22)
	mission_distance_label = _label(objective_stack,"",16,true)
	journal_panel = _panel(Rect2(-476,186,452,440),1.0)
	journal_panel.visible = false
	var journal_scroll := ScrollContainer.new()
	journal_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	journal_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	journal_panel.add_child(journal_scroll)
	var details := VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.add_theme_constant_override("separation",9)
	journal_scroll.add_child(details)
	_label(details,_v08("ПУЛЬС ГОРОДА · H — СКРЫТЬ","CITY JOURNAL · H — CLOSE","城市日志 · H 关闭"),18,true)
	_label(details,_v08("ЭКОНОМИКА И БЕЗОПАСНОСТЬ","ECONOMY AND SAFETY","经济和安全"),14,true)
	context_label = _label(details,"",16)
	law_label = _label(details,"",16,true)
	_separator(details)
	_label(details,_v08("ПОМОЩЬ ЖИТЕЛЯМ · J","NEIGHBORHOOD · J","社区任务 · J"),14,true)
	neighborhood_label = _label(details,"",16)
	_separator(details)
	_label(details,_v08("АВТОШКОЛА · T","DRIVING ACADEMY · T","驾校 · T"),14,true)
	trial_label = _label(details,"",16)
	_separator(details)
	_label(details,_v08("ДОСТАВКИ","DELIVERIES","配送任务"),14,true)
	contract_label = _label(details,"",16)
	_separator(details)
	_label(details,_v08("ГОРОДСКИЕ СЛУЖБЫ · R","CITY SERVICES · R","城市服务 · R"),14,true)
	service_label = _label(details,"",16)
	_separator(details)
	_label(details,_v08("СОБЫТИЯ · C","CITY EVENTS · C","城市事件 · C"),14,true)
	city_case_label = _label(details,"",16)
	map_panel = _panel(Rect2(24,-276,248,252),0.0,1.0)
	map = preload("res://scripts/minimap.gd").new()
	map.custom_minimum_size = Vector2(208,208)
	map_panel.add_child(map)
	controls_panel = _panel(Rect2(290,-92,-672,68),1.0,1.0)
	var controls := controls_panel
	controls.anchor_left = 0.0
	hint_label = _label(controls,"",17)
	speed_panel = _panel(Rect2(-360,-145,336,122),1.0,1.0)
	speed_panel.visible = false
	speed_label = _label(speed_panel,"",20,true)
	toast_panel = _panel(Rect2(-252,24,504,64),0.5)
	toast_panel.visible = false
	toast_label = _label(toast_panel,"",18,true)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	diagnostic_panel = _panel(Rect2(24,116,360,105))
	diagnostic_panel.visible = false
	diagnostic_label = _label(diagnostic_panel,"PERFORMANCE",15,true)

func toggle_field_journal() -> void:
	if journal_panel != null and not open and not pause_open:
		journal_panel.visible = not journal_panel.visible

func _process(_delta: float) -> void:
	if toast_panel != null and toast_panel.visible and Time.get_ticks_msec() > toast_until_ms:
		toast_panel.visible = false

func _make_strategy() -> void:
	overlay = ColorRect.new()
	overlay.color = Color(0.005,0.012,0.025,0.88)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.visible = false
	root.add_child(overlay)
	var window := PanelContainer.new()
	strategy_window = window
	window.anchor_left = 0.5
	window.anchor_right = 0.5
	window.anchor_top = 0.5
	window.anchor_bottom = 0.5
	window.offset_left = -450
	window.offset_right = 450
	window.offset_top = -365
	window.offset_bottom = 365
	window.add_theme_stylebox_override("panel",_style(Color("081522"),Color("a78b56"),14))
	overlay.add_child(window)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation",9)
	window.add_child(stack)
	var title_row := HBoxContainer.new()
	stack.add_child(title_row)
	strategy_title = _label(title_row,"",25,true)
	strategy_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_button(title_row,"✕",Callable(self,"toggle_strategy"))
	strategy_scroll = ScrollContainer.new()
	strategy_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(strategy_scroll)
	strategy_contents = VBoxContainer.new()
	strategy_contents.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	strategy_contents.add_theme_constant_override("separation",9)
	strategy_scroll.add_child(strategy_contents)

func _make_dialogs() -> void:
	importer = FileDialog.new()
	importer.title = "OSGARD — v3 → v4"
	importer.access = FileDialog.ACCESS_FILESYSTEM
	importer.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	importer.filters = PackedStringArray(["*.json ; OSGARD v3 JSON"])
	importer.file_selected.connect(_import_v3)
	add_child(importer)
	confirm_reset = ConfirmationDialog.new()
	confirm_reset.confirmed.connect(_confirm_new_game)
	add_child(confirm_reset)
	citizen_popup = ConfirmationDialog.new()
	citizen_popup.title = "OSGARD — CITIZEN"
	citizen_popup.confirmed.connect(_support_citizen)
	citizen_popup.custom_action.connect(_citizen_custom_action)
	citizen_popup.visibility_changed.connect(_citizen_visibility_changed)
	add_child(citizen_popup)
	listen_button = citizen_popup.add_button("Listen",true,"listen")
	neighborhood_button = citizen_popup.add_button("Neighborhood job",true,"neighborhood_job")
	city_case_popup = ConfirmationDialog.new()
	city_case_popup.title = "OSGARD · CITY INCIDENT"
	city_case_popup.confirmed.connect(_city_case_second)
	city_case_popup.custom_action.connect(_city_case_custom_action)
	city_case_popup.visibility_changed.connect(_city_case_visibility_changed)
	add_child(city_case_popup)
	city_case_button = city_case_popup.add_button("Invest",true,"invest")

func is_city_case_open() -> bool:
	return city_case_popup != null and city_case_popup.visible

func _city_case_visibility_changed() -> void:
	dialogue_changed.emit(city_case_popup.visible)

func show_city_case() -> void:
	var case: Dictionary = GameState.CITY_CASES.current(GameState.data)
	if pause_open or is_citizen_open() or case.is_empty(): return
	var active: Dictionary = GameState.data.get("city_case",{})
	city_case_popup.title = str(case["title"].get(GameState.locale,case["title"]["ru"]))
	var description: String = str(case["description"].get(GameState.locale,case["description"]["ru"]))
	var options: Array = case["options"]
	var first: Dictionary = options[0]
	var second: Dictionary = options[1]
	city_case_popup.dialog_text = description + "\n" + _v08("Срок: такт ","Deadline: turn ","截止回合：") + str(active["due_turn"]) + "\n\n" + str(first["title"].get(GameState.locale,first["title"]["ru"])) + ": " + _case_effect_text(first) + "\n" + str(second["title"].get(GameState.locale,second["title"]["ru"])) + ": " + _case_effect_text(second)
	city_case_button.text = str(first["title"].get(GameState.locale,first["title"]["ru"])) + "  ·  " + _case_cost_text(first)
	city_case_button.disabled = not GameState.CITY_CASES.can_pay(GameState.data,first)
	city_case_popup.ok_button_text = str(second["title"].get(GameState.locale,second["title"]["ru"])) + "  ·  " + _case_cost_text(second)
	city_case_popup.get_ok_button().disabled = not GameState.CITY_CASES.can_pay(GameState.data,second)
	city_case_popup.popup_centered(Vector2i(770,360))

func _case_cost_text(option: Dictionary) -> String:
	var pieces: Array[String] = []
	for resource in option["cost"]:
		pieces.append(t("cash" if resource == "treasury" else resource) + " " + str(option["cost"][resource]))
	return ", ".join(pieces)

func _case_effect_text(option: Dictionary) -> String:
	var parts: Array[String] = []
	for resource in option.get("effects",{}):
		var change: int = int(option["effects"][resource])
		var label_name: String = t("cash" if resource == "treasury" else resource)
		if resource == "road_quality": label_name = _v08("дороги", "roads", "道路")
		elif resource == "reputation": label_name = _v08("репутация", "reputation", "声望")
		elif resource == "science": label_name = _v08("наука", "science", "科研")
		parts.append(label_name + " " + ("+" if change > 0 else "") + str(change))
	return ", ".join(parts)

func _city_case_custom_action(action: String) -> void:
	if action == "invest": _resolve_city_case(action)

func _city_case_second() -> void:
	_resolve_city_case("mobilize")

func _resolve_city_case(action: String) -> void:
	var successful: bool = GameState.resolve_city_case(action)
	city_case_popup.hide()
	announce(_v08("Районное происшествие разрешено","District incident resolved","地区事件已处理") if successful else t("need"))

func _open_case_from_cabinet() -> void:
	if open: toggle_strategy()
	show_city_case()

func is_citizen_open() -> bool:
	return citizen_popup != null and citizen_popup.visible

func show_citizen(citizen_id: int, district: String) -> void:
	if pause_open or open or not GameState.citizen_available(citizen_id):
		var messages: Dictionary = GameState.CITIZEN_REQUESTS.LABELS.get(GameState.locale,GameState.CITIZEN_REQUESTS.LABELS["ru"])
		announce(str(messages["already"]))
		return
	active_citizen = citizen_id
	active_citizen_district = district
	var messages: Dictionary = GameState.CITIZEN_REQUESTS.LABELS.get(GameState.locale,GameState.CITIZEN_REQUESTS.LABELS["ru"])
	citizen_popup.title = str(messages["title"])
	citizen_popup.dialog_text = GameState.CITIZEN_REQUESTS.text(GameState.data,citizen_id,GameState.locale)
	var local_job: Dictionary = GameState.NEIGHBORHOOD.offer(GameState.data,citizen_id,district)
	if not local_job.is_empty():
		citizen_popup.dialog_text += "\n\n" + str(local_job["title"].get(GameState.locale,local_job["title"]["ru"]))
		citizen_popup.dialog_text += "\n" + str(local_job["description"].get(GameState.locale,local_job["description"]["ru"]))
		citizen_popup.dialog_text += "\n" + _v08("Материалы: ","Supplies: ","物资成本：") + str(local_job["supply_cost"]) + " кр.  →  " + str(local_job["reward"]) + " кр."
	neighborhood_button.text = _v08("Взять поручение","Accept errand","接受委托")
	neighborhood_button.disabled = not GameState.NEIGHBORHOOD.can_accept(GameState.data,citizen_id,district)
	citizen_popup.ok_button_text = str(messages["support"])
	listen_button.text = str(messages["listen"])
	citizen_popup.popup_centered(Vector2i(720,280))

func _citizen_visibility_changed() -> void:
	dialogue_changed.emit(citizen_popup.visible)

func _citizen_custom_action(action: String) -> void:
	if action == "listen":
		_resolve_citizen("listen")
	elif action == "neighborhood_job":
		_accept_neighborhood_job()

func _accept_neighborhood_job() -> void:
	var successful: bool = GameState.accept_neighborhood_job(active_citizen,active_citizen_district)
	citizen_popup.hide()
	if successful:
		MissionManager.register_action("neighborhood_accept")
		announce(GameState.NEIGHBORHOOD.status_text("accepted",GameState.locale))
	else:
		announce(GameState.NEIGHBORHOOD.status_text("busy",GameState.locale))

func _support_citizen() -> void:
	_resolve_citizen("support")

func _resolve_citizen(choice: String) -> void:
	var worked: bool = GameState.respond_to_citizen(active_citizen,active_citizen_district,choice)
	citizen_popup.hide()
	if worked:
		var messages: Dictionary = GameState.CITIZEN_REQUESTS.LABELS.get(GameState.locale,GameState.CITIZEN_REQUESTS.LABELS["ru"])
		announce(str(messages["done"]))
	else:
		announce(t("need"))

func _on_state_changed(_reason: String) -> void:
	_refresh()

func _on_mission_changed(_index: int, _title: String) -> void:
	_refresh()

func _refresh() -> void:
	if header_value == null: return
	header_value.text = _v08("EMPIRE Ω","EMPIRE Ω","帝国 Ω") if compact_hud else t("brand")
	var d: Dictionary = GameState.data
	meters_label.text = ("№%d  ·  %d кр." % [d["turn"],d["wallet"]]) if compact_hud else ("%s %d   ·   %s %d кр.   ·   %s %d кр." % [t("turn"),d["turn"],t("wallet"),d["wallet"],t("cash"),d["treasury"]])
	context_label.text = "%s: %s\n%s: %d\n%s: %d%%  |  %s: %d%%\n%s: %d%%  |  %s: %d%%" % [t("cash"),str(d["treasury"])+" кр.",t("population"),d["population"],t("stability"),d["stability"],t("energy"),d["energy"],t("water"),d["water"],t("food"),d["food"]]
	if law_label != null:
		var law: Dictionary = d.get("law",{})
		var heat: int = int(law.get("heat",0))
		var fine: int = int(law.get("fine",0))
		if heat>0:
			law_label.text = _v08("РОЗЫСК ","WANTED ","通缉 ") + "★".repeat(heat) + "  ·  " + str(fine) + " кр."
		elif fine>0:
			law_label.text = _v08("ШТРАФ ","FINE ","罚款 ") + str(fine) + " кр.  ·  P"
		else:
			law_label.text = _v08("Патрули: спокойно","Patrols: clear","巡逻：正常")
	mission_label.text = MissionManager.title(GameState.locale)
	if trial_label != null:
		var session: Dictionary = d.get("driving_trial",{})
		var route: Dictionary = GameState.TRIALS.find_route(str(session.get("id",""))) if not session.is_empty() else GameState.TRIALS.offer(d)
		var route_title: Dictionary = route.get("title",{})
		if session.is_empty():
			trial_label.text = _v08("T у дворца в машине · 35 кр.", "T in your car at City Hall · 35 кр.", "市政厅车内按 T · 35 кр.") + "\n" + str(route_title.get(GameState.locale,route_title.get("ru","")))
		else:
			trial_label.text = str(route_title.get(GameState.locale,route_title.get("ru",""))) + "\n" + "%d/%d  ·  %ds / %ds" % [int(session["step"]),route["checkpoints"].size(),roundi(float(session["elapsed"])),int(route["limit_seconds"])]
	contract_label.text = ContractManager.goal_text(GameState.locale) if contract_label != null else ""
	if service_label != null: service_label.text = GameState.SERVICE.goal_text(d,GameState.locale)
	if neighborhood_label != null: neighborhood_label.text = GameState.NEIGHBORHOOD.goal_text(d,GameState.locale)
	if city_case_label != null:
		var case: Dictionary = GameState.CITY_CASES.current(d)
		if case.is_empty():
			city_case_label.text = _v08("Районы спокойны · ждём новых событий", "Districts are quiet · no pending incident", "各区平静 · 暂无事件")
		else:
			city_case_label.text = str(case["title"].get(GameState.locale,case["title"]["ru"])) + "\n" + _v08("Решить до такта ","Resolve before turn ","处理截止回合 ") + str(d["city_case"]["due_turn"]) + "  ·  C / Tab"
	hint_label.text = _v08("АВТО · ИДТИ · ДЕЙСТВИЯ","CAR · WALK · ACTIONS","车辆 · 行走 · 操作") if compact_hud else _v08("WASD — идти · E — авто · F — действие · Tab — город · H — журнал","WASD — move · E — car · F — interact · Tab — city · H — journal","WASD 移动 · E 上车 · F 互动 · Tab 城市 · H 日志")
	if open:
		_redraw_strategy()

func update_world_context(player_at: Vector3, vehicle_at: Vector3, goal_at: Vector3, is_driving: bool, speed: float, fuel: float, nearest: String, condition: float = 100.0, handbrake: bool = false, gear: String = "N", drift_score: int = 0, assist_power: float = 0.0, assist_steering: float = 0.0) -> void:
	if map != null:
		map.player_world = player_at
		map.vehicle_world = vehicle_at
		map.goal_world = goal_at
		map.driving = is_driving
		map.queue_redraw()
	if contract_label != null and not ContractManager.active_contract().is_empty():
		contract_label.text = ContractManager.goal_text(GameState.locale)
	if service_label != null and not GameState.data.get("service_active",{}).is_empty():
		service_label.text = GameState.SERVICE.goal_text(GameState.data,GameState.locale)
	if trial_label != null and not GameState.data.get("driving_trial",{}).is_empty():
		var session: Dictionary = GameState.data["driving_trial"]
		var route: Dictionary = GameState.TRIALS.find_route(str(session["id"]))
		trial_label.text = str(route["title"].get(GameState.locale,route["title"]["ru"])) + "\n" + "%d/%d  ·  %ds / %ds" % [int(session["step"]),route["checkpoints"].size(),roundi(float(session["elapsed"])),int(route["limit_seconds"])]
	if neighborhood_label != null and not GameState.data.get("neighborhood_active",{}).is_empty():
		neighborhood_label.text = GameState.NEIGHBORHOOD.goal_text(GameState.data,GameState.locale)
	if mission_distance_label != null:
		var travel_distance: float = Vector2(player_at.x-goal_at.x,player_at.z-goal_at.z).length()
		mission_distance_label.text = _v08("ДО ЦЕЛИ","DISTANCE TO GOAL","目标距离") + ": %d м" % roundi(travel_distance)
	if speed_panel != null:
		speed_panel.visible = is_driving
	if is_driving:
		speed_label.text = "%d км/ч · %s" % [roundi(absf(speed)*3.6),gear]
		speed_label.text += "\n%s %d%% · %d%%" % [t("fuel"),roundi(fuel),roundi(condition)] if compact_hud else "\n%s %d%%  ·  %s %d%%" % [t("fuel"),roundi(fuel),t("condition"),roundi(condition)]
		if handbrake: speed_label.text += " · " + t("handbrake")
		if drift_score >= 12: speed_label.text += " · DRIFT %d" % drift_score
		var assist_intensity: float = clampf(maxf(assist_power,assist_steering*3.0),0.0,1.0)
		if assist_intensity >= 0.025:
			speed_label.text += "\n" + _v08("ПОМОЩЬ СЦЕПЛЕНИЮ","GRIP ASSIST","抓地辅助") + " %d%%" % roundi(assist_intensity*100.0)
		hint_label.text = _v08("ГАЗ · ТОРМ · РУЛЬ · АВТО","GAS · BRAKE · STEER · CAR","油门 · 刹车 · 转向 · 车辆") if compact_hud else _v08("W / S — газ и тормоз · A / D — руль · Пробел — ручник · E — выйти","W / S — drive and brake · A / D — steer · Space — handbrake · E — exit","W / S 油门刹车 · A / D 方向 · 空格 手刹 · E 下车")
	else:
		speed_label.text = ""
		hint_label.text = ((_v08("РЯДОМ: ","NEAR: ","附近: ")+nearest.left(24)) if nearest != "" else _v08("АВТО · ИДТИ · ДЕЙСТВИЯ","CAR · WALK · ACTIONS","车辆 · 行走 · 操作")) if compact_hud else (("F: "+nearest) if nearest != "" else _v08("WASD — идти · E — авто · F — действие · Tab — город · H — журнал","WASD — move · E — car · F — interact · Tab — city · H — journal","WASD 移动 · E 上车 · F 互动 · Tab 城市 · H 日志"))

func toggle_diagnostics() -> void:
	diagnostic_visible = not diagnostic_visible
	if diagnostic_panel != null:
		diagnostic_panel.visible = diagnostic_visible

func update_diagnostics(fps: int, chunks: int, total_chunks: int, citizens: int, traffic: int, stopped: int = 0) -> void:
	if diagnostic_label == null or not diagnostic_visible:
		return
	diagnostic_label.text = "FPS: %d   ·   3D NODES: %d\nQUARTERS: %d / %d   ·   NPC: %d   ·   CARS: %d   ·   STOPPED: %d" % [fps,int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),chunks,total_chunks,citizens,traffic,stopped]

func announce(message: String) -> void:
	last_announcement = message
	if toast_label != null and toast_panel != null:
		toast_label.text = message
		toast_panel.visible = true
		toast_until_ms = Time.get_ticks_msec() + 4400

func toggle_strategy() -> void:
	if pause_open: return
	open = not open
	overlay.visible = open
	if journal_panel != null: journal_panel.visible = false
	if open:
		_redraw_strategy()
	strategy_changed.emit(open)

func is_strategy_open() -> bool:
	return open

func switch_language() -> void:
	var languages := ["ru","en","zh"]
	var index := languages.find(GameState.locale)
	GameSettings.set_locale(languages[(index+1)%languages.size()])
	_refresh()

func _v08(ru: String, en: String, zh: String) -> String:
	return ru if GameState.locale == "ru" else (en if GameState.locale == "en" else zh)

func _do_trade(id: String, buying: bool) -> void:
	if GameState.trade_goods(id,buying,10):
		MissionManager.register_action("trade")
		announce(t("success"))
	else:
		announce(t("need"))

func _do_vehicle(id: String) -> void:
	if bool(get_parent().get("driving")):
		announce(_v08("Остановитесь и выйдите из автомобиля, чтобы сменить его", "Park and exit before changing vehicles", "请停车并下车后换车"))
		return
	var owned: bool = bool(GameState.data["vehicle_owned"].get(id,false))
	var done: bool = GameState.select_vehicle(id) if owned else GameState.buy_vehicle(id)
	if done:
		MissionManager.register_action("vehicle_select" if owned else "vehicle_buy")
		announce(t("success"))
	else:
		announce(t("need"))

func _redraw_strategy() -> void:
	strategy_title.text = t("strategy")
	for child in strategy_contents.get_children():
		strategy_contents.remove_child(child)
		child.queue_free()
	var d: Dictionary = GameState.data
	var forecast: Dictionary = GameState.forecast()
	_label(strategy_contents,"%s %d  ·  %s %d  ·  %s %d" % [t("turn"),d["turn"],t("science"),d["science"],t("actions"),d["actions_left"]],16,true)
	_label(strategy_contents,"%s: %d кр.   |   %s: %d кр.   |   %s: %d кр. / %s" % [t("wallet"),d["wallet"],t("cash"),d["treasury"],t("business_income"),GameState.private_turn_income(),t("turn")],16)
	_label(strategy_contents,"%s: %d кр.   ·   %s: %d/100   ·   %s: %s" % [estate_text("income_personal"),forecast["personal_income"],estate_text("reputation"),d.get("reputation",35),estate_text("weather"),GameState.CITY_WEATHER.LABELS[GameState.current_weather()["kind"]].get(GameState.locale,"Clear")],16)
	_button(strategy_contents,t("invest"),Callable(self,"_invest"),int(d["wallet"]) < 250)
	if int(d.get("personal_debt",0)) > 0:
		_label(strategy_contents,"%s: %d кр." % [estate_text("private_debt"),d["personal_debt"]],17)
		_button(strategy_contents,estate_text("repay"),Callable(self,"_pay_private_debt"),int(d["wallet"]) < 1)
	_separator(strategy_contents)
	_separator(strategy_contents)
	_label(strategy_contents,_v08("АТЛАС ГОРОДА · ОТКРЫТИЯ", "CITY ATLAS · DISCOVERIES", "城市图鉴 · 探索"),20,true)
	var found: Array = d.get("discovered_sites",[])
	_label(strategy_contents,_v08("Открыто мест: ","Places discovered: ","已发现地点：") + "%d / 12" % found.size(),17,true)
	_label(strategy_contents,_v08("Ищите бирюзовые маяки на мини-карте, подойдите пешком и нажмите F.","Find teal map markers, approach on foot and press F.","寻找地图上的青绿色标记，步行接近并按 F。"),15)
	for district in GameState.DISTRICTS:
		var completed_here: int = 0
		for site in GameState.DISCOVERY.sites():
			if str(site["district"]) == district and found.has(str(site["id"])):
				completed_here += 1
		_label(strategy_contents,translated(DIST_NAMES[district])+"  %d / 3" % completed_here,15)
	var exploration_records: Array = d.get("discovery_history",[])
	for record in exploration_records.slice(0,3):
		var discovered_site: Dictionary = GameState.DISCOVERY.find_site(str(record["id"]))
		if not discovered_site.is_empty():
			_label(strategy_contents,"✓ "+GameState.DISCOVERY.title(discovered_site,GameState.locale),14)
			var details: Dictionary = discovered_site["description"]
			_label(strategy_contents,str(details.get(GameState.locale,details["ru"])),13)
	_separator(strategy_contents)
	_label(strategy_contents,t("forecast"),20,true)
	_label(strategy_contents,"%s: %d кр.     %s: %d кр.     %s: %+d кр." % [t("income"),forecast["revenue"],t("expenses"),forecast["expenses"],t("net"),forecast["net"]],17)
	_label(strategy_contents,"%s %d%%   ·   %s %d%%   ·   %s %d%%" % [t("energy"),forecast["energy"],t("water"),forecast["water"],t("food"),forecast["food"]],16)
	if d["history"].size() >= 2:
		_label(strategy_contents,t("budget_graph"),15,true)
		var chart = preload("res://scripts/history_chart.gd").new()
		strategy_contents.add_child(chart)
		chart.set_history(d["history"])
	_separator(strategy_contents)
	_label(strategy_contents,_v08("ГОРОДСКОЙ СОВЕТ И ВЫБОРЫ","CITY COUNCIL & ELECTIONS","市政议会与选举"),20,true)
	var politics: Dictionary = d.get("politics",GameState.POLITICS.initial())
	var election_poll: int = GameState.POLITICS.current_poll(d)
	_label(strategy_contents,_v08("Поддержка по опросам","Support in polls","民意支持率") + ": %d%%  ·  " % election_poll + _v08("Мандат","Mandate","施政授权") + ": %d%%" % int(politics["mandate"]),17,true)
	_label(strategy_contents,_v08("До выборов: ","Turns until election: ","距离选举回合：") + str(GameState.POLITICS.election_in(int(d["turn"]))),15)
	for group in GameState.POLITICS.GROUPS:
		var group_name: String = str(GameState.POLITICS.LABELS[group].get(GameState.locale,group))
		_label(strategy_contents,"%s: %d%%" % [group_name,int(politics["support"][group])],15)
	var last_ballot: Dictionary = politics.get("last_ballot",{})
	if not last_ballot.is_empty():
		var ballot_result: String = _v08("Мандат подтверждён","Mandate renewed","成功连任") if bool(last_ballot["won"]) else _v08("Поддержка утрачена","Mandate lost","授权未获通过")
		_label(strategy_contents,_v08("Последние выборы · ход ","Last election · turn ","上次选举 · 回合 ") + str(last_ballot["turn"]) + " · %d%% · " % int(last_ballot["share"]) + ballot_result,15)
	_label(strategy_contents,_v08("ОДНО ОБЩЕСТВЕННОЕ РЕШЕНИЕ ЗА ХОД", "ONE CIVIC MEASURE PER TURN", "每回合限一项公共政策"),14,true)
	for measure in GameState.POLITICS.MEASURE_ORDER:
		var definition: Dictionary = GameState.POLITICS.MEASURES[measure]
		var name_label: String = str(definition["title"].get(GameState.locale,definition["title"]["ru"]))
		var price: String = "  ·  %d кр." % int(definition["treasury"])
		if int(definition["materials"]) > 0: price += " · %d " % int(definition["materials"]) + t("materials")
		if int(definition["goods"]) > 0: price += " · %d " % int(definition["goods"]) + t("goods")
		var support_label: String = ""
		for group in definition["support"]:
			support_label += "  +%d%% %s" % [int(definition["support"][group]),str(GameState.POLITICS.LABELS[group].get(GameState.locale,group))]
		_button(strategy_contents,name_label + price + support_label,Callable(self,"_do_council_measure").bind(measure),not GameState.POLITICS.can_enact(d,measure))
	_separator(strategy_contents)
	_label(strategy_contents,_v08("КАРЬЕРА И НАВЫКИ", "CAREERS AND SKILLS", "职业与技能"),20,true)
	for track in GameState.CAREER.TRACKS:
		var xp: int = int(d.get("career_xp",{}).get(track,0))
		var rank: int = GameState.CAREER.level(xp)
		var next: int = GameState.CAREER.next_level_xp(xp)
		var career_label: String = str(GameState.CAREER.LABELS[track].get(GameState.locale,track))
		_label(strategy_contents,"%s  ·  Lv.%d  ·  %d XP%s" % [career_label,rank,xp,(" / %d" % next) if next >= 0 else "  ✓"],15)
	_separator(strategy_contents)
	_label(strategy_contents,t("economy"),20,true)
	var freight: float = float(forecast.get("freight_efficiency",1.0))
	_label(strategy_contents,_v08("ЛОГИСТИКА И ДОРОГИ", "TRANSPORT & ROAD REPAIRS", "物流与道路维护") + "  ·  %d%%" % roundi(freight*100.0),19,true)
	_label(strategy_contents,_v08("Состояние дорожной сети", "Road network condition", "道路状况") + "  %d/100  ·  %d" % [int(d.get("road_quality",75)),int(d.get("roads_repaired_total",0))],15)
	var maintenance_available: bool = int(d.get("road_quality",75)) < 100 and int(d["actions_left"]) > 0 and int(d["treasury"]) >= 190 and int(d["inventories"].get("materials",0)) >= 8
	_button(strategy_contents,_v08("ПРОФИЛАКТИКА ДОРОГ · 190 кр. / 8 материалов", "ROAD MAINTENANCE · 190 кр. / 8 materials", "道路维护 · 190 кр. / 8 材料"),Callable(self,"_do_road_maintenance"),not maintenance_available)
	for blocked in GameState.MOBILITY.active_incidents(d):
		var road_id: String = str(blocked["id"])
		var road_name: String = str(blocked.get(GameState.locale,blocked["ru"]))
		var can_repair: bool = int(d["actions_left"]) > 0 and int(d["treasury"]) >= 120 and int(d["inventories"].get("materials",0)) >= 6
		_button(strategy_contents,road_name + "  ·  " + _v08("ОТКРЫТЬ · 120 кр. / 6 материалов", "REOPEN · 120 кр. / 6 materials", "修复 · 120 кр. / 6 材料"),Callable(self,"_do_road_repair").bind(road_id),not can_repair)
	var active_case: Dictionary = GameState.CITY_CASES.current(d)
	if not active_case.is_empty():
		_separator(strategy_contents)
		_label(strategy_contents,_v08("СРОЧНОЕ РАЙОННОЕ СОБЫТИЕ", "ACTIVE DISTRICT INCIDENT", "紧急地区事件"),20,true)
		_label(strategy_contents,str(active_case["title"].get(GameState.locale,active_case["title"]["ru"])),17)
		_button(strategy_contents,_v08("ВЫБРАТЬ РЕШЕНИЕ", "CHOOSE RESPONSE", "选择应对方案"),Callable(self,"_open_case_from_cabinet"))
	var previous_cases: Array = d.get("case_history",[])
	if not previous_cases.is_empty():
		_label(strategy_contents,_v08("ХРОНИКА РАЙОННЫХ СОБЫТИЙ", "DISTRICT INCIDENT JOURNAL", "地区事件记录"),17,true)
		for n in range(previous_cases.size()-1,maxi(-1,previous_cases.size()-6),-1):
			var event: Dictionary = previous_cases[n]
			var story: Dictionary = GameState.CITY_CASES.by_id(str(event["id"]))
			var result: String = str(event["outcome"])
			var outcome: String = _v08("Вмешательство", "Funded response", "财政支持") if result == "invest" else (_v08("Помощь жителей", "Community response", "社区支持") if result == "mobilize" else _v08("Просрочено", "Expired", "已过期"))
			_label(strategy_contents,"%s · %s · %s %d" % [str(story.get("title",{}).get(GameState.locale,story.get("id","?"))),outcome,t("turn"),int(event["turn"])],14)
	_separator(strategy_contents)
	_label(strategy_contents,_v08("РАЙОННЫЕ ПОРУЧЕНИЯ", "NEIGHBORHOOD ERRANDS", "居民委托"),19,true)
	_label(strategy_contents,GameState.NEIGHBORHOOD.goal_text(d,GameState.locale),15)
	_label(strategy_contents,_v08("Выполнено: ","Completed: ","完成数量：") + str(d.get("neighborhood_completed",0)),15)
	for record in d.get("neighborhood_history",[]).slice(0,4):
		var job: Dictionary = GameState.NEIGHBORHOOD.by_id(str(record["id"]))
		var localized: String = str(job.get("title",{}).get(GameState.locale,str(record["id"])))
		var status: String = _v08("Выполнено","Completed","已完成") if record["status"] == "completed" else _v08("Просрочено","Expired","已逾期")
		_label(strategy_contents,"%s · %s · %d кр." % [localized,status,int(record["reward"])],14)
	if int(d.get("contracts_completed",0)) > 0:
		var quality_avg: int = roundi(float(d.get("cargo_quality_sum",100*int(d["contracts_completed"])))/float(d["contracts_completed"]))
		_label(strategy_contents,_v08("КАЧЕСТВО ДОСТАВОК", "DELIVERY QUALITY", "配送货物完好率") + "  ·  %d%%" % quality_avg,15)
	var stocks: Dictionary = d.get("inventories",{})
	_label(strategy_contents,"%s: %d   ·   %s: %d   ·   %s: %d" % [t("grain"),stocks.get("grain",0),t("materials"),stocks.get("materials",0),t("goods"),stocks.get("goods",0)],17)
	_label(strategy_contents,"%s: %d%%   ·   %s: %d" % [t("unemployment"),d.get("unemployment",0),t("shortages"),forecast.get("shortages",0)],17)
	var scores: Dictionary = forecast.get("district_scores",{})
	for region in GameState.DISTRICTS:
		_label(strategy_contents,"%s  ·  %s: %d/100" % [translated(DIST_NAMES[region]),t("district_wellbeing"),scores.get(region,0)],15)
	_separator(strategy_contents)
	_label(strategy_contents,_v08("ТОРГОВАЯ БИРЖА · 10 ЕД.","COMMODITY MARKET · 10 UNITS","商品交易所 · 10 单位"),20,true)
	_label(strategy_contents,_v08("Операций в этом такте:","Orders this turn:","本回合交易次数：") + " %d / 4" % int(d.get("market_orders",0)),15)
	for product in GameState.CITY_MARKET.GOODS:
		var buy_quote: Dictionary = GameState.market_quote(product,true)
		var sell_quote: Dictionary = GameState.market_quote(product,false)
		var trade_row := HBoxContainer.new()
		strategy_contents.add_child(trade_row)
		_label(trade_row,t(product)+"  ·  "+str(stocks.get(product,0)),16)
		_button(trade_row,_v08("Купить","Buy","买入")+"  %d кр." % int(buy_quote["total"]),Callable(self,"_do_trade").bind(product,true),not bool(buy_quote["allowed"]))
		_button(trade_row,_v08("Продать","Sell","卖出")+"  %d кр." % int(sell_quote["total"]),Callable(self,"_do_trade").bind(product,false),not bool(sell_quote["allowed"]))
	_separator(strategy_contents)
	_label(strategy_contents,_v08("АВТОПАРК · КУПИТЬ / ВЫБРАТЬ","GARAGE · BUY / SELECT","车库 · 购买 / 选择"),20,true)
	for vehicle_id in GameState.VEHICLE_CATALOG.ORDER:
		var profile: Dictionary = GameState.VEHICLE_CATALOG.VEHICLES[vehicle_id]
		var owned: bool = bool(d["vehicle_owned"].get(vehicle_id,false))
		var selected: bool = str(d["vehicle_selected"]) == vehicle_id
		var vehicle_label: String = str(profile.get(GameState.locale,profile["ru"]))
		if owned:
			var condition: Dictionary = d.get("garage_status",{}).get(vehicle_id,{})
			vehicle_label += "  ·  ⛽ %d%%  ·  ◆ %d%%" % [roundi(float(condition.get("fuel",100.0))),roundi(float(condition.get("health",100.0)))]
		if selected:
			vehicle_label += "  ✓"
		elif owned:
			vehicle_label += "  ·  " + _v08("ВЫБРАТЬ","SELECT","选择")
		else:
			vehicle_label += "  ·  %d кр.  /  ★ %d" % [int(profile["price"]),int(profile["reputation"])]
		_button(strategy_contents,vehicle_label,Callable(self,"_do_vehicle").bind(vehicle_id),selected or (not owned and (int(d["wallet"]) < int(profile["price"]) or int(d["reputation"]) < int(profile["reputation"]))))
	_separator(strategy_contents)
	_label(strategy_contents,t("district"),20,true)
	var district_row := HBoxContainer.new()
	strategy_contents.add_child(district_row)
	for id in GameState.DISTRICTS:
		var name_text := translated(DIST_NAMES[id])
		_button(district_row,("◆ " if d["selected"] == id else "") + name_text,Callable(self,"_select_district").bind(id))
	_label(strategy_contents,t("development"),20,true)
	for id in GameState.BUILDING_ORDER:
		if GameState.BUILDINGS[id]["district"] != d["selected"]: continue
		var level: int = d["buildings"][id]
		var price: int = GameState.get_build_cost(id)
		var desc := "%s   Lv. %d/4   ·   %d кр." % [translated(BUILDS[id]),level,price]
		_button(strategy_contents,desc,Callable(self,"_do_build").bind(id),level>=4 or d["treasury"]<price or d["actions_left"]<1)
	_separator(strategy_contents)
	_label(strategy_contents,_v08("ГОРОДСКИЕ ИНИЦИАТИВЫ · СРОК / РЕСУРСЫ", "CITY INITIATIVES · TIME / RESOURCES", "城市发展项目 · 工期与资源"),20,true)
	for project_id in GameState.INITIATIVES.ORDER:
		var project: Dictionary = GameState.INITIATIVES.PROJECTS[project_id]
		if str(project["district"]) != str(d["selected"]):
			continue
		var title_text: String = str(project.get(GameState.locale,project["ru"]))
		if d.get("projects_done",[]).has(project_id):
			_label(strategy_contents,title_text + "  ✓",16)
		elif d.get("projects_active",{}).has(project_id):
			var remaining: int = int(d["projects_active"][project_id]["remaining"])
			_label(strategy_contents,title_text + "  ·  " + str(remaining) + " " + _v08("тактов", "turns", "回合"),16)
		else:
			var detail: String = "%s  ·  %d кр.  ·  %d M / %d G  ·  %d t" % [title_text,int(project["cost"]),int(project["materials"]),int(project["goods"]),int(project["turns"])]
			_button(strategy_contents,detail,Callable(self,"_do_initiative").bind(project_id),not GameState.INITIATIVES.can_start(d,project_id))
	_separator(strategy_contents)
	_label(strategy_contents,t("research"),20,true)
	var research_grid := GridContainer.new()
	research_grid.columns = 2
	strategy_contents.add_child(research_grid)
	for id in GameState.RESEARCH_ORDER:
		var tech: Dictionary = GameState.TECH[id]
		var checked: bool = d["technologies"][id]
		var desc := translated(TECH_NAMES[id]) + ("  ✓" if checked else "  %d⚛ / %d кр." % [tech["science"],tech["cost"]])
		var available: bool = not checked and d["science"] >= tech["science"] and d["treasury"] >= tech["cost"] and d["actions_left"] > 0
		for dep in tech["requires"]:
			available = available and d["technologies"][dep]
		_button(research_grid,desc,Callable(self,"_do_research").bind(id),not available)
	_separator(strategy_contents)
	_label(strategy_contents,t("policy"),20,true)
	var taxes := HBoxContainer.new()
	strategy_contents.add_child(taxes)
	_button(taxes,t("tax_minus"),Callable(self,"_shift_tax").bind(-2),d["tax"]<2)
	_label(taxes,"%s %d%%" % [t("tax"),d["tax"]],18)
	_button(taxes,t("tax_plus"),Callable(self,"_shift_tax").bind(2),d["tax"]>38)
	var policies := HBoxContainer.new()
	strategy_contents.add_child(policies)
	for course in ["balance","industry","energy","welfare"]:
		var localization: String = "energy_policy" if course == "energy" else str(course)
		_button(policies,("◈ " if d["course"] == course else "")+t(localization),Callable(self,"_choose_policy").bind(course))
	_separator(strategy_contents)
	_label(strategy_contents,t("business"),20,true)
	for id in GameState.BUSINESSES:
		var company: Dictionary = GameState.BUSINESSES[id]
		var owned: bool = d["businesses"][id]
		var desc := "%s  ·  %d кр. / %s  ·  %d кр." % [translated(BUSINESS_NAMES[id]),company["income"],t("turn"),company["cost"]]
		_button(strategy_contents,desc + ("  ✓ " + t("owned") if owned else ""),Callable(self,"_buy_business").bind(id),owned or d["wallet"]<company["cost"])
	_separator(strategy_contents)
	_label(strategy_contents,estate_text("title"),20,true)
	var estate_result: Dictionary = forecast["real_estate"]
	_label(strategy_contents,"%s: %+d кр.  ·  %s: %d%%" % [estate_text("rent"),estate_result["net"],estate_text("occupancy"),estate_result["mean_occupancy"]],16)
	for property_id in GameState.REAL_ESTATE.PROPERTY_IDS:
		var level: int = int(d["properties"].get(property_id,0))
		var cost: int = GameState.property_cost(property_id)
		var label_text: String = "%s   ·   %s %d/3" % [property_name(property_id),estate_text("level"),level]
		if level < GameState.REAL_ESTATE.MAX_LEVEL:
			label_text += "   ·   %s %d кр." % [estate_text("acquire") if level == 0 else estate_text("renovate"),cost]
		else:
			label_text += "   ✓ " + t("max")
		_button(strategy_contents,label_text,Callable(self,"_property_transaction").bind(property_id),cost < 0 or int(d["wallet"]) < cost)
	if d["incident"] != "":
		_separator(strategy_contents)
		_label(strategy_contents,t("crisis")+": "+incident_name(str(d["incident"])),20,true)
		_button(strategy_contents,t("aid"),Callable(self,"_resolve_incident").bind(true),d["treasury"]<175)
		_button(strategy_contents,t("ignore"),Callable(self,"_resolve_incident").bind(false))
	_separator(strategy_contents)
	_button(strategy_contents,t("start_turn"),Callable(self,"_next_turn"))
	var file_row := HBoxContainer.new()
	strategy_contents.add_child(file_row)
	_button(file_row,t("save"),Callable(self,"_save"))
	_button(file_row,t("load"),Callable(self,"_load"))
	_button(file_row,t("import"),Callable(self,"_show_import"))
	_button(file_row,t("reset"),Callable(self,"_show_reset"))

func _pay_private_debt() -> void:
	if GameState.repay_private_debt(250):
		announce(t("success"))
	else:
		announce(t("need"))

func _invest() -> void:
	if GameState.transfer_to_city(250):
		MissionManager.register_action("transfer")
		announce(t("success"))
	else:
		announce(t("need"))

func _select_district(id: String) -> void:
	GameState.set_district(id)

func _do_build(id: String) -> void:
	if GameState.build(id):
		MissionManager.register_action("build")
		announce(t("success"))
	else:
		announce(t("need"))

func _do_road_repair(road_id: String) -> void:
	if GameState.repair_road(road_id):
		MissionManager.register_action("road_repair")
	else:
		announce(t("need"))

func _do_road_maintenance() -> void:
	if GameState.maintain_roads():
		MissionManager.register_action("road_maintenance")
	else:
		announce(t("need"))

func _do_council_measure(id: String) -> void:
	if GameState.enact_council_measure(id):
		MissionManager.register_action("council_measure")
		announce(_v08("Решение городского совета принято","Council measure enacted","议会政策已通过"))
	else:
		announce(t("need"))

func _do_initiative(id: String) -> void:
	if GameState.start_initiative(id):
		MissionManager.register_action("initiative_start")
		announce(t("success"))
	else:
		announce(t("need"))

func _do_research(id: String) -> void:
	if GameState.research(id):
		MissionManager.register_action("research")
		announce(t("success"))
	else: announce(t("need"))

func _shift_tax(delta: int) -> void:
	GameState.set_tax(int(GameState.data["tax"])+delta)

func _choose_policy(course: String) -> void:
	if GameState.set_course(course):
		MissionManager.register_action("set_course")

func _buy_business(id: String) -> void:
	if GameState.buy_business(id):
		MissionManager.register_action("business")
		announce(t("bought"))
	else:
		announce(t("need"))

func _property_transaction(id: String) -> void:
	var level: int = int(GameState.data["properties"].get(id,0))
	var done: bool = GameState.buy_property(id) if level == 0 else GameState.renovate_property(id)
	if done:
		MissionManager.register_action("property" if level == 0 else "renovation")
		announce(t("success"))
	else:
		announce(t("need"))

func _resolve_incident(pay_for_help: bool) -> void:
	if GameState.resolve_incident(pay_for_help):
		MissionManager.register_action("resolve_incident")
	else:
		announce(t("need"))

func _next_turn() -> void:
	if GameState.advance_turn():
		MissionManager.register_action("advance_turn")
	else:
		announce(_v08("Разрешите текущий кризис перед ходом","Resolve the active crisis before advancing","请在下一回合前解决当前危机"))

func _save() -> void:
	wants_save.emit()

func _load() -> void:
	wants_load.emit()

func _show_import() -> void:
	importer.popup_centered_ratio(0.65)

func _import_v3(path: String) -> void:
	var file := FileAccess.open(path,FileAccess.READ)
	if file == null or file.get_length() > 300000:
		announce(t("import_failed"))
		return
	var payload: Variant = JSON.parse_string(file.get_as_text())
	if payload is Dictionary and GameState.import_v3_payload(payload):
		announce(t("imported"))
	else:
		announce(t("import_failed"))

func _show_reset() -> void:
	confirm_reset.dialog_text = t("restart_confirm")
	confirm_reset.popup_centered()

func _confirm_new_game() -> void:
	wants_reset.emit()

func _make_pause_menu() -> void:
	pause_overlay = ColorRect.new()
	pause_overlay.name = "PauseOverlay"
	pause_overlay.color = Color(0.015,0.032,0.065,0.95)
	pause_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	pause_overlay.visible = false
	root.add_child(pause_overlay)
	var panel := PanelContainer.new()
	pause_panel = panel
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -390
	panel.offset_right = 390
	panel.offset_top = -340
	panel.offset_bottom = 340
	panel.add_theme_stylebox_override("panel",_style(Color("081522"),Color("b99156"),14))
	pause_overlay.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",14)
	panel.add_child(column)
	pause_heading = _label(column,"OSGARD Ω",29,true)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	pause_contents = VBoxContainer.new()
	pause_contents.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pause_contents.add_theme_constant_override("separation",10)
	scroll.add_child(pause_contents)

func is_pause_open() -> bool:
	return pause_open

func toggle_pause() -> void:
	if pause_open:
		pause_open = false
		pause_overlay.visible = false
		settings_page = false
		awaiting_binding = ""
		get_tree().paused = false
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE if open or DisplayServer.is_touchscreen_available() else Input.MOUSE_MODE_CAPTURED)
		return
	if open:
		toggle_strategy()
	pause_open = true
	settings_page = false
	pause_overlay.visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().paused = true
	_redraw_pause()

func _input(event: InputEvent) -> void:
	if is_citizen_open() or is_city_case_open():
		if event.is_action_pressed("pause_game") and not (event is InputEventKey and (event as InputEventKey).echo):
			if is_city_case_open(): city_case_popup.hide()
			else: citizen_popup.hide()
			get_viewport().set_input_as_handled()
		return
	if not pause_open:
		if event.is_action_pressed("pause_game") and not (event is InputEventKey and (event as InputEventKey).echo):
			toggle_pause()
			get_viewport().set_input_as_handled()
		return
	if awaiting_binding != "":
		if event is InputEventKey:
			var keyboard := event as InputEventKey
			if not keyboard.pressed or keyboard.echo: return
			if keyboard.physical_keycode == KEY_ESCAPE:
				awaiting_binding = ""
				status_binding = t("bind_cancel")
			elif GameSettings.rebind(awaiting_binding,int(keyboard.physical_keycode)):
				awaiting_binding = ""
				status_binding = t("bind_saved")
			else:
				status_binding = t("bind_conflict")
			_redraw_pause()
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("pause_game") and not (event is InputEventKey and (event as InputEventKey).echo):
		if settings_page:
			settings_page = false
			_redraw_pause()
		else:
			toggle_pause()
		get_viewport().set_input_as_handled()

func _clear_pause() -> void:
	for child in pause_contents.get_children():
		pause_contents.remove_child(child)
		child.queue_free()

func _redraw_pause() -> void:
	if pause_contents == null: return
	_clear_pause()
	pause_heading.text = t("preferences") if settings_page else t("paused")
	if not settings_page:
		_label(pause_contents,t("pause_description"),19)
		_separator(pause_contents)
		_button(pause_contents,t("resume"),Callable(self,"toggle_pause"))
		_button(pause_contents,t("preferences"),Callable(self,"_open_settings"))
		_button(pause_contents,t("save"),Callable(self,"_save_from_pause"))
		_button(pause_contents,t("load"),Callable(self,"_load_from_pause"))
		if status_binding != "":
			_label(pause_contents,status_binding,16,true)
		_label(pause_contents,t("pause_help"),16)
		return
	_button(pause_contents,t("back"),Callable(self,"_back_from_settings"))
	_label(pause_contents,t("volume"),18,true)
	var volume_slider := HSlider.new()
	volume_slider.min_value = 0.0
	volume_slider.max_value = 1.0
	volume_slider.step = 0.05
	volume_slider.value = GameSettings.volume
	volume_slider.custom_minimum_size = Vector2(560,36)
	volume_slider.value_changed.connect(Callable(GameSettings,"set_volume"))
	pause_contents.add_child(volume_slider)
	_label(pause_contents,t("mouse_sensitivity"),18,true)
	var sensitivity_slider := HSlider.new()
	sensitivity_slider.min_value = 0.001
	sensitivity_slider.max_value = 0.012
	sensitivity_slider.step = 0.001
	sensitivity_slider.value = GameSettings.mouse_sensitivity
	sensitivity_slider.custom_minimum_size.y = 36
	sensitivity_slider.value_changed.connect(Callable(GameSettings,"set_mouse_sensitivity"))
	pause_contents.add_child(sensitivity_slider)
	_label(pause_contents,t("visual_quality"),18,true)
	var quality := OptionButton.new()
	for mode in GameSettings.GRAPHICS_MODES:
		quality.add_item(t(mode))
	quality.select(GameSettings.GRAPHICS_MODES.find(GameSettings.graphics))
	quality.item_selected.connect(Callable(self,"_on_quality_changed"))
	pause_contents.add_child(quality)
	var motion := CheckButton.new()
	motion.text = t("reduced_motion")
	motion.button_pressed = GameSettings.reduced_motion
	motion.toggled.connect(Callable(self,"_on_motion_changed"))
	pause_contents.add_child(motion)
	_label(pause_contents,t("language_label"),18,true)
	var language := OptionButton.new()
	for name in ["Русский", "English", "中文"]:
		language.add_item(name)
	language.select(["ru","en","zh"].find(GameState.locale))
	language.item_selected.connect(Callable(self,"_on_language_changed"))
	pause_contents.add_child(language)
	_separator(pause_contents)
	_label(pause_contents,t("key_bindings"),21,true)
	_label(pause_contents,t("key_instructions"),15)
	for action in EDITABLE_ACTIONS:
		var row := HBoxContainer.new()
		pause_contents.add_child(row)
		var caption := _label(row,t("action_"+action),16)
		caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_button(row,GameSettings.binding_name(action),Callable(self,"_start_rebind").bind(action))
	if status_binding != "":
		_label(pause_contents,status_binding,15,true)
	_button(pause_contents,t("reset_keys"),Callable(self,"_reset_keys"))
	_button(pause_contents,t("back"),Callable(self,"_back_from_settings"))

func _open_settings() -> void:
	settings_page = true
	_redraw_pause()

func _back_from_settings() -> void:
	settings_page = false
	awaiting_binding = ""
	_redraw_pause()

func _start_rebind(action: String) -> void:
	awaiting_binding = action
	status_binding = t("press_key") + " — " + t("action_"+action)
	_redraw_pause()

func _reset_keys() -> void:
	GameSettings.reset_bindings()
	status_binding = t("keys_reset")
	_redraw_pause()

func _on_quality_changed(selected: int) -> void:
	GameSettings.set_graphics(GameSettings.GRAPHICS_MODES[selected])

func _on_motion_changed(enabled: bool) -> void:
	GameSettings.set_reduced_motion(enabled)

func _on_language_changed(selected: int) -> void:
	GameSettings.set_locale(["ru","en","zh"][selected])
	_refresh()
	_redraw_pause()

func _save_from_pause() -> void:
	_save()
	status_binding = t("saved") if GameState.last_save_ok else t("save_failed")
	_redraw_pause()

func _load_from_pause() -> void:
	_load()
	status_binding = (t("save_recovered") if GameState.last_load_source != "primary" else t("loaded")) if GameState.last_load_source != "" else t("load_failed")
	_redraw_pause()

# HORIZON R7 - compact HUD is a screen geometry adaptation, never a gameplay state.
# Anchor restoration is explicit so rotating a phone or resizing desktop is safe.
func _set_panel_frame(panel: Control, frame: Rect2, left: float, right: float, top: float, bottom: float) -> void:
	if panel == null: return
	panel.anchor_left = left
	panel.anchor_right = right
	panel.anchor_top = top
	panel.anchor_bottom = bottom
	panel.offset_left = frame.position.x
	panel.offset_top = frame.position.y
	panel.offset_right = frame.end.x
	panel.offset_bottom = frame.end.y

func _apply_responsive_layout() -> void:
	if header_panel == null or pause_panel == null or strategy_window == null: return
	var screen: Vector2 = get_viewport().get_visible_rect().size
	if screen.x < 1.0 or screen.y < 1.0: return
	var frames: Dictionary = HORIZON_LAYOUT.compute(screen)
	compact_hud = bool(frames.get("compact",false))
	if compact_hud:
		_set_panel_frame(header_panel,frames["header"],0,0,0,0)
		_set_panel_frame(objective_panel,frames["objective"],0,0,0,0)
		_set_panel_frame(speed_panel,frames["speed"],0,0,0,0)
		_set_panel_frame(map_panel,frames["map"],0,0,0,0)
		_set_panel_frame(controls_panel,frames["help"],0,0,0,0)
		_set_panel_frame(journal_panel,frames["journal"],0,0,0,0)
		_set_panel_frame(diagnostic_panel,frames["diagnostics"],0,0,0,0)
		_set_panel_frame(toast_panel,frames["toast"],0,0,0,0)
		var modal: Rect2 = frames["modal"]
		var panel_frame := Rect2(modal.position-screen*0.5,modal.size)
		_set_panel_frame(strategy_window,panel_frame,0.5,0.5,0.5,0.5)
		_set_panel_frame(pause_panel,panel_frame,0.5,0.5,0.5,0.5)
		map.custom_minimum_size = Vector2(106,106)
		if not map_override: map_panel.visible = bool(frames["map_default"])
		header_value.add_theme_font_size_override("font_size",15)
		meters_label.add_theme_font_size_override("font_size",12)
		mission_label.add_theme_font_size_override("font_size",16)
		mission_distance_label.add_theme_font_size_override("font_size",12)
		speed_label.add_theme_font_size_override("font_size",13)
		hint_label.add_theme_font_size_override("font_size",12)
	else:
		_set_panel_frame(header_panel,Rect2(24,20,420,86),0,0,0,0)
		_set_panel_frame(objective_panel,Rect2(-476,20,452,150),1,1,0,0)
		_set_panel_frame(speed_panel,Rect2(-360,-145,336,122),1,1,1,1)
		_set_panel_frame(map_panel,Rect2(24,-276,248,252),0,0,1,1)
		_set_panel_frame(controls_panel,Rect2(290,-92,-672,68),0,1,1,1)
		_set_panel_frame(journal_panel,Rect2(-476,186,452,440),1,1,0,0)
		_set_panel_frame(diagnostic_panel,Rect2(24,116,360,105),0,0,0,0)
		_set_panel_frame(toast_panel,Rect2(-252,24,504,64),0.5,0.5,0,0)
		_set_panel_frame(strategy_window,Rect2(-450,-365,900,730),0.5,0.5,0.5,0.5)
		_set_panel_frame(pause_panel,Rect2(-390,-340,780,680),0.5,0.5,0.5,0.5)
		map.custom_minimum_size = Vector2(208,208)
		if not map_override: map_panel.visible = true
		header_value.add_theme_font_size_override("font_size",23)
		meters_label.add_theme_font_size_override("font_size",16)
		mission_label.add_theme_font_size_override("font_size",22)
		mission_distance_label.add_theme_font_size_override("font_size",16)
		speed_label.add_theme_font_size_override("font_size",20)
		hint_label.add_theme_font_size_override("font_size",17)
	_refresh()

func toggle_map() -> void:
	if map_panel == null: return
	map_override = true
	map_panel.visible = not map_panel.visible
