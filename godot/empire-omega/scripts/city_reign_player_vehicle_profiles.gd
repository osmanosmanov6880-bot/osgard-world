extends RefCounted
## CITY REIGN AAA A7: four DISTINCT original closed 3D vehicle silhouettes
## for the original REAL player garage: compact, courier, executive, utility.
## Each is a transformed source profile in the EXISTING Horizon sculpt; no
## new MeshInstance3D, fake thumbnails, collision changes, wheels or save keys.
const SCULPT = preload("res://scripts/horizon_coupe_sculpt.gd")
const STYLES = ["compact","courier","executive","utility"]
const MAX_CACHED_NEW_MESHES: int = 6
static var _body_cache: Dictionary = {}
static var _roof_cache: Dictionary = {}

static func _valid(style: String) -> String:
	return style if STYLES.has(style) else "compact"

static func profile_for(style: String, is_roof: bool) -> Array:
	var name: String = _valid(style)
	var base: Array = SCULPT.CANOPY_PROFILE if is_roof else SCULPT.BODY_PROFILE
	var result: Array = base.duplicate(true)
	if name == "compact":
		return result
	for i in range(result.size()):
		var section: Vector4 = result[i]
		var t: float = float(i)/float(maxi(1,result.size()-1))
		var ramp: float = sin(PI*t)
		var length_at: float = section.x
		var half_width: float = section.y
		var top_y: float = section.z
		var bottom_y: float = section.w
		match name:
			"courier":
				if is_roof:
					# The service van has a long, high rear cargo roof and
					# nearly vertical greenhouse sides, not a sports-car bubble.
					half_width = minf(1.10,half_width*1.09)
					top_y += 0.20+0.18*ramp
				else:
					half_width = minf(1.34,half_width*1.025)
					top_y += 0.055
			"executive":
				# Longer-looking roof by softening the front/rear swoop
				# without increasing the original 5.4m physical collider.
				if is_roof:
					half_width *= 0.96
					top_y -= 0.07
					length_at += -0.11 if i < 2 else (0.11 if i >= result.size()-2 else 0.0)
				else:
					half_width = minf(1.34,half_width*1.018)
					top_y += 0.014*ramp
			"utility":
				# Strong taller squared greenhouse and pronounced high hood.
				if is_roof:
					half_width = minf(1.12,half_width*1.11)
					top_y += 0.28+0.12*ramp
				else:
					half_width = minf(1.35,half_width*1.035)
					top_y += 0.083
		result[i] = Vector4(length_at,half_width,top_y,bottom_y)
	return result

static func _mesh_for(style: String,is_roof: bool) -> ArrayMesh:
	var kind: String = _valid(style)
	if kind == "compact":
		return null # The original original FlowBody/Greenhouse remains in use.
	var cache: Dictionary = _roof_cache if is_roof else _body_cache
	if cache.has(kind):
		return cache[kind]
	var profile: Array = profile_for(kind,is_roof)
	var temp: MeshInstance3D = SCULPT.sculpt(
		"CityReignGarage_"+kind+("_roof" if is_roof else "_body"),
		profile,StandardMaterial3D.new())
	var physical_source: ArrayMesh = temp.mesh as ArrayMesh
	temp.free()
	if is_roof:
		_roof_cache[kind] = physical_source
	else:
		_body_cache[kind] = physical_source
	return physical_source

static func body_mesh(style: String) -> ArrayMesh:
	return _mesh_for(style,false)

static func canopy_mesh(style: String) -> ArrayMesh:
	return _mesh_for(style,true)

static func cache_count() -> int:
	return _body_cache.size()+_roof_cache.size()

static func bounded() -> bool:
	if cache_count() > MAX_CACHED_NEW_MESHES:
		return false
	for style in ["courier","executive","utility"]:
		for is_roof in [false,true]:
			var profile: Array = profile_for(style,is_roof)
			var bounds: AABB = SCULPT.profile_bounds(profile)
			if not bounds.position.is_finite() or not bounds.size.is_finite():
				return false
			if bounds.size.x > 2.8 or bounds.size.z > 5.5:
				return false
			if bounds.position.y < -0.8 or bounds.position.y + bounds.size.y > 1.4:
				return false
	return true
