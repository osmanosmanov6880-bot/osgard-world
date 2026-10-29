extends Node3D
## CITY REIGN R176 — REAL original paid cargo becomes measurable 3D cargo.
## Three original car case positions retained. Genuine physical mileage and
## damage are projected read-only from existing CargoLogistics, not duplicated.
const SOURCE=preload("res://scripts/city_reign_freight_telemetry.gd")
const SCULPT=preload("res://scripts/city_reign_cargo_case_geometry.gd")
const MAX_SCENE_CHILDREN: int=6
var crates: Array[MeshInstance3D]=[]
var cargo_text: Label3D
var distance_frame: MeshInstance3D
var distance_fill: MeshInstance3D
var low_case: BoxMesh
var native_case: ArrayMesh
var freight_pbr: StandardMaterial3D
var quality: String="standard"
var current_language: String="ru"
var last_projection: Dictionary={}
var current_active: Dictionary={}
var grade_ready: bool=false

func _ready() -> void:
	name="CargoOnVehicle"
	# One low draw resource plus ONE authentic source geometry shared by
	# all three original physical cases; no per-frame allocations.
	low_case=BoxMesh.new()
	low_case.size=Vector3(0.72,0.48,0.85)
	native_case=SCULPT.physical_crate()
	assert(SCULPT.within_original_envelope(native_case),
		"Real R176 metal case must preserve original 3D envelope")
	freight_pbr=StandardMaterial3D.new()
	freight_pbr.albedo_color=Color("5b795e")
	freight_pbr.vertex_color_use_as_albedo=true
	freight_pbr.roughness=0.52
	freight_pbr.metallic=0.24
	freight_pbr.cull_mode=BaseMaterial3D.CULL_DISABLED
	for index in range(3):
		var crate:=MeshInstance3D.new()
		crate.name="CargoBox%d" % index
		crate.mesh=native_case
		crate.position=Vector3(-0.75+float(index)*0.75,1.17,0.38)
		crate.material_override=freight_pbr
		crate.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(crate)
		crates.append(crate)
	# Native 3D progress meter, not a DOM canvas or a new GameState key.
	distance_frame=MeshInstance3D.new()
	distance_frame.name="RealTripMeterFrame"
	var frame_mesh:=BoxMesh.new()
	frame_mesh.size=Vector3(1.63,0.087,0.080)
	distance_frame.mesh=frame_mesh
	distance_frame.position=Vector3(0.0,1.72,0.60)
	var frame_material:=StandardMaterial3D.new()
	frame_material.albedo_color=Color("1e2a33")
	frame_material.roughness=0.78
	distance_frame.material_override=frame_material
	distance_frame.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(distance_frame)
	distance_fill=MeshInstance3D.new()
	distance_fill.name="ActualDrivenMeters"
	var gauge_mesh:=BoxMesh.new()
	gauge_mesh.size=Vector3(1.53,0.095,0.085)
	distance_fill.mesh=gauge_mesh
	distance_fill.position=Vector3(-0.765,1.72,0.60)
	distance_fill.scale.x=0.001
	var fill_material:=StandardMaterial3D.new()
	fill_material.albedo_color=Color("78c0ac")
	fill_material.metallic=0.12
	fill_material.roughness=0.44
	distance_fill.material_override=fill_material
	distance_fill.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(distance_fill)
	var label:=Label3D.new()
	label.name="FreightCondition"
	label.position=Vector3(0.0,2.00,0.25)
	label.font_size=40
	label.pixel_size=0.0055
	label.outline_size=10
	label.outline_modulate=Color("14232b")
	label.modulate=Color("e9eddc")
	label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	add_child(label)
	cargo_text=label
	visible=false
	grade_ready=true
	set_quality(quality)

func sync_state(state: Dictionary,locale: String="ru") -> void:
	current_language=locale
	var active: Dictionary=state.get("active_contract",{})
	current_active=active
	last_projection=SOURCE.snapshot(active,current_language)
	visible=bool(last_projection.get("active",false))
	if not visible:
		if cargo_text!=null: cargo_text.text=""
		if distance_frame!=null: distance_frame.visible=false
		if distance_fill!=null: distance_fill.visible=false
		return
	var valid: bool=bool(last_projection.get("valid",false))
	var quality_pct: int=int(last_projection.get("condition",0))
	var condition: float=clampf(float(quality_pct)/100.0,0.0,1.0)
	if freight_pbr!=null:
		freight_pbr.albedo_color=(
			Color("4b987d").lerp(Color("bd625a"),1.0-condition) if valid
			else Color("777b82"))
	if cargo_text!=null:
		if valid and quality=="low":
			cargo_text.text=("ГРУЗ" if current_language=="ru" else (
				"FREIGHT" if current_language=="en" else "货物"))+" "+str(quality_pct)+"%"
		else:
			cargo_text.text=str(last_projection.get("label",""))
		cargo_text.modulate=Color("e4f0e5") if condition>=0.60 else Color("f6c2b1")
	var fraction: float=clampf(float(last_projection.get("fraction",0.0)),0.0,1.0) if valid else 0.0
	if distance_fill!=null:
		distance_fill.scale.x=maxf(0.001,fraction)
		distance_fill.position.x=-0.765+0.765*distance_fill.scale.x
		var mat: StandardMaterial3D=distance_fill.material_override
		mat.albedo_color=Color("65c6a2") if bool(last_projection.get("distance_met",false)) else Color("b59b70")
	if distance_frame!=null:
		distance_frame.visible=quality!="low" and valid
	if distance_fill!=null:
		distance_fill.visible=quality!="low" and valid and fraction>0.005

func set_quality(tier: String) -> void:
	quality=tier if ["low","standard","cinematic"].has(tier) else "standard"
	if not grade_ready:return
	for crate in crates:
		crate.mesh=low_case if quality=="low" else native_case
	# Rebuild no source object: only swap the shared mesh resource.
	if not current_active.is_empty():
		var source: Dictionary={"active_contract":current_active}
		sync_state(source,current_language)
	else:
		if distance_frame!=null:distance_frame.visible=false
		if distance_fill!=null:distance_fill.visible=false

func visuals_are_source_bounded() -> bool:
	if not grade_ready or get_child_count()!=MAX_SCENE_CHILDREN or crates.size()!=3:
		return false
	if not SCULPT.within_original_envelope(native_case):
		return false
	for crate in crates:
		if crate.get_child_count()!=0 or crate.material_override!=freight_pbr:
			return false
		if crate.mesh!=low_case and crate.mesh!=native_case:
			return false
	if distance_fill==null or distance_frame==null or cargo_text==null:
		return false
	return true

func display_is_authoritative() -> bool:
	return SOURCE.source_is_consistent(current_active,last_projection)
