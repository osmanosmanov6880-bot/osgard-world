extends RefCounted
## CITY REIGN R170: the first six ORIGINAL campaign actions as a genuine
## recoverable interactive journey. Pure projection of authoritative GameState;
## NO new mission state, reward, duplicate wallet, timer, save key or quest RNG.
const TOTAL_STEPS: int = 6
const EXPECTED_ACTIONS = [
	"enter_vehicle","deliver","business","advance_turn","contract_accept","contract_deliver"
]
const CITYHALL = Vector3(-130.0,0.0,-130.0)
const MARKET = Vector3(130.0,0.0,-130.0)
const LANGS = ["ru","en","zh"]
const TEXTS = {
	"ru":{
		"chapter":"ЭПИЗОД 01 · ПЕРВОЕ ДЕЛО","done":"ГЛАВА ЗАВЕРШЕНА · ГОРОД ВАМ ДОВЕРЯЕТ",
		"car":"Займите место за рулём","car_body":"Подойдите к настоящему автомобилю у стартовой площади. Управление доступно от третьего лица и из салона.","car_hint":"E — сесть в машину · V — сменить камеру",
		"market":"Доставьте первый заказ на рынок","market_body":"Проедьте через городской трафик до Торговой галереи. Остановитесь у входа и подтвердите доставку.","market_hint":"WASD — движение · S — тормоз · F — доставка",
		"business":"Приобретите городскую компанию","business_body":"У Торговой галереи оформите первую настоящую покупку бизнеса. Баланс и доход обновляются только через GameState.","business_hint":"B — купить бизнес вблизи рынка",
		"turn":"Проведите первый городской такт","turn_body":"Вернитесь к городскому управлению: откройте кабинет и завершите экономический такт. Решения реально меняют бюджет.","turn_hint":"Tab — управление · N — следующий такт",
		"pickup":"Заберите первый коммерческий груз","pickup_body":"Езжайте к пункту погрузки из текущего настоящего контракта. Машина должна находиться рядом.","pickup_hint":"F — принять груз у указанного терминала",
		"dropoff":"Доставьте коммерческий груз","dropoff_body":"Доставьте груз по живым улицам с учётом пробега, состояния машины, погоды и расстояния. Остановитесь у пункта выдачи.","dropoff_hint":"Маршрут по карте · F — разгрузить после остановки",
		"recover":"Груз не активен · заберите новую перевозку","recover_body":"Если рейс прерван, вернитесь к реальному пункту погрузки. Получите новый контракт, затем завершите доставку.","recover_hint":"К терминалу · F — новый груз · затем доставка",
		"complete":"Шесть реальных заданий выполнены. Прогресс главы хранится в основном сохранении; теперь доступны следующие миссии и независимые городские проекты.",
		"complete_hint":"Продолжайте кампанию и выбирайте настоящий городской проект",
		"trial":"Пока идёт автоиспытание, следуйте его реальным контрольным точкам"
	},
	"en":{
		"chapter":"EPISODE 01 · FIRST REAL JOB","done":"CHAPTER COMPLETE · THE CITY TRUSTS YOU",
		"car":"Take the driver's seat","car_body":"Approach the real vehicle by the starting square. Third-person and cockpit views are both available.","car_hint":"E — enter vehicle · V — cycle camera",
		"market":"Deliver your first market order","market_body":"Drive through real city traffic to Market Gallery. Stop at the entrance to complete delivery.","market_hint":"WASD — drive · S — brake · F — deliver",
		"business":"Acquire your first company","business_body":"Make an actual business purchase near Market Gallery. Only the authoritative GameState changes your money.","business_hint":"B — acquire the market business",
		"turn":"Advance your first city turn","turn_body":"Open city government and advance a real economic turn. Decisions affect actual city resources.","turn_hint":"Tab — city management · N — next turn",
		"pickup":"Collect your first commercial cargo","pickup_body":"Drive to the pickup from the actual current contract. Your real vehicle must be nearby.","pickup_hint":"F — accept cargo at the correct depot",
		"dropoff":"Deliver the commercial cargo","dropoff_body":"Transport goods over the genuine road network. Mileage, condition and stopping distance affect completion.","dropoff_hint":"Follow the route · stop · F — unload",
		"recover":"Cargo interrupted · collect a new contract","recover_body":"Return to the authentic pickup point if a delivery is no longer active. Accept another job, then complete it.","recover_hint":"Drive to depot · F — new cargo · complete delivery",
		"complete":"Six real career objectives are complete. Progress lives in the original campaign save, and city projects remain open.",
		"complete_hint":"Continue the original campaign and choose an actual city project",
		"trial":"Finish the active physical checkpoint trial first"
	},
	"zh":{
		"chapter":"第一章 · 初次任务","done":"章节完成 · 城市信任你",
		"car":"进入驾驶席","car_body":"走到初始广场的真实车辆旁。可切换第三人称和车内视角。","car_hint":"E 上车 · V 切换镜头",
		"market":"完成首次市场配送","market_body":"穿过真实城市交通前往贸易中心。停车后确认配送。","market_hint":"WASD 驾驶 · S 刹车 · F 配送",
		"business":"收购第一家企业","business_body":"在市场附近进行真实企业交易。资金只能由游戏状态系统更新。","business_hint":"B 购买市场企业",
		"turn":"推进首个城市回合","turn_body":"打开市政管理并推进真实经济回合，决策会改变城市资源。","turn_hint":"Tab 管理 · N 下一回合",
		"pickup":"领取首个商业货物","pickup_body":"驾驶真实车辆前往当前合同的取货点，并将车停在附近。","pickup_hint":"在正确地点按 F 接货",
		"dropoff":"完成商业货运","dropoff_body":"沿城市道路运输货物，驾驶里程、车辆状态和停车位置影响完成条件。","dropoff_hint":"跟随路线 · 停车 · F 卸货",
		"recover":"货物已中断 · 重新取货","recover_body":"如果配送已中断，请返回真实取货点，重新领取合同后完成运输。","recover_hint":"前往仓库 · F 取货 · 继续配送",
		"complete":"六项真实任务已完成。进度保存在原有战役存档中，城市建设仍可继续。",
		"complete_hint":"继续原有战役，投资真实城市建设",
		"trial":"请先完成正在进行的真实驾考"
	}
}

static func local(locale: String) -> Dictionary:
	return TEXTS[locale] if LANGS.has(locale) else TEXTS["en"]

static func valid_position(value: Variant) -> bool:
	return value is Vector3 and (value as Vector3).is_finite()

static func first_six(state: Dictionary,offer: Dictionary,locations: Dictionary,locale: String) -> Dictionary:
	# Stage is NOT an invented task tracker. MissionManager owns all six
	# action confirmations and the existing JSON versioned save.
	var stage: int = clampi(int(state.get("mission",0)),0,TOTAL_STEPS)
	var l: Dictionary = local(locale)
	var result: Dictionary = {
		"step":mini(stage+1,TOTAL_STEPS),"total":TOTAL_STEPS,
		"completed":stage>=TOTAL_STEPS,"action":"",
		"goal":Vector3.ZERO,"goal_available":false,
		"status":"complete" if stage>=TOTAL_STEPS else "active",
		"heading":str(l["done"] if stage>=TOTAL_STEPS else l["chapter"]),
		"title":"","body":"","hint":"",
		"progress":str(TOTAL_STEPS)+"/"+str(TOTAL_STEPS) if stage>=TOTAL_STEPS else str(stage+1)+"/"+str(TOTAL_STEPS)
	}
	if stage>=TOTAL_STEPS:
		result["title"]=str(l["done"])
		result["body"]=str(l["complete"])
		result["hint"]=str(l["complete_hint"])
		return result
	result["action"]=EXPECTED_ACTIONS[stage]
	var key: String = ["car","market","business","turn","pickup","dropoff"][stage]
	var goal: Vector3=Vector3.ZERO
	match stage:
		0:
			var pos: Variant=state.get("vehicle_position",[])
			if pos is Array and (pos as Array).size()==3:
				var x: float=float(pos[0])
				var z: float=float(pos[2])
				if is_finite(x) and is_finite(z):
					goal=Vector3(x,0.0,z)
		1,2: goal=MARKET
		3: goal=CITYHALL
		4,5:
			var active: Dictionary=state.get("active_contract",{})
			var pending: bool=not active.is_empty()
			if stage==5 and not pending:
				key="recover"
				result["status"]="recover"
			var entry: Dictionary=active if pending else offer
			var place: String=str(entry.get("dropoff","")) if pending else str(entry.get("pickup",""))
			var physical: Variant=locations.get(place,Vector3.ZERO)
			if valid_position(physical):
				goal=physical
	result["goal"]=goal
	result["goal_available"]=goal!=Vector3.ZERO and goal.is_finite()
	result["title"]=str(l[key])
	result["body"]=str(l[key+"_body"])
	result["hint"]=str(l[key+"_hint"])
	if not state.get("driving_trial",{}).is_empty():
		result["status"]="trial"
		result["hint"]=str(l["trial"])
	return result

static func short_progress(projected: Dictionary) -> String:
	return str(projected.get("progress",""))+" · "+str(projected.get("title",""))
