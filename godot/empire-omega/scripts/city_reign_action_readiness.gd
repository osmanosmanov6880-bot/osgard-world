extends RefCounted
## CITY REIGN R172: read-only live instructions from the existing, real
## six-mission sequence. No rewards, new save keys or injected actions.
## "ready" means the physical input is in range, NEVER a payment guarantee.
const CARGO = preload("res://scripts/cargo_logistics.gd")
const MARKET := Vector3(130.0,0.0,-130.0)
const VEHICLE_RADIUS: float = 8.0
const USE_RADIUS: float = 29.0
const LOAD_CAR_RADIUS: float = 35.0
const UNLOAD_SPEED: float = 1.5
const COPY = {
	"unavailable":{"ru":["ЦЕЛЬ НЕ ОПРЕДЕЛЕНА","Проверьте активное задание в журнале.",""],
		"en":["OBJECTIVE UNAVAILABLE","Check the live mission in the journal.",""],
		"zh":["目标暂不可用","请在任务日志中查看当前目标。",""]},
	"complete":{"ru":["ПЕРВАЯ ГЛАВА ПРОЙДЕНА","Продолжайте основную кампанию.",""],
		"en":["OPENING COMPLETE","Continue the original campaign.",""],
		"zh":["第一章已完成","继续主线任务。",""]},
	"vehicle_walk":{"ru":["ПОДОЙДИТЕ К МАШИНЕ","Войдите в радиус 8 м от своего автомобиля.","E"],
		"en":["APPROACH YOUR CAR","Move within 8 m of your vehicle.","E"],
		"zh":["靠近车辆","走到车辆 8 米范围内。","E"]},
	"vehicle_enter":{"ru":["СЕСТЬ ЗА РУЛЬ","Автомобиль рядом. Нажмите E или экранную АВТО.","E"],
		"en":["ENTER THE CAR","Vehicle in reach. Press E or the CAR touch control.","E"],
		"zh":["进入驾驶席","车辆已靠近。按 E 或屏幕上的车辆按钮。","E"]},
	"market_drive":{"ru":["ДОСТАВКА НА РЫНОК","Доберитесь до Торговой галереи по реальным улицам.","F"],
		"en":["DELIVER TO MARKET","Follow the real streets to Market Gallery.","F"],
		"zh":["送货至市场","沿真实道路前往贸易中心。","F"]},
	"market_deliver":{"ru":["ПЕРЕДАТЬ ЗАКАЗ","Рынок рядом. Нажмите F или экранную ДЕЙ.","F"],
		"en":["HAND OVER THE ORDER","At the market. Press F or the USE touch control.","F"],
		"zh":["完成送货","已到市场。按 F 或屏幕互动按钮。","F"]},
	"business_walk":{"ru":["ВЕРНИТЕСЬ НА РЫНОК","Покупка через B доступна в 29 м от галереи.","B"],
		"en":["RETURN TO MARKET","The B purchase is available within 29 m of the gallery.","B"],
		"zh":["返回市场","在贸易中心 29 米范围内可按 B 购买。","B"]},
	"business_buy":{"ru":["КУПИТЬ БИЗНЕС","Нажмите B или ПОКУПКА БИЗНЕСА в меню телефона. Средства проверит экономика.","B"],
		"en":["BUY THE BUSINESS","Press B or BUY BUSINESS in the phone menu. The economy checks funds.","B"],
		"zh":["收购商铺","按 B 或手机菜单中的购买企业。资金由经济系统核验。","B"]},
	"government_open":{"ru":["ОТКРЫТЬ УПРАВЛЕНИЕ","Нажмите Tab или УПРАВЛЕНИЕ ГОРОДОМ в меню телефона.","Tab"],
		"en":["OPEN CITY MANAGEMENT","Press Tab or GOVERN CITY from phone actions.","Tab"],
		"zh":["打开城市管理","按 Tab 或手机操作菜单中的城市管理。","Tab"]},
	"government_turn":{"ru":["СЛЕДУЮЩИЙ ТАКТ","Нажмите N или СЛЕДУЮЩИЙ ТАКТ в кабинете. Решение проверяет GameState.","N"],
		"en":["ADVANCE ONE TURN","Press N or NEXT TURN in the city cabinet. GameState validates it.","N"],
		"zh":["推进城市回合","按 N 或城市管理中的下一回合。游戏状态系统会校验。","N"]},
	"car_to_pickup":{"ru":["ПОДГОНЯЙТЕ АВТО","Для приёма груза автомобиль должен быть в 35 м от терминала.","F"],
		"en":["BRING YOUR VEHICLE","Your car must be within 35 m of the real pickup.","F"],
		"zh":["将车辆开到货站","车辆必须距离实际取货点不超过 35 米。","F"]},
	"pickup_drive":{"ru":["К ПУНКТУ ПОГРУЗКИ","Следуйте к адресу действующего предложения, затем нажмите F.","F"],
		"en":["GO TO THE PICKUP","Follow the current contract pickup location, then press F.","F"],
		"zh":["前往取货点","前往当前合同的取货位置，然后按 F。","F"]},
	"pickup_ready":{"ru":["ПОЛУЧИТЬ ГРУЗ","Грузовой терминал рядом и ваш автомобиль подан. Нажмите F.","F"],
		"en":["COLLECT YOUR CARGO","The depot and your car are in range. Press F.","F"],
		"zh":["领取货物","车辆与货站距离满足要求。按 F 取货。","F"]},
	"recover_cargo":{"ru":["ВОССТАНОВИТЬ РЕЙС","Груз не активен. Вернитесь к настоящей точке погрузки.","F"],
		"en":["RECOVER THE DELIVERY","No cargo is active. Return to the real pickup.","F"],
		"zh":["恢复配送","当前没有货物。返回真实取货点。","F"]},
	"freight_route":{"ru":["ВЕЗИТЕ ГРУЗ","Следуйте к реальному получателю по дорожному маршруту.","F"],
		"en":["TRANSPORT THE CARGO","Drive to the actual dropoff on the road network.","F"],
		"zh":["运输货物","沿道路驶向实际卸货点。","F"]},
	"freight_distance":{"ru":["НУЖЕН ПРОБЕГ","Требуемое расстояние ещё не пройдено; продолжайте перевозку.","F"],
		"en":["DRIVE THE REQUIRED DISTANCE","Cargo mileage requirement is not yet met.","F"],
		"zh":["继续行驶","货物需要的运输里程尚未达到。","F"]},
	"freight_stop":{"ru":["ОСТАНОВИТЕ МАШИНУ","Перед разгрузкой снизьте скорость до 1,5 м/с или ниже.","F"],
		"en":["STOP BEFORE UNLOADING","Slow to 1.5 m/s or less before delivery.","F"],
		"zh":["停车后卸货","卸货前将速度降至每秒 1.5 米或更低。","F"]},
	"freight_car":{"ru":["НУЖНА ИСХОДНАЯ МАШИНА","Доставляйте груз на автомобиле, назначенном при погрузке.","F"],
		"en":["USE THE LOADED VEHICLE","Deliver in the vehicle assigned at pickup.","F"],
		"zh":["使用装货时的车辆","请驾驶领取货物时指定的车辆配送。","F"]},
	"freight_unload":{"ru":["РАЗГРУЗИТЬ ГРУЗ","Получатель рядом, пробег и условия разгрузки выполнены. Нажмите F.","F"],
		"en":["UNLOAD THE CARGO","Dropoff, mileage and vehicle gates are met. Press F.","F"],
		"zh":["完成卸货","已抵达终点且通过行驶与车辆要求。按 F。","F"]},
	"finish_prior":{"ru":["ЗАКОНЧИТЬ ПРЕЖНИЙ РЕЙС","Уже принят другой груз. Завершите его, затем возьмите новый.","F"],
		"en":["FINISH THE CURRENT JOB","Another cargo is active. Deliver it before collecting new freight.","F"],
		"zh":["先完成当前配送","已有货物在途。先送达，再领取新货物。","F"]}
}

static func _cue(phase: String,stage: int,ready: bool=false) -> Dictionary:
	var captions: Dictionary=COPY.get(phase,COPY["unavailable"])
	# Language set after this pure call; see localized() below.
	return {"active":phase!="unavailable" and phase!="complete",
		"ready":ready,"phase":phase,"step":clampi(stage+1,1,6),
		"progress":"%d/6" % clampi(stage+1,1,6),
		"copy":captions}

static func localized(cue: Dictionary,locale: String) -> Dictionary:
	var lang: String=locale if ["ru","en","zh"].has(locale) else "ru"
	var captions: Dictionary=cue.get("copy",COPY["unavailable"])
	var words: Array=captions.get(lang,captions["ru"])
	return {"active":bool(cue.get("active",false)),
		"ready":bool(cue.get("ready",false)),"phase":str(cue.get("phase","unavailable")),
		"step":int(cue.get("step",1)),"progress":str(cue.get("progress","1/6")),
		"title":str(words[0]),"detail":str(words[1]),"key":str(words[2])}

static func _distance(a: Vector3,b: Vector3) -> float:
	if not a.is_finite() or not b.is_finite() or b==Vector3.ZERO:
		return INF
	return a.distance_to(b)

static func _destination(locations: Dictionary,key: String) -> Vector3:
	var point: Variant=locations.get(key,Vector3.ZERO)
	if point is Vector3 and (point as Vector3).is_finite():
		return point
	return Vector3.ZERO

static func _freight(active: Dictionary,locations: Dictionary,state: Dictionary,
		at: Vector3,driving: bool,speed: float,stage: int) -> Dictionary:
	var where: Vector3=_destination(locations,str(active.get("dropoff","")))
	if where==Vector3.ZERO:
		return _cue("unavailable",stage)
	var progress: Dictionary=active.get("cargo_progress",{})
	if not bool(progress.get("legacy",false)):
		if not driving or str(progress.get("vehicle",""))!=str(state.get("vehicle_selected","")):
			return _cue("freight_car",stage)
	if _distance(at,where)>=USE_RADIUS:
		return _cue("freight_route",stage)
	if not CARGO.ready(active):
		return _cue("freight_distance",stage)
	if driving and absf(speed)>UNLOAD_SPEED:
		return _cue("freight_stop",stage)
	if stage==4:
		# Real completion clears this unrelated prior contract; it does not
		# advance the original mission's new-pickup action.
		return _cue("finish_prior",stage,true)
	return _cue("freight_unload",stage,true)

static func project(state: Dictionary,offer: Dictionary,locations: Dictionary,
		player_at: Vector3,vehicle_at: Vector3,driving: bool,speed: float,
		cabinet_open: bool,locale: String) -> Dictionary:
	var stage: int=clampi(int(state.get("mission",0)),0,6)
	if stage>=6:
		return localized(_cue("complete",6),locale)
	# Side jobs currently override the main campaign in the original scene.
	# Never present a competing actionable command over an active side mission.
	for field in ["driving_trial","neighborhood_active","service_active"]:
		var ongoing: Variant=state.get(field,{})
		if ongoing is Dictionary and not ongoing.is_empty():
			return localized(_cue("unavailable",stage),locale)
	if not player_at.is_finite() or not vehicle_at.is_finite() or not is_finite(speed):
		return localized(_cue("unavailable",stage),locale)
	var at: Vector3=vehicle_at if driving else player_at
	var active: Variant=state.get("active_contract",{})
	var contract: Dictionary=active if active is Dictionary else {}
	var result: Dictionary={}
	match stage:
		0:
			result=_cue("vehicle_enter",stage,true) if not driving and _distance(player_at,vehicle_at)<VEHICLE_RADIUS else _cue("vehicle_walk",stage)
		1:
			result=_cue("market_deliver",stage,true) if _distance(at,MARKET)<USE_RADIUS else _cue("market_drive",stage)
		2:
			result=_cue("business_buy",stage,true) if _distance(at,MARKET)<USE_RADIUS else _cue("business_walk",stage)
		3:
			result=_cue("government_turn",stage,true) if cabinet_open else _cue("government_open",stage,true)
		4,5:
			if not contract.is_empty():
				result=_freight(contract,locations,state,at,driving,speed,stage)
			else:
				var pickup: Vector3=_destination(locations,str(offer.get("pickup","")))
				if pickup==Vector3.ZERO:
					result=_cue("unavailable",stage)
				elif _distance(vehicle_at,pickup)>=LOAD_CAR_RADIUS:
					result=_cue("car_to_pickup",stage)
				elif _distance(at,pickup)>=USE_RADIUS:
					result=_cue("recover_cargo",stage) if stage==5 else _cue("pickup_drive",stage)
				else:
					result=_cue("pickup_ready",stage,true)
	return localized(result,locale)
