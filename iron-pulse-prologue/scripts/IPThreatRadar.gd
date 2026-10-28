extends RefCounted
class_name IPThreatRadar
## V16: honest, read-only analysis of the CURRENT fictional A7 simulation.
## No outside data, forecasting shortcuts, hardware claims or game commands.

const FORMAT: String = "IRON_PULSE_THREAT_RADAR_V16"
const LEVELS: Array[String] = ["STABLE","WATCH","CRITICAL","FAILED","COMPLETE"]
const REASONS: Array[String] = [
    "nominal","thermal","oxygen","crew","clock","coolant","life",
    "pulse","unsealed","microleak","evacuated","reactor_overheat",
    "life_support_lost","time_expired"
]

func snapshot(engine: IPCrisisEngine) -> Dictionary:
    if engine == null:
        return {}
    var tier: String = "STABLE"
    var reason: String = "nominal"
    var pulse_seconds: float = -1.0
    var microleak: bool = engine.scenario_id == "breach" and engine.coolant_repaired and engine.repair_method == "rapid_patch"
    var unsealed: bool = engine.scenario_id == "breach" and not engine.coolant_repaired
    if engine.scenario_id == "thermal" and not engine.finished():
        pulse_seconds = maxf(0.0,engine.next_pulse_at-engine.elapsed)
    if engine.won:
        tier = "COMPLETE"
        reason = "evacuated"
    elif engine.lost:
        tier = "FAILED"
        if engine.heat >= 100.0:
            reason = "reactor_overheat"
        elif engine.oxygen <= 0.0 or engine.crew_health <= 0.0:
            reason = "life_support_lost"
        elif engine.time_left <= 0.0:
            reason = "time_expired"
        else:
            reason = "clock"
    elif engine.heat >= 88.0:
        tier = "CRITICAL"
        reason = "thermal"
    elif engine.oxygen <= 25.0:
        tier = "CRITICAL"
        reason = "oxygen"
    elif engine.crew_health <= 25.0:
        tier = "CRITICAL"
        reason = "crew"
    elif engine.time_left <= 25.0:
        tier = "CRITICAL"
        reason = "clock"
    elif engine.heat >= 75.0:
        tier = "WATCH"
        reason = "thermal"
    elif engine.oxygen <= 50.0:
        tier = "WATCH"
        reason = "oxygen"
    elif engine.crew_health <= 55.0:
        tier = "WATCH"
        reason = "crew"
    elif engine.time_left <= 70.0:
        tier = "WATCH"
        reason = "clock"
    elif pulse_seconds >= 0.0 and pulse_seconds <= 20.0:
        tier = "WATCH"
        reason = "pulse"
    elif microleak:
        tier = "WATCH"
        reason = "microleak"
    elif unsealed:
        tier = "WATCH"
        reason = "unsealed"
    elif not engine.powered("coolant"):
        tier = "WATCH"
        reason = "coolant"
    elif not engine.powered("life"):
        tier = "WATCH"
        reason = "life"
    return {
        "schema":FORMAT,
        "scenario":engine.scenario_id,
        "tier":tier,
        "reason":reason,
        "thermal_pulse_in_s":snappedf(pulse_seconds,0.1) if pulse_seconds >= 0.0 else -1.0,
        "microleak":microleak,
        "coolant_powered":engine.powered("coolant"),
        "life_powered":engine.powered("life"),
        "time_left":snappedf(engine.time_left,0.1),
        "heat":snappedf(engine.heat,0.1),
        "oxygen":snappedf(engine.oxygen,0.1),
        "crew":snappedf(engine.crew_health,0.1),
        "finished":engine.finished()
    }

func cockpit_text(report: Dictionary,locale: String = "ru") -> String:
    if report.is_empty():
        return ""
    var english: bool = locale == "en"
    var severity: String = str(report.get("tier","STABLE"))
    var reason: String = str(report.get("reason","nominal"))
    var levels: Dictionary = {
        "STABLE":["НОРМА","NOMINAL"],"WATCH":["РИСК","WATCH"],
        "CRITICAL":["КРИТИЧНО","CRITICAL"],"FAILED":["ПРОВАЛ","FAILED"],
        "COMPLETE":["ЭВАКУАЦИЯ","EVACUATED"]
    }
    var labels: Dictionary = {
        "nominal":["ПОКАЗАТЕЛИ ПОД КОНТРОЛЕМ","SYSTEMS WITHIN LIMITS"],
        "thermal":["ТЕМПЕРАТУРА ЯДРА","REACTOR TEMPERATURE"],
        "oxygen":["ЗАПАС КИСЛОРОДА","OXYGEN RESERVE"],
        "crew":["СОСТОЯНИЕ ЭКИПАЖА","CREW CONDITION"],
        "clock":["ОСТАТОК ВРЕМЕНИ","REMAINING TIME"],
        "coolant":["НЕТ ПИТАНИЯ COOLANT","COOLANT BUS OFFLINE"],
        "life":["НЕТ ПИТАНИЯ LIFE","LIFE BUS OFFLINE"],
        "pulse":["СКОРО ТЕПЛОВОЙ ИМПУЛЬС","THERMAL PULSE APPROACHING"],
        "unsealed":["УТЕЧКА НЕ УСТРАНЕНА","BREACH NOT SEALED"],
        "microleak":["ОСТАТОЧНАЯ МИКРОУТЕЧКА","RESIDUAL MICRO-LEAK"],
        "evacuated":["ЭКИПАЖ ЭВАКУИРОВАН","CREW EVACUATED"],
        "reactor_overheat":["ПЕРЕГРЕВ ЯДРА","CORE OVERHEAT"],
        "life_support_lost":["ЖИЗНЕОБЕСПЕЧЕНИЕ ПОТЕРЯНО","LIFE SUPPORT LOST"],
        "time_expired":["ВРЕМЯ ИСТЕКЛО","TIME EXPIRED"]
    }
    var index: int = 1 if english else 0
    if not levels.has(severity) or not labels.has(reason):
        return ""
    var suffix: String = ""
    if reason == "pulse":
        suffix = " / %ds" % ceili(float(report.get("thermal_pulse_in_s",0.0)))
    return "A7 / %s\n%s%s" % [str(levels[severity][index]),str(labels[reason][index]),suffix]
