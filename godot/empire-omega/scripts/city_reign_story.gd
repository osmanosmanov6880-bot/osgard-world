extends RefCounted
## CITY REIGN: first playable civic-power narrative, sourced ONLY from saves.
## Existing 40 mission IDs and transaction rules remain authoritative.
const DISTRICTS = ["forum","housing","lower","aqueduct"]
const NAMES = {
	"forum":{"ru":"Сенатский форум","en":"Senate Forum","zh":"议会广场"},
	"housing":{"ru":"Жилой квартал","en":"Residential Quarter","zh":"住宅区"},
	"lower":{"ru":"Нижний город","en":"Lower City","zh":"下城区"},
	"aqueduct":{"ru":"Акведуки","en":"Aqueducts","zh":"水道区"}
}

static func _loc(ru: String, en: String, zh: String, lang: String) -> String:
	return ru if lang == "ru" else (en if lang == "en" else zh)

static func briefing(state: Dictionary, lang: String) -> Dictionary:
	var stage: int = clampi(int(state.get("mission",0)),0,40)
	var act: int = 0 if stage < 6 else (1 if stage < 20 else (2 if stage < 40 else 3))
	var heading: String = ""
	var copy: String = ""
	match act:
		0:
			heading = _loc("АКТ I · ПЕРВОЕ ВЛИЯНИЕ","ACT I · FIRST INFLUENCE","第一幕 · 初获影响力",lang)
			copy = _loc(
				"Начни с улиц: освой машину, заработай первые деньги и добейся права принимать решения о бюджете города.",
				"Start on the street: master your car, earn your first money and gain a real say over the city's budget.",
				"从街头开始：驾驶车辆、赚取第一笔收入，并逐步获得城市预算决策权。",lang)
		1:
			heading = _loc("АКТ II · ЦЕНА РЕШЕНИЙ","ACT II · THE COST OF POWER","第二幕 · 权力的代价",lang)
			copy = _loc(
				"Каждая покупка и стройка меняет реальные доходы, ресурсы и занятость. Прибыль без устойчивого города не удержит доверие.",
				"Every acquisition and building changes real income, resources and employment. Profit alone cannot sustain civic trust.",
				"每笔收购与建设都会改变实际收入、资源和就业。仅靠利润无法维持市民信任。",lang)
		2:
			heading = _loc("АКТ III · ГОРОД ОТВЕЧАЕТ","ACT III · THE CITY RESPONDS","第三幕 · 城市回应",lang)
			copy = _loc(
				"Теперь решения проверяют кризисы, дороги, жители и службы. Восстанови связи между районами и оцени последствия.",
				"Crises, roads, residents and services now test your decisions. Reconnect districts and face the consequences.",
				"危机、道路、居民与公共服务正在检验你的决策。恢复城区联系并承担后果。",lang)
		_:
			heading = _loc("ЭПИЛОГ · НАСЛЕДИЕ","EPILOGUE · YOUR LEGACY","尾声 · 你的城市遗产",lang)
			copy = _loc(
				"Основная цепочка заданий завершена. У города по-прежнему есть ресурсы, конфликты и выборы — управляй им свободно.",
				"The main mission chain is complete. Your city still has resources, conflicts and elections: govern it freely.",
				"主线任务已完成。城市仍有资源、冲突和选举，现在由你自由治理。",lang)
	var scores: Dictionary = state.get("district_scores",{})
	var weakest: String = "forum"
	var weakest_score: int = 101
	for district in DISTRICTS:
		var score: int = clampi(int(scores.get(district,100)),0,100)
		if score < weakest_score:
			weakest = district
			weakest_score = score
	var stability: int = int(state.get("stability",0))
	var treasury: int = int(state.get("treasury",0))
	var worst_name: String = str(NAMES[weakest].get(lang,NAMES[weakest]["ru"]))
	var pulse: String = "%s %d/100   ·   %s %d   ·   %s %d/100" % [
		_loc("Стабильность","Stability","稳定度",lang),stability,
		_loc("Казна","Treasury","市政预算",lang),treasury,worst_name,weakest_score]
	var crisis: String = str(state.get("incident",""))
	if crisis != "":
		pulse += "  ·  " + _loc("АКТИВНЫЙ КРИЗИС","ACTIVE CRISIS","危机中",lang)
	return {"act":act,"heading":heading,"copy":copy,"pulse":pulse,
		"weakest":weakest,"weakest_score":weakest_score,"mission":stage}
