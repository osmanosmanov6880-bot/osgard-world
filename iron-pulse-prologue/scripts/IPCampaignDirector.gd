extends RefCounted
class_name IPCampaignDirector
## V9 original three-operation campaign: real sequential gameplay and actual
## resource carry-over. Offline, optional, never alters old standalone modes.
## The user:// ledger is written by the existing checksum/atomic save store.
const SCHEMA: String = "IRON_PULSE_THREE_ACT_CAMPAIGN_V9"
const PROGRESS_PATH: String = "user://iron_pulse_campaign_progress_v9.json"
const STAGES: Array[String] = ["blackout","thermal","breach"]
const VALID_GRADES: Array[String] = ["S","A","B"]
const VALID_METHODS: Array[String] = ["standard","deep_stabilize","rapid_purge","full_seal","rapid_patch"]
const VALID_PRIORITIES: Array[String] = ["","crew","core"]
const VALID_RELAYS: Array[String] = ["medbay","quench","uplink"]
const MAX_EVENTS: int = 3
var completed: Array[Dictionary] = []

func reset() -> void:
    completed.clear()

func stage_index() -> int:
    return mini(completed.size(), STAGES.size())

func finished() -> bool:
    return completed.size() == STAGES.size()

func next_scenario() -> String:
    return "" if finished() else STAGES[completed.size()]

func wins() -> int:
    return completed.size()

func campaign_grade() -> String:
    if not finished():
        return "INCOMPLETE"
    var score: int = 0
    for result in completed:
        match str(result["grade"]):
            "S":
                score += 3
            "A":
                score += 2
            "B":
                score += 1
    if score >= 8:
        return "S"
    if score >= 6:
        return "A"
    return "B"

func ending_id() -> String:
    if not finished():
        return ""
    var crew_orders: int = 0
    var core_orders: int = 0
    var crew_sum: float = 0.0
    for outcome in completed:
        if str(outcome["priority"]) == "crew":
            crew_orders += 1
        elif str(outcome["priority"]) == "core":
            core_orders += 1
        crew_sum += float(outcome["crew"])
    if crew_orders >= 2 and crew_sum >= 210.0:
        return "humanity"
    if core_orders >= 2:
        return "steel"
    return "signal"

func carryover() -> Dictionary:
    if completed.is_empty():
        return {"oxygen":100.0,"crew":100.0,"from":""}
    var prior: Dictionary = completed.back()
    # Between separate crises, surviving crew receives a small emergency
    # resupply, not a full reset: casualties have actual campaign meaning.
    return {
        "oxygen":clampf(float(prior["oxygen"])+12.0,55.0,100.0),
        "crew":clampf(float(prior["crew"])+8.0,50.0,100.0),
        "from":str(prior["scenario"])
    }

func apply_to_engine(engine: IPCrisisEngine) -> bool:
    if finished() or engine.scenario_id != next_scenario():
        return false
    if completed.is_empty():
        return true
    if engine.core_scanned or engine.elapsed != 0.0 or engine.finished():
        return false
    var carry: Dictionary = carryover()
    engine.oxygen = minf(engine.oxygen,float(carry["oxygen"]))
    engine.crew_health = minf(engine.crew_health,float(carry["crew"]))
    return true

func record_victory(engine: IPCrisisEngine) -> bool:
    # Only a real completed, correct-order IPCrisisEngine operation counts.
    # Duplicate end-screen callbacks cannot generate a second victory.
    if finished() or not engine.won or engine.lost or engine.scenario_id != next_scenario():
        return false
    var entry: Dictionary = {
        "scenario":engine.scenario_id,
        "grade":engine.grade(),
        "priority":engine.priority_id,
        "repair":engine.repair_method,
        "relays":engine.relays_activated.duplicate(),
        "crew":snappedf(engine.crew_health,0.001),
        "oxygen":snappedf(engine.oxygen,0.001),
        "heat":snappedf(engine.heat,0.001),
        "elapsed":snappedf(engine.elapsed,0.001),
        "switches":engine.switches,
        "faults":engine.faults
    }
    if not _valid_entry(entry,completed.size()):
        return false
    completed.append(entry)
    return true

func summary(locale: String = "ru") -> String:
    var language: String = "en" if locale == "en" else "ru"
    var chapter: int = mini(completed.size()+1,3)
    if finished():
        if language == "ru":
            return "КАМПАНИЯ 3/3  •  РАНГ " + campaign_grade()
        return "CAMPAIGN 3/3  •  RANK " + campaign_grade()
    var names_ru: Array[String] = ["GRID / ОТКЛЮЧЕНИЕ","HEAT / ПЕРЕГРЕВ","AIR / РАЗГЕРМЕТИЗАЦИЯ"]
    var names_en: Array[String] = ["GRID / BLACKOUT","HEAT / CASCADE","AIR / BREACH"]
    var chapter_names: Array[String] = names_en if language == "en" else names_ru
    var label: String = chapter_names[chapter-1]
    var carry: Dictionary = carryover()
    if language == "en":
        return "CAMPAIGN %d/3  •  %s  •  CREW %d%%" % [chapter,label,int(carry["crew"])]
    return "КАМПАНИЯ %d/3  •  %s  •  ЭКИПАЖ %d%%" % [chapter,label,int(carry["crew"])]

func ending_text(locale: String = "ru") -> String:
    if not finished():
        return ""
    var result: String = ending_id()
    var endings_ru := {
        "humanity":"ПРОТОКОЛ ЧЕЛОВЕЧНОСТИ: вы сохранили людей ценой времени и энергии. Последний сигнал комплекса стал началом эвакуации.",
        "steel":"СТАЛЬНОЙ ПРИКАЗ: вы спасли реактор, но ваши решения изменили судьбу экипажа. Станция уцелела — доверие придётся вернуть.",
        "signal":"ПОСЛЕДНИЙ СИГНАЛ: реактор и экипаж выстояли не без потерь. Архив A7 сохранил цену каждого решения."
    }
    var endings_en := {
        "humanity":"HUMANITY PROTOCOL: you protected the crew at the cost of time and power. The last A7 transmission became the start of an evacuation.",
        "steel":"STEEL ORDER: you saved the reactor, but your choices shaped the crew's fate. The station stands; trust must be rebuilt.",
        "signal":"LAST SIGNAL: the reactor and crew survived with sacrifices. The A7 archive remembers every decision."
    }
    var endings: Dictionary = endings_en if locale == "en" else endings_ru
    return str(endings[result])

func checkpoint() -> Dictionary:
    return {"schema":SCHEMA,"completed":completed.duplicate(true)}

func _number_in(value: Variant,smallest: float,largest: float) -> bool:
    if typeof(value) not in [TYPE_FLOAT,TYPE_INT]:
        return false
    var n: float = float(value)
    return n == n and n >= smallest and n <= largest

func _valid_entry(entry: Dictionary,idx: int) -> bool:
    if idx < 0 or idx >= STAGES.size() or entry.size() != 11:
        return false
    if entry.get("scenario") != STAGES[idx]:
        return false
    if entry.get("grade") not in VALID_GRADES or entry.get("priority") not in VALID_PRIORITIES:
        return false
    if entry.get("repair") not in VALID_METHODS:
        return false
    if (idx == 0 and entry.get("repair") != "standard") or (idx == 1 and entry.get("repair") not in ["deep_stabilize","rapid_purge"]) or (idx == 2 and entry.get("repair") not in ["full_seal","rapid_patch"]):
        return false
    var relays: Variant = entry.get("relays",null)
    if not relays is Array or relays.size() > 2:
        return false
    var seen: Array[String] = []
    for relay in relays:
        if not relay is String or relay not in VALID_RELAYS or seen.has(relay):
            return false
        seen.append(relay)
    if not _number_in(entry.get("crew",null),0.0,100.0) or not _number_in(entry.get("oxygen",null),0.0,100.0) or not _number_in(entry.get("heat",null),0.0,110.0):
        return false
    if not _number_in(entry.get("elapsed",null),0.0,1000.0) or not _number_in(entry.get("switches",null),0.0,1000.0) or not _number_in(entry.get("faults",null),0.0,1000.0):
        return false
    return true

func restore(data: Dictionary) -> bool:
    # Completely validate without mutation. The save store's SHA is
    # corruption detection, NOT anti-tampering or a remote authority.
    if data.get("schema") != SCHEMA:
        return false
    var items: Variant = data.get("completed",null)
    if not items is Array or items.size() > STAGES.size():
        return false
    var rebuilt: Array[Dictionary] = []
    for index in range(items.size()):
        var value: Variant = items[index]
        if not value is Dictionary or not _valid_entry(value,index):
            return false
        rebuilt.append((value as Dictionary).duplicate(true))
    completed = rebuilt
    return true
