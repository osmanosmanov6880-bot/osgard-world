extends RefCounted
## EMPIRE Omega R36: opt-in 20s *real* on-device render-frame measurement.
## Samples Node._process(delta) plus Godot Performance draw calls. Only the
## actual player runtime supplies samples; unit tests are synthetic and do not
## qualify as phone evidence. No analytics service, personal ID or network API.
const WARMUP_SECONDS: float = 2.0
const CAPTURE_SECONDS: float = 20.0
const MAX_SAMPLES: int = 6000
const MAX_DELTA: float = 1.0
var active := false
var completed := false
var aborted := ""
var elapsed := 0.0
var captured_seconds := 0.0
var frame_ms := PackedFloat32Array()
var draw_calls := PackedInt32Array()
var dropped := 0
var preset: String = "standard"
var view: Vector2 = Vector2.ZERO
var platform: String = ""

func begin(preset_mode: String,viewport: Vector2,platform_name: String) -> void:
	active = true
	completed = false
	aborted = ""
	elapsed = 0.0
	captured_seconds = 0.0
	frame_ms.clear()
	draw_calls.clear()
	dropped = 0
	preset = preset_mode if ["low","standard","cinematic"].has(preset_mode) else "standard"
	view = viewport
	platform = platform_name

func record_frame(delta: float,draw_call_count: int,foreground: bool = true) -> void:
	if not active:
		return
	if not foreground:
		active = false
		completed = false
		aborted = "browser-backgrounded"
		return
	if not is_finite(delta) or delta<=0.0 or delta>MAX_DELTA:
		dropped += 1
		return
	elapsed += delta
	if elapsed<=WARMUP_SECONDS:
		return
	captured_seconds += delta
	if frame_ms.size()<MAX_SAMPLES:
		frame_ms.append(delta*1000.0)
		draw_calls.append(maxi(0,draw_call_count))
	else:
		dropped += 1
	if captured_seconds>=CAPTURE_SECONDS:
		active=false
		completed=frame_ms.size()>=100
		if not completed:
			aborted="insufficient-real-frames"

func _percentile(values: PackedFloat32Array,p: float) -> float:
	if values.is_empty():
		return 0.0
	var sorted: PackedFloat32Array = values.duplicate()
	sorted.sort()
	var pos: int = clampi(ceili(float(sorted.size())*clampf(p,0.0,1.0))-1,0,sorted.size()-1)
	return float(sorted[pos])

func progress() -> float:
	return clampf(captured_seconds/CAPTURE_SECONDS,0.0,1.0)

func report() -> Dictionary:
	if not completed:
		return {"status":"not-ready","hardware_attested":false,"frame_count":frame_ms.size(),
			"aborted":aborted}
	var draws := PackedFloat32Array()
	var peak_draw_calls := 0
	for value in draw_calls:
		peak_draw_calls = maxi(peak_draw_calls,value)
		draws.append(float(value))
	return {
		"schema":"empire-omega-real-frames-r36-v1",
		"status":"complete",
		"metric_source":"Godot render-frame _process(delta), actual in-game Performance renderer counters",
		"engine":"Godot 4.4.1",
		"platform_reported_by_engine":platform,
		"physical_hardware_attested":false,
		"device_model_verified":false,
		"capture_s":captured_seconds,
		"warmup_s":WARMUP_SECONDS,
		"frame_count":frame_ms.size(),
		"dropped_invalid_or_capacity":dropped,
		"p50_frame_ms":_percentile(frame_ms,0.50),
		"p95_frame_ms":_percentile(frame_ms,0.95),
		"p99_frame_ms":_percentile(frame_ms,0.99),
		"p95_draw_calls":_percentile(draws,0.95),
		"maximum_draw_calls":peak_draw_calls,
		"mean_observed_fps":float(frame_ms.size())/maxf(0.001,captured_seconds),
		"graphics_quality":preset,
		"viewport_width":roundi(view.x),
		"viewport_height":roundi(view.y),
		"source_sha_verified":false,
		"notice":"Requires human verification of device, build SHA and full screen recording; not a certified physical device benchmark."
	}
