extends RefCounted
class_name IPLookComfort
## G14 native Godot camera accessibility, driven by actual physical input.
## This never touches campaign state, player motion, scores, event records or
## remote telemetry. No autonomous camera positioning or scripted progress.
const FORMAT: String = "IRON_PULSE_LOOK_COMFORT_G14"
const SAVE_PATH: String = "user://iron_pulse_look_comfort_g14.cfg"
const GROUP: String = "presentation"
const OPTIONS: Array[String] = ["standard", "gentle", "invert_y"]
const ORIGINAL_SPEED: float = 0.0021
const GENTLE_SPEED: float = 0.00125
const MAX_RELATIVE: float = 1000.0
var mode: String = "standard"

func set_mode(candidate: String) -> bool:
    if not OPTIONS.has(candidate):
        return false
    mode = candidate
    return true

func next_mode() -> String:
    mode = OPTIONS[(OPTIONS.find(mode)+1)%OPTIONS.size()]
    return mode

func speed() -> float:
    return GENTLE_SPEED if mode == "gentle" else ORIGINAL_SPEED

func inverted() -> bool:
    return mode == "invert_y"

func angular_delta(raw_motion: Vector2) -> Vector2:
    # Match original Godot _look() horizontal/vertical signs by default.
    # Mouse relative, touch drag, and gamepad right-stick already enter
    # _look() through the same authentic event path.
    if not is_finite(raw_motion.x) or not is_finite(raw_motion.y):
        return Vector2.ZERO
    var dx: float = clampf(raw_motion.x, -MAX_RELATIVE, MAX_RELATIVE)
    var dy: float = clampf(raw_motion.y, -MAX_RELATIVE, MAX_RELATIVE)
    var amount: float = speed()
    return Vector2(-dx*amount, dy*amount if inverted() else -dy*amount)

func caption(lang: String) -> String:
    var english: bool = lang == "en"
    match mode:
        "gentle":
            return "LOOK / GENTLE" if english else "ВЗГЛЯД / ПЛАВНО"
        "invert_y":
            return "LOOK / INVERT Y" if english else "ВЗГЛЯД / ИНВЕРСИЯ"
        _:
            return "LOOK / STANDARD" if english else "ВЗГЛЯД / ОБЫЧНЫЙ"

func touch_caption(lang: String) -> String:
    var english: bool = lang == "en"
    match mode:
        "gentle":
            return "LOOK SLOW" if english else "ОБЗОР МЕДЛ"
        "invert_y":
            return "LOOK INV Y" if english else "ОБЗОР ИНВ"
        _:
            return "LOOK / F10" if english else "ОБЗОР / F10"

func save_to(path: String = SAVE_PATH) -> bool:
    # Plain allowlisted enum only. Never hardware fingerprints, coordinates,
    # user identities, analytics, session IDs or game save state.
    var data := ConfigFile.new()
    data.set_value(GROUP,"schema",FORMAT)
    data.set_value(GROUP,"mode",mode)
    return data.save(path) == OK

func load_from(path: String = SAVE_PATH) -> bool:
    var data := ConfigFile.new()
    if data.load(path) != OK:
        return false
    if str(data.get_value(GROUP,"schema","")) != FORMAT:
        return false
    var stored: Variant = data.get_value(GROUP,"mode","")
    if typeof(stored) != TYPE_STRING:
        return false
    return set_mode(str(stored))

func readout() -> Dictionary:
    return {
        "schema": FORMAT,
        "mode": mode,
        "options": OPTIONS.duplicate(),
        "camera_speed": speed(),
        "invert_y": inverted(),
        "original_input_path": "Godot InputEventMouseMotion / InputEventScreenDrag / gamepad right stick",
        "camera_physics": "existing true CharacterBody3D/player + Camera3D",
        "local_only": true,
        "presentation_only": true,
        "autonomous_camera": false,
        "gameplay_mutated": false,
        "telemetry_uploaded": false,
        "device_identifiers_collected": false,
        "user_identifiers_collected": false
    }
