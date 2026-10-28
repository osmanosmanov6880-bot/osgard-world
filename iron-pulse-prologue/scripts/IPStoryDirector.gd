extends RefCounted
class_name IPStoryDirector
## IRON PULSE V6 — original narrative, localized radio dialogue and choice consequences.
## The 3 acts are short story beats in the actual playable vertical slice.
## No generated voices, third-party fiction or external services.

const MAX_LINES: int = 24
const SCENARIOS: Array[String] = ["blackout","thermal","breach"]
const SPEAKERS := {
    "mara": {"ru":"МАРА / ОПЕРАТОР", "en":"MARA / CONTROL"},
    "zion": {"ru":"СИСТЕМА A7", "en":"A7 / SYSTEM"}
}
const SCRIPT := {
    "ru": {
        "arrival_blackout":"МАРА: Оператор, если слышишь — энергосеть разрушена. Я выведу тебя к экипажу. Действуй осторожно.",
        "arrival_thermal":"МАРА: A7 разогревается. Датчики показывают повторные тепловые удары. Нам нужен холодный расчёт.",
        "arrival_breach":"МАРА: В жилом секторе падает давление. С каждым вдохом времени меньше. Найди источник утечки.",
        "scan":"МАРА: Диагноз подтверждён. Прежде чем чинить контур, реши, что важнее: защитить экипаж или стабилизировать ядро. [1] / [2]",
        "priority_crew":"МАРА: Приоритет людям. Кислород перенаправлен в жилой сектор, но ядро стало горячее.",
        "priority_core":"МАРА: Приоритет реактору. Температура падает, но часть ресурсов экипажа потеряна.",
        "priority_skip":"МАРА: Ты оставил приказ открытым. Решение всё равно отзовётся на итоговом отчёте.",
        "repair_standard":"МАРА: Контур восстановлен. Впереди две линии питания и три устройства. Выбери безопасную последовательность.",
        "repair_careful":"МАРА: Тщательный ремонт стоил времени, но люди выдержали. Не забывай об аварийном шлюзе.",
        "repair_fast":"МАРА: Быстро, но дорого. Я фиксирую потери экипажа; следующий выбор должен быть точным.",
        "surge":"СИСТЕМА A7: СКАЧОК НАПРЯЖЕНИЯ. Ожидается нестабильная температура.",
        "thermal_pulse":"СИСТЕМА A7: ПОВТОРНЫЙ ТЕПЛОВОЙ ИМПУЛЬС. Не оставляйте охлаждение без питания.",
        "bus_switched":"МАРА: Питание перенаправлено. Следи одновременно за кислородом, теплом и зарядом двери.",
        "sector_service":"МАРА: Ты в техническом секторе. За стеной слышу живые сигналы — экипаж ещё здесь.",
        "sector_evacuation":"МАРА: Шлюз близко. Сначала верни жизненно важные контуры и подтверди допуск.",
        "override":"МАРА: Доступ подтверждён. Ты можешь вывести людей. Я оставляю линию открытой.",
        "ending_crew":"МАРА: Люди вышли. Ты рисковал ядром, чтобы дать им воздух. Это решение войдёт в хронику A7.",
        "ending_core":"МАРА: Комплекс уцелел благодаря твоему выбору. Теперь нам придётся ответить за цену спасённой системы.",
        "ending_none":"МАРА: Эвакуация завершена. Ты справился без отдельного приказа о приоритетах. Последствия всё равно останутся.",
        "failure":"МАРА: Связь пропадает... Мы зафиксировали все решения. У тебя будет шанс понять, где пошло не так."
    },
    "en": {
        "arrival_blackout":"MARA: If you can hear me, the power grid is broken. I'll guide you to the trapped crew. Move carefully.",
        "arrival_thermal":"MARA: Reactor A7 is heating fast. The sensors show repeating thermal shocks. We need clear decisions.",
        "arrival_breach":"MARA: The habitable sector is losing pressure. Every breath costs time. Find the breach.",
        "scan":"MARA: Diagnosis confirmed. Before repairs, choose what matters most: protect the crew or stabilize the core. [1] / [2]",
        "priority_crew":"MARA: Crew first. Oxygen was redirected to the living quarters, but the reactor grew hotter.",
        "priority_core":"MARA: Reactor first. Temperature is dropping, but the crew sacrificed precious supplies.",
        "priority_skip":"MARA: You left the priority unresolved. That choice, too, will appear in the final report.",
        "repair_standard":"MARA: Cooling restored. Two power buses, three critical loads. Choose a safe sequence.",
        "repair_careful":"MARA: The careful repair took time, but the crew survived it. Don't forget the bulkhead.",
        "repair_fast":"MARA: Fast, but costly. I've recorded the crew losses; make your next choice count.",
        "surge":"A7 SYSTEM: POWER SURGE. Reactor temperature instability expected.",
        "thermal_pulse":"A7 SYSTEM: RECURRING THERMAL SHOCK. Keep power on cooling.",
        "bus_switched":"MARA: Power transferred. Watch oxygen, reactor temperature and the door capacitor together.",
        "sector_service":"MARA: You made it to the service spine. I can still hear the crew through the walls.",
        "sector_evacuation":"MARA: The airlock is close. Restore critical systems and authorize evacuation first.",
        "override":"MARA: Access confirmed. Get them out. I'm keeping the channel open.",
        "ending_crew":"MARA: They're out. You risked the core to keep them breathing. That choice is now part of A7's history.",
        "ending_core":"MARA: The complex survived because of your decision. We'll still have to answer for the cost.",
        "ending_none":"MARA: Evacuation complete. You managed without a separate priority order. Consequences remain.",
        "failure":"MARA: Signal fading... We logged your decisions. Next time, we'll know where it went wrong."
    }
}
const KEY_TO_ACT := {
    "scan":1,"priority_crew":1,"priority_core":1,"priority_skip":1,
    "repair_standard":2,"repair_careful":2,"repair_fast":2,
    "surge":2,"thermal_pulse":2,"bus_switched":2,"sector_service":2,
    "sector_evacuation":3,"override":3,
    "ending_crew":3,"ending_core":3,"ending_none":3,"failure":3
}
const SOURCE_EVENTS := {
    "core_scanned":"scan",
    "coolant_repaired":"repair_standard",
    "thermal_stabilized":"repair_careful",
    "breach_sealed":"repair_careful",
    "thermal_purged":"repair_fast",
    "breach_patched":"repair_fast",
    "surge":"surge",
    "thermal_pulse":"thermal_pulse",
    "bus_switched":"bus_switched",
    "override_authorized":"override",
    "reactor_overheat":"failure",
    "life_support_lost":"failure",
    "time_expired":"failure"
}

var scenario: String = "blackout"
var act: int = 0
var journal: Array[Dictionary] = []
var heard: Array[String] = []
var latest_key: String = ""
var transmissions: int = 0

func reset(next_scenario: String = "blackout") -> void:
    scenario = next_scenario if SCENARIOS.has(next_scenario) else "blackout"
    act = 0
    journal.clear()
    heard.clear()
    latest_key = ""
    transmissions = 0
    _transmit("arrival_" + scenario)

func _known(key: String) -> bool:
    return SCRIPT["ru"].has(key) and SCRIPT["en"].has(key)

func _transmit(key: String) -> bool:
    if not _known(key) or heard.has(key):
        return false
    heard.append(key)
    latest_key = key
    act = maxi(act,int(KEY_TO_ACT.get(key,0)))
    transmissions += 1
    var speaker: String = "zion" if key in ["surge","thermal_pulse"] else "mara"
    journal.append({"key":key,"speaker":speaker,"act":act})
    if journal.size() > MAX_LINES:
        journal.pop_front()
    return true

func on_game_event(event_name: String, priority: String) -> bool:
    if event_name == "priority_crew" or event_name == "priority_core":
        return _transmit(event_name)
    if event_name == "crew_evacuated":
        var ending: String = priority if priority in ["crew","core"] else "none"
        return _transmit("ending_" + ending)
    if SOURCE_EVENTS.has(event_name):
        return _transmit(str(SOURCE_EVENTS[event_name]))
    return false

func enter_sector(sector_id: String) -> bool:
    if sector_id == "service" or sector_id == "evacuation":
        return _transmit("sector_" + sector_id)
    return false

func latest(locale: String = "ru") -> Dictionary:
    if latest_key == "" or not _known(latest_key):
        return {}
    var language: String = locale if SCRIPT.has(locale) else "en"
    var source: String = "zion" if latest_key in ["surge","thermal_pulse"] else "mara"
    return {
        "speaker":str(SPEAKERS[source][language]),
        "text":str(SCRIPT[language][latest_key]),
        "key":latest_key,
        "act":act
    }

func journal_localized(locale: String = "ru") -> String:
    var language: String = locale if SCRIPT.has(locale) else "en"
    var lines: Array[String] = []
    for entry in journal:
        var key: String = str(entry["key"])
        if _known(key):
            lines.append(str(SCRIPT[language][key]))
    return "\n\n".join(lines)

func checkpoint() -> Dictionary:
    return {
        "schema":"IRON_PULSE_STORY_V6",
        "scenario":scenario,
        "act":act,
        "journal":journal.duplicate(true),
        "heard":heard.duplicate(),
        "latest_key":latest_key,
        "transmissions":transmissions
    }

func restore(data: Dictionary) -> bool:
    if data.get("schema") != "IRON_PULSE_STORY_V6":
        return false
    if not SCENARIOS.has(str(data.get("scenario",""))):
        return false
    var saved_journal: Variant = data.get("journal",null)
    var saved_heard: Variant = data.get("heard",null)
    if not saved_journal is Array or not saved_heard is Array:
        return false
    if saved_journal.size() > MAX_LINES or saved_heard.size() > 60:
        return false
    var checked_journal: Array[Dictionary] = []
    var checked_heard: Array[String] = []
    for val in saved_journal:
        if not val is Dictionary:
            return false
        var key: String = str(val.get("key",""))
        if not _known(key):
            return false
        var speaker: String = str(val.get("speaker",""))
        if speaker not in ["mara","zion"]:
            return false
        checked_journal.append({"key":key,"speaker":speaker,"act":clampi(int(val.get("act",0)),0,3)})
    for val in saved_heard:
        if not val is String or not _known(str(val)) or checked_heard.has(str(val)):
            return false
        checked_heard.append(str(val))
    var latest: String = str(data.get("latest_key",""))
    if latest != "" and not checked_heard.has(latest):
        return false
    var new_act: int = int(data.get("act",-1))
    if new_act < 0 or new_act > 3:
        return false
    var new_transmissions: int = int(data.get("transmissions",-1))
    if new_transmissions < 0 or new_transmissions > 1000:
        return false
    scenario = str(data["scenario"])
    act = new_act
    journal = checked_journal
    heard = checked_heard
    latest_key = latest
    transmissions = new_transmissions
    return true

func diagnostic() -> Dictionary:
    return {
        "act":act,"latest_key":latest_key,"transmissions":transmissions,
        "journal_entries":journal.size(),"scenario":scenario
    }
