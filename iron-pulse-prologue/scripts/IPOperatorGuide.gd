extends RefCounted
class_name IPOperatorGuide
## G1: optional, real-source onboarding. The player still must walk,
## inspect, operate terminals and earn victories via IPCrisisEngine.
## No in-game actions, no timer manipulation, no cloud or tutorial teleport.

const FORMAT: String = "IRON_PULSE_OPERATOR_GUIDE_G1"
const MAX_TIER: int = 3
const STUCK_SECONDS: float = 30.0
const VALID_OBJECTIVES: Array[String] = ["scan","repair","charge","override","exit"]
const STAGE_LABELS: Dictionary = {
    "scan":["СКАНИРОВАНИЕ","REACTOR SCAN"],
    "repair":["РЕМОНТ","COOLANT REPAIR"],
    "charge":["ЭНЕРГОКОНТУР","POWER ROUTING"],
    "override":["АВАРИЙНЫЙ ДОПУСК","EMERGENCY OVERRIDE"],
    "exit":["ЭВАКУАЦИЯ","EVACUATION"]
}

var objective: String = ""
var seconds_on_objective: float = 0.0
var tier: int = 0
var requests: int = 0
var observed_denials: int = 0
var last_faults: int = 0

func reset(engine: IPCrisisEngine) -> void:
    objective = engine.objective_id() if engine != null else ""
    seconds_on_objective = 0.0
    tier = 0
    requests = 0
    observed_denials = 0
    last_faults = engine.faults if engine != null else 0

func observe(delta: float, engine: IPCrisisEngine, active: bool) -> void:
    if engine == null or engine.finished():
        return
    var current: String = engine.objective_id()
    if current != objective:
        objective = current
        seconds_on_objective = 0.0
        tier = 0
        last_faults = engine.faults
    if not active or not is_finite(delta) or delta <= 0.0 or delta > 0.25:
        return
    seconds_on_objective += delta
    if engine.faults > last_faults:
        observed_denials += engine.faults-last_faults
    last_faults = engine.faults

func request(engine: IPCrisisEngine, locale: String) -> Dictionary:
    # A read-only request; it cannot affect the game engine or save file.
    if engine == null or engine.finished():
        return {}
    if engine.objective_id() != objective:
        objective = engine.objective_id()
        seconds_on_objective = 0.0
        tier = 0
    if not VALID_OBJECTIVES.has(objective):
        return {}
    tier = mini(tier+1,MAX_TIER)
    requests += 1
    return readout(engine,locale)

func readout(engine: IPCrisisEngine, locale: String = "ru") -> Dictionary:
    if engine == null or engine.finished() or not VALID_OBJECTIVES.has(engine.objective_id()):
        return {}
    return {
        "schema": FORMAT,
        "scenario": engine.scenario_id,
        "objective": engine.objective_id(),
        "tier": tier,
        "requested": requests,
        "seconds_without_stage_progress": snappedf(seconds_on_objective,0.1),
        "stuck_hint_available": seconds_on_objective >= STUCK_SECONDS or observed_denials > 0,
        "denied_actions_observed": observed_denials,
        "source_derived": true,
        "real_gameplay_modified": false,
        "telemetry_uploaded": false,
        "text": guidance(engine,locale)
    }

func guidance(engine: IPCrisisEngine, locale: String = "ru") -> String:
    if engine == null or engine.finished():
        return ""
    var stage: String = engine.objective_id()
    if not STAGE_LABELS.has(stage):
        return ""
    var en: bool = locale == "en"
    var language: int = 1 if en else 0
    var lines: Array[String] = []
    lines.append("A7 / OPERATOR GUIDE  •  %d/%d" % [maxi(tier,1),MAX_TIER] if en
        else "A7 / ПОМОЩЬ ОПЕРАТОРУ  •  %d/%d" % [maxi(tier,1),MAX_TIER])
    lines.append(str(STAGE_LABELS[stage][language]))
    lines.append("")
    match stage:
        "scan":
            lines.append("Find the physical CORE SCANNER and press E." if en
                else "Найдите физический СКАНЕР ЯДРА и нажмите E.")
            if tier >= 2:
                lines.append("The highlighted terminal and H wayfinding show the route." if en
                    else "Подсвеченный терминал и навигация H показывают маршрут.")
            if tier >= 3:
                lines.append("The scan must happen before repair, relays or power routing." if en
                    else "Сначала сканирование: без него ремонт и станции недоступны.")
        "repair":
            lines.append("Reach the coolant maintenance terminal and use E." if en
                else "Идите к пульту ремонта охлаждения и нажмите E.")
            if tier >= 2:
                lines.append("E is the careful route; Q is an emergency alternative in HEAT/AIR." if en
                    else "E — аккуратный ремонт; Q — аварийный вариант в HEAT/AIR.")
            if tier >= 3:
                var tradeoff_en: String = "HEAT: rapid Q lowers heat but costs air and crew." if engine.scenario_id == "thermal" else "AIR: rapid Q leaves a persistent oxygen leak."
                var tradeoff_ru: String = "HEAT: быстрый Q снижает температуру ценой воздуха и здоровья." if engine.scenario_id == "thermal" else "AIR: быстрый Q оставляет постоянную микроутечку."
                if engine.scenario_id == "blackout":
                    lines.append("GRID: repair with E; Q is unavailable." if en else "GRID: ремонт только E; Q недоступен.")
                else:
                    lines.append(tradeoff_en if en else tradeoff_ru)
        "charge":
            lines.append("Route one power bus to DOOR at terminal A or B." if en
                else "Перенаправьте линию A или B на DOOR у физического пульта.")
            if tier >= 2:
                lines.append("E cycles a bus after repair. Two buses power three systems." if en
                    else "E переключает линию после ремонта. Есть две линии и три системы.")
                if en:
                    lines.append("DOOR POWER: ON" if engine.powered("door") else "DOOR POWER: OFF")
                else:
                    lines.append("ПИТАНИЕ DOOR: ВКЛ." if engine.powered("door") else "ПИТАНИЕ DOOR: ВЫКЛ.")
            if tier >= 3:
                lines.append(("Wait for real DOOR charge to reach %.0f%% before override." % IPCrisisEngine.CHARGE_REQUIRED) if en
                    else ("Дождитесь реального заряда DOOR не менее %.0f%%." % IPCrisisEngine.CHARGE_REQUIRED))
        "override":
            lines.append("Restore COOLANT and LIFE, then use the override console." if en
                else "Верните питание COOLANT и LIFE, затем используйте пульт допуска.")
            if tier >= 2:
                var missing: Array[String] = []
                if not engine.powered("coolant"):
                    missing.append("COOLANT")
                if not engine.powered("life"):
                    missing.append("LIFE")
                lines.append(("OFFLINE: "+", ".join(missing)) if not missing.is_empty()
                    else ("COOLANT + LIFE: ONLINE" if en else "COOLANT + LIFE: РАБОТАЮТ"))
            if tier >= 3:
                lines.append("Override needs heat below 85 C, oxygen >=20%, and adequate door charge." if en
                    else "Допуск требует температуру ниже 85°C, кислород ≥20% и заряд двери.")
        "exit":
            lines.append("Reach the physical evacuation airlock and press E." if en
                else "Дойдите до настоящего эвакуационного шлюза и нажмите E.")
            if tier >= 2:
                lines.append("H marks the route. No remote exit or automatic victory." if en
                    else "H подсказывает маршрут. Дистанционной победы нет.")
            if tier >= 3:
                lines.append("The crew wins only when you activate the exit at the site." if en
                    else "Экипаж будет спасён только после действия у шлюза.")
    if tier >= 2:
        lines.append("")
        lines.append("A: %s  /  B: %s  /  DOOR: %.0f%%" % [
            engine.bus_a.to_upper(),engine.bus_b.to_upper(),engine.door_charge])
    if tier >= 3:
        lines.append("HEAT: %.0f C  /  O2: %.0f%%  /  CREW: %.0f%%" % [
            engine.heat,engine.oxygen,engine.crew_health])
    lines.append("")
    lines.append("F1 / NEXT HINT • ESC / CLOSE" if en
        else "F1 / ЕЩЁ ПОДСКАЗКА • ESC / ЗАКРЫТЬ")
    lines.append("REAL MISSION • NO AUTO-ACTIONS" if en
        else "НАСТОЯЩАЯ МИССИЯ • БЕЗ АВТОДЕЙСТВИЙ")
    return "\n".join(PackedStringArray(lines))
