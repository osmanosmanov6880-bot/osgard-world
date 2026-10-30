extends RefCounted
class_name IPVisionProfile
## G11: local, reversible, privacy-safe visual readability preferences.
## Presentation only: never touches IPCrisisEngine, scores or campaign saves.
const FORMAT: String = "IRON_PULSE_VISUAL_READABILITY_G11"
const PATH: String = "user://iron_pulse_visual_readability_g11.cfg"
const MODES: Array[String] = ["standard","contrast","large"]
const SAVE_GROUP: String = "presentation"
const SAVE_FIELD: String = "vision_mode"
const STANDARD_TEXT: float = 1.0
const LARGE_TEXT_DESKTOP: float = 1.15
const LARGE_TEXT_MOBILE: float = 1.09
var mode: String = "standard"

func set_mode(candidate: String) -> bool:
    if not MODES.has(candidate):
        return false
    mode = candidate
    return true

func cycle() -> String:
    mode = MODES[(MODES.find(mode)+1)%MODES.size()]
    return mode

func high_contrast() -> bool:
    return mode == "contrast" or mode == "large"

func text_scale(compact: bool) -> float:
    if mode == "large":
        return LARGE_TEXT_MOBILE if compact else LARGE_TEXT_DESKTOP
    return STANDARD_TEXT

func emphasis_tier(heat: float,oxygen: float) -> String:
    # Deliberately redundant visual language: numeric metrics + words + shape.
    # This is purely the fictional reactor engine's status, not medical advice.
    if not is_finite(heat) or not is_finite(oxygen):
        return "unknown"
    if heat >= 85.0 or oxygen <= 24.0:
        return "critical"
    if heat >= 69.0 or oxygen <= 48.0:
        return "watch"
    return "stable"

func hazard_words(tier: String,language: String) -> String:
    if language == "en":
        match tier:
            "critical": return "! / CRITICAL"
            "watch": return "! / CAUTION"
            "stable": return "✓ / NORMAL"
            _: return "? / UNKNOWN"
    match tier:
        "critical": return "! / ОПАСНОСТЬ"
        "watch": return "! / ВНИМАНИЕ"
        "stable": return "✓ / НОРМА"
        _: return "? / НЕТ ДАННЫХ"

func label(language: String) -> String:
    var en: bool = language == "en"
    match mode:
        "contrast": return "VISION / HIGH CONTRAST" if en else "ВИД / ВЫСОКИЙ КОНТРАСТ"
        "large": return "VISION / LARGE TEXT" if en else "ВИД / КРУПНЫЙ ТЕКСТ"
        _: return "VISION / STANDARD" if en else "ВИД / СТАНДАРТ"

func save_to(path: String = PATH) -> bool:
    # Only a 3-value enum. Never persist device IDs, account data or telemetry.
    var config := ConfigFile.new()
    config.set_value(SAVE_GROUP,"schema",FORMAT)
    config.set_value(SAVE_GROUP,SAVE_FIELD,mode)
    return config.save(path) == OK

func load_from(path: String = PATH) -> bool:
    var config := ConfigFile.new()
    if config.load(path) != OK:
        return false
    if str(config.get_value(SAVE_GROUP,"schema","")) != FORMAT:
        return false
    var candidate: Variant = config.get_value(SAVE_GROUP,SAVE_FIELD,"")
    if typeof(candidate) != TYPE_STRING:
        return false
    return set_mode(str(candidate))

func readout(compact: bool = false) -> Dictionary:
    return {
        "schema":FORMAT,
        "mode":mode,
        "modes":MODES.duplicate(),
        "high_contrast":high_contrast(),
        "text_scale":text_scale(compact),
        "presentation_only":true,
        "gameplay_mutated":false,
        "local_storage_only":true,
        "device_identifiers_collected":false,
        "account_ids_collected":false,
        "telemetry_uploaded":false
    }
