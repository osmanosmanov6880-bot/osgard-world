extends RefCounted
class_name IPCareerProfile
## IRON PULSE / OPERATIONS PLATFORM V9.
## Offline-first, privacy-preserving player career progression. Only aggregate
## fictional gameplay is stored; no identifiers, accounts or network telemetry.
## Hash checks detect corruption, but are NOT cryptographic authentication.

const SCHEMA: String = "IRON_PULSE_OPERATIONS_PROFILE_V9"
const DEFAULT_PATH: String = "user://iron_pulse_operations_v9.json"
const MAX_HISTORY: int = 24
const MAX_RUNS: int = 1000000
const MAX_SECONDS: float = 3600.0
const ACHIEVEMENT_IDS: Array[String] = [
    "FIRST_EXTRACTION","PRECISION_OPERATOR","ZERO_FAULT","CREW_GUARDIAN",
    "RELAY_ARCHITECT","SOLO_OPERATOR","THREE_FRONTS","VETERAN"
]
const ACHIEVEMENT_TITLES := {
    "ru":{
        "FIRST_EXTRACTION":"ПЕРВАЯ ЭВАКУАЦИЯ",
        "PRECISION_OPERATOR":"ИДЕАЛЬНАЯ ОПЕРАЦИЯ",
        "ZERO_FAULT":"БЕЗ ОШИБОК",
        "CREW_GUARDIAN":"ЗАЩИТНИК ЭКИПАЖА",
        "RELAY_ARCHITECT":"ДВА РЕШЕНИЯ",
        "SOLO_OPERATOR":"БЕЗ ПОДДЕРЖКИ",
        "THREE_FRONTS":"ТРИ ФРОНТА",
        "VETERAN":"ВЕТЕРАН A7"
    },
    "en":{
        "FIRST_EXTRACTION":"FIRST EXTRACTION",
        "PRECISION_OPERATOR":"PRECISION OPERATOR",
        "ZERO_FAULT":"ZERO FAULT",
        "CREW_GUARDIAN":"CREW GUARDIAN",
        "RELAY_ARCHITECT":"RELAY ARCHITECT",
        "SOLO_OPERATOR":"SOLO OPERATOR",
        "THREE_FRONTS":"THREE FRONTS",
        "VETERAN":"A7 VETERAN"
    }
}

var operations: int = 0
var victories: int = 0
var mission_records: Dictionary = {}
var recent: Array[Dictionary] = []
var achievements: Array[String] = []
var last_awards: Array[String] = []
var last_result: Dictionary = {}
var _storage: IPCheckpointStore = IPCheckpointStore.new()

func _mission_empty() -> Dictionary:
    return {"attempts":0,"wins":0,"best_grade":"-","best_seconds":0.0}

func reset() -> void:
    operations = 0
    victories = 0
    mission_records = {}
    for scenario in IPCrisisEngine.SCENARIOS:
        mission_records[scenario] = _mission_empty()
    recent.clear()
    achievements.clear()
    last_awards.clear()
    last_result.clear()

func _init() -> void:
    reset()

func _grade_rank(value: String) -> int:
    match value:
        "S": return 3
        "A": return 2
        "B": return 1
    return 0

func record_finished(engine: IPCrisisEngine, sectors: Array[String]) -> Dictionary:
    if engine == null or not engine.finished() or operations >= MAX_RUNS:
        return {}
    if not IPCrisisEngine.SCENARIOS.has(engine.scenario_id):
        return {}
    var result: Dictionary = {
        "id":operations+1,
        "scenario":engine.scenario_id,
        "won":engine.won,
        "grade":engine.grade(),
        "elapsed":clampf(engine.elapsed,0.0,MAX_SECONDS),
        "crew":clampf(engine.crew_health,0.0,100.0),
        "heat":clampf(engine.heat,0.0,110.0),
        "oxygen":clampf(engine.oxygen,0.0,100.0),
        "switches":clampi(engine.switches,0,100000),
        "faults":clampi(engine.faults,0,100000),
        "priority":engine.priority_id,
        "repair":engine.repair_method,
        "relays":engine.relays_activated.duplicate(),
        "sectors":clampi(sectors.size(),0,3)
    }
    operations += 1
    var record: Dictionary = mission_records[engine.scenario_id]
    record["attempts"] = int(record["attempts"])+1
    if engine.won:
        victories += 1
        record["wins"] = int(record["wins"])+1
        if _grade_rank(engine.grade()) > _grade_rank(str(record["best_grade"])):
            record["best_grade"] = engine.grade()
        if float(record["best_seconds"]) <= 0.0 or result["elapsed"] < float(record["best_seconds"]):
            record["best_seconds"] = result["elapsed"]
    mission_records[engine.scenario_id] = record
    recent.push_front(result.duplicate(true))
    if recent.size() > MAX_HISTORY:
        recent.resize(MAX_HISTORY)
    last_result = result.duplicate(true)
    last_awards.clear()
    _award_if(engine.won,"FIRST_EXTRACTION")
    _award_if(engine.won and engine.grade()=="S","PRECISION_OPERATOR")
    _award_if(engine.won and engine.faults==0,"ZERO_FAULT")
    _award_if(engine.won and engine.priority_id=="crew" and engine.crew_health>=90.0,"CREW_GUARDIAN")
    _award_if(engine.won and engine.relays_activated.size()==2,"RELAY_ARCHITECT")
    _award_if(engine.won and engine.relays_activated.is_empty(),"SOLO_OPERATOR")
    var all_won: bool = true
    for scenario in IPCrisisEngine.SCENARIOS:
        if int(mission_records[scenario]["wins"]) <= 0:
            all_won = false
    _award_if(all_won,"THREE_FRONTS")
    _award_if(victories>=5,"VETERAN")
    return {"result":result.duplicate(true),"awards":last_awards.duplicate()}

func _award_if(qualifies: bool,achievement_id: String) -> void:
    if qualifies and ACHIEVEMENT_IDS.has(achievement_id) and not achievements.has(achievement_id):
        achievements.append(achievement_id)
        last_awards.append(achievement_id)

func achievement_title(achievement_id: String,language: String="ru") -> String:
    var use_locale: String = "en" if language=="en" else "ru"
    return str(ACHIEVEMENT_TITLES[use_locale].get(achievement_id,"?"))

func recommended_scenario() -> String:
    # No content is paywalled: point to the least-completed emergency.
    var selected: String = IPCrisisEngine.SCENARIOS[0]
    var least_wins: int = MAX_RUNS
    var least_attempts: int = MAX_RUNS
    for scenario in IPCrisisEngine.SCENARIOS:
        var wins: int = int(mission_records[scenario]["wins"])
        var played: int = int(mission_records[scenario]["attempts"])
        if wins < least_wins or (wins==least_wins and played<least_attempts):
            least_wins = wins
            least_attempts = played
            selected = scenario
    return selected

func snapshot() -> Dictionary:
    var best: Dictionary = {}
    for scenario in IPCrisisEngine.SCENARIOS:
        best[scenario] = (mission_records[scenario] as Dictionary).duplicate(true)
    return {
        "schema":SCHEMA,"operations":operations,"victories":victories,
        "mission_records":best,"recent":recent.duplicate(true),
        "achievements":achievements.duplicate(),"recommended":recommended_scenario(),
        "achievement_count":achievements.size()
    }

func save(path: String=DEFAULT_PATH) -> bool:
    return _storage.save(snapshot(),path)

func load(path: String=DEFAULT_PATH) -> bool:
    var payload: Dictionary = _storage.load_checkpoint(path)
    if payload.is_empty():
        return false
    return restore(payload)

func _valid_integer(value: Variant, min_value: int, max_value: int) -> bool:
    return typeof(value)==TYPE_INT and value>=min_value and value<=max_value

func _valid_float(value: Variant, low: float, high: float) -> bool:
    return (typeof(value)==TYPE_FLOAT or typeof(value)==TYPE_INT) and is_finite(float(value)) and float(value)>=low and float(value)<=high

func _valid_result(value: Variant) -> bool:
    if not value is Dictionary:
        return false
    var item: Dictionary = value
    if not _valid_integer(item.get("id",null),1,MAX_RUNS):
        return false
    var scenario: Variant = item.get("scenario")
    if not scenario is String or not IPCrisisEngine.SCENARIOS.has(scenario):
        return false
    if typeof(item.get("won",null))!=TYPE_BOOL:
        return false
    var grade: Variant = item.get("grade")
    if not grade is String or (grade not in ["S","A","B"] if item["won"] else grade!="UNRATED"):
        return false
    for stat in ["elapsed","crew","heat","oxygen"]:
        var maximum: float = MAX_SECONDS if stat=="elapsed" else 110.0 if stat=="heat" else 100.0
        if not _valid_float(item.get(stat,null),0.0,maximum):
            return false
    for field in ["switches","faults"]:
        if not _valid_integer(item.get(field,null),0,100000):
            return false
    if not _valid_integer(item.get("sectors",null),0,3):
        return false
    var priority: Variant = item.get("priority")
    var repair: Variant = item.get("repair")
    if not priority is String or priority not in ["","crew","core"]:
        return false
    if not repair is String or repair not in ["","standard","deep_stabilize","rapid_purge","full_seal","rapid_patch"]:
        return false
    var relays: Variant = item.get("relays")
    if not relays is Array or relays.size()>IPCrisisEngine.MAX_RELAYS:
        return false
    var seen: Array[String] = []
    for relay in relays:
        if not relay is String or not IPCrisisEngine.RELAYS.has(relay) or seen.has(relay):
            return false
        seen.append(relay)
    return true

func restore(payload: Dictionary) -> bool:
    # Transactional: reject malformed foreign/corrupted career records before
    # modifying the user's active profile. Bounded, versioned and offline.
    if payload.get("schema")!=SCHEMA:
        return false
    var total: Variant = payload.get("operations")
    var won: Variant = payload.get("victories")
    if not _valid_integer(total,0,MAX_RUNS) or not _valid_integer(won,0,int(total)):
        return false
    var restored_records: Variant = payload.get("mission_records")
    var restored_history: Variant = payload.get("recent")
    var restored_awards: Variant = payload.get("achievements")
    if not restored_records is Dictionary or not restored_history is Array or not restored_awards is Array:
        return false
    if restored_records.size()!=IPCrisisEngine.SCENARIOS.size() or restored_history.size()>MAX_HISTORY:
        return false
    if restored_awards.size()>ACHIEVEMENT_IDS.size() or restored_history.size()>int(total):
        return false
    var checked_records: Dictionary = {}
    var counted_attempts: int = 0
    var counted_wins: int = 0
    for scenario in IPCrisisEngine.SCENARIOS:
        if not restored_records.has(scenario) or not restored_records[scenario] is Dictionary:
            return false
        var entry: Dictionary = restored_records[scenario]
        var attempts: Variant = entry.get("attempts")
        var wins: Variant = entry.get("wins")
        var grade: Variant = entry.get("best_grade")
        var best_seconds: Variant = entry.get("best_seconds")
        if not _valid_integer(attempts,0,int(total)) or not _valid_integer(wins,0,int(attempts)):
            return false
        if not grade is String or grade not in ["-","S","A","B"]:
            return false
        if not _valid_float(best_seconds,0.0,MAX_SECONDS):
            return false
        if (int(wins)==0 and (grade!="-" or best_seconds!=0.0)) or (int(wins)>0 and grade=="-"):
            return false
        checked_records[scenario] = {
            "attempts":attempts,"wins":wins,
            "best_grade":grade,"best_seconds":float(best_seconds)
        }
        counted_attempts += int(attempts)
        counted_wins += int(wins)
    if counted_attempts!=int(total) or counted_wins!=int(won):
        return false
    var checked_awards: Array[String] = []
    for award in restored_awards:
        if not award is String or not ACHIEVEMENT_IDS.has(award) or checked_awards.has(award):
            return false
        checked_awards.append(award)
    var checked_history: Array[Dictionary] = []
    var previous_id: int = int(total)+1
    for item in restored_history:
        if not _valid_result(item):
            return false
        var id_value: int = int(item["id"])
        if id_value>=previous_id:
            return false
        previous_id = id_value
        checked_history.append((item as Dictionary).duplicate(true))
    if int(total)>0 and checked_history.is_empty():
        return false
    if not checked_history.is_empty() and int(checked_history[0]["id"]) != int(total):
        return false
    # Mutate only after every check succeeds.
    operations = int(total)
    victories = int(won)
    mission_records = checked_records
    recent = checked_history
    achievements = checked_awards
    last_result = recent[0].duplicate(true) if not recent.is_empty() else {}
    last_awards.clear()
    return true
