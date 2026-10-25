extends RefCounted
## HORIZON R15: bounded mobile-only visual quality governor for Godot Web.
## Player graphics choice remains the maximum quality, never overwritten.
## No authority over vehicle physics, touch input, saving or mission progress.
## FPS is sampled by the real game once per second; no synthetic benchmark claims.

const MODES = ["low", "standard", "cinematic"]
const WARMUP_SECONDS: float = 6.0
const DOWN_FPS: float = 27.0
const UP_FPS: float = 45.0
const DOWN_SECONDS: float = 4.0
const UP_SECONDS: float = 12.0
const MAX_SAMPLE_SECONDS: float = 2.0
const BAD_P95_FRAME_MS: float = 40.0
const RECOVERY_P95_FRAME_MS: float = 1000.0/UP_FPS

var requested_mode: String = "standard"
var mobile: bool = false
var _ceiling: int = 1
var _tier: int = 1
var _warmup: float = 0.0
var _slow: float = 0.0
var _fast: float = 0.0

func configure(mode: String, on_mobile: bool) -> void:
	requested_mode = mode if MODES.has(mode) else "standard"
	mobile = on_mobile
	_ceiling = MODES.find(requested_mode)
	_tier = _ceiling
	_warmup = 0.0
	_slow = 0.0
	_fast = 0.0

func effective_quality() -> String:
	return MODES[_tier]

func is_adapting() -> bool:
	return mobile and _tier < _ceiling

## R48: a high average FPS with frequent visible stutters is NOT smooth.
## Use the actual 240-frame ring p95 after 30 qualified samples. Never read
## an invented/synthetic frame time or change the user graphics ceiling.
func observe_frame_pacing(fps: float,p95_ms: float,qualified_frames: int,elapsed: float,in_focus: bool = true) -> bool:
	var assessed: float = fps
	if qualified_frames>=30 and is_finite(p95_ms) and p95_ms>0.0:
		if p95_ms>=BAD_P95_FRAME_MS:
			assessed=minf(fps,DOWN_FPS-1.0)
		elif p95_ms>RECOVERY_P95_FRAME_MS:
			assessed=minf(fps,UP_FPS-1.0)
	return observe(assessed,elapsed,in_focus)

func observe(fps: float, elapsed: float, in_focus: bool = true) -> bool:
	# A background tab or paused browser can report almost no frames. It must
	# not permanently force low quality when the player returns.
	if not mobile or not in_focus:
		_slow = 0.0
		_fast = 0.0
		if not in_focus:
			_warmup = 0.0
		return false
	if not is_finite(fps) or fps <= 0.0 or not is_finite(elapsed) or elapsed <= 0.0:
		return false
	var seconds: float = minf(elapsed,MAX_SAMPLE_SECONDS)
	if _warmup < WARMUP_SECONDS:
		_warmup += seconds
		return false
	if fps < DOWN_FPS:
		_slow += seconds
		_fast = 0.0
	elif fps >= UP_FPS:
		_fast += seconds
		_slow = 0.0
	else:
		_slow = 0.0
		_fast = 0.0
	if _slow >= DOWN_SECONDS and _tier > 0:
		_tier -= 1
		_slow = 0.0
		_fast = 0.0
		return true
	if _fast >= UP_SECONDS and _tier < _ceiling:
		_tier += 1
		_slow = 0.0
		_fast = 0.0
		return true
	return false
