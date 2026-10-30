extends SceneTree
## R187 pure physical source geometry: 16 real marked junction boxes.
const MARKS=preload("res://scripts/city_reign_real_junction_box_paint.gd")
const BOX=preload("res://scripts/city_reign_junction_box_clearance.gd")
const SOURCE=preload("res://scripts/city_reign_intersection_policy.gd")
var passed: int=0
var failed: int=0
func check(ok: bool,why: String) -> void:
	if ok:passed+=1
	else:
		failed+=1
		push_error("R187 ORIGINAL KEEP CLEAR GEOMETRY FAIL: "+why)
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	check(BOX.source_integrity() and SOURCE.source_grid_valid() and
		MARKS.ORIGINAL_JUNCTIONS==16 and MARKS.PAINT_GPU_BATCHES==2,
		"real original R186 16 source junctions and only TWO GPU road-marking groups")
	check(MARKS.ROAD_PAINT_HALF_M+MARKS.OUTLINE_PAINT_WIDTH_M*0.5<
		SOURCE.ROAD_HALF_WIDTH_M and
		MARKS.ROAD_PAINT_HALF_M<BOX.SOURCE_BOX_HALF_M,
		"true yellow paint remains entirely inside physical 10m asphalt and 12.8m guarded box")
	var x_left: Transform3D=MARKS.outline_transform(-156,-156,"x",-1)
	var x_right: Transform3D=MARKS.outline_transform(-156,-156,"x",1)
	var z_left: Transform3D=MARKS.outline_transform(-156,-156,"z",-1)
	check(is_equal_approx(x_left.origin.x,-160.3) and
		is_equal_approx(x_right.origin.x,-151.7) and
		is_equal_approx(z_left.origin.z,-160.3) and
		is_equal_approx(x_left.origin.y,MARKS.Y_ABOVE_ORIGINAL_ASPHALT_M),
		"four true original road-box outlines frame centre (-156,-156) inside existing asphalt")
	check(MARKS.outline_transform(100,100,"x",1)==Transform3D.IDENTITY and
		MARKS.outline_transform(-156,-156,"no",1)==Transform3D.IDENTITY,
		"non-existent source intersection or direction cannot generate painted fake roads")
	var central: Transform3D=MARKS.hatch_transform(-156,-156,2)
	check(is_equal_approx(central.origin.x,-156.0) and
		is_equal_approx(central.origin.z,-156.0) and
		central.basis.z.length()>12.0,
		"source middle 45deg road hatch genuinely crosses original central asphalt box")
	var actual_hatches: int=0
	for x in SOURCE.JUNCTIONS:
		for z in SOURCE.JUNCTIONS:
			for k in range(MARKS.DIAGONALS_PER_JUNCTION):
				var tr: Transform3D=MARKS.hatch_transform(float(x),float(z),k)
				var a: Vector3=tr.origin-tr.basis.z*0.5
				var b: Vector3=tr.origin+tr.basis.z*0.5
				check(absf(a.x-float(x))<=MARKS.ROAD_PAINT_HALF_M+0.001 and
					absf(a.z-float(z))<=MARKS.ROAD_PAINT_HALF_M+0.001 and
					absf(b.x-float(x))<=MARKS.ROAD_PAINT_HALF_M+0.001 and
					absf(b.z-float(z))<=MARKS.ROAD_PAINT_HALF_M+0.001,
					"each of 80 native yellow hatches is geometrically CLIPPED to original 10m asphalt")
				actual_hatches+=1
	check(actual_hatches==80 and MARKS.OUTLINE_INSTANCES==64 and
		MARKS.HATCH_INSTANCES==80,
		"all 16 actual source junction boxes receive 64 outlines + 80 true 3D diagonals")
	check(MARKS.hatch_transform(-156,-156,-1)==Transform3D.IDENTITY and
		MARKS.hatch_transform(-156,-156,5)==Transform3D.IDENTITY,
		"invalid original source hatch indices never create extra roads")
	print("CITY REIGN R187 ORIGINAL 16 KEEP CLEAR ROAD BOXES: %d PASS %d FAIL" % [passed,failed])
	quit(0 if failed==0 else 1)
