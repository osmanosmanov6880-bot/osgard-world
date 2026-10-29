extends RefCounted
## CITY REIGN R171: a bounded truth guard around the ORIGINAL closed-road A*
## route; no teleport links or invented straight-line roads are permitted.
const MAX_POINTS: int=128
const MAX_START_SNAP: float=100.0
const MAX_GOAL_SNAP: float=100.0
const MAX_SEGMENT: float=320.0
const MAX_ROUTE_LENGTH: float=7200.0
const REPLAN_INTERVAL: float=0.75

static func horizontal(a: Vector3,b: Vector3) -> float:
	return Vector2(a.x,a.z).distance_to(Vector2(b.x,b.z))

static func usable(path: Array[Vector3],origin: Vector3,goal: Vector3) -> bool:
	if not origin.is_finite() or not goal.is_finite() or path.is_empty() or path.size()>MAX_POINTS:
		return false
	for point in path:
		if not point.is_finite():
			return false
	if horizontal(path[0],origin)>MAX_START_SNAP:
		return false
	if path.size()==1:
		# Original A* disconnected route sentinel. Keep it a BLOCKED road,
		# never synthesize a straight line that ignores genuine roadworks.
		return true
	if horizontal(path[-1],goal)>MAX_GOAL_SNAP:
		return false
	var total: float=0.0
	for i in range(path.size()-1):
		var segment: float=horizontal(path[i],path[i+1])
		if segment>MAX_SEGMENT:
			return false
		total+=segment
	return total<=MAX_ROUTE_LENGTH

static func verified(path: Array[Vector3],origin: Vector3,goal: Vector3) -> Array[Vector3]:
	if usable(path,origin,goal):
		return path
	return [] as Array[Vector3]

static func should_recalculate(elapsed: float,goal_changed: bool,source_changed: bool,
		off_route: bool) -> bool:
	if goal_changed or source_changed:
		return true
	if not is_finite(elapsed) or elapsed<0.0:
		return false
	return elapsed>=REPLAN_INTERVAL if off_route else elapsed>=1.25
