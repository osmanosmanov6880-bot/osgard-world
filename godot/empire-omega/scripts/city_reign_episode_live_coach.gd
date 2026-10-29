extends RefCounted
## CITY REIGN R171 — live, source-authoritative playable first chapter coach.
## This is a READ-ONLY projection of the existing original 40-mission state.
## No invented reward, quest counter, navigation trigger, save key or physics.
const EPISODE = preload("res://scripts/city_reign_episode_sequence.gd")
const FREIGHT = preload("res://scripts/cargo_logistics.gd")
const MAX_DISPLAY_DISTANCE: int = 9999
const LANGUAGES = ["ru","en","zh"]
const ADVICE = {
    "ru":{
        "done":"Первое дело выполнено · продолжайте основную кампанию",
        "priority":"Действующая поездка или поручение важнее подсказок эпизода",
        "trial":"Сначала завершите настоящее автоиспытание",
        "invalid":"Текущее местоположение не определено · ориентируйтесь по журналу",
        "walk_car":"Подойдите к вашей машине у площади",
        "enter_car":"Автомобиль рядом · нажмите E",
        "drive_market":"Следуйте по улицам до Торговой галереи",
        "deliver_market":"Рынок рядом · нажмите F для первой доставки",
        "buy_market":"Рядом с рынком · нажмите B, чтобы купить первую компанию",
        "drive_buy":"Приезжайте к рынку, чтобы приобрести первую компанию",
        "funds":"Недостаточно средств для покупки · заработайте средства в доступных заданиях",
        "owned":"Предприятие уже принадлежит вам · проверьте прогресс сохранения",
        "open_city":"Откройте городское управление через Tab",
        "city_turn":"Городское управление открыто · нажмите N для следующего такта",
        "incident":"Сначала разрешите активный городской кризис",
        "to_cargo":"Отправляйтесь в настоящий пункт погрузки",
        "bring_car":"Подведите свой автомобиль к месту погрузки",
        "collect_cargo":"Место погрузки рядом · нажмите F",
        "recover_cargo":"После прерванного рейса возьмите реальный новый груз",
        "existing_cargo":"Предыдущий груз ещё в пути · сначала доставьте его",
        "drive_dropoff":"Езжайте к настоящему пункту разгрузки",
        "travel_more":"Для завершения рейса необходимо проехать оставшуюся дистанцию",
        "assigned_car":"Продолжайте рейс на машине, принявшей груз",
        "stop_car":"Вы на месте · остановите автомобиль перед выгрузкой",
        "unload_cargo":"Пробег и точка разгрузки подтверждены · нажмите F",
        "fuel":"Мало топлива · заправьтесь на логистическом терминале (F)",
        "repair":"Машина повреждена · отремонтируйте её у терминала (F)"
    },
    "en":{
        "done":"First job complete · continue the original career",
        "priority":"Finish your current courier or community objective first",
        "trial":"Finish the authentic driving trial before continuing",
        "invalid":"Location is unavailable · use the original mission journal",
        "walk_car":"Walk toward your actual car near the starting square",
        "enter_car":"Vehicle is close · press E",
        "drive_market":"Follow the live streets toward Market Gallery",
        "deliver_market":"At the market · press F for your first delivery",
        "buy_market":"At Market Gallery · press B to acquire your first company",
        "drive_buy":"Travel to Market Gallery before buying your first company",
        "funds":"Not enough personal money · earn credits through available activities",
        "owned":"Business already owned · review the original saved career stage",
        "open_city":"Open the city management screen with Tab",
        "city_turn":"Management is open · press N to advance the real city turn",
        "incident":"Resolve the current city crisis before advancing a turn",
        "to_cargo":"Drive to the actual current cargo pickup",
        "bring_car":"Bring the assigned car close to the pickup point",
        "collect_cargo":"Cargo pickup is close · press F",
        "recover_cargo":"Your prior cargo is interrupted · collect a real new contract",
        "existing_cargo":"An older cargo delivery is still active · finish it first",
        "drive_dropoff":"Drive to the real cargo dropoff",
        "travel_more":"Travel the remaining genuine driven distance before unloading",
        "assigned_car":"Use the actual car assigned to this original cargo",
        "stop_car":"At the destination · stop the car before unloading",
        "unload_cargo":"Driven distance and destination verified · press F to unload",
        "fuel":"Low fuel · refuel at the real logistics depot (F)",
        "repair":"Vehicle is damaged · visit the real depot for repair (F)"
    },
    "zh":{
        "done":"首个任务完成 · 继续原有战役",
        "priority":"先完成当前配送或社区任务",
        "trial":"请先完成当前真实驾驶考试",
        "invalid":"当前位置不可用 · 请查看原有任务日志",
        "walk_car":"步行靠近起点广场的真实汽车",
        "enter_car":"汽车就在附近 · 按 E",
        "drive_market":"沿城市道路前往贸易中心",
        "deliver_market":"到达市场 · 按 F 完成首次配送",
        "buy_market":"到达市场 · 按 B 购买第一家企业",
        "drive_buy":"先前往市场，再购买第一家企业",
        "funds":"个人资金不足 · 请通过现有活动赚取资金",
        "owned":"企业已购买 · 请检查原有存档进度",
        "open_city":"按 Tab 打开城市管理",
        "city_turn":"管理界面已打开 · 按 N 推进真实城市回合",
        "incident":"推进回合前先处理当前城市危机",
        "to_cargo":"驾驶前往当前真实取货点",
        "bring_car":"将指定车辆驶近装货点",
        "collect_cargo":"已到达取货点 · 按 F",
        "recover_cargo":"上一单已中断 · 领取真实的新订单",
        "existing_cargo":"当前已有货物在途 · 先完成配送",
        "drive_dropoff":"驾驶前往真实卸货点",
        "travel_more":"卸货前还需要完成实际驾驶里程",
        "assigned_car":"必须驾驶接货时指定的车辆",
        "stop_car":"已抵达目的地 · 停车后卸货",
        "unload_cargo":"里程和目的地已确认 · 按 F 卸货",
        "fuel":"油量不足 · 到真实物流站加油（F）",
        "repair":"车辆受损 · 到真实物流站维修（F）"
    }
}

static func horizontal_distance(a: Vector3,b: Vector3) -> float:
    if not a.is_finite() or not b.is_finite():
        return -1.0
    return Vector2(a.x,a.z).distance_to(Vector2(b.x,b.z))

static func explain(code: String,lang: String) -> String:
    var vocabulary: Dictionary = ADVICE[lang] if LANGUAGES.has(lang) else ADVICE["en"]
    return str(vocabulary.get(code,vocabulary["invalid"]))

static func _result(code: String,locale: String,projection: Dictionary,distance: float) -> Dictionary:
    # No unbounded distance numbers, no negative/NaN text, no fake marker.
    var usable: bool=is_finite(distance) and distance>=0.0 and distance<=MAX_DISPLAY_DISTANCE
    var nearest: int=clampi(roundi(distance/10.0)*10,0,MAX_DISPLAY_DISTANCE) if usable else -1
    return {
        "mode":code,"text":explain(code,locale),"step":int(projection["step"]),
        "progress":str(projection["progress"]),"goal":projection["goal"],
        "distance_m":nearest,"show_distance":usable and distance>=35.0
    }

static func recommend(state: Dictionary,offer: Dictionary,locations: Dictionary,
        locale: String,player_at: Vector3,vehicle_at: Vector3,driving: bool,
        velocity: float,fuel: float,health: float,city_menu: bool,
        market_cost: int) -> Dictionary:
    var projection: Dictionary=EPISODE.first_six(state,offer,locations,locale)
    if bool(projection["completed"]):
        return _result("done",locale,projection,-1.0)
    var target: Vector3=projection["goal"]
    var person: Vector3=vehicle_at if driving else player_at
    if not person.is_finite() or not vehicle_at.is_finite() or not target.is_finite() or
            not is_finite(velocity) or not is_finite(fuel) or not is_finite(health):
        return _result("invalid",locale,projection,-1.0)
    var distance: float=horizontal_distance(person,target)
    if not bool(projection["goal_available"]):
        return _result("invalid",locale,projection,-1.0)
    if not state.get("driving_trial",{}).is_empty():
        return _result("trial",locale,projection,distance)
    for key in ["neighborhood_active","service_active"]:
        var assignment: Variant=state.get(key,{})
        if assignment is Dictionary and not (assignment as Dictionary).is_empty():
            return _result("priority",locale,projection,distance)
    var step: int=int(state.get("mission",0))
    var active: Dictionary=state.get("active_contract",{})
    # Restrict priority warnings to real travel tasks, and never mask an
    # authentic completed delivery that is ready for its F interaction.
    if step in [1,4,5] and driving and distance>70.0:
        if health<25.0: return _result("repair",locale,projection,distance)
        if fuel<10.0: return _result("fuel",locale,projection,distance)
    match step:
        0:
            return _result("enter_car" if horizontal_distance(player_at,vehicle_at)<=8.0
                else "walk_car",locale,projection,distance)
        1:
            return _result("deliver_market" if distance<=29.0
                else "drive_market",locale,projection,distance)
        2:
            var companies: Dictionary=state.get("businesses",{})
            if bool(companies.get("market_stall",false)):
                return _result("owned",locale,projection,distance)
            if int(state.get("wallet",0))<market_cost:
                return _result("funds",locale,projection,distance)
            return _result("buy_market" if distance<=29.0
                else "drive_buy",locale,projection,distance)
        3:
            if str(state.get("incident",""))!="":
                return _result("incident",locale,projection,distance)
            return _result("city_turn" if city_menu
                else "open_city",locale,projection,distance)
        4,5:
            if step==5 and active.is_empty():
                if distance<=29.0 and horizontal_distance(vehicle_at,target)<=35.0:
                    return _result("recover_cargo",locale,projection,distance)
                return _result("to_cargo",locale,projection,distance)
            if active.is_empty():
                if distance<=29.0 and horizontal_distance(vehicle_at,target)>35.0:
                    return _result("bring_car",locale,projection,distance)
                return _result("collect_cargo" if distance<=29.0
                    else "to_cargo",locale,projection,distance)
            # Existing cargo blocks collecting a second contract. Physical
            # delivery remains authoritative, never silently completed here.
            var progress: Dictionary=active.get("cargo_progress",{})
            var assigned: String=str(progress.get("vehicle",""))
            if assigned!="" and assigned!=str(state.get("vehicle_selected","")):
                return _result("assigned_car",locale,projection,distance)
            if not FREIGHT.ready(active):
                return _result("travel_more",locale,projection,distance)
            if distance>29.0:
                return _result("existing_cargo" if step==4 else "drive_dropoff",
                    locale,projection,distance)
            if driving and absf(velocity)>1.5:
                return _result("stop_car",locale,projection,distance)
            return _result("unload_cargo",locale,projection,distance)
    return _result("invalid",locale,projection,distance)
