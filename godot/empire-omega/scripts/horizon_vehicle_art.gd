extends Node3D
const SPRING = preload("res://scripts/horizon_chassis_spring.gd")
## OSGARD HORIZON DRIVE: original PBR sports coupe assembled in Godot.
## These are editable original meshes, not meshes or assets from Forza.
## Built for Godot 4.4.1 GL Compatibility / HTML5.

var painted_parts: Array[MeshInstance3D] = []
var wheel_rigs: Array[Node3D] = []
var brake_strip: MeshInstance3D
var body_paint: Color = Color("d45835")
var first_build := true
var body_parts: Array[MeshInstance3D] = []
var body_rest: Array[Transform3D] = []
var roll_angle := 0.0
var roll_velocity := 0.0
var pitch_angle := 0.0
var pitch_velocity := 0.0
var ride_bob := 0.0
var ride_bob_velocity := 0.0

func _ready() -> void:
	name = "HorizonCoupe"
	_create_body()
	_create_wheels()
	_create_lighting()
	set_paint(body_paint)

func _mat(color: Color, metal: float = 0.1, rough: float = 0.5, emission: bool = false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metal
	m.roughness = rough
	if emission:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = 1.6
	return m

func _part(id: String, size: Vector3, at: Vector3, tint: Color, metal: float = 0.1, rough: float = 0.45, painted: bool = false, emissive: bool = false) -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	visual.name = id
	var cube := BoxMesh.new()
	cube.size = size
	visual.mesh = cube
	visual.position = at
	visual.material_override = _mat(tint,metal,rough,emissive)
	add_child(visual)
	body_parts.append(visual)
	body_rest.append(visual.transform)
	if painted:
		painted_parts.append(visual)
	return visual

func _glass_quad(id: String, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for v in [a,b,c,a,c,d]:
		surface.add_vertex(v)
	surface.generate_normals()
	var visual := MeshInstance3D.new()
	visual.name = id
	visual.mesh = surface.commit()
	var glass := _mat(Color("39687a"),0.42,0.12)
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	visual.material_override = glass
	add_child(visual)
	body_parts.append(visual)
	body_rest.append(visual.transform)

func _create_body() -> void:
	# Vehicle forward is -Z. Tapered upper surfaces visually reduce blockiness.
	_part("FrontNose",Vector3(2.53,0.41,2.75),Vector3(0,-0.38,-1.04),body_paint,0.55,0.23,true)
	_part("RearDeck",Vector3(2.58,0.50,2.40),Vector3(0,-0.30,1.40),body_paint,0.55,0.23,true)
	_part("Cabin",Vector3(2.06,0.56,2.30),Vector3(0,0.37,0.05),body_paint.darkened(0.1),0.50,0.26,true)
	_part("Roof",Vector3(1.92,0.18,1.45),Vector3(0,0.78,0.08),body_paint,0.6,0.22,true)
	_part("HoodHighlight",Vector3(1.48,0.035,1.18),Vector3(0,-0.145,-1.42),body_paint.lightened(0.06),0.55,0.22,true)
	_part("FrontSplitter",Vector3(2.75,0.13,0.64),Vector3(0,-0.65,-2.34),Color("101a24"),0.22,0.31)
	_part("RearDiffuser",Vector3(2.78,0.14,0.56),Vector3(0,-0.64,2.30),Color("101a24"),0.22,0.34)
	_part("RearSpoiler",Vector3(2.60,0.10,0.45),Vector3(0,0.36,2.26),Color("101b23"),0.25,0.30)
	for sign in [-1.0,1.0]:
		_part("SideSill",Vector3(0.18,0.16,3.42),Vector3(sign*1.26,-0.62,0),Color("121d25"),0.3,0.39)
		_part("SpoilerBracket",Vector3(0.11,0.47,0.13),Vector3(sign*0.94,0.09,2.20),Color("17232a"),0.4,0.35)
		_part("SideMirror",Vector3(0.38,0.21,0.43),Vector3(sign*1.13,0.38,-0.91),body_paint,0.5,0.26,true)
		_part("MirrorGlass",Vector3(0.035,0.13,0.28),Vector3(sign*1.34,0.39,-0.91),Color("789da7"),0.3,0.12)
		_part("DoorTrim",Vector3(0.04,0.06,1.30),Vector3(sign*1.30,-0.09,0.18),Color("c8cdd1"),0.75,0.22)
		_part("FrontVent",Vector3(0.10,0.17,0.65),Vector3(sign*1.29,-0.32,-1.68),Color("15202b"),0.12,0.7)
		_part("TailVent",Vector3(0.10,0.18,0.56),Vector3(sign*1.31,-0.29,1.65),Color("15202b"),0.12,0.7)
	# Sloped glazing: one windshield and one rear window, plus side glass.
	_glass_quad("SlopedWindshield",Vector3(-.92,.70,-.69),Vector3(.92,.70,-.69),Vector3(.99,.09,-1.28),Vector3(-.99,.09,-1.28))
	_glass_quad("RearGlass",Vector3(-.93,.66,.83),Vector3(.93,.66,.83),Vector3(1.01,.13,1.40),Vector3(-1.01,.13,1.40))
	_glass_quad("LeftSideGlass",Vector3(-1.035,.64,-.65),Vector3(-1.035,.64,.71),Vector3(-1.06,.10,.87),Vector3(-1.06,.10,-.98))
	_glass_quad("RightSideGlass",Vector3(1.035,.64,-.65),Vector3(1.035,.64,.71),Vector3(1.06,.10,.87),Vector3(1.06,.10,-.98))

func _create_wheels() -> void:
	for side in [-1.0,1.0]:
		for z in [-1.75,1.76]:
			var steering_rig := Node3D.new()
			steering_rig.name = "FrontWheelRig" if z < 0 else "RearWheelRig"
			steering_rig.position = Vector3(side*1.34,-0.28,z)
			add_child(steering_rig)
			wheel_rigs.append(steering_rig)
			var rolling := Node3D.new()
			rolling.name = "RollingWheel"
			steering_rig.add_child(rolling)
			var tyre := CylinderMesh.new()
			tyre.top_radius = 0.57
			tyre.bottom_radius = 0.57
			tyre.height = 0.35
			tyre.radial_segments = 20
			var rubber := MeshInstance3D.new()
			rubber.name = "PbrTyre"
			rubber.mesh = tyre
			rubber.rotation.z = PI*0.5
			rubber.material_override = _mat(Color("13191c"),0.04,0.95)
			rolling.add_child(rubber)
			var rim := CylinderMesh.new()
			rim.top_radius = 0.34
			rim.bottom_radius = 0.34
			rim.height = 0.375
			rim.radial_segments = 12
			var alloy := MeshInstance3D.new()
			alloy.name = "AlloyRim"
			alloy.mesh = rim
			alloy.rotation.z = PI*0.5
			alloy.material_override = _mat(Color("9da8b0"),0.88,0.18)
			rolling.add_child(alloy)
			var centre := CylinderMesh.new()
			centre.top_radius = 0.13
			centre.bottom_radius = 0.13
			centre.height = 0.39
			centre.radial_segments = 12
			var cap := MeshInstance3D.new()
			cap.name = "WheelCentre"
			cap.mesh = centre
			cap.rotation.z = PI*0.5
			cap.material_override = _mat(Color("293844"),0.6,0.28)
			rolling.add_child(cap)

func _create_lighting() -> void:
	# Emissive surfaces, not expensive realtime omni lights per vehicle.
	_part("LeftLED",Vector3(0.78,0.13,0.045),Vector3(-.83,-.29,-2.43),Color("d9f2ff"),0.0,0.15,false,true)
	_part("RightLED",Vector3(0.78,0.13,0.045),Vector3(.83,-.29,-2.43),Color("d9f2ff"),0.0,0.15,false,true)
	brake_strip = _part("FullWidthRearLight",Vector3(2.25,0.10,0.055),Vector3(0,-0.24,2.52),Color("ff5861"),0.0,0.2,false,true)

func set_paint(color: Color) -> void:
	body_paint = color
	for piece in painted_parts:
		if piece == null:
			continue
		var mat: StandardMaterial3D = (piece.material_override as StandardMaterial3D).duplicate() as StandardMaterial3D
		mat.albedo_color = color
		mat.metallic = 0.62
		mat.roughness = 0.22
		piece.material_override = mat

func roll_wheels(metres: float, steering: float) -> void:
	for rig in wheel_rigs:
		if rig == null: continue
		rig.rotation.y = steering*0.25 if rig.position.z < 0.0 else 0.0
		var spin: Node3D = rig.get_node("RollingWheel") as Node3D
		spin.rotate_x(metres / 0.57)

func set_brake_lights(on: bool) -> void:
	if brake_strip == null: return
	var mat := brake_strip.material_override as StandardMaterial3D
	if mat != null:
		mat.emission_energy_multiplier = 3.5 if on else 0.45

func simulate_chassis(forward_speed: float, yaw_rate: float, forward_acceleration: float, grip: float, handbrake: bool, contacts: Array[float], dt: float) -> void:
	# Visual spring-damper layer; do not replace the collision body authority.
	if dt <= 0.0: return
	var target_lean: float = SPRING.target_roll(forward_speed,yaw_rate,grip,handbrake)
	var target_squat: float = SPRING.target_pitch(forward_acceleration)
	var roll_result: Vector2 = SPRING.integrate(roll_angle,roll_velocity,target_lean,dt,4.2)
	roll_angle = roll_result.x
	roll_velocity = roll_result.y
	var pitch_result: Vector2 = SPRING.integrate(pitch_angle,pitch_velocity,target_squat,dt,4.8)
	pitch_angle = pitch_result.x
	pitch_velocity = pitch_result.y
	var sum_contact: float = 0.0
	for contact in contacts:
		sum_contact += contact
	var bob_target: float = clampf(sum_contact/float(maxi(contacts.size(),1))*0.45,-0.065,0.07)
	var vertical: Vector2 = SPRING.integrate(ride_bob,ride_bob_velocity,bob_target,dt,5.2)
	ride_bob = vertical.x
	ride_bob_velocity = vertical.y
	var lean := Basis.from_euler(Vector3(pitch_angle,0.0,roll_angle))
	for index in range(body_parts.size()):
		if not is_instance_valid(body_parts[index]): continue
		body_parts[index].transform = Transform3D(lean,Vector3(0,ride_bob,0))*body_rest[index]
	for index in range(wheel_rigs.size()):
		if index >= contacts.size(): break
		wheel_rigs[index].position.y = lerpf(wheel_rigs[index].position.y,-0.28+clampf(contacts[index],-0.10,0.18),clampf(dt*13.0,0.0,1.0))
