extends Node3D
## Original character silhouette, separate from the gameplay collision capsule.
## Proportions and arm/leg movement are driven by actual pedestrian speed.

var left_leg: Node3D
var right_leg: Node3D
var left_arm: Node3D
var right_arm: Node3D
var motion_clock: float = 0.0
var detail_nodes := 0

func _ready() -> void:
	name = "HorizonCitizen"
	_create_clothing()

func _mat(color: Color, rough: float = 0.82) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	return m

func _box(parent: Node3D, id: String, size: Vector3, at: Vector3, color: Color) -> MeshInstance3D:
	var item := MeshInstance3D.new()
	item.name = id
	var shape := BoxMesh.new()
	shape.size = size
	item.mesh = shape
	item.material_override = _mat(color)
	item.position = at
	parent.add_child(item)
	detail_nodes += 1
	return item

func _sphere(parent: Node3D, id: String, radius: float, at: Vector3, color: Color) -> MeshInstance3D:
	var item := MeshInstance3D.new()
	item.name = id
	var shape := SphereMesh.new()
	shape.radius = radius
	shape.height = radius*2.0
	shape.radial_segments = 12
	shape.rings = 7
	item.mesh = shape
	item.material_override = _mat(color)
	item.position = at
	parent.add_child(item)
	detail_nodes += 1
	return item

func _cylinder(parent: Node3D, id: String, height: float, width: float, at: Vector3, color: Color) -> MeshInstance3D:
	var item := MeshInstance3D.new()
	item.name = id
	var shape := CylinderMesh.new()
	shape.height = height
	shape.top_radius = width
	shape.bottom_radius = width*1.09
	shape.radial_segments = 9
	item.mesh = shape
	item.material_override = _mat(color)
	item.position = at
	parent.add_child(item)
	detail_nodes += 1
	return item

func _create_clothing() -> void:
	var jacket := Color("25394b")
	var trousers := Color("20323d")
	var skin := Color("d7a889")
	_box(self,"TailoredJacket",Vector3(.64,.78,.37),Vector3(0,.19,0),jacket)
	_box(self,"JacketHem",Vector3(.66,.12,.41),Vector3(0,-.25,0),jacket.darkened(.18))
	_box(self,"Collar",Vector3(.41,.11,.40),Vector3(0,.63,-.02),Color("dce0df"))
	_cylinder(self,"Neck",.15,.13,Vector3(0,.69,0),skin)
	_sphere(self,"Head",.28,Vector3(0,.96,-.015),skin)
	var hair := _sphere(self,"ShortHair",.286,Vector3(0,1.07,.012),Color("25272b"))
	hair.scale = Vector3(1.04,.55,1.05)
	for side in [-1.0,1.0]:
		_sphere(self,"Eye",.028,Vector3(side*.105,.975,-.274),Color("1c242c"))
		var leg := Node3D.new()
		leg.name = "LeftLeg" if side < 0 else "RightLeg"
		leg.position = Vector3(side*.18,-.27,0)
		add_child(leg)
		_cylinder(leg,"Trouser",.64,.17,Vector3(0,-.31,0),trousers)
		_box(leg,"Sneaker",Vector3(.27,.16,.46),Vector3(0,-.66,-.09),Color("111c25"))
		var arm := Node3D.new()
		arm.name = "LeftArm" if side < 0 else "RightArm"
		arm.position = Vector3(side*.41,.48,0)
		add_child(arm)
		_cylinder(arm,"Sleeve",.58,.135,Vector3(0,-.27,0),jacket)
		_sphere(arm,"Hand",.135,Vector3(0,-.59,0),skin)
		if side < 0:
			left_leg = leg
			left_arm = arm
		else:
			right_leg = leg
			right_arm = arm
	_box(self,"UtilityBelt",Vector3(.67,.09,.43),Vector3(0,-.23,0),Color("171d24"))

func animate_walk(actual_speed: float, delta: float) -> void:
	var pace: float = clampf(actual_speed/8.0,0.0,1.0)
	motion_clock += delta * actual_speed * 1.75
	var angle: float = sin(motion_clock) * 0.38 * pace
	if left_leg != null: left_leg.rotation.x = angle
	if right_leg != null: right_leg.rotation.x = -angle
	if left_arm != null: left_arm.rotation.x = -angle*0.78
	if right_arm != null: right_arm.rotation.x = angle*0.78
