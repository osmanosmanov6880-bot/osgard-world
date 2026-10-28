extends RefCounted
class_name IPPerformanceAudit
## V12 engineering telemetry, based only on REAL local frame deltas.
## This is not benchmark data and NEVER declares AAA/hardware certification.
const WINDOW: int = 120
var frame_ms: Array[float] = []
var lifetime_frames: int = 0
var _paused_frames: int = 0
var worst_seen_ms: float = 0.0
var current_quality: String = "hero"

func observe(delta: float,active: bool,quality: String) -> void:
    current_quality = "eco" if quality == "eco" else "hero"
    if not active:
        _paused_frames += 1
        return
    if delta <= 0.0 or delta > 1.0 or is_nan(delta) or is_inf(delta):
        return
    var value: float = delta*1000.0
    frame_ms.append(value)
    if frame_ms.size() > WINDOW:
        frame_ms.pop_front()
    lifetime_frames += 1
    worst_seen_ms = maxf(worst_seen_ms,value)

func telemetry() -> Dictionary:
    var sample_count: int = frame_ms.size()
    var average_ms: float = 0.0
    var p95_ms: float = 0.0
    var worst_ms: float = 0.0
    if sample_count > 0:
        var ordered: Array[float] = frame_ms.duplicate()
        ordered.sort()
        for value in ordered:
            average_ms += value
        average_ms /= float(sample_count)
        var p95_index: int = clampi(ceili(float(sample_count)*0.95)-1,0,sample_count-1)
        p95_ms = ordered[p95_index]
        worst_ms = ordered[sample_count-1]
    var fps: float = 1000.0/average_ms if average_ms > 0.001 else 0.0
    var suggest_eco: bool = sample_count >= 30 and p95_ms > 34.0
    return {
        "sample_count":sample_count,
        "lifetime_frames":lifetime_frames,
        "avg_frame_ms":snappedf(average_ms,0.01),
        "p95_frame_ms":snappedf(p95_ms,0.01),
        "window_worst_ms":snappedf(worst_ms,0.01),
        "estimated_fps":snappedf(fps,0.1),
        "eco_suggested":suggest_eco,
        "quality":current_quality,
        "hardware_certified":false,
        "production_approved":false,
        "external_device_tested":false
    }

func diagnostic_text(locale: String,scenario: String,campaign: IPCampaignFlow) -> String:
    var t: Dictionary = telemetry()
    var english: bool = locale == "en"
    var title: String = "IRON PULSE / ENGINEERING DIAGNOSTICS" if english else "IRON PULSE / ИНЖЕНЕРНАЯ ДИАГНОСТИКА"
    var quality_note: String = "ECO SUGGESTED" if bool(t["eco_suggested"]) else "QUALITY OBSERVATION"
    var warning: String = "HARDWARE QA NOT CERTIFIED" if english else "ФИЗИЧЕСКИЕ УСТРОЙСТВА НЕ ПРОВЕРЕНЫ"
    return "%s\n%s  /  %s\nFRAME AVG  %.2f ms  /  P95  %.2f ms\nEST. FPS  %.1f   /  SAMPLES  %d\n%s\n%s" % [
        title,scenario.to_upper(),current_quality.to_upper(),
        float(t["avg_frame_ms"]),float(t["p95_frame_ms"]),
        float(t["estimated_fps"]),int(t["sample_count"]),
        quality_note,
        warning
    ]

func release_gate() -> Dictionary:
    # Exact-head CI, art, legal and physical GPU testing are EXTERNAL gates.
    # An in-game telemetry HUD must never counterfeit their approval.
    return {
        "software_ci_verified_here":false,
        "production_ready":false,
        "outstanding":[
            "exact_head_godot_windows_webgl_ci",
            "real_windows_gpu_30_minute_playtest",
            "physical_android_ios_touch_qa",
            "real_gamepad_qa",
            "independent_art_direction_approval",
            "20_player_gameplay_review",
            "rights_and_name_clearance",
            "staging_and_rollback"
        ]
    }
