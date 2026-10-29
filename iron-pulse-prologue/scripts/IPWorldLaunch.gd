extends RefCounted
class_name IPWorldLaunch
## Validated bridge from a same-origin static world portal to the ACTUAL
## Godot V9-V12 campaign. Query data is NEVER evaluated or executed.
const SCENARIOS: Array[String] = ["blackout","thermal","breach"]
const LANGUAGES: Array[String] = ["ru","en"]
const MAX_QUERY: int = 256
const FORMAT: String = "IRON_PULSE_WORLD_LAUNCH_V13"

static func parse(query: String) -> Dictionary:
    var result: Dictionary = {
        "schema":FORMAT,"scenario":"blackout","lang":"ru",
        "campaign":false,"accepted":false
    }
    if query.length() > MAX_QUERY:
        return result
    var raw: String = query.trim_prefix("?").strip_edges()
    if raw.is_empty():
        return result
    for entry in raw.split("&",false):
        var pair: PackedStringArray = entry.split("=",false,1)
        if pair.size() != 2:
            continue
        var key: String = pair[0]
        var value: String = pair[1].uri_decode().to_lower()
        match key:
            "scenario":
                if SCENARIOS.has(value):
                    result["scenario"] = value
                    result["accepted"] = true
            "lang":
                if LANGUAGES.has(value):
                    result["lang"] = value
                    result["accepted"] = true
            "campaign":
                if value == "1":
                    result["campaign"] = true
                    result["accepted"] = true
                elif value == "0":
                    result["campaign"] = false
                    result["accepted"] = true
    # A campaign always begins with GRID: no query can jump to HEAT/AIR.
    if result["campaign"]:
        result["scenario"] = "blackout"
    return result
