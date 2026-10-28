extends RefCounted
class_name IPCampaignDirector
## IRON PULSE / V9 - THREE SHIFTS, an actual three-operation offline campaign.
##
## This class owns ONLY campaign progress and validated consequences.
## Existing IPCrisisEngine remains sole authority for all mechanical events.
## No accounts, network API, cloud saves, microtransactions or fake leaderboard.

const SCHEMA: String = "IRON_PULSE_THREE_SHIFTS_V9"
const CHAPTERS: Array[String] = ["blackout","thermal","breach"]
const TOTAL_CHAPTERS: int = 3
const ENDINGS: Array[String] = ["","humanity","balance","survival"]
const SUPPORTED_REPAIRS: Array[String] = [
    "standard","deep_stabilize","rapid_purge","full_seal","rapid_patch"
]

var active: bool = false
var chapter: int = 0
var history: Array[Dictionary] = []
var ending: String = ""
var last_carryover: Dictionary = {}

func reset() -> void:
    active = false
    chapter = 0
    history.clear()
    ending = ""
    last_carryover.clear()

func begin() -> void:
    reset()
    active = true

func complete() -> bool:
    return active and chapter == TOTAL_CHAPTERS and history.size() == TOTAL_CHAPTERS

func stage_scenario() -> String:
    if not active or complete() or chapter < 0 or chapter >= TOTAL_CHAPTERS:
        return ""
    return CHAPTERS[chapter]

func stage_number() -> int:
    return mini(TOTAL_CHAPTERS,chapter+1) if active else 0

func start_current(engine: IPCrisisEngine) -> bool:
    # It is valid to retry a failed chapter, but never to launch a completed
    # chapter again without explicitly starting a new campaign.
    if not active or complete() or chapter != history.size():
        return false
    engine.reset(CHAPTERS[chapter])
    last_carryover = {}
    if chapter > 0:
        _apply_previous_decisions(engine)
    return true

func _apply_previous_decisions(engine: IPCrisisEngine) -> void:
    # Each player choice has a bounded, deterministic and measurable
    # consequence in the NEXT real episode. It is never a cosmetic caption.
    var previous: Dictionary = history[chapter-1]
    var inherited_heat: float = clampf((float(previous["heat"])-60.0)*0.18,-4.0,8.0)
    var inherited_oxygen: float = clampf((float(previous["oxygen"])-75.0)*0.20,-7.0,4.0)
    var inherited_crew: float = clampf((float(previous["crew"])-82.0)*0.36,-10.0,6.0)
    if str(previous["priority"]) == "crew":
        inherited_heat += 3.0
        inherited_oxygen += 3.5
        inherited_crew += 2.0
    elif str(previous["priority"]) == "core":
        inherited_heat -= 3.0
        inherited_oxygen -= 1.0
        inherited_crew -= 2.0
    if previous["relays"].has("medbay"):
        inherited_crew += 3.0
    if previous["relays"].has("quench"):
        inherited_heat -= 2.0
    if previous["relays"].has("uplink"):
        inherited_oxygen += 2.0
    engine.heat = clampf(engine.heat+inherited_heat,35.0,84.0)
    engine.oxygen = clampf(engine.oxygen+inherited_oxygen,45.0,100.0)
    engine.crew_health = clampf(engine.crew_health+inherited_crew,65.0,100.0)
    last_carryover = {
        "source_chapter":chapter,
        "heat_delta":snappedf(inherited_heat,0.01),
        "oxygen_delta":snappedf(inherited_oxygen,0.01),
        "crew_delta":snappedf(inherited_crew,0.01),
        "new_heat":engine.heat,
        "new_oxygen":engine.oxygen,
        "new_crew":engine.crew_health
    }

func record_victory(engine: IPCrisisEngine) -> bool:
    # Never credit a chapter from the menu, on a failed run, in the wrong
    # scenario, or multiple times from repeated end-panel refreshes.
    if not active or complete() or not engine.won or engine.lost:
        return false
    if engine.scenario_id != stage_scenario() or history.size() != chapter:
        return false
    var relay_choices: Array[String] = engine.relays_activated.duplicate()
    var points: int = clampi(
        roundi(300.0 + 3.0*engine.crew_health + 1.5*engine.oxygen
            + 1.0*engine.time_left - 1.5*engine.heat
            - 11.0*float(engine.faults) - 2.0*float(engine.switches)),
        0,1000)
    var episode: Dictionary = {
        "scenario":engine.scenario_id,
        "grade":engine.grade(),
        "score":points,
        "heat":snappedf(engine.heat,0.001),
        "oxygen":snappedf(engine.oxygen,0.001),
        "crew":snappedf(engine.crew_health,0.001),
        "elapsed":snappedf(engine.elapsed,0.001),
        "priority":engine.priority_id,
        "repair":engine.repair_method,
        "relays":relay_choices,
        "faults":engine.faults
    }
    history.append(episode)
    chapter += 1
    if complete():
        ending = _derive_ending(history)
    last_carryover.clear()
    return true

func _derive_ending(episodes: Array[Dictionary]) -> String:
    if episodes.size() != TOTAL_CHAPTERS:
        return ""
    var total_score: int = 0
    var crew_orders: int = 0
    var worst_crew: float = 100.0
    for entry in episodes:
        total_score += int(entry["score"])
        worst_crew = minf(worst_crew,float(entry["crew"]))
        if str(entry["priority"]) == "crew":
            crew_orders += 1
    if crew_orders >= 2 and worst_crew >= 55.0 and total_score >= 1450:
        return "humanity"
    if total_score >= 1450 and worst_crew >= 45.0:
        return "balance"
    return "survival"

func total_score() -> int:
    var combined: int = 0
    for entry in history:
        combined += int(entry.get("score",0))
    return combined

func summary(locale: String = "ru") -> String:
    if not active:
        return ""
    var stage: String = "ГЛАВА" if locale == "ru" else "CHAPTER"
    var progress: String = "%s %d/3   |   %s %d" % [
        stage,stage_number(),"ОЧКИ" if locale == "ru" else "SCORE",total_score()]
    if complete():
        var names_ru: Dictionary = {"humanity":"ЛЮДИ ПРЕЖДЕ ВСЕГО","balance":"СИСТЕМА СОХРАНЕНА","survival":"ЦЕНА ВЫЖИВАНИЯ"}
        var names_en: Dictionary = {"humanity":"HUMANITY FIRST","balance":"THE SYSTEM ENDURES","survival":"THE COST OF SURVIVAL"}
        var names: Dictionary = names_ru if locale == "ru" else names_en
        return progress + "\n" + str(names.get(ending,ending.to_upper()))
    if chapter > 0:
        var carry: Dictionary = last_carryover
        if not carry.is_empty():
            return progress + "\n" + (
                "ПОСЛЕДСТВИЯ РЕШЕНИЙ ПРЕДЫДУЩЕЙ ГЛАВЫ" if locale == "ru"
                else "YOUR LAST CHAPTER CHANGED THIS OPERATION")
    return progress

func checkpoint() -> Dictionary:
    return {
        "schema":SCHEMA,
        "active":active,
        "chapter":chapter,
        "history":history.duplicate(true),
        "ending":ending
    }

func _valid_stat(value: Variant, low: float, high: float) -> bool:
    if typeof(value) not in [TYPE_INT,TYPE_FLOAT]:
        return false
    var number: float = float(value)
    return number == number and number >= low and number <= high

func restore_checkpoint(saved: Dictionary) -> bool:
    # Validate EVERYTHING before mutating any campaign progress. This also
    # protects a valid V6/V8 checkpoint when a malformed V9 record is supplied.
    if saved.get("schema") != SCHEMA:
        return false
    if typeof(saved.get("active",null)) != TYPE_BOOL:
        return false
    # Godot JSON deserializes numeric values as floats; validate integer
    # SEMANTICS, not a raw TYPE_INT tag, to retain all old V6 checkpoints.
    if not _valid_stat(saved.get("chapter",null),0.0,float(TOTAL_CHAPTERS)):
        return false
    if float(saved["chapter"]) != floorf(float(saved["chapter"])):
        return false
    var next_active: bool = bool(saved["active"])
    var next_chapter: int = int(saved["chapter"])
    if next_chapter < 0 or next_chapter > TOTAL_CHAPTERS:
        return false
    var candidate: Variant = saved.get("history",null)
    if not candidate is Array or candidate.size() != next_chapter:
        return false
    var checked: Array[Dictionary] = []
    for index in range(candidate.size()):
        var source: Variant = candidate[index]
        if not source is Dictionary:
            return false
        var record: Dictionary = source as Dictionary
        if record.get("scenario") != CHAPTERS[index]:
            return false
        if str(record.get("grade","")) not in ["S","A","B"]:
            return false
        if not _valid_stat(record.get("score",null),0.0,1000.0):
            return false
        if float(record["score"]) != floorf(float(record["score"])):
            return false
        for key in ["heat","oxygen","crew","elapsed"]:
            var upper: float = 110.0 if key == "heat" else 1000.0 if key == "elapsed" else 100.0
            if not _valid_stat(record.get(key,null),0.0,upper):
                return false
        if record.get("priority") not in ["","crew","core"]:
            return false
        if record.get("repair") not in SUPPORTED_REPAIRS:
            return false
        if not _valid_stat(record.get("faults",null),0.0,1000.0):
            return false
        if float(record["faults"]) != floorf(float(record["faults"])):
            return false
        var relays: Variant = record.get("relays",null)
        if not relays is Array or relays.size() > IPCrisisEngine.MAX_RELAYS:
            return false
        var checked_relays: Array[String] = []
        for relay in relays:
            if not relay is String or not IPCrisisEngine.RELAYS.has(relay) or checked_relays.has(relay):
                return false
            checked_relays.append(relay)
        checked.append({
            "scenario":record["scenario"],
            "grade":record["grade"],
            "score":int(record["score"]),
            "heat":float(record["heat"]),
            "oxygen":float(record["oxygen"]),
            "crew":float(record["crew"]),
            "elapsed":float(record["elapsed"]),
            "priority":record["priority"],
            "repair":record["repair"],
            "relays":checked_relays,
            "faults":int(record["faults"])
        })
    var stored_ending: Variant = saved.get("ending",null)
    if not stored_ending is String or stored_ending not in ENDINGS:
        return false
    if not next_active and (next_chapter != 0 or not checked.is_empty() or stored_ending != ""):
        return false
    if next_chapter == TOTAL_CHAPTERS:
        if not next_active or stored_ending != _derive_ending(checked):
            return false
    elif stored_ending != "":
        return false
    active = next_active
    chapter = next_chapter
    history = checked
    ending = str(stored_ending)
    last_carryover.clear()
    return true

func diagnostic() -> Dictionary:
    var played: Array[String] = []
    for entry in history:
        played.append(str(entry["scenario"]))
    return {
        "active":active,
        "chapter":stage_number(),
        "chapter_index":chapter,
        "total_chapters":TOTAL_CHAPTERS,
        "scenario":stage_scenario(),
        "completed":history.size(),
        "finished":complete(),
        "ending":ending,
        "score":total_score(),
        "past_scenarios":played,
        "last_carryover":last_carryover.duplicate(true)
    }
