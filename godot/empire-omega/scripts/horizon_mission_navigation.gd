extends RefCounted
## R87: authoritative mission-aware guidance.
## Only mark a destination if the actual current task (or active side activity)
## has a concrete 3D location. Governance/garage/interior-choice actions do not
## borrow the courier waypoint and pretend it leads to the mission.
##
## Pure functions: never advance a quest, spend money or modify a save.

const WORLD_ACTIONS = [
	"enter_vehicle", "deliver", "contract_accept", "contract_deliver",
	"service_accept"
]

const CITY_ACTIONS = [
	"business", "build", "research", "property", "renovation", "transfer",
	"set_course", "resolve_incident", "advance_turn", "trade",
	"vehicle_buy", "vehicle_select", "initiative_start", "road_maintenance"
]

static func has_world_goal(action: String, trial_active: bool,
		contract_active: bool, neighborhood_active: bool,
		service_active: bool) -> bool:
	if trial_active or neighborhood_active or service_active or contract_active:
		return true
	return WORLD_ACTIONS.has(action)

static func hud_hint(action: String, locale: String = "ru", touch: bool = false) -> String:
	var lang: String = locale if locale in ["ru", "en", "zh"] else "ru"
	if CITY_ACTIONS.has(action):
		if touch:
			return _local(lang, "ДЕЙСТВИЕ В МЕНЮ «ГОРОД»",
				"OPEN THE CITY MENU", "打开城市菜单")
		return _local(lang, "ОТКРОЙТЕ КАБИНЕТ · TAB",
			"OPEN GOVERNANCE · TAB", "打开城市治理 · TAB")
	if action == "neighborhood_accept":
		return _local(lang, "ПОГОВОРИТЕ С ЖИТЕЛЕМ · J",
			"TALK TO A RESIDENT · J", "与居民交谈 · J") if not touch else _local(
				lang, "НАЙДИТЕ ЖИТЕЛЯ · ДЕЙСТВИЯ",
				"FIND A RESIDENT · ACTIONS", "寻找居民 · 互动")
	if action == "neighborhood_deliver":
		return _local(lang, "СНАЧАЛА ВОЗЬМИТЕ ПОРУЧЕНИЕ",
			"ACCEPT A RESIDENT ERRAND FIRST", "先接受居民委托")
	if action == "interior_enter":
		return _local(lang, "ИЩИТЕ ВХОД В ЗДАНИЕ · I",
			"FIND A BUILDING ENTRANCE · I", "寻找建筑入口 · I") if not touch else _local(
				lang, "ИЩИТЕ ВХОД · ДЕЙСТВИЯ",
				"FIND AN ENTRANCE · ACTIONS", "寻找入口 · 互动")
	if action == "road_repair":
		return _local(lang, "РЕМОНТ ДОРОГИ · ГОРОД / F",
			"REPAIR ROAD · CITY / F", "修复道路 · 城市 / F")
	if action == "service_complete":
		return _local(lang, "СНАЧАЛА ВОЗЬМИТЕ ВЫЗОВ",
			"ACCEPT A SERVICE CALL FIRST", "先接受公共服务任务")
	if action == "complete":
		return _local(lang, "СВОБОДНАЯ ИГРА · ВЫБЕРИТЕ ЦЕЛЬ",
			"FREE PLAY · CHOOSE YOUR GOAL", "自由模式 · 选择目标")
	return _local(lang, "ИЗУЧИТЕ ЗАДАНИЕ И ВЫБЕРИТЕ ДЕЙСТВИЕ",
		"REVIEW YOUR OBJECTIVE AND TAKE ACTION", "查看目标并选择操作")


static func _local(lang: String, ru: String, en: String, zh: String) -> String:
	if lang == "en": return en
	if lang == "zh": return zh
	return ru
