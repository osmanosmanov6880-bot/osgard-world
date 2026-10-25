extends Node
## W26: aggregate educational event counts ONLY. No identifiers, timestamps,
## IP addresses, third-party SDK, HTTP, device fingerprints or remote upload.
## Tracking starts disabled. User must explicitly opt in with a real Godot button.
## This is local progress telemetry, NOT cloud product analytics.
const SAVE_PATH = "user://r135_private_learning_metrics_v1.cfg"
const SCHEMA_VERSION: int = 1
const EVENT_NAMES = [
    "training_started", "training_completed",
    "diagnosis_started", "diagnosis_completed",
    "safety_blocked", "scan_accepted"
]
const MAX_COUNT: int = 1000000
var consent: bool = false
var counts: Dictionary = {}
var last_save_ok: bool = true
var last_event: String = ""
var write_failures: int = 0


func _ready() -> void:
    _load()


func _defaults() -> Dictionary:
    var defaults: Dictionary = {}
    for name in EVENT_NAMES:
        defaults[name] = 0
    return defaults


func _load() -> void:
    consent = false
    counts = _defaults()
    var cfg := ConfigFile.new()
    if cfg.load(SAVE_PATH) != OK:
        return
    var saved_schema: Variant = cfg.get_value("metrics", "schema", null)
    var saved_consent: Variant = cfg.get_value("metrics", "consent", null)
    var saved_counts: Variant = cfg.get_value("metrics", "counts", null)
    if typeof(saved_schema) != TYPE_INT or saved_schema != SCHEMA_VERSION or \
            typeof(saved_consent) != TYPE_BOOL or typeof(saved_counts) != TYPE_DICTIONARY:
        return
    var safe: Dictionary = _defaults()
    for key in EVENT_NAMES:
        var value: Variant = saved_counts.get(key, null)
        if typeof(value) != TYPE_INT or value < 0 or value > MAX_COUNT:
            return
        safe[key] = value
    # Reject unknown additional keys, including hidden identifiers.
    if saved_counts.size() != EVENT_NAMES.size():
        return
    consent = saved_consent
    counts = safe if consent else _defaults()


func _save() -> void:
    var cfg := ConfigFile.new()
    cfg.set_value("metrics", "schema", SCHEMA_VERSION)
    cfg.set_value("metrics", "consent", consent)
    cfg.set_value("metrics", "counts", counts.duplicate(true))
    last_save_ok = cfg.save(SAVE_PATH) == OK
    if not last_save_ok:
        write_failures += 1


func set_consent(allow: bool) -> void:
    # Opting out deletes all previously collected local aggregate counters.
    consent = allow
    if not allow:
        counts = _defaults()
        last_event = ""
    _save()


func record(event: String) -> bool:
    if not consent or not (event in EVENT_NAMES):
        return false
    counts[event] = mini(int(counts[event]) + 1, MAX_COUNT)
    last_event = event
    _save()
    return last_save_ok


func erase() -> void:
    counts = _defaults()
    last_event = ""
    _save()


func total() -> int:
    var sum: int = 0
    for key in EVENT_NAMES:
        sum += int(counts[key])
    return sum


func snapshot() -> Dictionary:
    return {
        "schema": SCHEMA_VERSION,
        "consent": consent,
        "total": total(),
        "training_started": int(counts["training_started"]),
        "training_completed": int(counts["training_completed"]),
        "diagnosis_started": int(counts["diagnosis_started"]),
        "diagnosis_completed": int(counts["diagnosis_completed"]),
        "safety_blocked": int(counts["safety_blocked"]),
        "scan_accepted": int(counts["scan_accepted"]),
        "last_event": last_event,
        "saved": last_save_ok,
        "write_failures": write_failures,
        "network_uploads": 0,
        "user_identifiers_stored": false,
        "timestamps_stored": false,
        "simulation_only": true
    }
