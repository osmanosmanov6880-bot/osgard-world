extends Node3D
## HORIZON R10 checkpoint arch. Purely visual; game progression is verified
## only by driving_trials.gd physical position, mileage and elapsed time.
## One arch with bounded mesh count and NO colliders or shadow-casting lights.
const ACCENT := Color("59f1df")
const WARM := Color("e8c58b")
const DARK := Color("102235")
var animation_time := 0.0
var arch: Node3D
var gate_number: Label3D
var marker_step := 0
var marker_total := 0

static func approach_yaw(from_point: Vector3, destination: Vector3) -> float:
	var heading := Vector2(destination.x-from_point.x,destination.z-from_point.z)
	if heading.length_squared() < 0.1: return 0.0
	return atan2(-heading.x,-heading.y)

func _material(color: Color, luminous: bool = false) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = 0.55 if not luminous else 0.12
	mat.roughness = 0.25 if not luminous else 0.46
	if luminous:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 2.1
	return mat

func _bar(id: String, size: Vector3, location: Vector3, material: Material, turn: float = 0.0) -> void:
	var mesh := MeshInstance3D.new()
	mesh.name = id
	var body := BoxMesh.new()
	body.size = size
	mesh.mesh = body
	mesh.material_override = material
	mesh.position = location
	mesh.rotation.z = turn
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	arch.add_child(mesh)

func _ready() -> void:
	name = "AcademyCheckpointGate"
	arch = Node3D.new()
	arch.name = "EmissiveFrame"
	add_child(arch)
	var chassis := _material(DARK)
	var light := _material(ACCENT,true)
	var premium := _material(WARM,true)
	# Two structural pylons, inner emissive rails, safety feet and upper bridge.
	for side in [-1.0,1.0]:
		var x: float = side*4.1
		_bar("Pylon_%d" % roundi(side),Vector3(0.53,4.65,0.74),Vector3(x,2.1,0),chassis)
		_bar("LightRail_%d" % roundi(side),Vector3(0.13,3.7,0.81),Vector3(x-side*0.30,2.1,0),light)
		_bar("Foot_%d" % roundi(side),Vector3(1.15,0.32,1.4),Vector3(x,0.05,0),chassis)
		_bar("FootTrim_%d" % roundi(side),Vector3(1.1,0.09,1.45),Vector3(x,0.24,0),premium)
		_bar("ChevTop_%d" % roundi(side),Vector3(0.16,0.94,0.81),Vector3(side*3.0,4.58,0.0),light,side*0.36)
		_bar("ChevBottom_%d" % roundi(side),Vector3(0.16,0.94,0.81),Vector3(side*2.65,4.34,0),light,-side*0.36)
	_bar("Header",Vector3(8.75,0.64,0.82),Vector3(0,4.58,0),chassis)
	_bar("HeaderGlow",Vector3(8.5,0.11,0.88),Vector3(0,4.92,0),premium)
	_bar("CenterStripe",Vector3(5.3,0.09,0.9),Vector3(0,4.31,0),light)
	# Proper world-space checkpoint index: not a fake trophy or reward screen.
	gate_number = Label3D.new()
	gate_number.name = "CheckpointNumber"
	gate_number.text = "01 / 04"
	gate_number.font_size = 64
	gate_number.pixel_size = 0.006
	gate_number.outline_size = 5
	gate_number.modulate = Color("e9faf6")
	gate_number.position = Vector3(0,3.82,0.46)
	arch.add_child(gate_number)
	visible = false

func show_at(point: Vector3, approach_from: Vector3 = Vector3.ZERO, step: int = 1, total: int = 1) -> void:
	global_position = point
	rotation.y = approach_yaw(approach_from,point)
	marker_step = maxi(1,step)
	marker_total = maxi(marker_step,total)
	if gate_number != null:
		gate_number.text = "%02d / %02d" % [marker_step,marker_total]
	visible = true

func _process(delta: float) -> void:
	if not visible: return
	animation_time += minf(delta,0.1)
	if arch != null:
		arch.position.y = sin(animation_time*2.6)*0.09
