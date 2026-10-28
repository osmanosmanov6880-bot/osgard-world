extends RefCounted
## CITY REIGN B65-B66: the player can inspect physically delivered public
## infrastructure IN THE STREET. This is not another paid action, mission,
## cash payout, quest shortcut or virtual map; existing F stays authoritative.
## Only the real GameState projects_done enables a completion inspection.
const CIVIC = preload("res://scripts/civic_initiatives.gd")
const PROJECTS = preload("res://scripts/project_landmarks.gd")
const PUBLIC_WORKS = preload("res://scripts/city_reign_civic_outcomes.gd")
const PUBLIC_PARK = preload("res://scripts/city_reign_park_furniture.gd")
const TRAFFIC = preload("res://scripts/city_reign_civic_traffic_safety.gd")
const PARK_ROUTE = preload("res://scripts/city_reign_park_routine.gd")
const INSPECTION_RADIUS_M: float = 8.5
const SITES: Array[String] = [
	"safe_crossings","open_records","community_park"
]

static func _loc(lang: String,ru: String,en: String,zh: String) -> String:
	return ru if lang=="ru" else (en if lang=="en" else zh)

static func _sites(id: String) -> Array[Vector3]:
	var points: Array[Vector3] = []
	match id:
		"safe_crossings":
			for cross in PUBLIC_WORKS.CROSSINGS:
				points.append(cross)
		"open_records":
			points.append(PUBLIC_WORKS.KIOSK_AT)
		"community_park":
			points.append(PUBLIC_PARK.PARK_AT+Vector3(8,0,0))
		_:
			pass
	return points

static func near_completed(state: Dictionary,player_at: Vector3,
		driving: bool,is_inside: bool) -> String:
	if not player_at.is_finite() or driving or is_inside:
		return ""
	var finished: Variant = state.get("projects_done",[])
	if not (finished is Array):
		return ""
	var best: float = INSPECTION_RADIUS_M*INSPECTION_RADIUS_M
	var chosen: String = ""
	for id in SITES:
		if not finished.has(id):
			continue
		for point in _sites(id):
			var dx: float = point.x-player_at.x
			var dz: float = point.z-player_at.z
			var d2: float = dx*dx+dz*dz
			if d2<=best:
				best=d2
				chosen=id
	return chosen

static func report(state: Dictionary,project_id: String,lang: String) -> String:
	var finished: Variant = state.get("projects_done",[])
	if not (finished is Array) or not finished.has(project_id):
		return ""
	if not SITES.has(project_id) or not CIVIC.PROJECTS.has(project_id):
		return ""
	var label: String = str(CIVIC.PROJECTS[project_id].get(
		lang,CIVIC.PROJECTS[project_id]["ru"]))
	var status: String = _loc(lang,"ПОСТРОЕНО","BUILT","已竣工")
	match project_id:
		"safe_crossings":
			# The actual commuter traffic_agent, not the player's car,
			# obeys this saved municipal speed decision.
			var speed_kmh: float = TRAFFIC.SPEED_LIMIT_MPS*3.6
			return _loc(lang,
				"%s · %s · 4 перехода · скорость машин NPC до %.1f км/ч" % [
					label,status,speed_kmh],
				"%s · %s · 4 crossings · NPC cars slow to %.1f km/h" % [
					label,status,speed_kmh],
				"%s · %s · 4 处人行横道 · NPC 车辆限速 %.1f 公里/小时" % [
					label,status,speed_kmh])
		"open_records":
			var treasury: int = int(state.get("treasury",0))
			var trust: Variant = state.get("trust",[])
			var local_trust: int = int(trust[0]) if trust is Array and trust.size()>0 else 0
			return _loc(lang,
				"%s · %s · казна %d кр. · доверие %d%%" % [
					label,status,treasury,local_trust],
				"%s · %s · treasury %d cr. · trust %d%%" % [
					label,status,treasury,local_trust],
				"%s · %s · 财政 %d · 信任 %d%%" % [
					label,status,treasury,local_trust])
		"community_park":
			var hour: float = float(state.get("day_clock",12.0))
			var visiting: bool = hour>=17.0 and hour<21.0
			var timed: String = _loc(lang,
				"вечерние прогулки" if visiting else "парк доступен",
				"evening walks" if visiting else "park open",
				"晚间散步" if visiting else "公园开放")
			return "%s · %s · %s" % [label,status,timed]
	return ""

static func source_invariants() -> bool:
	return SITES.size()==3 and (
		PROJECTS.POSITIONS["community_park"]==PUBLIC_PARK.PARK_AT) and (
		TRAFFIC.geometry_matches_installed_city()) and (
		PARK_ROUTE.sourced_and_bounded()) and (
		INSPECTION_RADIUS_M<10.0)
