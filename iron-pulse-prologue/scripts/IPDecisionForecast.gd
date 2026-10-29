extends RefCounted
class_name IPDecisionForecast
## V15: Forecast actual deterministic A7 crisis engine on isolated cloned state.
## No real-world equipment guidance, autoplay, fake win/score or state mutation.
## Does NOT predict future player movement, interactions or campaign choices.

const WINDOW_SECONDS: float = 30.0
const MAX_ROUTES: int = 3

func evaluate(source: IPCrisisEngine) -> Dictionary:
    if source == null:
        return {}
    var checkpoint: Dictionary = source.checkpoint()
    var routes: Array[Dictionary] = []
    var hold: Dictionary = _project(checkpoint,-1)
    if hold.is_empty():
        return {}
    routes.append(hold)
    # Only compare power routes when a real player would already be permitted
    # to switch the physical bus console. Do not unlock or activate terminals.
    if source.coolant_repaired and not source.finished():
        for index in [0,1]:
            var alternative: Dictionary = _project(checkpoint,index)
            if not alternative.is_empty():
                routes.append(alternative)
    return {
        "schema":"IRON_PULSE_DECISION_FORECAST_V15",
        "scenario":source.scenario_id,
        "horizon_seconds":WINDOW_SECONDS,
        "assumption":"no further player interactions",
        "actual_buses":[source.bus_a,source.bus_b],
        "comparison_available":source.coolant_repaired and not source.finished(),
        "routes":routes
    }

func _project(saved: Dictionary,bus_index: int) -> Dictionary:
    var simulation := IPCrisisEngine.new()
    # A forged/incompatible checkpoint must never be projected.
    if not simulation.restore_checkpoint(saved):
        return {}
    var original_elapsed: float = simulation.elapsed
    if bus_index >= 0 and not simulation.cycle_bus(bus_index):
        return {}
    # This invokes the ORIGINAL engine including pulses, leaks, relay costs
    # and the original 0.1s deterministic internal integrator.
    simulation.tick(WINDOW_SECONDS)
    var severity: String = "STABLE"
    if simulation.lost:
        severity = "FAILURE"
    elif simulation.heat >= 85.0 or simulation.oxygen < 30.0 or simulation.crew_health < 35.0:
        severity = "CRITICAL"
    elif simulation.heat >= 74.0 or simulation.oxygen < 50.0 or simulation.crew_health < 60.0:
        severity = "WATCH"
    return {
        "bus_index":bus_index,
        "bus_a":simulation.bus_a,
        "bus_b":simulation.bus_b,
        "severity":severity,
        "predicted_seconds":snappedf(simulation.elapsed-original_elapsed,0.1),
        "heat":snappedf(simulation.heat,0.1),
        "oxygen":snappedf(simulation.oxygen,0.1),
        "crew":snappedf(simulation.crew_health,0.1),
        "door":snappedf(simulation.door_charge,0.1),
        "loss":simulation.lost,
        "loss_reason":simulation.last_event if simulation.lost else "",
        "pulse_count":simulation.thermal_pulses,
        "time_left":snappedf(simulation.time_left,0.1)
    }

func text_report(report: Dictionary,locale: String = "ru") -> String:
    var english: bool = locale == "en"
    if report.is_empty():
        return "NO SIMULATION" if english else "ПРОГНОЗ НЕДОСТУПЕН"
    var result: Array[String] = []
    result.append("A7 / DECISION WINDOW  +30s" if english else "A7 / ПРОГНОЗ РЕШЕНИЙ  +30с")
    result.append("Assumes no further actions." if english else "Без будущих действий игрока.")
    for route in report.get("routes",[]):
        var bus_index: int = int(route.get("bus_index",-1))
        var label: String = "HOLD" if english else "БЕЗ СМЕНЫ"
        if bus_index >= 0:
            label = "SWITCH A" if bus_index == 0 else "SWITCH B"
            if not english:
                label = "СМЕНА A" if bus_index == 0 else "СМЕНА B"
        var status: String = str(route.get("severity",""))
        if not english:
            match status:
                "STABLE": status = "СТАБИЛЬНО"
                "WATCH": status = "РИСК"
                "CRITICAL": status = "КРИТИЧНО"
                "FAILURE": status = "ПРОВАЛ"
        result.append("%s  >  %s / %s  [%s]" % [
            label,str(route.get("bus_a","")).to_upper(),
            str(route.get("bus_b","")).to_upper(),status])
        result.append("  %dC  /  O2 %d%%  /  CREW %d%%  /  DOOR %d%%" % [
            roundi(float(route.get("heat",0.0))),
            roundi(float(route.get("oxygen",0.0))),
            roundi(float(route.get("crew",0.0))),
            roundi(float(route.get("door",0.0)))])
    if not bool(report.get("comparison_available",false)):
        result.append("Repair first to compare routes." if english else "Сначала ремонт — затем сравнение.")
    result.append("READ-ONLY / NO COMMAND SENT" if english else "ТОЛЬКО ПРОГНОЗ / БЕЗ КОМАНД")
    return "\n".join(PackedStringArray(result))
