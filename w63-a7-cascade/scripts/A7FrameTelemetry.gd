extends RefCounted
class_name A7FrameTelemetry
## W74 real in-process timing samples; NOT a substitute for physical
## consumer GPU benchmarking. Provides an auditable p95 and tail stutter.
const WINDOW: int = 240
const MIN_VALID_DELTA: float = 0.001
const MAX_VALID_DELTA: float = 0.500
const STUTTER_THRESHOLD: float = 0.050
var samples: Array[float] = []
var total_frames: int = 0
var rejected_samples: int = 0
var stutter_samples: int = 0
var actual_observed_seconds: float = 0.0
var longest_frame_ms: float = 0.0

func sample_frame(delta: float) -> bool:
    if not is_finite(delta) or delta < MIN_VALID_DELTA or (
            delta > MAX_VALID_DELTA):
        rejected_samples += 1
        return false
    total_frames += 1
    actual_observed_seconds += delta
    var millis: float = delta*1000.0
    longest_frame_ms = maxf(longest_frame_ms,millis)
    if delta > STUTTER_THRESHOLD:
        stutter_samples += 1
    samples.append(millis)
    if samples.size() > WINDOW:
        samples.pop_front()
    return true

func qa_readout() -> Dictionary:
    var count: int = samples.size()
    var sorted: Array[float] = samples.duplicate()
    sorted.sort()
    var total_ms: float = 0.0
    for n in samples:
        total_ms += n
    var mean_ms: float = total_ms / float(count) if count > 0 else 0.0
    var p95_ms: float = sorted[clampi(ceili(count*0.95)-1,0,count-1)] if count > 0 else 0.0
    return {
        "schema":"LAST_FRONTIER_W74_LOCAL_FRAME_TIMING_TELEMETRY_V1",
        "window_samples":count,
        "valid_actual_frame_samples":total_frames,
        "rejected_invalid_samples":rejected_samples,
        "observed_seconds":snappedf(actual_observed_seconds,0.001),
        "mean_frame_ms":snappedf(mean_ms,0.01),
        "window_p95_frame_ms":snappedf(p95_ms,0.01),
        "estimated_window_fps":snappedf(1000.0/mean_ms,0.1) if mean_ms>0.0 else 0.0,
        "observed_stutter_over_50ms":stutter_samples,
        "worst_frame_ms":snappedf(longest_frame_ms,0.01),
        "frame_data_source":"GODOT_REAL_PROCESS_DELTA_NOT_GPU_PROFILER",
        "consumer_pc_gpu_benchmarked":false,
        "physical_mobile_benchmarked":false,
        "AAA_60fps_certified":false,
    }

func display(locale: String) -> String:
    var data: Dictionary = qa_readout()
    if total_frames < 20:
        return ("FPS: НАКОПЛЕНИЕ ДАННЫХ" if locale == "ru" else
            "FPS: COLLECTING RENDER DATA")
    return (("ИГРА: ~%.1f FPS / p95 %.1f мс / пиковых: %d"
        if locale == "ru" else
        "GAME: ~%.1f FPS / p95 %.1f ms / slow frames: %d") % [
        float(data["estimated_window_fps"]),
        float(data["window_p95_frame_ms"]),
        int(data["observed_stutter_over_50ms"])])
