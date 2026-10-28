extends SceneTree
## V9: deterministic optional campaign checks against REAL IPCrisisEngine.
var checks: int = 0
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _check(yes: bool, label: String) -> void:
    checks += 1
    if not yes:
        failures.append(label)

func _run() -> void:
    var rules := IPSignalCampaign.new()
    var engine := IPCrisisEngine.new()
    engine.reset("blackout")
    _check(not rules.collect("resonance",engine),
        "Cannot acquire source signals before real reactor scanner")
    _check(rules.collected.is_empty(),"Pre-scan rejection never grants free signals")
    _check(not rules.collect("magic",engine),"Unknown signal ID always rejected")
    engine.scan_core()
    var starting_time: float = engine.time_left
    var heat_before: float = engine.heat
    _check(rules.collect("resonance",engine),"Resonance accepted after physical scanner")
    _check(rules.collected == ["resonance"] and engine.last_event == "signal_resonance",
        "Real event log recognizes acquired first signal")
    _check(engine.heat < heat_before and engine.oxygen <= 89.0,
        "Resonance really cools core, sacrificing air")
    _check(engine.time_left <= starting_time-5.9,
        "Signal analysis spends real simulated emergency time")
    var prior_oxygen: float = engine.oxygen
    _check(rules.collect("atmosphere",engine),"Atmosphere signal can be acquired in a new sector")
    _check(engine.oxygen > prior_oxygen and engine.heat > heat_before-7.0,
        "Second signal has distinct tradeoff: crew air versus reactor heat")
    var prior_charge: float = engine.door_charge
    var prior_crew: float = engine.crew_health
    _check(rules.collect("transit",engine),"Third independent transit signal can be acquired")
    _check(engine.door_charge > prior_charge and engine.crew_health < prior_crew,
        "Transit charges actual door and costs actual crew condition")
    _check(rules.route_unlocked() and rules.collected.size()==3 and not rules.completed(),
        "Collecting exactly three signals unlocks a new final engineering decision")
    _check(not rules.collect("resonance",engine) and rules.collected.size()==3,
        "All three one-shot signals are protected against resource farming")
    _check(not rules.collect("fake",engine) and rules.collected.size()==3,
        "Invented fourth signal cannot inflate progress")

    var branch_engine: Dictionary = engine.checkpoint()
    var branch_mission: Dictionary = rules.checkpoint()
    var copy_engine := IPCrisisEngine.new()
    _check(copy_engine.restore_checkpoint(branch_engine),
        "New campaign uses valid ordinary V6 engine checkpoint")
    var copy_mission := IPSignalCampaign.new()
    _check(copy_mission.restore(branch_mission,copy_engine),
        "Signal chain restores from independent validated V9 slot")
    _check(copy_mission.collected == rules.collected and copy_mission.route_unlocked(),
        "V9 checkpoint restores all three source-bound signals in order")

    var heat_initial: float = engine.heat
    var air_initial: float = engine.oxygen
    var crew_initial: float = engine.crew_health
    _check(rules.commit_route("crew",engine),"CREW route commits an irreversible moral choice")
    _check(rules.completed() and rules.directive == "crew" and engine.last_event == "directive_crew",
        "Real engine/journal records official evacuation directive")
    _check(engine.oxygen > air_initial and engine.crew_health > crew_initial,
        "Crew route genuinely restores life support and human condition")
    _check(engine.heat > heat_initial+5.0,
        "Crew priority imposes non-cosmetic reactor overheating cost")
    _check(not rules.commit_route("core",engine) and rules.directive=="crew",
        "Committed final directive cannot be overwritten or double rewarded")
    _check(engine.time_left < starting_time-25.0,
        "Three physical readings plus final protocol consume 26 real seconds")

    _check(copy_mission.commit_route("core",copy_engine),"CORE route is a distinct, reachable decision")
    _check(copy_mission.directive == "core" and copy_engine.last_event == "directive_core",
        "Opposite campaign ending is recorded independently")
    _check(copy_engine.heat < heat_initial-12.0 and copy_engine.oxygen < air_initial,
        "Reactor-protecting directive really trades oxygen for major heat reduction")
    _check(copy_engine.crew_health < crew_initial,
        "Reactor route makes distinct real crew-health sacrifice")
    _check(copy_mission.directive != rules.directive,
        "Identical pre-choice state supports two different consequences")

    var saved: Dictionary = rules.checkpoint()
    var resumed := IPSignalCampaign.new()
    _check(resumed.restore(saved,engine) and resumed.directive=="crew",
        "Saved irreversible choice restores with full progress")
    var source: Dictionary = saved.duplicate(true)
    source["directive"]="nobody"
    _check(not resumed.restore(source,engine) and resumed.directive=="crew",
        "Unlisted directive is rejected without partial mutation")
    source = saved.duplicate(true)
    source["signals"]=["resonance","resonance","transit"]
    _check(not resumed.restore(source,engine) and resumed.collected.size()==3,
        "Duplicate reward injection is rejected atomically")
    source = saved.duplicate(true)
    source["signals"]=["resonance"]
    _check(not resumed.restore(source,engine) and resumed.directive=="crew",
        "Forged final protocol with only one clue is rejected")
    source = saved.duplicate(true)
    source["signals"]=["resonance","atmosphere","transit","unknown"]
    _check(not resumed.restore(source,engine),
        "Over-capacity signal list is rejected")
    source = saved.duplicate(true)
    source["signals"]=["resonance","atmosphere","unknown"]
    _check(not resumed.restore(source,engine),
        "Unknown station ID cannot appear in imported checkpoint")
    var untouched := IPCrisisEngine.new()
    untouched.reset()
    _check(not resumed.restore(saved,untouched),
        "Campaign progress cannot be forged when reactor was never scanned")
    var legacy := IPSignalCampaign.new()
    _check(legacy.restore({},untouched) and legacy.collected.is_empty() and legacy.directive=="",
        "Every historical V6–V8 checkpoint can import as new optional mission")
    _check(not legacy.restore({"signals":[]},untouched),
        "Malformed unversioned signal data is rejected instead of trusted")
    resumed.reset()
    _check(resumed.collected.is_empty() and not resumed.route_unlocked() and not resumed.completed(),
        "Restart resets all optional signals and irreversible directive")

    var narrative := IPStoryDirector.new()
    narrative.reset("thermal")
    _check(narrative.on_game_event("signal_resonance","") and narrative.latest_key=="signal_resonance",
        "Original MARA dialogue reacts to first REAL signal in native engine")
    _check(narrative.on_game_event("signal_transit","") and narrative.latest("ru")["text"].contains("Маршрут"),
        "Third-sector transition has dedicated authored Russian radio")
    _check(narrative.on_game_event("directive_core","") and narrative.latest("en")["text"].contains("Reactor shield"),
        "Opposite directive has original translated authored English consequence")
    _check(narrative.journal_localized("en").contains("MARA"),
        "Independent portable radio journal keeps new story in EN")
    _finish()

func _finish() -> void:
    if failures.is_empty():
        print("IRON PULSE V9 SIGNAL CHAIN PASS: %d deterministic real-game checks" % checks)
        quit(0)
    else:
        for failure in failures:
            push_error("V9 SIGNAL CHAIN FAIL: "+failure)
        quit(1)
