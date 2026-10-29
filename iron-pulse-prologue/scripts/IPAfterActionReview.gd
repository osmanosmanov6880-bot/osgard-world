extends RefCounted
class_name IPAfterActionReview
## V16 / A7 BLACK BOX: player-visible evidence from finished engine sessions.
## All numbers, outcomes and event order come from IPCrisisEngine.
## This is not an upload, analytics SDK, network leaderboard or fake replay.

const FORMAT: String = "IRON_PULSE_AFTER_ACTION_V16"
const HISTORY_LIMIT: int = 12
const EVENT_LABELS: Dictionary = {
    "shift_started":["Начало смены","Shift started"],
    "core_scanned":["Сканирование ядра","Core scanned"],
    "priority_crew":["Приоритет экипажу","Crew priority"],
    "priority_core":["Приоритет ядру","Core priority"],
    "priority_skip":["Приоритет не выбран","Priority not selected"],
    "coolant_repaired":["Контур восстановлен","Coolant repaired"],
    "thermal_stabilized":["Точная стабилизация","Deep stabilization"],
    "thermal_purged":["Аварийный тепловой сброс","Emergency purge"],
    "breach_sealed":["Полная герметизация","Breach sealed"],
    "breach_patched":["Экстренная заплатка","Emergency patch"],
    "relay_medbay":["Медблок подключён","Medbay activated"],
    "relay_quench":["Гаситель подключён","Quench activated"],
    "relay_uplink":["Связь подключена","Uplink activated"],
    "field_sink":["Тепловой якорь: потрачен воздух","Heat sink: air sacrificed"],
    "field_air":["Резерв воздуха: цена — перегрев","Air buffer: reactor heat cost"],
    "bus_switched":["Линия питания переключена","Power bus switched"],
    "surge":["Скачок напряжения","Power surge"],
    "thermal_pulse":["Тепловой импульс","Thermal pulse"],
    "override_authorized":["Доступ подтверждён","Override authorized"],
    "crew_evacuated":["Экипаж эвакуирован","Crew evacuated"],
    "reactor_overheat":["Критический перегрев","Core overheated"],
    "life_support_lost":["Жизнеобеспечение потеряно","Life support lost"],
    "time_expired":["Время истекло","Time expired"],
    "action_denied":["Действие отклонено","Action denied"]
}
const FOCUS_LABELS: Dictionary = {
    "cooling":["Не оставляй COOLANT без питания слишком долго.","Avoid deprioritizing COOLANT for too long."],
    "life":["Сохраняй LIFE и следи за остатком кислорода.","Keep LIFE powered and monitor oxygen."],
    "time":["Планируй маршруты между терминалами и распределение времени.","Plan terminal routes and the available operation time."],
    "faults":["Сверяй разрешённые действия с текущей задачей.","Check allowed actions against your current objective."],
    "crew":["Сравнивай цену решений для людей и реактора.","Review the human cost of each core-versus-crew choice."],
    "balanced":["Сопоставь результат с журналом действий и попробуй другой маршрут.","Compare this result with the event log and try another route."]
}

func review(engine: IPCrisisEngine,campaign: IPCampaignFlow = null) -> Dictionary:
    if engine == null or not engine.finished():
        return {}
    var reason: String = "crew_evacuated"
    var focus: String = "balanced"
    if engine.lost:
        if engine.heat >= 100.0:
            reason = "reactor_overheat"
            focus = "cooling"
        elif engine.oxygen <= 0.0 or engine.crew_health <= 0.0:
            reason = "life_support_lost"
            focus = "life"
        elif engine.time_left <= 0.0:
            reason = "time_expired"
            focus = "time"
        else:
            reason = "time_expired"
            focus = "time"
    elif engine.faults >= 3:
        focus = "faults"
    elif engine.crew_health < 50.0:
        focus = "crew"
    var history: Array[String] = []
    var first: int = maxi(0,engine.event_log.size()-HISTORY_LIMIT)
    for i in range(first,engine.event_log.size()):
        history.append(engine.event_log[i])
    var confirmed_victories: int = 0
    if campaign != null and campaign.active:
        confirmed_victories = campaign.records.size()
    return {
        "schema":FORMAT,
        "scenario":engine.scenario_id,
        "outcome":"VICTORY" if engine.won else "FAILURE",
        "reason":reason,
        "grade":engine.grade(),
        "elapsed_seconds":snappedf(engine.elapsed,0.1),
        "heat":snappedf(engine.heat,0.1),
        "oxygen":snappedf(engine.oxygen,0.1),
        "crew":snappedf(engine.crew_health,0.1),
        "door":snappedf(engine.door_charge,0.1),
        "switches":engine.switches,
        "faults":engine.faults,
        "priority":engine.priority_id,
        "repair":engine.repair_method,
        "field_protocol":engine.field_protocol,
        "relays":engine.relays_activated.duplicate(),
        "history":history,
        "total_event_count":engine.event_log.size(),
        "history_has_timestamps":false,
        "campaign":campaign != null and campaign.active,
        "campaign_confirmed_victories":confirmed_victories,
        "focus":focus
    }

func localized(report: Dictionary,locale: String = "ru") -> String:
    if report.is_empty():
        return ""
    var english: bool = locale == "en"
    var lang: int = 1 if english else 0
    var lines: Array[String] = []
    lines.append("A7 / BLACK BOX / VERIFIED RUN" if english else "A7 / ЧЁРНЫЙ ЯЩИК / РЕАЛЬНЫЙ ПРОХОД")
    var result: String = "CREW EVACUATED" if english else "ЭКИПАЖ СПАСЁН"
    if report["outcome"] == "FAILURE":
        result = "OPERATION FAILED" if english else "ОПЕРАЦИЯ ПРОВАЛЕНА"
    lines.append("%s  /  %s  /  %s" % [
        str(report["scenario"]).to_upper(),result,str(report["grade"])])
    lines.append("")
    lines.append(("ELAPSED" if english else "ПРОШЛО") + "  %.1f s" % float(report["elapsed_seconds"]))
    lines.append("HEAT  %.1f C    O2  %.1f%%" % [float(report["heat"]),float(report["oxygen"])])
    lines.append("CREW  %.1f%%    DOOR  %.1f%%" % [float(report["crew"]),float(report["door"])])
    lines.append(("POWER SWITCHES" if english else "ПЕРЕКЛЮЧЕНИЯ") + "  %d" % int(report["switches"]))
    lines.append(("DENIED ACTIONS" if english else "ОТКЛОНЁННЫЕ ДЕЙСТВИЯ") + "  %d" % int(report["faults"]))
    lines.append(("REPAIR" if english else "РЕМОНТ") + "  " + str(report["repair"]).to_upper())
    var protocol: String = str(report.get("field_protocol",""))
    var protocol_name: String = "HEAT SINK" if protocol == "sink" else "AIR BUFFER" if protocol == "air" else "NONE" if english else "НЕТ"
    lines.append(("FIELD PROTOCOL" if english else "ПОЛЕВОЙ ПРОТОКОЛ") + "  " + protocol_name)
    var relays: Array = report["relays"]
    lines.append(("RELAYS" if english else "СТАНЦИИ") + "  " + (", ".join(PackedStringArray(relays)) if not relays.is_empty() else "—"))
    if bool(report["campaign"]):
        lines.append(("CAMPAIGN VICTORIES" if english else "ПОБЕДЫ КАМПАНИИ") + "  %d/3" % int(report["campaign_confirmed_victories"]))
    lines.append("")
    lines.append("NEXT ATTEMPT / FOCUS" if english else "СЛЕДУЮЩАЯ ПОПЫТКА / ВЫВОД")
    var focus: String = str(report["focus"])
    if FOCUS_LABELS.has(focus):
        lines.append(str(FOCUS_LABELS[focus][lang]))
    lines.append("")
    lines.append("RECORDED EVENTS / ORDER ONLY" if english else "ЗАПИСАННЫЕ СОБЫТИЯ / ТОЛЬКО ПОРЯДОК")
    var history: Array = report["history"]
    for index in range(history.size()):
        var key: String = str(history[index])
        var localized_event: String = str(EVENT_LABELS[key][lang]) if EVENT_LABELS.has(key) else key.replace("_"," ").to_upper()
        lines.append("%02d  %s" % [index+1,localized_event])
    lines.append("")
    lines.append("The engine did not record event times; no timestamps are invented." if english else "Движок не сохранял время событий. Метки времени не выдуманы.")
    lines.append("LOCAL ONLY / NO TELEMETRY SENT" if english else "ТОЛЬКО ЛОКАЛЬНО / БЕЗ ОТПРАВКИ ДАННЫХ")
    return "\n".join(PackedStringArray(lines))
