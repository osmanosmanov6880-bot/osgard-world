extends SceneTree
## R175: actual source economic values and ORIGINAL native 3D shape.
const PULSE=preload("res://scripts/city_reign_live_economy_pulse.gd")
const DISTRICT=preload("res://scripts/city_reign_district_identity.gd")
var passed: int=0
var failed: int=0
func check(ok: bool,reason: String) -> void:
	if ok: passed+=1
	else:
		failed+=1
		push_error("R175 REAL ECONOMIC SOURCE FAIL: "+reason)
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var src: Dictionary=GameState.new_game()
	var original: Dictionary=src.duplicate(true)
	check(PULSE.value_for(src,"forum")["value"]==72 and
		PULSE.value_for(src,"aqueduct")["value"]==93,
		"existing actual stability and energy source, not fake HUD values")
	check(PULSE.value_for(src,"housing")["value"]==80 and
		PULSE.value_for(src,"lower")["value"]==90,
		"actual saved inventory goods/materials displayed exactly")
	check(PULSE.value_for(src,"fictional").is_empty(),
		"unregistered production cannot invent a new service site")
	for site in PULSE.SITES:
		var a: Vector3=PULSE.SITE_ANCHORS[site]
		check(PULSE.original_anchor_is_safe(site,a),
			"each source service-site public verge avoids original road and 25m collider: "+site)
		var mesh: ArrayMesh=PULSE.static_mesh(site)
		check(mesh!=null and mesh.get_surface_count()==1,
			"original authored in-scene source vertices with one draw surface: "+site)
		var data: Array=mesh.surface_get_arrays(0)
		var v: PackedVector3Array=data[Mesh.ARRAY_VERTEX]
		var n: PackedVector3Array=data[Mesh.ARRAY_NORMAL]
		var c: PackedColorArray=data[Mesh.ARRAY_COLOR]
		check(v.size()==n.size() and v.size()==c.size() and
			v.size()<=PULSE.MAX_MESH_VERTICES and v.size()>160,
			"real metal utility mesh, bounded colored vertices and normals: "+site)
		for i in range(0,v.size(),maxi(1,v.size()/17)):
			check(v[i].is_finite() and n[i].is_finite(),
				"no NaN in physical source utility silhouette: "+site)
		var grade: Color=DISTRICT.living_color(site,80,93)
		var distress: Color=DISTRICT.living_color(site,8,0)
		check(grade.r>distress.r and grade.g>distress.g,
			"saved city district health and genuine blackout change actual PBR instance tint: "+site)
	var rotor: ArrayMesh=PULSE.rotor_mesh()
	check(rotor!=null and rotor.get_surface_count()==1 and
		rotor.surface_get_array_len(0)<PULSE.MAX_MESH_VERTICES,
		"one reusable source 3D rotor, not a per-frame generated mesh")
	check(not PULSE.original_anchor_is_safe("forum",Vector3(-104,0,-130)) and
		not PULSE.original_anchor_is_safe("housing",Vector3(130,0,-130)),
		"cannot place additional 3D objects in live roads and buildings")
	src["energy"]=0
	src["inventories"]["materials"]=0
	check(PULSE.value_for(src,"aqueduct")["low"] and
		PULSE.value_for(src,"lower")["low"] and
		float(PULSE.value_for(src,"lower")["normalized"])==0.0,
		"actual saved resource scarcity produces real stopped economic rotor")
	check(original["energy"]==93 and original["inventories"]["materials"]==90,
		"pure economic display projection never writes source state")
	print("CITY REIGN R175 ORIGINAL SOURCE MESH + ECONOMY: %d PASS %d FAIL" % [passed,failed])
	quit(0 if failed==0 else 1)
