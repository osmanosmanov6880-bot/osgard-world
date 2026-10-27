extends RefCounted
class_name A7IncidentDirector
## W65 ORIGINAL procedural writing and transparent direct-effect forecasts.
## No deterministic game rule is changed; this presents already-defined facts.

const RU_BEATS := [
    {"id": "wake", "title": "01 / ТИХИЙ ИМПУЛЬС", "body": "В отсеке A7 пробуждается сердечник. Две команды — и система ответит вам сама."},
    {"id": "thermal", "title": "02 / ТЕПЛОВОЙ СЛЕД", "body": "Температурная волна прошла сквозь корпус. Исправление одного контура может нагрузить другой."},
    {"id": "blind", "title": "03 / СЛЕПОЙ СИГНАЛ", "body": "Отголосок сбоя искажает диаграмму. Будьте внимательны: качество сигнала — тоже ресурс."},
    {"id": "pressure", "title": "04 / СДВИГ КОРПУСА", "body": "Новая вибрация раскачала систему. Только последовательность действий решит исход."},
    {"id": "reserve", "title": "05 / ПОСЛЕДНИЙ РЕЗЕРВ", "body": "Автономная станция теряет запас энергии. Вы уже видите цену поспешных решений."},
    {"id": "finale", "title": "06 / ПОСЛЕДНИЙ РУБЕЖ", "body": "Остался один цикл. Удержите шесть параметров в допуске — или посмотрите последствия."},
]
const EN_BEATS := [
    {"id": "wake", "title": "01 / THE SILENT PULSE", "body": "The A7 core stirs. Two commands remain before the facility answers for itself."},
    {"id": "thermal", "title": "02 / THERMAL ECHO", "body": "A heat wave has passed through the chamber. Fixing one loop may burden another."},
    {"id": "blind", "title": "03 / BLIND SIGNAL", "body": "The aftermath of the fault distorts your readings. Signal fidelity is a finite resource."},
    {"id": "pressure", "title": "04 / THE STRUCTURAL SHIFT", "body": "A new vibration spreads through the facility. Order, not speed, determines the outcome."},
    {"id": "reserve", "title": "05 / THE FINAL RESERVE", "body": "The autonomous station is losing power. Every reckless action now has a visible cost."},
    {"id": "finale", "title": "06 / LAST FRONTIER", "body": "One cycle remains. Balance all six systems or face the consequences."},
]
const RU_END := {
    "won": {"id": "won", "title": "A7 / КОМПЛЕКС УДЕРЖАН", "body": "Вы не просто пережили аварийную смену: ваши решения стабилизировали систему."},
    "failed": {"id": "failed", "title": "A7 / КОНТРОЛЬ ПОТЕРЯН", "body": "Один из параметров вышел за пределы игры. Измените порядок действий и попробуйте снова."},
    "unstable": {"id": "unstable", "title": "A7 / ШЕСТЬ ЦИКЛОВ, НО НЕ ПОБЕДА", "body": "Комплекс продержался, однако параметры не стали безопасными. Попробуйте другую стратегию."},
}
const EN_END := {
    "won": {"id": "won", "title": "A7 / FACILITY STABILIZED", "body": "You did more than survive the last shift. Your decisions brought the whole system into balance."},
    "failed": {"id": "failed", "title": "A7 / CONTAINMENT LOST", "body": "A fictional limit was breached. Change the order of your actions and try again."},
    "unstable": {"id": "unstable", "title": "A7 / SIX CYCLES, NO VICTORY", "body": "The facility survived, but its systems remain unstable. Find a different strategy."},
}
const RU_TERMS := {
    "heat": "тепло", "pressure": "давление", "seal": "герметичность",
    "signal": "сигнал", "energy": "энергия", "integrity": "целостность",
}
const EN_TERMS := {
    "heat": "heat", "pressure": "pressure", "seal": "seal",
    "signal": "signal", "energy": "energy", "integrity": "integrity",
}

static func describe(locale: String, snapshot: Dictionary) -> Dictionary:
    var russian: bool = locale == "ru"
    var status: String = str(snapshot.get("status", "playing"))
    if status != "playing":
        return (RU_END if russian else EN_END).get(status, {}).duplicate(true)
    var index: int = clampi(int(snapshot.get("shift", 0)), 0, 5)
    var data: Dictionary = (RU_BEATS if russian else EN_BEATS)[index].duplicate(true)
    # Show actual gameplay consequence, not a generic false cinematic alert.
    var event: String = str(snapshot.get("last_event", ""))
    if event.begins_with("damage_"):
        var loss: int = maxi(0, int(event.trim_prefix("damage_")))
        var detail: String = ("ЦЕЛОСТНОСТЬ -%d. " if russian else "CONTAINMENT -%d. ") % loss
        data["body"] = detail + str(data["body"])
    data["round"] = index + 1
    data["status"] = status
    return data

static func preview(locale: String, action: String, stats: Dictionary) -> Dictionary:
    var russian: bool = locale == "ru"
    if not A7CascadeCore.ACTIONS.has(action):
        return {"valid": false, "headline": "", "body": "", "risk": false}
    var delta: Dictionary = A7CascadeCore.ACTIONS[action]
    var keys: Array[String] = ["heat", "pressure", "seal", "signal", "energy"]
    var titles: Dictionary = RU_TERMS if locale == "ru" else EN_TERMS
    var fragments: PackedStringArray = PackedStringArray()
    var risk: bool = false
    var projected: Dictionary = stats.duplicate(true)
    for key in keys:
        if not delta.has(key):
            continue
        var before: int = int(stats.get(key, 0))
        var value: int = clampi(before + int(delta[key]), 0, 100)
        projected[key] = value
        var sign: String = "+" if int(delta[key]) >= 0 else ""
        fragments.append("%s %s%d" % [str(titles[key]), sign, int(delta[key])])
        if (key == "heat" or key == "pressure") and value >= 85:
            risk = true
        if (key == "seal" or key == "signal" or key == "energy") and value < 25:
            risk = true
    var title: String = ("РИСК ДЛЯ СИСТЕМЫ" if russian else "SYSTEM RISK") if risk else (
        "ПРЯМОЙ ЭФФЕКТ" if russian else "DIRECT EFFECT")
    var warning: String = " / ПОСЛЕ ВТОРОГО ДЕЙСТВИЯ БУДЕТ СОБЫТИЕ" if russian else (
        " / INCIDENT AFTER SECOND ACTION")
    return {
        "valid": true, "action": action, "headline": title,
        "body": "  /  ".join(fragments) + warning,
        "risk": risk, "projected": projected,
        "model_changed": false,
        "industrial_advice": false,
    }
