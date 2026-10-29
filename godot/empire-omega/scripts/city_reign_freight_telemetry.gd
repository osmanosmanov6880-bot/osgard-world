extends RefCounted
## R176: read-only REAL courier telemetry from original physical cargo.
## No duplicate distance, condition, reward, save or arbitrary completion.
const CARGO=preload("res://scripts/cargo_logistics.gd")
const LANG={
	"ru":{"cargo":"ГРУЗ","route":"ПУТЬ","meters":"м",
		"ready":"ТРЕБОВАНИЕ ПО ПРОБЕГУ ВЫПОЛНЕНО",
		"driving":"ПРОДОЛЖАЙТЕ ПЕРЕВОЗКУ",
		"legacy":"СОВМЕСТИМЫЙ СТАРЫЙ ДОГОВОР",
		"unavailable":"ДАННЫЕ ГРУЗА НЕДОСТУПНЫ"},
	"en":{"cargo":"FREIGHT","route":"TRIP","meters":"m",
		"ready":"DRIVING DISTANCE MET",
		"driving":"KEEP DRIVING THE ROUTE",
		"legacy":"LEGACY CONTRACT ACCEPTED",
		"unavailable":"CARGO DATA UNAVAILABLE"},
	"zh":{"cargo":"货物","route":"行驶","meters":"米",
		"ready":"行驶距离已达到要求",
		"driving":"继续完成实际路线",
		"legacy":"已兼容历史合同",
		"unavailable":"货物数据不可用"}
}
static func snapshot(active: Dictionary,locale: String="ru") -> Dictionary:
	var lang: String=locale if LANG.has(locale) else "en"
	var l: Dictionary=LANG[lang]
	if active.is_empty():
		return {"active":false,"valid":false,"fraction":0.0,
			"condition":100,"meters":0,"required":0,"legacy":false,
			"distance_met":false,"label":""}
	var p_value: Variant=active.get("cargo_progress",{})
	var progress: Dictionary=p_value if p_value is Dictionary else {}
	if not CARGO.valid_progress(progress):
		# Fail closed — display no fictitious ready or expected trip values.
		return {"active":true,"valid":false,"fraction":0.0,
			"condition":0,"meters":0,"required":0,"legacy":false,
			"distance_met":false,"label":str(l["unavailable"])}
	var fraction: float=CARGO.completion_fraction(active)
	var ready: bool=CARGO.ready(active)
	var condition: int=clampi(roundi(float(progress["condition"])),5,100)
	var distance: int=mini(CARGO.MAX_TRACKED_METERS,roundi(float(progress["meters"])))
	var required: int=roundi(float(progress["required"]))
	var compatible: bool=bool(progress.get("legacy",false))
	var status: String=str(l["legacy"]) if compatible else (
		str(l["ready"]) if ready else str(l["driving"]))
	var readout: String=str(l["cargo"])+" "+str(condition)+"%  ·  "+
		str(l["route"])+" "+str(distance)+"/"+str(required)+" "+str(l["meters"])
	return {"active":true,"valid":true,"fraction":fraction,
		"condition":condition,"meters":distance,"required":required,
		"legacy":compatible,"distance_met":ready,
		"label":readout+"\n"+status}

static func source_is_consistent(active: Dictionary,projection: Dictionary) -> bool:
	if active.is_empty(): return not bool(projection.get("active",true))
	var p: Variant=active.get("cargo_progress",{})
	if not (p is Dictionary) or not CARGO.valid_progress(p):
		return not bool(projection.get("valid",true)) and not bool(projection.get("distance_met",true))
	if not bool(projection.get("valid",false)): return false
	return is_equal_approx(float(projection.get("fraction",-1.0)),
		CARGO.completion_fraction(active)) and bool(projection.get("distance_met",false))==CARGO.ready(active)
