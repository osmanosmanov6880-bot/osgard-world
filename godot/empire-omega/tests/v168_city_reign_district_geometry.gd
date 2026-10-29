extends SceneTree
## R173 actual original per-vertex 3D mesh families and budgets.
const ID=preload("res://scripts/city_reign_district_identity.gd")
var pass_count: int=0
var fail_count: int=0
func check(ok: bool,why: String) -> void:
	if ok: pass_count+=1
	else:
		fail_count+=1
		push_error("CITY REIGN R173 REAL DISTRICT GEOMETRY FAIL: "+why)
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var sizes: Dictionary={}
	for district in ID.DISTRICTS:
		var mesh: ArrayMesh=ID.relief_mesh(district)
		check(mesh!=null and mesh.get_surface_count()==1,
			"real source-authored physical 3D district sign: "+district)
		var arr: Array=mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array=arr[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array=arr[Mesh.ARRAY_NORMAL]
		var tint: PackedColorArray=arr[Mesh.ARRAY_COLOR]
		check(vertices.size()>=220 and vertices.size()<=2500,
			"strict original 3D triangle budget per family "+district)
		check(vertices.size()==normals.size() and vertices.size()==tint.size(),
			"true PBR-ready colored normals for every original vertex "+district)
		for i in range(0,vertices.size(),maxi(1,vertices.size()/30)):
			check(vertices[i].is_finite() and normals[i].is_finite(),
				"source relief must not emit nonfinite 3D vertices "+district)
		var bounds: AABB=mesh.get_aabb()
		check(bounds.position.x>=-3.5 and bounds.end.x<=3.5 and
			bounds.position.y>=0.18 and bounds.end.y<=6.1 and
			bounds.position.z>=-3.0 and bounds.end.z<=0.0,
			"street-facing near-door medallions avoid original collision footprint")
		sizes[district]=vertices.size()
	check(sizes.size()==4 and sizes["aqueduct"]>sizes["lower"],
		"water ribbons and freight chevrons have genuinely different 3D topology")
	check(ID.led_mesh().surface_get_array_len(0)<=100,
		"single original low-vertex lighting strip for shared GPU batch")
	check(ID.relief_mesh("invented")==null,"no invented fifth district geometry")
	print("CITY REIGN R173 ACTUAL NATIVE RELIEF: %d PASS %d FAIL" % [pass_count,fail_count])
	quit(0 if fail_count==0 else 1)
