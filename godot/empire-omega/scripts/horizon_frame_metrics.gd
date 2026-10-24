extends RefCounted
## HORIZON R16: measured render-frame time, not a synthetic FPS benchmark.
## Read from Node._process(delta). Drop large background-resume gaps.
## Bounded ring storage avoids allocations during gameplay except warmup.

const MAX_SAMPLES: int = 240
const MIN_FRAME_SECONDS: float = 0.0005
const MAX_FRAME_SECONDS: float = 0.25
const MIN_REPORT_SAMPLES: int = 30

var frame_milliseconds := PackedFloat32Array()
var next_index: int = 0
var dropped_samples: int = 0

func record_frame(seconds: float, focused: bool = true) -> void:
	if not focused:
		reset()
		return
	if not is_finite(seconds) or seconds < MIN_FRAME_SECONDS or seconds > MAX_FRAME_SECONDS:
		dropped_samples += 1
		return
	var ms: float = seconds * 1000.0
	if frame_milliseconds.size() < MAX_SAMPLES:
		frame_milliseconds.append(ms)
	else:
		frame_milliseconds[next_index] = ms
		next_index = (next_index + 1) % MAX_SAMPLES

func reset() -> void:
	frame_milliseconds.clear()
	next_index = 0

func samples() -> int:
	return frame_milliseconds.size()

func ready() -> bool:
	return samples() >= MIN_REPORT_SAMPLES

func percentile_ms(percentile: float) -> float:
	if not ready():
		return 0.0
	var sorted: PackedFloat32Array = frame_milliseconds.duplicate()
	sorted.sort()
	var index: int = clampi(ceili(float(sorted.size()) * clampf(percentile,0.0,1.0))-1,0,sorted.size()-1)
	return float(sorted[index])

func p95_ms() -> float:
	return percentile_ms(0.95)

func p99_ms() -> float:
	return percentile_ms(0.99)
