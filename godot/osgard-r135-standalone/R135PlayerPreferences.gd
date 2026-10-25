extends RefCounted
## W20 isolated local player preferences. No network, identifiers or hardware control.
## Intentionally NEVER touches W14 case records or W19 tutorial progress.

const SAVE_PATH: String = "user://r135_player_preferences_v1.cfg"
const SCHEMA_VERSION: int = 1

static func defaults(system_reduced_motion: bool = false) -> Dictionary:
    return {
        "schema": SCHEMA_VERSION,
        "locale": "ru",
        "quality": 0,
        "reduced_motion": system_reduced_motion,
        "loaded": false
    }


static func load_local(system_reduced_motion: bool = false, path: String = SAVE_PATH) -> Dictionary:
    var result: Dictionary = defaults(system_reduced_motion)
    var file := ConfigFile.new()
    if file.load(path) != OK:
        return result
    var schema: Variant = file.get_value("settings", "schema", -1)
    if typeof(schema) != TYPE_INT or int(schema) != SCHEMA_VERSION:
        return result
    # Malformed values never become arbitrary strings, unsafe quality settings,
    # or a false "accessibility enabled" state.
    var lang: Variant = file.get_value("settings", "locale", "ru")
    if typeof(lang) == TYPE_STRING and lang in ["ru", "en"]:
        result["locale"] = lang
    var detail: Variant = file.get_value("settings", "quality", 0)
    if typeof(detail) == TYPE_INT and detail in [0, 2]:
        result["quality"] = detail
    var motion: Variant = file.get_value("settings", "reduced_motion", system_reduced_motion)
    if typeof(motion) == TYPE_BOOL:
        result["reduced_motion"] = motion
    result["loaded"] = true
    return result


static func save_local(locale: String, quality: int, reduced_motion: bool, path: String = SAVE_PATH) -> bool:
    if locale not in ["ru", "en"] or quality not in [0, 2]:
        return false
    var file := ConfigFile.new()
    file.set_value("settings", "schema", SCHEMA_VERSION)
    file.set_value("settings", "locale", locale)
    file.set_value("settings", "quality", quality)
    file.set_value("settings", "reduced_motion", reduced_motion)
    return file.save(path) == OK
