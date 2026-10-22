extends CharacterBody3D
## Third-person pedestrian with gravity, jump, sprint and camera-relative movement.

const SPEED = 7.0
const SPRINT_SPEED = 12.0
const ACCELERATION = 17.0
const GRAVITY = 24.0
const JUMP_SPEED = 8.0
const HORIZON_CITIZEN = preload("res://scripts/horizon_citizen_art.gd")

var active := true
var camera_heading := 0.0
var distance_walked := 0.0
var citizen_visual: Node3D

func _ready() -> void:
	name = "PlayableCitizen"
	collision_layer = 2
	collision_mask = 1 | 8
	var collider := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.height = 1.8
	capsule.radius = 0.4
	collider.shape = capsule
	add_child(collider)
	var body := MeshInstance3D.new()
	var shape := CapsuleMesh.new()
	shape.radius = 0.38
	shape.height = 1.65
	body.mesh = shape
	body.position.y = 0.05
	body.material_override = _mat(Color("b8cad6"))
	add_child(body)
	var head := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.28
	sphere.height = 0.56
	head.mesh = sphere
	head.position.y = 0.99
	head.material_override = _mat(Color("dbbca5"))
	add_child(head)
	var jacket := MeshInstance3D.new()
	var torso := BoxMesh.new()
	torso.size = Vector3(0.65,0.65,0.36)
	jacket.mesh = torso
	jacket.position.y = 0.27
	jacket.material_override = _mat(Color("1a364a"))
	add_child(jacket)
	# Retain original player collision and legacy nodes for compatibility,
	# while the original animated silhouette is rendered instead.
	citizen_visual = HORIZON_CITIZEN.new()
	add_child(citizen_visual)
	for old in [body,head,jacket]:
		old.visible = false

func _mat(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	return material

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = -0.2
	var direction := Vector3.ZERO
	if active:
		var x: float = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
		var y: float = Input.get_action_strength("move_forward") - Input.get_action_strength("move_backward")
		var forward := Vector3(-sin(camera_heading),0,-cos(camera_heading))
		var right := Vector3(cos(camera_heading),0,-sin(camera_heading))
		direction = (right * x + forward * y).normalized()
		if Input.is_action_just_pressed("jump") and is_on_floor():
			velocity.y = JUMP_SPEED
	var speed := SPRINT_SPEED if Input.is_action_pressed("sprint") else SPEED
	velocity.x = move_toward(velocity.x,direction.x * speed, ACCELERATION * delta)
	velocity.z = move_toward(velocity.z,direction.z * speed, ACCELERATION * delta)
	if direction.length_squared() > 0.001:
		rotation.y = lerp_angle(rotation.y,atan2(-direction.x,-direction.z),delta * 11.0)
		distance_walked += delta * Vector2(velocity.x,velocity.z).length()
	move_and_slide()
	if citizen_visual != null:
		citizen_visual.call("animate_walk",Vector2(velocity.x,velocity.z).length(),delta)
	if position.y < -20:
		global_position = Vector3(-112,1.2,-104)
