extends RefCounted
## W24 independent, backward-compatible audio accessibility settings.
## Never modifies W14 case records, W19 tutorial or W20 graphics preferences.
const SAVE_PATH: String = "user://r135_audio_accessibility_v1.cfg"
const SCHEMA_VERSION: int = 1

static func defaults() -> Dictionary:
    return {
        "schema": SCHEMA_VERSION,
        "sound_enabled": false,
        "captions_enabled": true,
        "volume": 0.45,
        "loaded": false,
        "save_ok": true
    }


static func load_local(path: String = SAVE_PATH) -> Dictionary:
    var out: Dictionary = defaults()
    var file := ConfigFile.new()
    if file.load(path) != OK:
        return out
    var schema: Variant = file.get_value("audio", "schema", -1)
    if typeof(schema) != TYPE_INT or int(schema) != SCHEMA_VERSION:
        return out
    var enabled: Variant = file.get_value("audio", "sound_enabled", false)
    if typeof(enabled) == TYPE_BOOL:
        out["sound_enabled"] = enabled
    var captions: Variant = file.get_value("audio", "captions_enabled", true)
    if typeof(captions) == TYPE_BOOL:
        out["captions_enabled"] = captions
    var volume: Variant = file.get_value("audio", "volume", 0.45)
    if typeof(volume) in [TYPE_FLOAT, TYPE_INT] and is_finite(float(volume)) and float(volume) >= 0.0 and float(volume) <= 0.65:
        out["volume"] = float(volume)
    out["loaded"] = true
    return out


static func save_local(enabled: bool, captions: bool, volume: float,
        path: String = SAVE_PATH) -> bool:
    if not is_finite(volume) or volume < 0.0 or volume > 0.65:
        return false
    var settings := ConfigFile.new()
    settings.set_value("audio", "schema", SCHEMA_VERSION)
    settings.set_value("audio", "sound_enabled", enabled)
    settings.set_value("audio", "captions_enabled", captions)
    settings.set_value("audio", "volume", volume)
    return settings.save(path) == OK
