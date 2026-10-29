extends RefCounted
class_name IPAdaptivePerformance
## V18 / measured LOCAL frame-pacing control, NOT hardware certification.
## This policy never reads the gameplay engine, never touches its checkpoints,
## never sends telemetry and never promises a specific device frame rate.
## It suggests ONLY an already-existing graphics profile: hero or eco.

const FORMAT: String = "IRON_PULSE_ADAPTIVE_QUALITY_V18"
const MIN_SAMPLES: int = 90
const EVALUATION_SECONDS: float = 3.0
const COOLDOWN_SECONDS: float = 18.0
const SLOW_P95_MS: float = 34.0
const RECOVERY_P95_MS: float = 19.0
const SLOW_WINDOWS: int = 2
const FAST_WINDOWS: int = 4

var enabled: bool = false
var evaluation_seconds: float = 0.0
var since_change_seconds: float = COOLDOWN_SECONDS
var slow_windows: int = 0
var fast_windows: int = 0
var switches: int = 0
var eligible_evaluations: int = 0
var last_reason: String = "manual"
var compact_device: bool = false

func set_enabled(value: bool) -> void:
    enabled = value
    evaluation_seconds = 0.0
    since_change_seconds = COOLDOWN_SECONDS
    slow_windows = 0
    fast_windows = 0
    last_reason = "waiting_for_real_frames" if value else "manual"

func _reset_streaks() -> void:
    slow_windows = 0
    fast_windows = 0

func observe(delta: float, active: bool, current_quality: String,
        measured: Dictionary, compact: bool) -> String:
    # Return "" for no action. A return value is an actual existing art mode.
    compact_device = compact
    if not enabled or not active:
        evaluation_seconds = 0.0
        _reset_streaks()
        return ""
    # Alt-tab and browser suspension may produce giant deltas that are not
    # representative of real frame rendering. Ignore them, never downgrade.
    if not is_finite(delta) or delta <= 0.0 or delta > 0.25:
        return ""
    since_change_seconds += delta
    evaluation_seconds += delta
    if evaluation_seconds < EVALUATION_SECONDS:
        return ""
    evaluation_seconds = 0.0
    var count: int = int(measured.get("sample_count",0))
    if count < MIN_SAMPLES:
        _reset_streaks()
        last_reason = "sampling"
        return ""
    var p95: float = float(measured.get("p95_frame_ms",-1.0))
    if not is_finite(p95) or p95 <= 0.0 or p95 > 250.0:
        _reset_streaks()
        last_reason = "invalid_sample"
        return ""
    eligible_evaluations += 1
    if p95 > SLOW_P95_MS:
        slow_windows += 1
        fast_windows = 0
    elif p95 < RECOVERY_P95_MS:
        fast_windows += 1
        slow_windows = 0
    else:
        _reset_streaks()
        last_reason = "within_band"
    if since_change_seconds < COOLDOWN_SECONDS:
        return ""
    if current_quality == "hero" and slow_windows >= SLOW_WINDOWS:
        since_change_seconds = 0.0
        switches += 1
        last_reason = "measured_p95_slow"
        _reset_streaks()
        return "eco"
    # Never promote to the expensive profile on a compact viewport, even
    # when the synthetic/real sample happens to be very fast.
    if current_quality == "eco" and not compact and fast_windows >= FAST_WINDOWS:
        since_change_seconds = 0.0
        switches += 1
        last_reason = "sustained_measured_recovery"
        _reset_streaks()
        return "hero"
    return ""

func readout(quality: String, measured: Dictionary) -> Dictionary:
    return {
        "schema": FORMAT,
        "enabled": enabled,
        "quality": quality,
        "policy": "adaptive" if enabled else "manual",
        "local_frame_samples": int(measured.get("sample_count",0)),
        "local_p95_ms": float(measured.get("p95_frame_ms",0.0)),
        "local_estimated_fps": float(measured.get("estimated_fps",0.0)),
        "compact_device": compact_device,
        "switches": switches,
        "evaluations": eligible_evaluations,
        "last_reason": last_reason,
        "trigger_p95_ms": SLOW_P95_MS,
        "recovery_p95_ms": RECOVERY_P95_MS,
        "hardware_certified": false,
        "fps_guaranteed": false,
        "telemetry_uploaded": false
    }

func status_line(locale: String,quality: String,measured: Dictionary) -> String:
    var english: bool = locale == "en"
    var mode: String = "AUTO" if enabled else "MANUAL"
    var p95: String = "—"
    if int(measured.get("sample_count",0)) >= MIN_SAMPLES:
        p95 = "%.1f" % float(measured.get("p95_frame_ms",0.0))
    return ("GRAPHICS %s / %s / P95 %sms" if english else "ГРАФИКА %s / %s / P95 %sms") % [
        quality.to_upper(),mode,p95]
