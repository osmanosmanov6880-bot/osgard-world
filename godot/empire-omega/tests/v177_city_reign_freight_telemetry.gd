extends SceneTree
## R176 original CargoLogistics remains sole authority for measured driving.
const TELEMETRY=preload("res://scripts/city_reign_freight_telemetry.gd")
const CARGO=preload("res://scripts/cargo_logistics.gd")
const CASE=preload("res://scripts/city_reign_cargo_case_geometry.gd")
var passed: int=0
var failed: int=0
func check(ok: bool,why: String) -> void:
	if ok: passed+=1
	else:
		failed+=1
		push_error("R176 SOURCE CARGO TRUTH FAIL: "+why)
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var blank: Dictionary=TELEMETRY.snapshot({},"ru")
	check(not blank["active"] and not blank["distance_met"] and
		blank["label"]=="","no invented delivery from empty cargo")
	var offer: Dictionary={"id":"original_test","cargo":"goods","quantity":12,
		"reward":155,"pickup":"depot","dropoff":"market"}
	var freight: Dictionary=CARGO.begin(offer,100.0,0.0,100.0,"compact",1)
	var original: Dictionary=freight.duplicate(true)
	var first: Dictionary=TELEMETRY.snapshot(freight,"ru")
	check(first["valid"] and first["meters"]==0 and first["required"]==100 and
		not first["distance_met"],"real source physical freight begins at 0/100m, not free completion")
	check(first["condition"]==100 and first["fraction"]==0.0 and
		first["label"].contains("ПУТЬ"),"real RU label displays progress and quality")
	for locale in ["ru","en","zh"]:
		var projection: Dictionary=TELEMETRY.snapshot(freight,locale)
		check(TELEMETRY.source_is_consistent(freight,projection),
			"same original cargo truth for language: "+locale)
	check(freight==original,
		"telemetry read-only projection cannot mutate active contract or player reward")
	CARGO.update(freight,20.0,100.0,true,"clear")
	var early: Dictionary=TELEMETRY.snapshot(freight,"en")
	check(early["meters"]==20 and is_equal_approx(early["fraction"],0.20) and
		not early["distance_met"],"actual real odometer increment, not mission warp, controls gauge")
	for i in range(1,5):
		CARGO.update(freight,20.0+float(i)*20.0,100.0,true,"clear")
	var arrived: Dictionary=TELEMETRY.snapshot(freight,"en")
	check(arrived["distance_met"] and CARGO.ready(freight) and
		is_equal_approx(arrived["fraction"],1.0),
		"gauge can only show distance achieved after actual cargo meter accumulation")
	var legacy: Dictionary=CARGO.legacy_profile(offer,0.0,100.0,"compact")
	freight["cargo_progress"]=legacy
	var compatible: Dictionary=TELEMETRY.snapshot(freight,"zh")
	check(compatible["legacy"] and compatible["distance_met"] and
		TELEMETRY.source_is_consistent(freight,compatible),
		"old save acceptance policy identical to original cargo logistics")
	freight["cargo_progress"]={"condition":100.0}
	var bad: Dictionary=TELEMETRY.snapshot(freight,"ru")
	check(not bad["valid"] and not bad["distance_met"] and
		bad["label"].contains("НЕДОСТУПНЫ"),
		"corrupt/partial cargo cannot fabricate a completed delivery")
	var mesh: ArrayMesh=CASE.physical_crate()
	check(CASE.within_original_envelope(mesh) and
		mesh.get_surface_count()==1,
		"actual original shared source 3D cargo remains within old geometry footprint")
	var arr: Array=mesh.surface_get_arrays(0)
	var verts: PackedVector3Array=arr[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array=arr[Mesh.ARRAY_NORMAL]
	check(verts.size()==normals.size() and verts.size()>250,
		"real original 3D metal straps produce full vertex normals")
	print("CITY REIGN R176 REAL MILEAGE TELEMETRY: %d PASS %d FAIL" % [passed,failed])
	quit(0 if failed==0 else 1)
