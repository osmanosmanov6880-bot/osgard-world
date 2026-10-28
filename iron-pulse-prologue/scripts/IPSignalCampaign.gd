extends RefCounted
class_name IPSignalCampaign
## V9 / THE SIGNAL CHAIN: a new optional multi-sector 3-stage mission.
## All resource costs mutate the SAME validated IPCrisisEngine, not a fake UI.
## Existing V6/V7 checkpoints import as an untouched optional story campaign.
const FORMAT: String = "IRON_PULSE_SIGNAL_CHAIN_V9"
const SIGNALS: Array[String] = ["resonance","atmosphere","transit"]
const DIRECTIVES: Array[String] = ["crew","core"]
const SIGNAL_COST_SEC: float = 6.0
const DIRECTIVE_COST_SEC: float = 8.0

var collected: Array[String] = []
var directive: String = ""

func reset() -> void:
    collected.clear()
    directive = ""

func completed() -> bool:
    return directive != ""

func available(signal_id: String, engine: IPCrisisEngine) -> bool:
    return SIGNALS.has(signal_id) and engine.core_scanned and not engine.finished() and not collected.has(signal_id) and directive == ""

func collect(signal_id: String, engine: IPCrisisEngine) -> bool:
    if not available(signal_id,engine):
        return engine._reject()
    # The 6-second scan is a genuine emergency cost. Failure during it yields
    # no free benefit, even if heat/oxygen expired before signal acquisition.
    engine.tick(SIGNAL_COST_SEC)
    if engine.finished():
        return false
    match signal_id:
        "resonance":
            # Reactor signal noise can be filtered at an oxygen cost.
            engine.heat = maxf(0.0,engine.heat-7.0)
            engine.oxygen = maxf(0.0,engine.oxygen-4.0)
        "atmosphere":
            # Deep-life support telemetry stabilizes crew air at thermal cost.
            engine.oxygen = minf(100.0,engine.oxygen+10.0)
            engine.heat = minf(110.0,engine.heat+4.0)
        "transit":
            # A charged evacuation route costs crew condition.
            engine.door_charge = minf(100.0,engine.door_charge+14.0)
            engine.crew_health = maxf(0.0,engine.crew_health-5.0)
    collected.append(signal_id)
    engine._record("signal_" + signal_id)
    return true

func route_unlocked() -> bool:
    return collected.size() == SIGNALS.size() and directive == ""

func commit_route(choice: String, engine: IPCrisisEngine) -> bool:
    if not DIRECTIVES.has(choice) or not route_unlocked() or engine.finished() or not engine.core_scanned:
        return engine._reject()
    engine.tick(DIRECTIVE_COST_SEC)
    if engine.finished():
        return false
    if choice == "crew":
        # Evacuate people at the expense of reactor containment stability.
        engine.oxygen = minf(100.0,engine.oxygen+13.0)
        engine.crew_health = minf(100.0,engine.crew_health+12.0)
        engine.heat = minf(110.0,engine.heat+8.0)
    else:
        # Shield reactor, preserving the complex but sacrificing crew supplies.
        engine.heat = maxf(0.0,engine.heat-17.0)
        engine.oxygen = maxf(0.0,engine.oxygen-7.0)
        engine.crew_health = maxf(0.0,engine.crew_health-4.0)
    directive = choice
    engine._record("directive_" + choice)
    return true

func diagnostic() -> Dictionary:
    return {
        "mission":"SIGNAL_CHAIN",
        "collected":collected.duplicate(),
        "collected_count":collected.size(),
        "max_signals":SIGNALS.size(),
        "route_unlocked":route_unlocked(),
        "directive":directive,
        "completed":completed()
    }

func checkpoint() -> Dictionary:
    return {
        "schema":FORMAT,
        "signals":collected.duplicate(),
        "directive":directive
    }

func restore(data: Dictionary, engine: IPCrisisEngine) -> bool:
    # Restore MUST be all-or-nothing; validate before assigning any fields.
    # Legacy V6 saves have no signal-chain key and restore as fresh content.
    if data.is_empty():
        reset()
        return true
    if data.get("schema") != FORMAT:
        return false
    var raw_signals: Variant = data.get("signals",null)
    var raw_directive: Variant = data.get("directive",null)
    if not raw_signals is Array or not raw_directive is String:
        return false
    if raw_signals.size() > SIGNALS.size():
        return false
    var checked: Array[String] = []
    for item in raw_signals:
        if not item is String or not SIGNALS.has(str(item)) or checked.has(str(item)):
            return false
        checked.append(str(item))
    if raw_directive != "" and not DIRECTIVES.has(str(raw_directive)):
        return false
    if raw_directive != "" and checked.size() != SIGNALS.size():
        return false
    if not engine.core_scanned and not checked.is_empty():
        return false
    if not engine.core_scanned and raw_directive != "":
        return false
    collected = checked
    directive = str(raw_directive)
    return true
