extends SceneTree
## R174 real original native 3D ownership markers / safe city placements.
const OWNED=preload("res://scripts/city_reign_owned_business_world.gd")
var passed: int=0
var failed: int=0
func check(ok: bool,why: String) -> void:
	if ok: passed+=1
	else:
		failed+=1
		push_error("CITY REIGN R174 REAL 3D BUSINESS FAIL: "+why)
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var size_by_id: Dictionary={}
	for id in OWNED.INSIGNIAS:
		check(OWNED.safe_curb(OWNED.ANCHORS[id]),
			"business-owned landmark remains outside actual carriageway and original buildings "+id)
		var mesh: Mesh=OWNED.original_mesh(id)
		check(mesh!=null and mesh.get_surface_count()==1,
			"actual source-authored single native geometry for "+id)
		var arrays: Array=mesh.surface_get_arrays(0)
		var verts: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
		var colors: PackedColorArray=arrays[Mesh.ARRAY_COLOR]
		check(verts.size()>=210 and verts.size()<=OWNED.MAX_VERTICES_PER_SIGN,
			"real original geometry stays in small bounded physical GPU budget "+id)
		check(verts.size()==normals.size() and verts.size()==colors.size(),
			"native PBR/normal/vertex-color source for every sign "+id)
		for i in range(0,verts.size(),maxi(1,verts.size()/15)):
			check(verts[i].is_finite() and normals[i].is_finite(),
				"all original geometric normals and vertices finite "+id)
		var bb: AABB=mesh.get_aabb()
		check(bb.position.x>=-1.1 and bb.end.x<=1.1 and
			bb.position.y>=0.2 and bb.end.y<=3.1,
			"pedestrian-scale source object is not a huge fake 3D building "+id)
		size_by_id[id]=verts.size()
	check(size_by_id.size()==3 and
		size_by_id["workshop"]!=size_by_id["market_stall"],
		"original live-ownership art has three distinct authored symbol forms")
	check(not OWNED.safe_curb(Vector3(104,0,104)) and
		not OWNED.safe_curb(Vector3(130,0,-130)) and
		not OWNED.safe_curb(Vector3(INF,0,0)),
		"cannot fabricate a physical purchase sign in road, building or invalid location")
	check(OWNED.original_mesh("fake_business")==null,
		"unknown saved business cannot construct unauthorized world art")
	print("CITY REIGN R174 REAL OWNED 3D MESH: %d PASS %d FAIL" % [passed,failed])
	quit(0 if failed==0 else 1)
