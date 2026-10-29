extends Node3D
## HORIZON R39 original machined disc, bolts and tyre-sidewall details.
## A mesh pack is attached inside each existing animated RollingWheel node.
## Cosmetic geometry only: the validated 4-wheel contact/physics remain intact.
const BOLT_COUNT: int = 5
const TREAD_COUNT: int = 24
var rotor: MeshInstance3D
var bolts: MultiMeshInstance3D
var tread: MultiMeshInstance3D
var normalized_heat: float = 0.0
const THERMAL = preload("res://scripts/city_reign_rotor_thermal.gd")

func configure(side: float) -> void:
	name = "R39RollingWheelPBRDetails"
	var sign_side: float = -1.0 if side < 0.0 else 1.0
	var disc := CylinderMesh.new()
	disc.top_radius = 0.29
	disc.bottom_radius = 0.29
	disc.height = 0.055
	disc.radial_segments = 30
	rotor = MeshInstance3D.new()
	rotor.name = "MachinedBrakeRotor"
	rotor.mesh = disc
	rotor.rotation.z = PI*0.5
	rotor.position = Vector3(sign_side*0.215,0,0)
	var rotor_mat := StandardMaterial3D.new()
	rotor_mat.albedo_color = Color("87919a")
	rotor_mat.roughness = 0.32
	rotor_mat.metallic = 0.82
	# Material is configured ONCE; runtime heat changes only material
	# properties. No new meshes, point lights or shader reallocation.
	rotor_mat.emission_enabled = true
	rotor_mat.emission = Color("ff6d3c")
	rotor_mat.emission_energy_multiplier = 0.0
	rotor.material_override = rotor_mat
	add_child(rotor)
	var bolt_mesh := SphereMesh.new()
	bolt_mesh.radius = 0.038
	bolt_mesh.height = 0.075
	bolt_mesh.radial_segments = 8
	bolt_mesh.rings = 4
	var bolt_group := MultiMesh.new()
	bolt_group.mesh = bolt_mesh
	bolt_group.transform_format = MultiMesh.TRANSFORM_3D
	bolt_group.instance_count = BOLT_COUNT
	for i in range(BOLT_COUNT):
		var phi: float = TAU*float(i)/float(BOLT_COUNT)
		bolt_group.set_instance_transform(i,Transform3D(Basis(),Vector3(
			sign_side*0.260,cos(phi)*0.185,sin(phi)*0.185)))
	bolts = MultiMeshInstance3D.new()
	bolts.name = "MachinedWheelBoltBatch"
	bolts.multimesh = bolt_group
	var alloy := StandardMaterial3D.new()
	alloy.albedo_color = Color("d5d8d5")
	alloy.roughness = 0.16
	alloy.metallic = 0.88
	bolts.material_override = alloy
	bolts.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(bolts)
	var tread_mesh := BoxMesh.new()
	tread_mesh.size = Vector3(0.035,0.065,0.13)
	var segments := MultiMesh.new()
	segments.mesh = tread_mesh
	segments.transform_format = MultiMesh.TRANSFORM_3D
	segments.instance_count = TREAD_COUNT
	for i in range(TREAD_COUNT):
		var angle: float = TAU*float(i)/float(TREAD_COUNT)
		var at := Vector3(sign_side*0.170,cos(angle)*0.558,sin(angle)*0.558)
		var orientation := Basis(Vector3.RIGHT,angle)
		segments.set_instance_transform(i,Transform3D(orientation,at))
	tread = MultiMeshInstance3D.new()
	tread.name = "RealTyreShoulderTreadBatch"
	tread.multimesh = segments
	var rubber := StandardMaterial3D.new()
	rubber.albedo_color = Color("242829")
	rubber.metallic = 0.02
	rubber.roughness = 0.92
	tread.material_override = rubber
	tread.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(tread)
	set_quality("standard")

func apply_brake_heat(heat: float) -> void:
	if rotor==null or not is_finite(heat):
		return
	normalized_heat = clampf(heat,0.0,1.0)
	var mat: StandardMaterial3D = rotor.material_override as StandardMaterial3D
	if mat!=null:
		var glow: float = THERMAL.visible_glow(normalized_heat)
		mat.albedo_color = Color("87919a").lerp(Color("bf704f"),glow*0.72)
		mat.emission_energy_multiplier = glow*2.0

func set_quality(tier: String) -> void:
	var quality: String = tier if ["low","standard","cinematic"].has(tier) else "standard"
	visible = quality!="low"
	if rotor!=null:
		rotor.visible = quality!="low"
	if bolts!=null:
		bolts.visible = quality=="cinematic"
	if tread!=null:
		tread.visible = quality=="cinematic"

func instance_budget() -> int:
	return BOLT_COUNT+TREAD_COUNT
