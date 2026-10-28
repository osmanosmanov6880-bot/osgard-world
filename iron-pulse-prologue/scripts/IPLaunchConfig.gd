extends RefCounted
class_name IPLaunchConfig
## Explicit, strict launch contract from world portal to real Godot WebGL.
## No JavaScript commands, eval of user input, accounts, URLs or remote calls.
const SCENARIOS: Array[String] = ["blackout","thermal","breach"]
const LANGUAGES: Array[String] = ["ru","en"]
const MAX_QUERY: int = 256

static func parse(query: String) -> Dictionary:
    var result: Dictionary = {"scenario":"blackout","lang":"ru"}
    if query.length() > MAX_QUERY:
        return result
    var raw: String = query.trim_prefix("?").strip_edges()
    if raw.is_empty():
        return result
    for parameter in raw.split("&",false):
        var pair: PackedStringArray = parameter.split("=",false,1)
        if pair.size() != 2:
            continue
        var key: String = pair[0]
        var value: String = pair[1].uri_decode().to_lower()
        if key == "scenario" and SCENARIOS.has(value):
            result["scenario"] = value
        elif key == "lang" and LANGUAGES.has(value):
            result["lang"] = value
    return result
