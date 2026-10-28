extends RefCounted
class_name IPCampaignAtlas
## IRON PULSE WORLD / V9: a real 3-operation offline progression profile.
## Independent from the legacy V6 checkpoint: old saves remain untouched.
## No accounts, network traffic, artificial unlocks or simulated leaderboards.
const SCHEMA: String = "IRON_PULSE_WORLD_CAMPAIGN_V9"
const DEFAULT_PATH: String = "user://iron_pulse_world_atlas_v9.json"
const ORDER: Array[String] = ["blackout","thermal","breach"]
const MEDALS: Array[String] = ["S","A","B"]
const MAX_ATTEMPTS: int = 100000
const MAX_ELAPSED: float = 3600.0

var records: Dictionary = {}
var attempts: Dictionary = {}
var last_scenario: String = ""
var total_runs: int = 0

func _init() -> void:
    clear()

func clear() -> void:
    records.clear()
    attempts.clear()
    total_runs = 0
    last_scenario = ""
    for scenario in ORDER:
        attempts[scenario] = 0

func _rank(grade: String) -> int:
    var index: int = MEDALS.find(grade)
    return index if index >= 0 else 99

func _valid_count(value: Variant, limit: int = MAX_ATTEMPTS) -> bool:
    if typeof(value) not in [TYPE_INT,TYPE_FLOAT]:
        return false
    var n: float = float(value)
    return not is_nan(n) and not is_inf(n) and n >= 0.0 and n <= float(limit) and floorf(n) == n

func _valid_metric(value: Variant, lo: float, hi: float) -> bool:
    return typeof(value) in [TYPE_INT,TYPE_FLOAT] and not is_nan(float(value)) and not is_inf(float(value)) and float(value) >= lo and float(value) <= hi

func clear_count() -> int:
    return records.size()

func is_complete() -> bool:
    return clear_count() == ORDER.size()

func best_grade(scenario: String) -> String:
    if not records.has(scenario):
        return "-"
    return str(records[scenario]["best_grade"])

func next_mission(current: String) -> String:
    var index: int = ORDER.find(current)
    if index < 0 or index+1 >= ORDER.size():
        return ""
    return ORDER[index+1]

func current_run_count(scenario: String) -> int:
    return int(attempts.get(scenario,0))

func record_run(engine: IPCrisisEngine) -> bool:
    # Only an actual completed run can change the persistent world dossier.
    if engine == null or not engine.finished() or not ORDER.has(engine.scenario_id):
        return false
    var id: String = engine.scenario_id
    var count: int = current_run_count(id)
    if count >= MAX_ATTEMPTS or total_runs >= MAX_ATTEMPTS*ORDER.size():
        return false
    count += 1
    attempts[id] = count
    total_runs += 1
    last_scenario = id
    if not engine.won:
        return true
    var grade: String = engine.grade()
    if not MEDALS.has(grade):
        return false
    var candidate_time: float = snappedf(clampf(engine.elapsed,0.0,MAX_ELAPSED),0.01)
    var candidate_crew: float = snappedf(clampf(engine.crew_health,0.0,100.0),0.01)
    var prior: Dictionary = records.get(id,{})
    if prior.is_empty():
        records[id] = {
            "wins":1,"best_grade":grade,"best_time":candidate_time,
            "best_crew":candidate_crew,"best_faults":maxi(0,engine.faults),
            "last_priority":engine.priority_id if engine.priority_id in ["crew","core"] else "",
            "best_method":engine.repair_method,
            "last_rescue_count":engine.relays_activated.size()
        }
    else:
        var updated: Dictionary = prior.duplicate(true)
        updated["wins"] = int(prior["wins"])+1
        if _rank(grade) < _rank(str(prior["best_grade"])):
            updated["best_grade"] = grade
        updated["best_time"] = minf(float(prior["best_time"]),candidate_time)
        updated["best_crew"] = maxf(float(prior["best_crew"]),candidate_crew)
        updated["best_faults"] = mini(int(prior["best_faults"]),maxi(0,engine.faults))
        updated["last_priority"] = engine.priority_id if engine.priority_id in ["crew","core"] else ""
        updated["best_method"] = engine.repair_method
        updated["last_rescue_count"] = engine.relays_activated.size()
        records[id] = updated
    return true

func route_text(locale: String = "ru") -> String:
    var labels: Array[String] = ["GRID","HEAT","AIR"]
    var segments: Array[String] = []
    for i in range(ORDER.size()):
        segments.append("%02d %s  %s" % [i+1,labels[i],best_grade(ORDER[i])])
    var prefix: String = "КАМПАНИЯ / ОПЕРАЦИИ" if locale == "ru" else "CAMPAIGN / OPERATIONS"
    return "%s  %d/3\n%s" % [prefix,clear_count(),"   ·   ".join(PackedStringArray(segments))]

func last_result_text(locale: String = "ru") -> String:
    var title: String = "АРХИВ ОПЕРАТОРА" if locale == "ru" else "OPERATOR ARCHIVE"
    var status: String = "ВСЕ ТРИ ОПЕРАЦИИ ЗАВЕРШЕНЫ" if locale == "ru" else "ALL THREE OPERATIONS CLEARED"
    var progress: String = status if is_complete() else route_text(locale)
    return "%s\n%s" % [title,progress]

func diagnostic() -> Dictionary:
    var medals: Dictionary = {}
    for scenario in ORDER:
        medals[scenario] = best_grade(scenario)
    return {
        "schema":SCHEMA,"total_runs":total_runs,
        "cleared":clear_count(),"complete":is_complete(),
        "medals":medals,"attempts":attempts.duplicate(true),
        "last_scenario":last_scenario,
        "best_records":records.duplicate(true)
    }

func snapshot() -> Dictionary:
    return {
        "schema":SCHEMA,
        "total_runs":total_runs,
        "last_scenario":last_scenario,
        "attempts":attempts.duplicate(true),
        "records":records.duplicate(true)
    }

func restore(payload: Dictionary) -> bool:
    # No partial mutation: validate every persisted key and value before
    # replacing the active profile. Plain SHA-256 protects corruption only,
    # never claim anti-tamper security against a malicious local editor.
    if payload.get("schema") != SCHEMA:
        return false
    var trial_attempts: Variant = payload.get("attempts",null)
    var trial_records: Variant = payload.get("records",null)
    var trial_runs: Variant = payload.get("total_runs",null)
    var trial_last: Variant = payload.get("last_scenario",null)
    if not trial_attempts is Dictionary or not trial_records is Dictionary:
        return false
    if not _valid_count(trial_runs,MAX_ATTEMPTS*ORDER.size()):
        return false
    if not trial_last is String or (trial_last != "" and not ORDER.has(trial_last)):
        return false
    if trial_attempts.size() != ORDER.size() or trial_records.size() > ORDER.size():
        return false
    var checked_attempts: Dictionary = {}
    var checked_records: Dictionary = {}
    var summed: int = 0
    for scenario in ORDER:
        if not trial_attempts.has(scenario) or not _valid_count(trial_attempts[scenario]):
            return false
        var count: int = int(trial_attempts[scenario])
        checked_attempts[scenario] = count
        summed += count
    if summed != int(trial_runs) or (summed == 0 and trial_last != ""):
        return false
    for key in trial_records:
        if not key is String or not ORDER.has(str(key)) or not trial_records[key] is Dictionary:
            return false
        var entry: Dictionary = trial_records[key]
        var mandatory: Array[String] = [
            "wins","best_grade","best_time","best_crew","best_faults",
            "last_priority","best_method","last_rescue_count"
        ]
        if entry.size() != mandatory.size():
            return false
        for field in mandatory:
            if not entry.has(field):
                return false
        if not _valid_count(entry["wins"]) or int(entry["wins"]) < 1 or int(entry["wins"]) > int(checked_attempts[key]):
            return false
        if not entry["best_grade"] is String or not MEDALS.has(str(entry["best_grade"])):
            return false
        if not _valid_metric(entry["best_time"],0.0,MAX_ELAPSED) or not _valid_metric(entry["best_crew"],0.0,100.0):
            return false
        if not _valid_count(entry["best_faults"]) or not _valid_count(entry["last_rescue_count"],2):
            return false
        if not entry["last_priority"] is String or str(entry["last_priority"]) not in ["","crew","core"]:
            return false
        if not entry["best_method"] is String or str(entry["best_method"]) not in [
            "","standard","deep_stabilize","rapid_purge","full_seal","rapid_patch"
        ]:
            return false
        # Normalize JSON float/int representations to the same canonical
        # offline profile shape used by a freshly completed real mission.
        checked_records[key] = {
            "wins":int(entry["wins"]),
            "best_grade":str(entry["best_grade"]),
            "best_time":float(entry["best_time"]),
            "best_crew":float(entry["best_crew"]),
            "best_faults":int(entry["best_faults"]),
            "last_priority":str(entry["last_priority"]),
            "best_method":str(entry["best_method"]),
            "last_rescue_count":int(entry["last_rescue_count"])
        }
    attempts = checked_attempts
    records = checked_records
    total_runs = int(trial_runs)
    last_scenario = str(trial_last)
    return true

func save_profile(path: String = DEFAULT_PATH) -> bool:
    return IPCheckpointStore.new().save(snapshot(),path)

func load_profile(path: String = DEFAULT_PATH) -> bool:
    var payload: Dictionary = IPCheckpointStore.new().load_checkpoint(path)
    if payload.is_empty():
        return false
    return restore(payload)
