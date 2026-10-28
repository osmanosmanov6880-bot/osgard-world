extends RefCounted
## CITY REIGN R160: true original-player Camera3D lenses. No extra
## scene camera, car physics, scripted screenshot, credits or save mutations.
const MODES = ["street","classic","panorama","cockpit"]
const LABELS = {
	"ru":{"street":"КАМЕРА · УЛИЦА","classic":"КАМЕРА · СТАНДАРТ","panorama":"КАМЕРА · ПАНОРАМА","cockpit":"КАМЕРА · САЛОН"},
	"en":{"street":"CAMERA · STREET","classic":"CAMERA · CLASSIC","panorama":"CAMERA · PANORAMA","cockpit":"CAMERA · COCKPIT"},
	"zh":{"street":"镜头 · 街景","classic":"镜头 · 标准","panorama":"镜头 · 全景","cockpit":"镜头 · 驾驶舱"}
}
const MIN_RATIO: float = 0.75
const MAX_RATIO: float = 1.28

static func canonical(mode: String) -> String:
	return mode if MODES.has(mode) else "classic"

static func next_mode(current: String) -> String:
	return str(MODES[(MODES.find(current)+1)%MODES.size()])

static func localized_mode(mode: String,locale: String) -> String:
	var lang: String = locale if LABELS.has(locale) else "ru"
	return str(LABELS[lang][canonical(mode)])

static func distance_ratio(mode: String,driving: bool,phone: bool,
		cabinet: bool,reduced_motion: bool) -> float:
	if cabinet or reduced_motion:
		return 1.0
	match canonical(mode):
		"street":
			return 0.95 if phone and driving else (0.92 if phone else (0.84 if driving else 0.80))
		"panorama":
			return 1.14 if phone else (1.22 if driving else 1.26)
		_:
			return 1.0

static func pitch(base: float,mode: String,phone: bool,cabinet: bool,
		reduced_motion: bool) -> float:
	var safe: float = clampf(base if is_finite(base) else 0.38,0.08,1.18)
	if cabinet or reduced_motion:
		return safe
	if canonical(mode)=="street" and not phone:
		return clampf(safe-0.065,0.08,1.18)
	if canonical(mode)=="panorama":
		return clampf(safe+(0.065 if phone else 0.08),0.08,1.18)
	return safe

static func distance(focus: Vector3,ideal: Vector3,mode: String,
		driving: bool,phone: bool,cabinet: bool,reduced_motion: bool) -> Vector3:
	if not focus.is_finite() or not ideal.is_finite():
		return focus if focus.is_finite() else Vector3.ZERO
	var ratio: float = clampf(distance_ratio(mode,driving,phone,cabinet,reduced_motion),
		MIN_RATIO,MAX_RATIO)
	var result: Vector3 = focus+(ideal-focus)*ratio
	return result if result.is_finite() else focus

static func bounded() -> bool:
	if MODES.size()!=4:
		return false
	for mode in MODES:
		for driving in [false,true]:
			for phone in [false,true]:
				for blocked in [false,true]:
					var ratio: float = distance_ratio(mode,driving,phone,blocked,false)
					if ratio<MIN_RATIO or ratio>MAX_RATIO:
						return false
	for lang in ["ru","en","zh"]:
		if not LABELS.has(lang):
			return false
		for mode in MODES:
			if str(LABELS[lang].get(mode,"")).is_empty():
				return false
	return true
