extends RefCounted
## CITY REIGN Episode 01: THE FIRST PROMISE.
## A *playable* branching civic introduction built exclusively from real
## existing mission progress and the real eight-initiative city simulation.
## No parallel quest flags, invented rewards, new save keys or duplicated cash.
const INITIATIVES = preload("res://scripts/civic_initiatives.gd")
const IMPACT = preload("res://scripts/city_reign_impact.gd")
const CHOICES = ["open_records","safe_crossings"]

static func _loc(lang: String, ru: String, en: String, zh: String) -> String:
	if lang == "en": return en
	if lang == "zh": return zh
	return ru

static func choice(state: Dictionary, definitions: Dictionary, id: String, lang: String) -> Dictionary:
	if not CHOICES.has(id) or not INITIATIVES.PROJECTS.has(id):
		return {}
	var project: Dictionary = INITIATIVES.PROJECTS[id]
	var done: Array = state.get("projects_done",[])
	var active: Dictionary = state.get("projects_active",{})
	var waiting: int = int(active[id].get("remaining",0)) if active.has(id) else 0
	return {
		"id":id,
		"title":str(project.get(lang,project["ru"])),
		"district":str(project["district"]),
		"cost":int(project["cost"]),
		"materials":int(project["materials"]),
		"goods":int(project["goods"]),
		"turns":int(project["turns"]),
		"jobs":int(project["jobs"]),
		"completed":done.has(id),
		"active":active.has(id),
		"remaining":waiting,
		"allowed":INITIATIVES.can_start(state,id),
		"forecast":IMPACT.preview(state,definitions,id)
	}

static func phase(state: Dictionary) -> Dictionary:
	# Phase is reconstructed on load; prior save files are still valid.
	var done: Array = state.get("projects_done",[])
	var active: Dictionary = state.get("projects_active",{})
	for project_id in done:
		if CHOICES.has(str(project_id)):
			return {"id":"delivered","chosen":str(project_id),"remaining":0}
	for project_id in CHOICES:
		if active.has(project_id):
			return {"id":"building","chosen":project_id,
				"remaining":int(active[project_id].get("remaining",0))}
	var mission: int = int(state.get("mission",0))
	if mission < 2:
		return {"id":"arrival","chosen":"","remaining":0}
	if mission < 4:
		return {"id":"capital","chosen":"","remaining":0}
	return {"id":"council","chosen":"","remaining":0}

static func briefing(state: Dictionary, definitions: Dictionary, lang: String) -> Dictionary:
	var progress: Dictionary = phase(state)
	var phase_id: String = str(progress["id"])
	var heading: String = _loc(lang,
		"ЭПИЗОД 01 · ПЕРВОЕ ОБЕЩАНИЕ",
		"EPISODE 01 · THE FIRST PROMISE",
		"第一章 · 首次承诺")
	var description: String = ""
	var instructions: String = ""
	match phase_id:
		"arrival":
			description = _loc(lang,
				"У города нет доверия к новичкам. Сядьте в машину и доставьте первый заказ в торговый квартал.",
				"The city does not trust newcomers. Enter the car and make the first market delivery.",
				"城市尚未信任你。驾驶汽车，完成前往市场的第一笔配送。")
			instructions = _loc(lang,"E — машина · F — доставка · H — журнал",
				"E — car · F — delivery · H — journal","E — 上车 · F — 配送 · H — 日志")
		"capital":
			description = _loc(lang,
				"Вы показали себя на улицах. Теперь купите первую компанию и проведите городской такт. Вскоре придётся выбирать, куда направить бюджет.",
				"You proved yourself in the streets. Acquire your first company and advance the city turn. A public budget choice follows.",
				"你已在街头证明自己。收购第一家公司并推进城市回合，随后决定公共预算的用途。")
			instructions = _loc(lang,"B — бизнес · Tab — управление",
				"B — business · Tab — governance","B — 企业 · Tab — 治理")
		"council":
			description = _loc(lang,
				"Два реальных приоритета: открытый бюджет или безопасные переходы. Каждый требует денег и материалов; оба меняют город. Выберите первый проект в командном центре.",
				"Two real priorities: transparent budgets or safe crossings. Both spend money and materials and change the city. Choose your first project in governance.",
				"两项真实优先事项：公开预算或安全人行横道。两者都会消耗资金材料并改变城市。请在治理中心选择首个项目。")
			instructions = _loc(lang,"Tab — сравнить и инвестировать",
				"Tab — compare and invest","Tab — 对比并投资")
		"building":
			var project: Dictionary = choice(state,definitions,str(progress["chosen"]),lang)
			description = _loc(lang,
				"Работа уже идёт: " + str(project["title"]) + ". На улице появилась стройплощадка. Ещё " + str(progress["remaining"]) + " городских тактов до завершения.",
				"Construction is under way: " + str(project["title"]) + ". The site exists in the 3D street. " + str(progress["remaining"]) + " city turns remain.",
				"工程已启动：" + str(project["title"]) + "。街道中已出现施工场地，剩余 " + str(progress["remaining"]) + " 回合。")
			instructions = _loc(lang,"Tab — следующий такт · осмотрите объект",
				"Tab — advance a turn · visit the site","Tab — 推进回合 · 实地查看")
		"delivered":
			var project: Dictionary = INITIATIVES.PROJECTS[str(progress["chosen"])]
			var title: String = str(project.get(lang,project["ru"]))
			description = _loc(lang,
				"Обещание выполнено: " + title + ". Готовый 3D-объект существует в районе; экономическая модель учитывает его " + str(project["jobs"]) + " рабочих мест. Город продолжает меняться.",
				"Promise delivered: " + title + ". A finished 3D facility now stands in the district; the economic simulation accounts for " + str(project["jobs"]) + " new jobs. The city keeps changing.",
				"承诺已兑现：" + title + "。竣工设施已出现在城区，经济模拟计入新增 " + str(project["jobs"]) + " 个岗位。城市仍在发展。")
			instructions = _loc(lang,"Свободное развитие · остальные проекты доступны",
				"Free development · other investments remain open","自由发展 · 其他投资仍可进行")
	return {"heading":heading,"body":description,"hint":instructions,
		"phase":phase_id,"chosen":str(progress["chosen"]),
		"remaining":int(progress["remaining"]),"mission":int(state.get("mission",0)),
		"turn":int(state.get("turn",1))}

static func button_text(option: Dictionary, lang: String) -> String:
	if option.is_empty():
		return ""
	var header: String = _loc(lang,"ИНВЕСТИРОВАТЬ","INVEST","投资")
	return "%s · %s · %d кр. / %d M / %d G / %d t" % [
		header,str(option["title"]),int(option["cost"]),
		int(option["materials"]),int(option["goods"]),int(option["turns"])]
