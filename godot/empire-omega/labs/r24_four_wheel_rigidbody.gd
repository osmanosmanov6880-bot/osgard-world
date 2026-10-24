extends RigidBody3D
## HORIZON R24 LAB — separate real force-based 4-wheel suspension candidate.
## DOES NOT replace the published CharacterBody3D car. Requires physical
## validation and comparative handling telemetry before any live migration.
## Mass is kg, forces N, lengths metres; built for Godot 4.4.1 physics.

const BODY_MASS: float = 1220.0
const SPRING_REST: float = 0.42
const WHEEL_RADIUS: float = 0.51
const SPRING_STIFFNESS: float = 26000.0
const SPRING_DAMPING: float = 2350.0
const MAX_WHEEL_FORCE: float = 12500.0
const MOTOR_FORCE: float = 6900.0
const BRAKE_FORCE: float = 10300.0
const MAX_STEERING_TORQUE: float = 3200.0
const YAW_STABILITY: float = 1100.0
const LATERAL_STIFFNESS: float = 4100.0
const ROAD_MASK: int = 1
const WHEEL_OFFSETS = [
	Vector3(-1.05,-0.27,-1.48),
	Vector3(-1.05,-0.27,1.48),
	Vector3(1.05,-0.27,-1.48),
	Vector3(1.05,-0.27,1.48)
]

## External test/driver commands, intentionally not bound to live game input.
var command_drive: float = 0.0
var command_steer: float = 0.0
var command_brake: float = 0.0
var road_grip: float = 1.0
var grounded_wheels: int = 0
var average_spring_force: float = 0.0
var measured_forward_speed: float = 0.0
var last_wheel_compression: Array[float] = [0.0,0.0,0.0,0.0]

func _ready() -> void:
	name = "HorizonRigidBody24_EXPERIMENT"
	add_to_group("horizon_experimental_physics")
	mass = BODY_MASS
	can_sleep = false
	continuous_cd = true
	linear_damp = 0.12
	angular_damp = 0.75
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0.0,-0.19,0.0)
	collision_layer = 4
	collision_mask = ROAD_MASK
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.35,0.58,4.12)
	collision.shape = shape
	add_child(collision)
	# Low-cost lab silhouette, never substituted for player's PBR body.
	var body_mesh := MeshInstance3D.new()
	body_mesh.name = "ExperimentalMassBody"
	var box := BoxMesh.new()
	box.size = Vector3(2.35,0.52,4.05)
	body_mesh.mesh = box
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("697a87")
	material.metallic = 0.25
	material.roughness = 0.52
	body_mesh.material_override = material
	add_child(body_mesh)

static func traction(grip: float, support: int) -> float:
	var g: float = clampf(grip if is_finite(grip) else 0.35,0.35,1.15)
	return g*clampf(float(support)/4.0,0.0,1.0)

static func spring_force(compression: float, normal_speed: float) -> float:
	if not is_finite(compression) or not is_finite(normal_speed):
		return 0.0
	var force: float = SPRING_STIFFNESS*clampf(compression,0.0,SPRING_REST)
	force -= SPRING_DAMPING*clampf(normal_speed,-5.0,5.0)
	return clampf(force,0.0,MAX_WHEEL_FORCE)

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	var space: PhysicsDirectSpaceState3D = state.get_space_state()
	var orientation: Basis = state.transform.basis
	var center: Vector3 = state.transform.origin
	var down: Vector3 = -orientation.y.normalized()
	var forward: Vector3 = Vector3(-orientation.z.x,0.0,-orientation.z.z).normalized()
	var right: Vector3 = Vector3(orientation.x.x,0.0,orientation.x.z).normalized()
	grounded_wheels = 0
	var force_sum: float = 0.0
	for wheel_index in range(4):
		var mount: Vector3 = center+orientation*WHEEL_OFFSETS[wheel_index]
		var endpoint: Vector3 = mount+down*(SPRING_REST+WHEEL_RADIUS)
		var ray := PhysicsRayQueryParameters3D.create(mount,endpoint,ROAD_MASK)
		ray.exclude = [get_rid()]
		ray.collide_with_areas = false
		var hit: Dictionary = space.intersect_ray(ray)
		var normal: Vector3 = hit.get("normal",Vector3.UP) if not hit.is_empty() else Vector3.UP
		if hit.is_empty() or normal.y < 0.45:
			last_wheel_compression[wheel_index] = 0.0
			continue
		grounded_wheels += 1
		var road_point: Vector3 = hit["position"]
		var distance: float = mount.distance_to(road_point)
		var compression: float = clampf(SPRING_REST+WHEEL_RADIUS-distance,0.0,SPRING_REST)
		last_wheel_compression[wheel_index] = compression
		var lever: Vector3 = road_point-center
		var contact_velocity: Vector3 = state.linear_velocity+state.angular_velocity.cross(lever)
		var push: float = spring_force(compression,contact_velocity.dot(normal))
		force_sum += push
		# apply_force takes the GLOBAL-space force and an offset from body
		# origin, not an absolute world position (Godot 4.4 API).
		apply_force(normal*push,lever)
	average_spring_force = force_sum/float(maxi(1,grounded_wheels))
	var traction_fraction: float = traction(road_grip,grounded_wheels)
	measured_forward_speed = state.linear_velocity.dot(forward)
	if traction_fraction<=0.0:
		return
	var throttle: float = clampf(command_drive if is_finite(command_drive) else 0.0,-1.0,1.0)
	var brake: float = clampf(command_brake if is_finite(command_brake) else 0.0,0.0,1.0)
	var steer: float = clampf(command_steer if is_finite(command_steer) else 0.0,-1.0,1.0)
	apply_central_force(forward*throttle*MOTOR_FORCE*traction_fraction)
	var horizontal_velocity: Vector3 = Vector3(state.linear_velocity.x,0.0,state.linear_velocity.z)
	var speed: float = horizontal_velocity.length()
	if speed>0.10 and brake>0.0:
		apply_central_force(-horizontal_velocity.normalized()*minf(BRAKE_FORCE,11000.0*speed)*brake*traction_fraction)
	# Sideways tire damping is a first-order approximation. This is not a
	# Pacejka combined-slip model or a certified stability controller.
	var lateral: float = horizontal_velocity.dot(right)
	apply_central_force(-right*lateral*LATERAL_STIFFNESS*traction_fraction)
	var desired_turn: float = steer*clampf(absf(measured_forward_speed)/8.0,0.0,1.0)
	apply_torque(Vector3.UP*(desired_turn*MAX_STEERING_TORQUE*traction_fraction-state.angular_velocity.y*YAW_STABILITY))
	apply_central_force(-horizontal_velocity*speed*0.65)
