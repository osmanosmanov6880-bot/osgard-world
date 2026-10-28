extends RefCounted
class_name IPRunArchive
## V17 / A7 OPERATOR RECORDS: bounded, private, honest completed-run history.
## Stores actual IPAfterActionReview outputs, not generated leaderboards.
## Uses the existing V6 atomic user:// checksum wrapper (accidental corruption
## detection ONLY; local player files are not cryptographically authenticated).
## All current mission and campaign save formats remain unchanged.

const FORMAT: String = "IRON_PULSE_OPERATOR_RECORDS_V17"
const PATH: String = "user://iron_pulse_operator_records_v17.json"
const MAX_RECORDS: int = 16
const MAX_SEQUENCE: int = 10000000
const MAX_HISTORY: int = IPAfterActionReview.HISTORY_LIMIT
const GRADE_VALUES: Dictionary = {"S":3,"A":2,"B":1}
const REPAIRS: Array[String] = ["","standard","deep_stabilize","rapid_purge","full_seal","rapid_patch"]

var archive_path: String = PATH
var entries: Array[Dictionary] = []
var next_sequence: int = 1
var is_corrupt: bool = false
var checkpoint_store: IPCheckpointStore = IPCheckpointStore.new()
var review_engine: IPAfterActionReview = IPAfterActionReview.new()

func _number_valid(value: Variant,minimum: float,maximum: float) -> bool:
    if typeof(value) not in [TYPE_INT,TYPE_FLOAT]:
        return false
    var v: float = float(value)
    return is_finite(v) and v >= minimum and v <= maximum

func _whole_valid(value: Variant,minimum: int,maximum: int) -> bool:
    return _number_valid(value,float(minimum),float(maximum)) and float(value)==float(int(value))

func _valid_entry(raw: Variant) -> bool:
    if not raw is Dictionary:
        return false
    var item: Dictionary = raw
    if item.get("schema","") != IPAfterActionReview.FORMAT:
        return false
    if not _whole_valid(item.get("run_number",null),1,MAX_SEQUENCE):
        return false
    if item.get("scenario","") not in IPCrisisEngine.SCENARIOS:
        return false
    if item.get("outcome","") not in ["VICTORY","FAILURE"]:
        return false
    var won: bool = item["outcome"]=="VICTORY"
    if won:
        if not GRADE_VALUES.has(str(item.get("grade",""))) or item.get("reason","")!="crew_evacuated":
            return false
    elif item.get("grade","")!="UNRATED" or item.get("reason","") not in ["reactor_overheat","life_support_lost","time_expired"]:
        return false
    for key in ["elapsed_seconds","heat","oxygen","crew","door"]:
        var max_value: float = 110.0 if key=="heat" else 100.0 if key in ["oxygen","crew","door"] else 1000.0
        if not _number_valid(item.get(key,null),0.0,max_value):
            return false
    for key in ["switches","faults","total_event_count"]:
        if not _whole_valid(item.get(key,null),0,1000):
            return false
    if item.get("repair","") not in REPAIRS or item.get("priority","") not in ["","crew","core"]:
        return false
    if typeof(item.get("campaign",null))!=TYPE_BOOL or typeof(item.get("history_has_timestamps",null))!=TYPE_BOOL:
        return false
    if item["history_has_timestamps"]:
        return false
    if not _whole_valid(item.get("campaign_confirmed_victories",null),0,3):
        return false
    if (not item["campaign"] and int(item["campaign_confirmed_victories"])!=0):
        return false
    if item.get("focus","") not in IPAfterActionReview.FOCUS_LABELS:
        return false
    var relays: Variant = item.get("relays",null)
    if not relays is Array or relays.size()>IPCrisisEngine.MAX_RELAYS:
        return false
    var known_relays: Array[String] = []
    for relay in relays:
        if not relay is String or not IPCrisisEngine.RELAYS.has(str(relay)) or known_relays.has(str(relay)):
            return false
        known_relays.append(str(relay))
    var history: Variant = item.get("history",null)
    if not history is Array or history.is_empty() or history.size()>MAX_HISTORY:
        return false
    if int(item["total_event_count"])<history.size() or int(item["total_event_count"])>IPCrisisEngine.LOG_LIMIT:
        return false
    for event in history:
        if not event is String or event.length()>64 or not IPAfterActionReview.EVENT_LABELS.has(str(event)):
            return false
    if won and history.back()!="crew_evacuated":
        return false
    if not won and history.back()=="crew_evacuated":
        return false
    return true

func _reject_load() -> bool:
    # Preserve an invalid original file for deliberate user recovery; never
    # silently overwrite it when the next game finishes.
    if FileAccess.file_exists(archive_path):
        is_corrupt = true
    return false

func load_archive() -> bool:
    # A rejected/corrupt document must NOT mutate an already loaded archive.
    var data: Dictionary = checkpoint_store.load_checkpoint(archive_path)
    if data.is_empty() or data.get("schema","")!=FORMAT:
        return _reject_load()
    var saved: Variant = data.get("entries",null)
    var sequence: Variant = data.get("next_sequence",null)
    if not saved is Array or saved.size()>MAX_RECORDS:
        return _reject_load()
    if not _whole_valid(sequence,1,MAX_SEQUENCE):
        return _reject_load()
    var checked: Array[Dictionary] = []
    var previous: int = 0
    for raw in saved:
        if not _valid_entry(raw):
            return _reject_load()
        var item: Dictionary = raw
        var number: int = int(item["run_number"])
        if number<=previous or number>=int(sequence):
            return _reject_load()
        previous=number
        checked.append(item.duplicate(true))
    if previous>0 and int(sequence)!=previous+1:
        return _reject_load()
    if previous==0 and int(sequence)!=1:
        return _reject_load()
    entries=checked
    next_sequence=int(sequence)
    is_corrupt = false
    return true

func record_finished(engine: IPCrisisEngine,campaign: IPCampaignFlow = null) -> bool:
    # Only a genuinely completed original engine session can be recorded.
    if engine==null or not engine.finished() or is_corrupt or next_sequence>=MAX_SEQUENCE:
        return false
    var report: Dictionary = review_engine.review(engine,campaign)
    if report.is_empty():
        return false
    report["run_number"]=next_sequence
    if not _valid_entry(report):
        return false
    var updated: Array[Dictionary] = entries.duplicate(true)
    updated.append(report.duplicate(true))
    while updated.size()>MAX_RECORDS:
        updated.pop_front()
    var payload: Dictionary = {
        "schema":FORMAT,
        "next_sequence":next_sequence+1,
        "entries":updated
    }
    # The memory view is committed only after an atomic, successful write.
    if not checkpoint_store.save(payload,archive_path):
        return false
    entries=updated
    next_sequence+=1
    return true

func erase() -> bool:
    # Explicit two-step UI confirmation is handled in Main.gd.
    if not checkpoint_store.clear(archive_path):
        return false
    entries.clear()
    next_sequence=1
    is_corrupt=false
    return true

func readout() -> Dictionary:
    var wins: int=0
    var scenario_counts: Dictionary={"blackout":0,"thermal":0,"breach":0}
    for entry in entries:
        if entry["outcome"]=="VICTORY":
            wins+=1
        scenario_counts[str(entry["scenario"])]+=1
    return {
        "schema":FORMAT,
        "stored":entries.size(),
        "wins":wins,
        "failures":entries.size()-wins,
        "scenario_counts":scenario_counts.duplicate(true),
        "local_only":true,
        "authenticity_certified":false,
        "corrupt_file_protected":is_corrupt,
        "maximum_records":MAX_RECORDS
    }

func _grade_value(grade: String) -> int:
    return int(GRADE_VALUES.get(grade,0))

func _best_run(scenario: String) -> Dictionary:
    var candidate: Dictionary = {}
    for entry in entries:
        if entry["scenario"]!=scenario or entry["outcome"]!="VICTORY":
            continue
        if candidate.is_empty() or _grade_value(str(entry["grade"]))>_grade_value(str(candidate["grade"])) or (
            entry["grade"]==candidate["grade"] and float(entry["elapsed_seconds"])<float(candidate["elapsed_seconds"])):
            candidate=entry
    return candidate

func summary(locale: String = "ru") -> String:
    var english: bool=locale=="en"
    var lines: Array[String]=[]
    lines.append("A7 / OPERATOR RECORDS" if english else "A7 / АРХИВ ОПЕРАТОРА")
    lines.append("LOCAL SAVES / NO ONLINE RANK" if english else "ЛОКАЛЬНЫЕ ЗАПИСИ / БЕЗ ОНЛАЙН-РЕЙТИНГА")
    if is_corrupt:
        lines.append("CORRUPTED LOCAL FILE: PRESERVED, NOT OVERWRITTEN." if english else "ОШИБКА ЛОКАЛЬНОГО ФАЙЛА: НЕ ПЕРЕЗАПИСАН.")
        lines.append("Clear it explicitly if you want to start a new archive." if english else "Для нового архива подтвердите удаление повреждённого файла.")
    var counts: Dictionary=readout()
    lines.append(("RUNS %d/%d   WINS %d   LOSSES %d" if english else "ПРОХОДЫ %d/%d   ПОБЕДЫ %d   ПОРАЖЕНИЯ %d") % [
        int(counts["stored"]),MAX_RECORDS,int(counts["wins"]),int(counts["failures"])])
    lines.append("")
    lines.append("PERSONAL BEST / GRADE, THEN TIME" if english else "ЛИЧНЫЙ РЕКОРД / ОЦЕНКА, ЗАТЕМ ВРЕМЯ")
    for index in range(IPCrisisEngine.SCENARIOS.size()):
        var scenario: String=IPCrisisEngine.SCENARIOS[index]
        var label: String=["GRID","HEAT","AIR"][index]
        var best: Dictionary=_best_run(scenario)
        if best.is_empty():
            lines.append("%s   —" % label)
        else:
            lines.append("%s   %s / %.1fs" % [label,str(best["grade"]),float(best["elapsed_seconds"])])
    lines.append("")
    lines.append("RECENT LOCAL ATTEMPTS" if english else "ПОСЛЕДНИЕ ЛОКАЛЬНЫЕ ПРОХОДЫ")
    if entries.is_empty():
        lines.append("No completed operations recorded yet." if english else "Пока нет завершённых операций.")
    else:
        for i in range(entries.size()-1,-1,-1):
            var entry: Dictionary=entries[i]
            var scenario: String=str(entry["scenario"])
            var caption: String="GRID" if scenario=="blackout" else "HEAT" if scenario=="thermal" else "AIR"
            var outcome: String="WIN" if entry["outcome"]=="VICTORY" else "LOSS"
            if not english:
                outcome="ПОБЕДА" if entry["outcome"]=="VICTORY" else "ПРОВАЛ"
            lines.append("#%04d  %s / %s / %s" % [int(entry["run_number"]),caption,outcome,str(entry["grade"])])
            lines.append("   %.1fs   O2 %.0f%%   CREW %.0f%%   ERR %d" % [
                float(entry["elapsed_seconds"]),float(entry["oxygen"]),float(entry["crew"]),int(entry["faults"])])
    lines.append("")
    lines.append("Only genuine local results. SHA-256 detects corruption, not file tampering." if english else "Только локальные результаты. SHA-256 выявляет повреждения, не подделку файла.")
    lines.append("No cloud sync, replay timestamps or global rankings." if english else "Без облака, временных меток событий и глобального рейтинга.")
    return "\n".join(PackedStringArray(lines))
