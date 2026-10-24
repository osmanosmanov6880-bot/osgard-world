extends RefCounted
## HORIZON R15: bounded mobile-only visual quality governor for Godot Web.
## Player graphics choice remains the maximum quality, never overwritten.
## No authority over vehicle physics, touch input, saving or mission progress.
## FPS is sampled by the real game once per second; no synthetic benchmark claims.

const MODES: Array[String] = ["low", "standard", "cinematic"]
const WARMUP_SECONDS: float = 6.0
const DOWN_FPS: float = 27.0
const UP_FPS: float = 45.0
const DOWN_SECONDS: float = 4.0
const UP_SECONDS: float = 12.0
const MAX_SAMPLE_SECONDS: float = 2.0

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
