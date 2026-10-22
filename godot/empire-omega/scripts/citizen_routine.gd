extends RefCounted
## Deterministic daily schedule for visible pedestrian representatives.
## This deliberately is not a claim that all 12,800+ citizens are physical agents.

const DISTRICT_WAYPOINTS = [
	Vector3(-104.0,0.7,-104.0), Vector3(104.0,0.7,-104.0),
	Vector3(-104.0,0.7,104.0), Vector3(104.0,0.7,104.0)
]

static func plan(citizen_id: int, hour: float, unemployment: int, stability: int) -> Dictionary:
	var home_quarter: int = posmod(citizen_id,4)
	var office_quarter: int = posmod(citizen_id*7+3,4)
	var leisure_quarter: int = posmod(citizen_id*5+1,4)
	var inactive: bool = posmod(citizen_id*29+13,100) < unemployment
	var activity := "home"
	var quarter: int = home_quarter
	if hour >= 7.5 and hour < 17.0 and not inactive and stability >= 25:
		activity = "work"
		quarter = office_quarter
	elif hour >= 17.0 and hour < 21.0 and stability >= 30:
		activity = "leisure"
		quarter = leisure_quarter
	var jitter_x: float = float(posmod(citizen_id*17,22)-11)
	var jitter_z: float = float(posmod(citizen_id*23,22)-11)
	var destination: Vector3 = DISTRICT_WAYPOINTS[quarter] + Vector3(jitter_x,0.0,jitter_z)
	return {"activity":activity,"quarter":quarter,"destination":destination}
