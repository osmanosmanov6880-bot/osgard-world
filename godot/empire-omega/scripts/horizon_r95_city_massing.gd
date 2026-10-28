extends RefCounted
## R95: playable original city massing aligned to approved modern AAA visuals.
## Changes only structural height, never footprints, road centres, gameplay rules,
## RNG draw count, mission location, city inventory, weather or player physics.
const BOUNDS = {
	"forum":Vector2(25.0,74.0),
	"housing":Vector2(16.0,46.0),
	"lower":Vector2(9.0,30.0),
	"aqueduct":Vector2(14.0,47.0)
}
const GLOBAL_MAX_HEIGHT := 74.0
const MAX_BODY_COUNT := 128
const MAX_FORECAST_WINDOW_INSTANCES := 30000

static func height_for(district: String,sample: float,
		quarter_x: int,quarter_z: int,building_index: int) -> float:
	var bounds: Vector2 = BOUNDS.get(district,Vector2(9.0,35.0))
	var value: float = clampf(sample if is_finite(sample) else 0.5,0.0,1.0)
	# More vertical hierarchy in the central business district, lower-rise
	# residential/mixed quarters and a lower historic/supply area.
	var silhouette: float = pow(value,0.72) if district == "forum" else value
	var height: float = lerpf(bounds.x,bounds.y,silhouette)
	if district == "forum" and posmod(quarter_x*7+quarter_z*11+building_index*3,5)==0:
		height = minf(bounds.y,height+6.0)
	return snappedf(height,0.25)

static func predicted_window_limit(total_buildings: int) -> int:
	return maxi(0,total_buildings)*4*3*ceili(GLOBAL_MAX_HEIGHT/4.5)

static func passes_mobile_budget() -> bool:
	return predicted_window_limit(MAX_BODY_COUNT) <= MAX_FORECAST_WINDOW_INSTANCES
