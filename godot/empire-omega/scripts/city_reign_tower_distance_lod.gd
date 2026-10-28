extends RefCounted
## CITY REIGN B55 — deterministic camera-distance choice of actual 3D mesh LOD.
## Render-only: never mutates scene collision, city finances or traffic routes.
## Hysteresis prevents switching meshes on each frame at 110m/200m boundaries.
const STANDARD_METRES: float = 142.0
const CINEMATIC_METRES: float = 116.0
const CINEMATIC_TO_STANDARD_METRES: float = 204.0
const HYSTERESIS_METRES: float = 11.0

static func projected_distance(a: Vector3,b: Vector3) -> float:
	if not a.is_finite() or not b.is_finite():
		return INF
	return Vector2(a.x-b.x,a.z-b.z).length()

static func choose(user_quality: String,distance_metres: float,
		previous: String = "low") -> String:
	if user_quality=="low" or not is_finite(distance_metres):
		return "low"
	var distance: float = maxf(0.0,distance_metres)
	var former: String = previous if ["low","standard","cinematic"].has(previous) else "low"
	if user_quality=="standard":
		var threshold: float = STANDARD_METRES+(
			HYSTERESIS_METRES if former=="standard" or former=="cinematic"
			else -HYSTERESIS_METRES)
		return "standard" if distance<=threshold else "low"
	if user_quality!="cinematic":
		return "low"
	var near_threshold: float = CINEMATIC_METRES+(
		HYSTERESIS_METRES if former=="cinematic" else -HYSTERESIS_METRES)
	if distance<=near_threshold:
		return "cinematic"
	var medium_threshold: float = CINEMATIC_TO_STANDARD_METRES+(
		HYSTERESIS_METRES if former=="standard" or former=="cinematic"
		else -HYSTERESIS_METRES)
	if distance<=medium_threshold:
		return "standard"
	return "low"

static func bounded_counts(total: int,counts: Dictionary) -> bool:
	if total<0 or counts.size()!=3:
		return false
	var sum: int = 0
	for key in ["low","standard","cinematic"]:
		if not counts.has(key):
			return false
		var count: int = int(counts[key])
		if count<0 or count>total:
			return false
		sum += count
	return sum==total
