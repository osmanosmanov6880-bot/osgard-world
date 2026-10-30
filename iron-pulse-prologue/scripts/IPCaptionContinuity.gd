extends RefCounted
class_name IPCaptionContinuity
## G14 — Accessible original dialogue timing, no replay synthesis.
## All words remain authored by IPStoryDirector, not generated or translated
## over the network. Only a whitelisted local display preference is persisted.
const FORMAT: String = "IRON_PULSE_CAPTION_CONTINUITY_G14"
const PATH: String = "user://iron_pulse_caption_continuity_g14.cfg"
const MODES: Array[String] = ["timed","extended","pinned"]
const DEFAULT: String = "timed"
const EXTENDED_SECONDS: float = 24.0

var mode: String = DEFAULT

func set_mode(next_mode: String) -> bool:
    if not MODES.has(next_mode):
        return false
    mode = next_mode
    return true

func cycle() -> String:
    mode = MODES[(MODES.find(mode)+1) % MODES.size()]
    return mode

func duration_seconds(original_seconds: float) -> float:
    if not is_finite(original_seconds):
        return 0.0
    var safe: float = clampf(original_seconds,0.0,120.0)
    return maxf(safe,EXTENDED_SECONDS) if mode == "extended" else safe

func should_display(game_active: bool,source_line_exists: bool,
        seconds_remaining: float,priority_visible: bool,
        blocking_overlay: bool) -> bool:
    # Do not surface any dialogue while in intro, pause, cinematic or modal.
    # A genuine crew/core selection always wins over a persistent subtitle.
    if not game_active or not source_line_exists or priority_visible or blocking_overlay:
        return false
    if mode == "pinned":
        return true
    return is_finite(seconds_remaining) and seconds_remaining > 0.0

func label(locale: String) -> String:
    var english: bool = locale == "en"
    match mode:
        "extended":
            return "CAPTIONS / 24 SEC" if english else "СУБТИТРЫ / 24 СЕК"
        "pinned":
            return "CAPTIONS / HOLD" if english else "СУБТИТРЫ / ЗАКРЕПЛЕНЫ"
        _:
            return "CAPTIONS / TIMED" if english else "СУБТИТРЫ / ОБЫЧНЫЕ"

func save_to(path: String = PATH) -> bool:
    var file := ConfigFile.new()
    file.set_value("presentation","schema",FORMAT)
    file.set_value("presentation","mode",mode)
    return file.save(path) == OK

func load_from(path: String = PATH) -> bool:
    var file := ConfigFile.new()
    if file.load(path) != OK:
        return false
    if str(file.get_value("presentation","schema","")) != FORMAT:
        return false
    var option: Variant = file.get_value("presentation","mode","")
    if typeof(option) != TYPE_STRING:
        return false
    return set_mode(str(option))

func readout() -> Dictionary:
    return {
        "schema":FORMAT,
        "mode":mode,
        "modes":MODES.duplicate(),
        "extended_seconds":EXTENDED_SECONDS,
        "authored_source_only":true,
        "story_events_created":false,
        "fictional_engine_state_changed":false,
        "local_only":true,
        "telemetry_uploaded":false,
        "player_identifiers_collected":false,
        "full_dialogue_retained_in_journal":true
    }
