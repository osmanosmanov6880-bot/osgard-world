extends Node
## R12 opt-in frame-time driven quality controller. Uses measured runtime FPS,
## not a GPU model heuristic. Manual F3 overrides it. Frozen while F7 benchmarks.
## Sustained deficits trigger a downgrade; recovery is deliberately slower.

signal quality_requested(mode: int, reason: String)

const DOWNSHIFT_FPS: float = 34.0
const UPSHIFT_FPS: float = 57.0
const DOWNSHIFT_SECONDS: float = 8.0
const UPSHIFT_SECONDS: float = 35.0
const SWITCH_COOLDOWN: float = 25.0

var auto_enabled: bool = false
var quality_mode: int = 0
var below_target: float = 0.0
var above_target: float = 0.0
var cooldown: float = 0.0
var monitor_elapsed: float = 0.0
var samples: int = 0
var last_fps: float = 0.0
var host_benchmark: Node

func _ready() -> void:
    host_benchmark = get_parent().get_node_or_null("R11_PerformanceLab")

func set_auto(enabled: bool) -> void:
    auto_enabled = enabled
    below_target = 0.0
    above_target = 0.0
    cooldown = 0.0
    monitor_elapsed = 0.0

func sync_quality(mode: int) -> void:
    quality_mode = clampi(mode, 0, 2)

func _reset_evidence() -> void:
    below_target = 0.0
    above_target = 0.0

func observe_fps(fps: float, seconds: float, recording: bool = false) -> int:
    # Deterministic entrypoint permits testing without fabricating actual GPU FPS.
    if not auto_enabled or recording or fps < 1.0 or seconds <= 0.0:
        _reset_evidence()
        return -1
    last_fps = fps
    cooldown = maxf(0.0, cooldown - seconds)
    if fps < DOWNSHIFT_FPS:
        below_target += seconds
        above_target = 0.0
    elif fps >= UPSHIFT_FPS:
        above_target += seconds
        below_target = 0.0
    else:
        _reset_evidence()
    if cooldown > 0.0:
        return -1
    if below_target >= DOWNSHIFT_SECONDS and quality_mode < 2:
        _reset_evidence()
        cooldown = SWITCH_COOLDOWN
        quality_mode += 1
        quality_requested.emit(quality_mode, "FPS ниже цели")
        return quality_mode
    if above_target >= UPSHIFT_SECONDS and quality_mode > 0:
        _reset_evidence()
        cooldown = SWITCH_COOLDOWN
        quality_mode -= 1
        quality_requested.emit(quality_mode, "Стабильный запас FPS")
        return quality_mode
    return -1

func _process(delta: float) -> void:
    if not auto_enabled:
        return
    monitor_elapsed += delta
    if monitor_elapsed < 2.0:
        return
    var window: float = monitor_elapsed
    monitor_elapsed = 0.0
    var fps: float = float(Performance.get_monitor(Performance.TIME_FPS))
    var recording: bool = is_instance_valid(host_benchmark) and host_benchmark.benchmarking
    observe_fps(fps, window, recording)
    samples += 1
