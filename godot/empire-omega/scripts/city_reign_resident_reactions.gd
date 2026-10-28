extends RefCounted
## CITY REIGN E01: real citizens have distinct opinions of the public promise.
## Narrative dialogue is a *fictional resident voice*, not a new public KPI.
## It reads live saved construction/finished city projects and district quality.
## No rewards, trust changes, hidden XP or new mission/save keys.
const CIVIC = preload("res://scripts/civic_initiatives.gd")
const DISTRICTS = CIVIC.DISTRICTS

static func _loc(lang: String, ru: String, en: String, zh: String) -> String:
	if lang == "en": return en
	if lang == "zh": return zh
	return ru

static func feedback(state: Dictionary, district: String, lang: String) -> Dictionary:
	if not DISTRICTS.has(district):
		return {}
	var project_id: String = ""
	if district == "forum":
		project_id = "open_records"
	elif district == "housing":
		project_id = "safe_crossings"
	var done: Array = state.get("projects_done",[])
	var active: Dictionary = state.get("projects_active",{})
	var title: String = _loc(lang,"ГОЛОС РАЙОНА","VOICE OF THE DISTRICT","城区声音")
	var comment: String = ""
	var phase: String = "ordinary"
	if project_id != "" and done.has(project_id):
		phase = "fulfilled"
		comment = _loc(lang,
			"Мы видим результат: " + str(CIVIC.PROJECTS[project_id]["ru"]) + ". Теперь за решениями можно следить на самих улицах.",
			"We can see the outcome: " + str(CIVIC.PROJECTS[project_id]["en"]) + ". City choices are changing what stands on our streets.",
			"我们看到了成果：" + str(CIVIC.PROJECTS[project_id]["zh"]) + "。城市决策正在真正改变街道。")
	elif project_id != "" and active.has(project_id):
		phase = "building"
		var remaining: int = int(active[project_id].get("remaining",0))
		comment = _loc(lang,
			"Стройка началась. Ещё " + str(remaining) + " тактов, и станет ясно, исполнит ли администрация своё обещание.",
			"Work has started. " + str(remaining) + " city turns remain before we can judge this promise.",
			"工程已经开始，还剩 " + str(remaining) + " 回合，我们才能判断承诺是否兑现。")
	elif project_id == "open_records":
		phase = "pending"
		comment = _loc(lang,
			"Горожане хотят знать, куда уходят средства. Без открытого бюджета обещания мало чего стоят.",
			"People want to know where public money goes. Promises mean little without an open budget.",
			"市民想知道公共资金的去向。没有公开预算，承诺很难让人信服。")
	elif project_id == "safe_crossings":
		phase = "pending"
		comment = _loc(lang,
			"В жилом квартале нужны переходы. Экономический рост должен делать улицы удобнее для пешеходов.",
			"Residential streets need safe crossings. Economic growth should make this a better place to walk.",
			"住宅区需要安全过街设施。经济增长应该让步行更安全。")
	else:
		var score: int = int(state.get("district_scores",{}).get(district,50))
		if score < 50:
			comment = _loc(lang,
				"Наш район отстаёт. По текущим городским показателям его состояние всего " + str(score) + "/100.",
				"Our district is falling behind. The city's current quality index here is just " + str(score) + "/100.",
				"我们城区发展落后。当前城市质量指数只有 " + str(score) + "/100。")
		else:
			comment = _loc(lang,
				"Город развивается, но нам важно, чтобы изменения дошли до каждого района.",
				"The city is developing, but we need the benefits to reach every district.",
				"城市正在发展，但每个城区都应该享受到变化的好处。")
	if str(state.get("incident","")) != "":
		comment += "\n" + _loc(lang,
			"Сейчас жителей тревожит городской кризис.",
			"The current city emergency worries residents.",
			"当前城市危机令居民担忧。")
	return {"title":title,"comment":comment,"phase":phase,
		"district":district,"project":project_id,
		"turn":int(state.get("turn",1))}
