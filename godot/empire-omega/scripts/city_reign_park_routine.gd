extends RefCounted
## CITY REIGN B63: physical finished park actually attracts the existing
## resident walking agents. This does not invent citizens, teleport walkers,
## change saves, pay XP, ignore closures, or create physical collision bodies.
## Preserve R41/R47 predictive vehicle/pedestrian yielding.
const CIVIC = preload("res://scripts/civic_initiatives.gd")
const PROJECT_SITES = preload("res://scripts/project_landmarks.gd")
const PARK_ID: String = "community_park"
const PARK_PARTICIPATION_MODULUS: int = 4
const MAX_PARK_VISITORS: int = 9
const NEAR_ROAD_BORDER: float = 161.0
const PARK_WALK_Y: float = 0.70

static func park_exists(state: Dictionary) -> bool:
	var finished: Variant = state.get("projects_done",[])
	return finished is Array and finished.has(PARK_ID)

static func participant(citizen_id: int) -> bool:
	return citizen_id>=0 and citizen_id<34 and (
		posmod(citizen_id*11+7,PARK_PARTICIPATION_MODULUS)==0)

static func park_target(citizen_id: int) -> Vector3:
	# The genuine 164,-91 municipal park project stands just beside the
	# existing vertical x=156 and horizontal z=-104 roads. Keep walkers on
	# the actual open inner block rather than routing into driving lanes.
	var site: Vector3 = PROJECT_SITES.POSITIONS[PARK_ID]
	var lateral: float = float(posmod(citizen_id*7+3,7)-3)*0.86
	var forward: float = float(posmod(citizen_id*13+5,7)-3)*0.82
	return Vector3(site.x+3.0+lateral,PARK_WALK_Y,site.z+forward)

static func choose(original: Dictionary,citizen_id: int,state: Dictionary) -> Dictionary:
	# Never mutate the original daily routine; citizens retain actual home,
	# work, unemployment, stability and real walking route state.
	var alternative: Dictionary = original.duplicate(true)
	if not park_exists(state) or not participant(citizen_id):
		return alternative
	if str(original.get("activity",""))!="leisure":
		return alternative
	var target: Vector3 = park_target(citizen_id)
	if not target.is_finite() or target.x<=NEAR_ROAD_BORDER:
		return alternative
	alternative["destination"]=target
	alternative["quarter"]=1 # actual built residential quarter
	alternative["municipal_attraction"]=PARK_ID
	return alternative

static func sourced_and_bounded() -> bool:
	if not CIVIC.PROJECTS.has(PARK_ID) or (
		PROJECT_SITES.POSITIONS[PARK_ID]!=Vector3(164.0,0.0,-91.0)):
		return false
	var count: int = 0
	for citizen_id in range(34):
		if participant(citizen_id):
			count+=1
			var target: Vector3 = park_target(citizen_id)
			if not target.is_finite() or target.x<=NEAR_ROAD_BORDER or (
				target.z<=-98.0 or target.z>=-82.0):
				return false
	return count>0 and count<=MAX_PARK_VISITORS
