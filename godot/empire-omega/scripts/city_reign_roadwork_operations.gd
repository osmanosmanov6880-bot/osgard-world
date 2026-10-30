extends RefCounted
## CITY REIGN R188 — one source of truth for REAL roadworks in the
## original 9x9 A* traffic network, physical 3D closure, and honest
## read-only driver warning. Never invents an incident, road, economy,
## navigation edge, signal, or law. No telemetry or external requests.
const MOBILITY=preload("res://scripts/city_mobility.gd")
const SOURCE=preload("res://scripts/city_reign_intersection_policy.gd")
const MAX_ACTIVE_SITES: int=2
const SOURCE_GRID_N: int=9
const SOURCE_EDGE_LENGTH_M: float=52.0
const PHYSICAL_BARRIER_WIDTH_M: float=10.0
const MAX_WARNING_M: float=42.0
const MIN_WARNING_M: float=4.0
const WARNING_HALF_LANE_M: float=4.4
const MIN_WARNING_SPEED_MPS: float=2.0
const MIN_ROAD_ALIGNMENT: float=0.90
const MAX_VISUAL_GROUPS_PER_SITE: int=4
const ORIGINAL_LIGHT_COUNT_PER_SITE: int=0

static func source_segment(incident: Dictionary) -> Dictionary:
	if incident.is_empty():return {}
	var id: String=str(incident.get("id",""))
	var canonical: Dictionary=MOBILITY.incident_by_id(id)
	if canonical.is_empty() or not canonical.has("a") or not canonical.has("b"):
		return {}
	var raw_a: Variant=incident.get("a",null)
	var raw_b: Variant=incident.get("b",null)
	if not raw_a is Array or not raw_b is Array:return {}
	var a: Array=raw_a
	var b: Array=raw_b
	if a!=canonical["a"] or b!=canonical["b"] or a.size()!=2 or b.size()!=2:
		return {}
	for value in a+b:
		if not value is int or value<0 or value>=SOURCE_GRID_N:
			return {}
	var ga:=Vector2i(int(a[0]),int(a[1]))
	var gb:=Vector2i(int(b[0]),int(b[1]))
	if abs(ga.x-gb.x)+abs(ga.y-gb.y)!=1:return {}
	var pa: Vector3=MOBILITY._pos(ga)
	var pb: Vector3=MOBILITY._pos(gb)
	if (not pa.is_finite() or not pb.is_finite() or
			not is_equal_approx(pa.distance_to(pb),SOURCE_EDGE_LENGTH_M)):
		return {}
	var direction: Vector3=(pb-pa).normalized()
	var midpoint: Vector3=(pa+pb)*0.5
	return {
		"id":id,
		"center":midpoint,
		"axis":direction,
		"edge":MOBILITY.edge_key(ga,gb),
		"yaw":PI*0.5 if absf(direction.z)>0.5 else 0.0
	}

static func active_sites(state: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary]=[]
	for item in MOBILITY.active_incidents(state):
		var verified: Dictionary=source_segment(item)
		if verified.is_empty():continue
		result.append(verified)
		if result.size()>=MAX_ACTIVE_SITES:break
	return result

static func driver_warning(at: Vector3,yaw: float,speed: float,
		active: Array[Dictionary]) -> Dictionary:
	if not at.is_finite() or not is_finite(yaw) or not is_finite(speed):
		return {}
	if absf(speed)<MIN_WARNING_SPEED_MPS:return {}
	var forward:=Vector2(-sin(yaw),-cos(yaw))
	if forward.length_squared()<0.9:return {}
	var winner: Dictionary={}
	var nearest: float=MAX_WARNING_M+1.0
	for candidate in active:
		var source: Dictionary=source_segment(candidate)
		if source.is_empty():continue
		var center: Vector3=source["center"]
		var road: Vector3=source["axis"]
		var road_axis:=Vector2(road.x,road.z)
		if absf(road_axis.dot(forward))<MIN_ROAD_ALIGNMENT:continue
		var offset:=Vector2(center.x-at.x,center.z-at.z)
		var ahead: float=offset.dot(forward)
		if ahead<MIN_WARNING_M or ahead>MAX_WARNING_M:continue
		if absf(offset.cross(forward))>WARNING_HALF_LANE_M:continue
		if ahead<nearest:
			nearest=ahead
			winner={
				"kind":"road_closed",
				"urgency":"caution",
				"distance_m":ahead,
				"source":"original_active_closed_AStar_edge",
				"incident_id":str(source["id"])
			}
	return winner

static func catalog_integrity() -> bool:
	var entries: Array=MOBILITY.catalog().get("incidents",[])
	if (entries.size()!=12 or MOBILITY.ROAD_SIZE!=SOURCE_GRID_N or
			MOBILITY.ROAD_SPACING!=SOURCE_EDGE_LENGTH_M or
			MOBILITY.ROAD_MIN!=-208.0 or
			not SOURCE.source_grid_valid()):
		return false
	var seen: Dictionary={}
	for item in entries:
		if not item is Dictionary:return false
		var source: Dictionary=source_segment(item)
		if source.is_empty() or seen.has(source["edge"]):return false
		seen[source["edge"]]=true
	return true
