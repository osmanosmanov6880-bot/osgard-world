extends RefCounted
class_name IPCampaignFlow
## IRON PULSE V9: true three-operation playable campaign.
## Keeps old standalone GRID/HEAT/AIR runs untouched. A failure never
## unlocks the next mission; a result cannot be recorded twice.
const FORMAT: String = "IRON_PULSE_CAMPAIGN_FLOW_V9"
const ORDER: Array[String] = ["blackout","thermal","breach"]
const MAX_RECORDS: int = 3
const GRADES: Array[String] = ["S","A","B"]

var active: bool = false
var index: int = 0
var records: Array[Dictionary] = []
var modifier_applied: bool = false

func begin() -> void:
    active = true
    index = 0
    records.clear()
    modifier_applied = false

func current_scenario() -> String:
    return ORDER[clampi(index,0,2)]

func completed() -> bool:
    return active and records.size() == MAX_RECORDS

func awaiting_advance() -> bool:
    return active and records.size() == index+1 and index < MAX_RECORDS-1

func record_victory(engine: IPCrisisEngine) -> bool:
    if not active or not engine.won or engine.lost or engine.scenario_id != current_scenario():
        return false
    if records.size() != index:
        return false
    var entry: Dictionary = {
        "scenario":engine.scenario_id,
        "grade":engine.grade(),
        "elapsed":snappedf(engine.elapsed,0.01),
        "crew_health":snappedf(engine.crew_health,0.01),
        "oxygen":snappedf(engine.oxygen,0.01),
        "heat":snappedf(engine.heat,0.01),
        "priority":engine.priority_id,
        "repair":engine.repair_method,
        "relays":engine.relays_activated.duplicate(),
        "switches":engine.switches,
        "faults":engine.faults
    }
    records.append(entry)
    return true

func advance() -> bool:
    if not awaiting_advance():
        return false
    index += 1
    modifier_applied = false
    return true

func summary(locale: String = "ru") -> String:
    var english: bool = locale == "en"
    var result: Array[String] = []
    result.append("THREE-OPERATION CAMPAIGN" if english else "КАМПАНИЯ / ТРИ АВАРИИ")
    for i in range(records.size()):
        var entry: Dictionary = records[i]
        var name: String = ["GRID","HEAT","AIR"][i]
        var priority: String = str(entry["priority"])
        var tag: String = "CREW" if priority == "crew" else "CORE" if priority == "core" else "-"
        result.append("%02d  %s  /  %s  /  %s  /  %d%%" % [
            i+1,name,str(entry["grade"]),tag,roundi(float(entry["crew_health"]))])
    if completed():
        var weakest: float = 100.0
        var sum_score: int = 0
        for entry in records:
            weakest = minf(weakest,float(entry["crew_health"]))
            sum_score += 3 if entry["grade"] == "S" else 2 if entry["grade"] == "A" else 1
        var ending: String = "GUARDIANS" if weakest >= 75.0 and sum_score >= 7 else "SURVIVORS" if weakest >= 45.0 else "COST OF POWER"
        result.append(("ENDING: " if english else "ФИНАЛ: ") + ending)
    return "\n".join(PackedStringArray(result))

func next_modifier() -> Dictionary:
    # V11: consequences from previous victories have mechanical meaning.
    # The player is told exactly what transfers forward.
    if not active or index <= 0 or records.size() < index:
        return {}
    var before: Dictionary = records[index-1]
    var health: float = float(before["crew_health"])
    var priority: String = str(before["priority"])
    var previous_relays: Array = before["relays"]
    var outcome: Dictionary = {"heat":0.0,"oxygen":0.0,"crew":0.0,"time":0.0}
    if priority == "crew":
        outcome["crew"] = 7.0
        outcome["heat"] = 5.0
    elif priority == "core":
        outcome["crew"] = -7.0
        outcome["heat"] = -6.0
    if previous_relays.has("medbay"):
        outcome["crew"] = float(outcome["crew"])+5.0
    if previous_relays.has("quench"):
        outcome["heat"] = float(outcome["heat"])-5.0
        outcome["oxygen"] = float(outcome["oxygen"])-4.0
    if previous_relays.has("uplink"):
        outcome["time"] = 18.0
        outcome["crew"] = float(outcome["crew"])-3.0
    if health < 45.0:
        outcome["crew"] = float(outcome["crew"])-5.0
    return outcome

func apply_to_next(engine: IPCrisisEngine) -> bool:
    # Call strictly after engine.reset(current_scenario()) and only at
    # the start of an unlocked next chapter. No extra resources on retries.
    if modifier_applied or not active or index == 0 or records.size() != index or engine.scenario_id != current_scenario():
        return false
    if engine.elapsed > 0.001 or engine.core_scanned or engine.finished():
        return false
    var effects: Dictionary = next_modifier()
    engine.heat = clampf(engine.heat+float(effects["heat"]),0.0,109.0)
    engine.oxygen = clampf(engine.oxygen+float(effects["oxygen"]),1.0,100.0)
    engine.crew_health = clampf(engine.crew_health+float(effects["crew"]),1.0,100.0)
    engine.time_left = clampf(engine.time_left+float(effects["time"]),1.0,IPCrisisEngine.MAX_TIME)
    modifier_applied = true
    return true

func checkpoint() -> Dictionary:
    return {
        "schema":FORMAT,
        "active":active,
        "index":index,
        "records":records.duplicate(true),
        "modifier_applied":modifier_applied
    }

func restore(data: Dictionary) -> bool:
    if data.get("schema") != FORMAT or typeof(data.get("active",null)) != TYPE_BOOL:
        return false
    var ix: Variant = data.get("index",null)
    var source: Variant = data.get("records",null)
    var applied: Variant = data.get("modifier_applied",false)
    if typeof(applied) != TYPE_BOOL or (bool(applied) and (int(ix) <= 0 or not bool(data["active"]))):
        return false
    if typeof(ix) != TYPE_INT or not source is Array:
        return false
    if int(ix) < 0 or int(ix) >= MAX_RECORDS or source.size() > MAX_RECORDS:
        return false
    if not bool(data["active"]) and (int(ix) != 0 or not source.is_empty()):
        return false
    if source.size() < int(ix) or source.size() > int(ix)+1:
        return false
    var checked: Array[Dictionary] = []
    for i in range(source.size()):
        var item: Variant = source[i]
        if not item is Dictionary or str(item.get("scenario","")) != ORDER[i] or not GRADES.has(str(item.get("grade",""))):
            return false
        if not item.get("priority","") in ["","crew","core"]:
            return false
        var relays: Variant = item.get("relays",null)
        if not relays is Array or relays.size() > 2:
            return false
        var checked_relays: Array[String] = []
        for value in relays:
            if not value is String or not IPCrisisEngine.RELAYS.has(value) or checked_relays.has(value):
                return false
            checked_relays.append(value)
        for key in ["elapsed","crew_health","oxygen","heat"]:
            var number: Variant = item.get(key,null)
            if typeof(number) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(number)):
                return false
            var bound: float = 100.0 if key in ["crew_health","oxygen"] else 110.0 if key == "heat" else 500.0
            if float(number) < 0.0 or float(number) > bound:
                return false
        for key in ["switches","faults"]:
            var number: Variant = item.get(key,null)
            if typeof(number) != TYPE_INT or int(number) < 0 or int(number) > 10000:
                return false
        var repair: Variant = item.get("repair",null)
        if not repair is String or repair.length() > 40:
            return false
        checked.append(item.duplicate(true))
    # Never partly mutate the active campaign on invalid checkpoint.
    active = bool(data["active"])
    index = int(ix)
    records = checked
    modifier_applied = bool(applied)
    return true

func diagnostic() -> Dictionary:
    return {
        "active":active,
        "operation":index+1 if active else 0,
        "current_scenario":current_scenario() if active else "",
        "victories":records.size(),
        "awaiting_next":awaiting_advance(),
        "complete":completed(),
        "modifier":next_modifier(),
        "modifier_applied":modifier_applied,
        "final_ending":summary("en").get_slice("\n",records.size()+1) if completed() else ""
    }
