extends RefCounted
class_name IPControlComfort
## G12 original in-engine keyboard/motor accessibility profiles.
## Holds no source engine reference; movement is always computed from physical
## keys, touch and mapped gamepad, never autonomous AI or scripted progress.
const FORMAT: String = "IRON_PULSE_CONTROL_COMFORT_G12"
const PATH: String = "user://iron_pulse_control_comfort_g12.cfg"
const MODES: Array[String] = ["wasd_hold","arrows_hold","arrows_toggle"]
const DEFAULT: String = "wasd_hold"
var mode: String = DEFAULT
var sprint_latched: bool = false

func set_mode(candidate: String) -> bool:
    if not MODES.has(candidate):
        return false
    mode = candidate
    sprint_latched = false
    return true

func cycle() -> String:
    set_mode(MODES[(MODES.find(mode)+1)%MODES.size()])
    return mode

func axes(wasd: Vector2,arrows: Vector2,touch: Vector2,gamepad: Vector2) -> Vector2:
    # The active physical keyboard preset is exclusive. Touch/gamepad always
    # remain available, and the same source-world movement physics integrates it.
    var keyboard: Vector2 = wasd if mode == "wasd_hold" else arrows
    var combined: Vector2 = keyboard+touch+gamepad
    if not is_finite(combined.x) or not is_finite(combined.y):
        return Vector2.ZERO
    return combined.limit_length(1.0)

func handle_shift_pressed(active_gameplay: bool) -> bool:
    # Return true only when explicit toggle-sprint mode handled this press.
    if mode != "arrows_toggle" or not active_gameplay:
        return false
    sprint_latched = not sprint_latched
    return true

func sprinting(physical_shift_held: bool) -> bool:
    return sprint_latched if mode == "arrows_toggle" else physical_shift_held

func on_stop() -> void:
    # A stopped, paused or finished game cannot have a sticky sprint.
    sprint_latched = false

func label(language: String) -> String:
    var english: bool = language == "en"
    match mode:
        "arrows_hold":
            return "ARROW KEYS / HOLD SHIFT" if english else "СТРЕЛКИ / SHIFT УДЕРЖАТЬ"
        "arrows_toggle":
            return "ARROWS / SHIFT TOGGLE" if english else "СТРЕЛКИ / SHIFT ПЕРЕКЛЮЧАТЕЛЬ"
        _:
            return "WASD / HOLD SHIFT" if english else "WASD / SHIFT УДЕРЖАТЬ"

func save_to(path: String = PATH) -> bool:
    # No key scan codes, account, personal info or gameplay metadata persists.
    var config := ConfigFile.new()
    config.set_value("presentation","schema",FORMAT)
    config.set_value("presentation","mode",mode)
    return config.save(path) == OK

func load_from(path: String = PATH) -> bool:
    var config := ConfigFile.new()
    if config.load(path) != OK:
        return false
    if str(config.get_value("presentation","schema","")) != FORMAT:
        return false
    var input_mode: Variant = config.get_value("presentation","mode","")
    if typeof(input_mode) != TYPE_STRING:
        return false
    return set_mode(str(input_mode))

func readout() -> Dictionary:
    return {
        "schema":FORMAT,
        "mode":mode,
        "modes":MODES.duplicate(),
        "keyboard":"WASD" if mode == "wasd_hold" else "ARROWS",
        "shift_behavior":"TOGGLE" if mode == "arrows_toggle" else "HOLD",
        "sprint_latched":sprint_latched,
        "touch_preserved":true,
        "standard_gamepad_preserved":true,
        "movement_engine":"existing_character_body_3d",
        "automated_player_actions":false,
        "gameplay_score_mutated":false,
        "telemetry_uploaded":false,
        "local_only":true,
        "device_ids_collected":false
    }
