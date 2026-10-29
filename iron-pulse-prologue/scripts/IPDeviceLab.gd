extends RefCounted
class_name IPDeviceLab
## G4: explicit OPT-IN local run-time frame-delta measurement.
## This measures actual executing client's _process delta, not GPU timings.
## Nothing is transmitted, fingerprints are not collected, and synthetic CI
## inputs are never evidence that physical devices have been tested.

const FORMAT: String = "IRON_PULSE_DEVICE_LAB_G4"
const REPORT_PATH: String = "user://iron_pulse_device_lab_g4.json"
const MAX_SAMPLES: int = 18000
const MAX_SECONDS: float = 600.0
const VALID_SECONDS: float = 90.0
const VALID_SAMPLES: int = 1800

var state: String = "idle"
var frames_ms: Array[float] = []
var total_frames: int = 0
var active_seconds: float = 0.0
var excluded_paused: int = 0
var excluded_interrupted: int = 0
var invalid_deltas: int = 0
var hitches_50ms: int = 0
var stalls_250ms: int = 0
var truncated_samples: bool = false
var quality_start: String = "hero"
var quality_end: String = "hero"
var locale_start: String = "ru"
var viewport_start: Vector2i = Vector2i.ZERO
var viewport_end: Vector2i = Vector2i.ZERO
var mixed_quality: bool = false
var viewport_changed: bool = false
var auto_completed: bool = false
var last_local_save_ok: bool = false
var _cached: Dictionary = {}
var _frames_since_summary: int = 0

func begin(quality: String,language: String,size: Vector2i,game_active: bool) -> bool:
    if not game_active or quality not in ["hero","eco"] or language not in ["ru","en"]:
        return false
    if size.x < 280 or size.y < 300 or size.x > 12000 or size.y > 12000:
        return false
    state = "recording"
    frames_ms.clear()
    total_frames = 0
    active_seconds = 0.0
    excluded_paused = 0
    excluded_interrupted = 0
    invalid_deltas = 0
    hitches_50ms = 0
    stalls_250ms = 0
    truncated_samples = false
    quality_start = quality
    quality_end = quality
    locale_start = language
    viewport_start = size
    viewport_end = size
    mixed_quality = false
    viewport_changed = false
    auto_completed = false
    last_local_save_ok = false
    _cached.clear()
    _frames_since_summary = 0
    return true

func observe(delta: float,game_active: bool,quality: String,size: Vector2i) -> void:
    if state != "recording":
        return
    if not game_active:
        excluded_paused += 1
        return
    if not is_finite(delta) or delta <= 0.0:
        invalid_deltas += 1
        return
    # Browser backgrounding can generate a multi-second delta. Mark it as
    # an interruption; never silently turn that delay into normal gameplay.
    if delta > 2.0:
        excluded_interrupted += 1
        return
    if quality not in ["hero","eco"]:
        invalid_deltas += 1
        return
    if size.x < 280 or size.y < 300:
        invalid_deltas += 1
        return
    if quality != quality_start:
        mixed_quality = true
    if size != viewport_start:
        viewport_changed = true
    quality_end = quality
    viewport_end = size
    var ms: float = delta*1000.0
    active_seconds += delta
    total_frames += 1
    if ms >= 50.0:
        hitches_50ms += 1
    if ms >= 250.0:
        stalls_250ms += 1
    frames_ms.append(ms)
    if frames_ms.size() > MAX_SAMPLES:
        frames_ms.pop_front()
        truncated_samples = true
    _frames_since_summary += 1
    if active_seconds >= MAX_SECONDS:
        finish()
        auto_completed = true

func finish() -> bool:
    if state != "recording":
        return false
    state = "complete"
    snapshot(true)
    return true

func _percentile(sorted: Array[float],fraction: float) -> float:
    if sorted.is_empty():
        return 0.0
    var index: int = clampi(ceili(float(sorted.size())*fraction)-1,0,sorted.size()-1)
    return sorted[index]

func snapshot(force: bool = false) -> Dictionary:
    # Recalculate at most every 60 accepted frames unless a user explicitly
    # finishes/exports. Read-only WebGL diagnostics don't sort each frame.
    if not force and not _cached.is_empty() and _frames_since_summary < 60:
        return _cached.duplicate(true)
    _frames_since_summary = 0
    var ordered: Array[float] = frames_ms.duplicate()
    ordered.sort()
    var avg: float = 0.0
    for number in ordered:
        avg += number
    if not ordered.is_empty():
        avg /= float(ordered.size())
    var median: float = _percentile(ordered,0.50)
    var p95: float = _percentile(ordered,0.95)
    var p99: float = _percentile(ordered,0.99)
    var comparable: bool = state == "complete" and
        active_seconds >= VALID_SECONDS and total_frames >= VALID_SAMPLES and
        not mixed_quality and not viewport_changed and
        excluded_interrupted == 0 and not truncated_samples
    _cached = {
        "schema": FORMAT,
        "status": state,
        "source": "actual_current_client_main_loop_delta",
        "main_thread_proxy_not_gpu_profiler": true,
        "frames_captured": total_frames,
        "stored_frame_samples": frames_ms.size(),
        "sample_truncated": truncated_samples,
        "active_seconds": snappedf(active_seconds,0.01),
        "median_ms": snappedf(median,0.01),
        "p95_ms": snappedf(p95,0.01),
        "p99_ms": snappedf(p99,0.01),
        "average_ms": snappedf(avg,0.01),
        "estimated_fps": snappedf(1000.0/avg,0.1) if avg>0.001 else 0.0,
        "hitches_over_50ms": hitches_50ms,
        "stalls_over_250ms": stalls_250ms,
        "paused_frames_excluded": excluded_paused,
        "background_interruption_count": excluded_interrupted,
        "invalid_deltas_excluded": invalid_deltas,
        "quality_start": quality_start,
        "quality_end": quality_end,
        "quality_changed": mixed_quality,
        "viewport_start": [viewport_start.x,viewport_start.y],
        "viewport_end": [viewport_end.x,viewport_end.y],
        "viewport_changed": viewport_changed,
        "locale_start": locale_start,
        "auto_stopped_at_10min": auto_completed,
        "comparable_local_run": comparable,
        "hardware_physically_verified": false,
        "independent_hardware_certification": false,
        "telemetry_uploaded": false,
        "account_ids_collected": false,
        "device_fingerprint_collected": false
    }
    return _cached.duplicate(true)

func report() -> Dictionary:
    if state != "complete":
        return {}
    var result: Dictionary = snapshot(true)
    result["format"] = FORMAT
    result["privacy"] = "local report only; no IP, GPU/phone identifiers or user accounts"
    result["interpretation"] = "Frame deltas from current actual running client; not GPU timings or physical certification"
    result["next_gate"] = "manual on-device 3-act input/30min soak plus independent reviewer signoff"
    return result

func save_local_report() -> bool:
    if state != "complete":
        last_local_save_ok = false
        return false
    var result: Dictionary = report()
    if result.is_empty():
        return false
    var file := FileAccess.open(REPORT_PATH,FileAccess.WRITE)
    if file == null:
        last_local_save_ok = false
        return false
    file.store_string(JSON.stringify(result,"  "))
    file.flush()
    file.close()
    last_local_save_ok = FileAccess.file_exists(REPORT_PATH)
    return last_local_save_ok

func panel_text(language: String) -> String:
    var english: bool = language=="en"
    var t: Dictionary = snapshot()
    var heading: String = "DEVICE LAB / LOCAL FRAME TEST" if english else "DEVICE LAB / ЛОКАЛЬНЫЙ ТЕСТ"
    var sub: String = "LIVE" if state=="recording" else "DONE" if state=="complete" else "NOT STARTED"
    if not english:
        sub = "ИДЁТ ЗАПИСЬ" if state=="recording" else "ГОТОВО" if state=="complete" else "НЕ ЗАПУЩЕН"
    var note: String = "MAIN-LOOP DELTA. NOT GPU FPS CERTIFICATION." if english else "ВРЕМЯ КАДРА. НЕ СЕРТИФИКАЦИЯ GPU."
    var warning: String = "REAL PHONE / WINDOWS HARDWARE QA: NOT VERIFIED" if english else "ПРОВЕРКА НА ФИЗИЧЕСКИХ УСТРОЙСТВАХ: НЕТ"
    return "%s\n%s   /   %s\nSAMPLES  %d   /   ACTIVE  %.1f s\nP50  %.2f ms   P95  %.2f ms   P99  %.2f ms\nHITCH >=50ms  %d   /   STALL >=250ms  %d\n%s\n%s" % [
        heading,sub,str(t["quality_start"]).to_upper(),
        int(t["frames_captured"]),float(t["active_seconds"]),
        float(t["median_ms"]),float(t["p95_ms"]),float(t["p99_ms"]),
        int(t["hitches_over_50ms"]),int(t["stalls_over_250ms"]),
        note,warning
    ]
