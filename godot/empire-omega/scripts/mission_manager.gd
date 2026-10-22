extends Node
## Forty sequential, locally validated career missions spanning open world, property and governance.

signal mission_updated(index: int, title: String)
signal mission_completed(index: int, reward: int)

const MISSIONS = [
	{"id":"enter_vehicle","ru":"Найдите автомобиль и нажмите E","en":"Find a car and press E","zh":"找到汽车并按 E","reward":100},
	{"id":"deliver","ru":"Доставьте заказ на рынок (F)","en":"Deliver an order to the market (F)","zh":"将订单送到市场 (F)","reward":360},
	{"id":"business","ru":"Купите свою первую компанию (B)","en":"Buy your first company (B)","zh":"购买第一家企业 (B)","reward":250},
	{"id":"advance_turn","ru":"Откройте управление (Tab), завершите такт (N)","en":"Open governance (Tab), advance turn (N)","zh":"打开城市管理 (Tab)，推进回合 (N)","reward":180},
	{"id":"contract_accept","ru":"Заберите коммерческий груз (F)","en":"Pick up a courier contract (F)","zh":"领取商业配送合同 (F)","reward":90},
	{"id":"contract_deliver","ru":"Отвезите груз в пункт назначения (F)","en":"Deliver the cargo to its destination (F)","zh":"将货物送达目的地 (F)","reward":240},
	{"id":"build","ru":"Постройте здание в кабинете правителя","en":"Build a project in the governor's cabinet","zh":"在管理界面建设一栋建筑","reward":250},
	{"id":"research","ru":"Изучите технологию в кабинете правителя","en":"Research a technology in the governor's cabinet","zh":"在管理界面研发一项技术","reward":350},
	{"id":"property","ru":"Купите первый объект недвижимости в кабинете","en":"Buy your first property in the city office","zh":"在管理界面购买第一处房产","reward":300},
	{"id":"renovation","ru":"Улучшите собственную недвижимость","en":"Renovate one of your properties","zh":"翻新自己的一处房产","reward":400},
	{"id":"transfer","ru":"Инвестируйте личные 250 ₽ в казну города","en":"Invest 250 of your own ₽ into the city","zh":"将个人的250卢布投资到城市","reward":300},
	{"id":"set_course","ru":"Измените политический курс города","en":"Change the city's political policy","zh":"调整城市的政策路线","reward":140},
	{"id":"contract_deliver","ru":"Выполните ещё один коммерческий рейс","en":"Complete another commercial delivery","zh":"再完成一次商业配送","reward":300},
	{"id":"property","ru":"Расширьте портфель: купите вторую недвижимость","en":"Expand your portfolio: buy another property","zh":"扩展投资组合：再购买一处房产","reward":440},
	{"id":"business","ru":"Купите второе действующее предприятие","en":"Acquire a second operating company","zh":"收购第二家运营企业","reward":400},
	{"id":"build","ru":"Вложите бюджет в новое городское здание","en":"Invest the budget in another civic project","zh":"从城市预算中投资新建筑","reward":400},
	{"id":"research","ru":"Откройте следующую технологию","en":"Unlock another technology","zh":"解锁下一项技术","reward":500},
	{"id":"advance_turn","ru":"Проведите экономический такт и проверьте доходность","en":"Run an economic turn and check your earnings","zh":"推进经济回合并查看收益","reward":300},
	{"id":"resolve_incident","ru":"Разрешите городской кризис через кабинет","en":"Resolve a city crisis from the governor's office","zh":"在管理界面解决一场城市危机","reward":600},
	{"id":"contract_deliver","ru":"Завершите финальный логистический контракт","en":"Complete a final logistics contract","zh":"完成最终物流合同","reward":800},
	{"id":"interior_enter","ru":"Зайдите в любое городское здание (I)","en":"Enter a city building (I)","zh":"进入一栋城市建筑 (I)","reward":280},
	{"id":"trade","ru":"Проведите сделку на товарной бирже","en":"Make a deal on the commodity market","zh":"在商品市场完成一笔交易","reward":350},
	{"id":"vehicle_buy","ru":"Расширьте автопарк покупкой транспорта","en":"Expand your fleet with another vehicle","zh":"购买车辆扩大车队","reward":600},
	{"id":"vehicle_select","ru":"Смените активный автомобиль в гараже","en":"Select your new car in the garage","zh":"在车库选择一辆新车","reward":280},
	{"id":"contract_deliver","ru":"Выполните доставку на новой машине","en":"Complete a delivery with your fleet","zh":"使用车队完成一项配送","reward":750},
	{"id":"trade","ru":"Помогите городской экономике следующей сделкой","en":"Support city supplies with another market trade","zh":"完成另一次交易来支持城市供应","reward":420},
	{"id":"advance_turn","ru":"Проведите такт и оцените эффект инвестиций","en":"Advance a turn and examine the returns","zh":"推进回合并查看投资回报","reward":440},
	{"id":"interior_enter","ru":"Посетите следующее здание, чтобы завершить главу","en":"Visit another interior to finish the chapter","zh":"探访另一栋建筑完成章节","reward":900},
	{"id":"initiative_start","ru":"Запустите инфраструктурный проект в кабинете","en":"Launch an infrastructure initiative","zh":"启动一项城市基础设施工程","reward":450},
	{"id":"advance_turn","ru":"Проведите строительный такт","en":"Advance an infrastructure construction turn","zh":"推进工程建设回合","reward":250},
	{"id":"trade","ru":"Обеспечьте город новыми ресурсами","en":"Trade to restore city supply chains","zh":"通过贸易补充城市资源","reward":500},
	{"id":"contract_deliver","ru":"Выполните рейс в развитом городе","en":"Complete a route in the developing city","zh":"在发展的城市里完成一项配送任务","reward":1100},
	{"id":"road_repair","ru":"Восстановите закрытую дорогу в кабинете или на улице (F)","en":"Reopen a blocked road in governance or on foot (F)","zh":"在管理面板或街道上修复封闭道路 (F)","reward":400},
	{"id":"road_maintenance","ru":"Проведите профилактику всей дорожной сети","en":"Invest in preventive road maintenance","zh":"投资道路预防性维护","reward":450},
	{"id":"advance_turn","ru":"Проведите такт и оцените доступность грузовых путей","en":"Advance the city and review freight connectivity","zh":"推进回合并检查货运连接性","reward":500},
	{"id":"contract_deliver","ru":"Доставьте груз по обновлённой дорожной сети","en":"Make a delivery through the rebuilt street network","zh":"通过修复后的道路进行一次货运配送","reward":1200},
	{"id":"service_accept","ru":"Возьмите задание городской службы у дворца (R)","en":"Accept a public-service call at City Hall (R)","zh":"在市政厅接受公共服务任务 (R)","reward":200},
	{"id":"service_complete","ru":"Доезжайте до пункта помощи и завершите поручение (F)","en":"Drive to the service destination and complete the call (F)","zh":"驾车到达目的地并完成任务 (F)","reward":600},
	{"id":"neighborhood_accept","ru":"Поговорите с горожанином (J) и возьмите личное поручение","en":"Talk to a resident (J) and accept a neighborhood errand","zh":"与居民交谈 (J) 并接受委托","reward":220},
	{"id":"neighborhood_deliver","ru":"Купите материалы и доставьте их жителю по маршруту (F)","en":"Purchase supplies and complete the local delivery (F)","zh":"购买物资并完成本地配送 (F)","reward":640}
]

func get_mission() -> Dictionary:
	var stage: int = int(GameState.data.get("mission",0))
	if stage >= MISSIONS.size():
		return {"id":"complete","ru":"Свободная игра: развивайте империю","en":"Free play: build your empire","zh":"自由模式：发展你的帝国","reward":0}
	return MISSIONS[stage]

func title(lang: String) -> String:
	var mission: Dictionary = get_mission()
	return str(mission.get(lang,mission["ru"]))

func register_action(action: String) -> bool:
	var stage: int = int(GameState.data.get("mission",0))
	if stage >= MISSIONS.size(): return false
	var mission: Dictionary = MISSIONS[stage]
	if mission["id"] != action: return false
	GameState.data["mission"] = stage + 1
	if action == "contract_deliver":
		GameState.data["science"] += 30
	GameState.add_reward(int(mission["reward"]),"mission_" + action)
	mission_completed.emit(stage,int(mission["reward"]))
	mission_updated.emit(stage+1,title(GameState.locale))
	return true
