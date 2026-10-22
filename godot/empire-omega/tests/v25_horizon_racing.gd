extends SceneTree
## Godot 4.4.1 native integration: tire slip, drift scoring, damped chassis,
## four wheel probes and procedurally tiled PBR surfaces.
const TIRES = preload("res://scripts/horizon_tire_model.gd")
const SPRING = preload("res://scripts/horizon_chassis_spring.gd")
const SURFACES = preload("res://scripts/horizon_road_materials.gd")
const CAR = preload("res://scripts/vehicle_controller.gd")

var checks := 0
var failures := 0

func require(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("HORIZON RACING FAILED: "+message)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var idle: float = TIRES.step_lateral(0.0,0.0,0.0,1.0,false,1.0/60.0)
	require(is_zero_approx(idle),"stationary car has no side motion")
	var slip: float = TIRES.step_lateral(0.0,18.0,0.5,1.0,false,0.3)
	require(slip > 0.2 and slip < 9.5,"yaw produces bounded outward tire slip")
	require(TIRES.step_lateral(0.0,-18.0,0.5,1.0,false,0.3) < 0.0,"reverse gear reverses slip direction")
	var wet: float = TIRES.step_lateral(0.0,18.0,0.5,0.5,false,0.3)
	var handbrake: float = TIRES.step_lateral(0.0,18.0,0.5,1.0,true,0.3)
	require(wet > slip,"wet road dissipates sideways momentum more slowly")
	require(handbrake > slip,"handbrake reduces lateral grip")
	require(absf(TIRES.step_lateral(20.0,28.0,1.0,0.3,true,0.5)) <= TIRES.MAX_SLIP_SPEED,"large slip is capped")
	require(TIRES.step_lateral(3.0,0.0,0.0,1.0,false,0.3) < 3.0,"tires stabilize at rest")
	require(TIRES.step_lateral(2.0,22.0,0.6,0.8,true,0.0)==2.0,"zero time does not modify state")
	require(absf(TIRES.step_lateral(0.0,20.0,0.5,1.0,false,5.0)-TIRES.step_lateral(0.0,20.0,0.5,1.0,false,0.5))<0.001,"long resume elapsed time is capped")
	var angle: float = TIRES.slip_angle_degrees(20.0,3.0)
	require(angle > 7.0 and angle < 10.0,"slip angle is measured in degrees")
	require(TIRES.drift_gain(6.0,4.0,true,0.1)==0.0,"parking maneuvers cannot farm drift scores")
	require(TIRES.drift_gain(22.0,2.6,true,0.1)>0.0,"controlled high-speed drift scores")
	require(TIRES.drift_gain(22.0,0.5,false,0.1)==0.0,"ordinary road turns do not score")
	require(TIRES.bank_reward(100.0,2.0)>=5,"validated skill chain pays modest credits")
	require(TIRES.bank_reward(1000.0,5.0)<=55,"drift credits are capped")
	require(TIRES.bank_reward(100.0,0.1)==0,"one-frame chain cannot produce credits")
	require(TIRES.bank_reward(10.0,3.0)==0,"tiny chain cannot produce credits")

	var spring_state := Vector2(0.0,0.0)
	for i in range(150):
		spring_state = SPRING.integrate(spring_state.x,spring_state.y,0.10,1.0/60.0)
	require(absf(spring_state.x-0.10)<0.003,"sprung body reaches target without oscillation")
	require(absf(SPRING.target_roll(25.0,1.0,0.5,true)) <= 0.13,"roll respects vehicle geometry limit")
	require(SPRING.target_pitch(-10.0)>0.0,"braking produces correct visual nose dive")
	require(SPRING.integrate(0.3,0.2,0.0,0.0)==Vector2(0.3,0.2),"zero-time spring integration is unchanged")

	var asphalt: StandardMaterial3D = SURFACES.asphalt()
	var concrete: StandardMaterial3D = SURFACES.concrete()
	require(asphalt.albedo_texture != null,"asphalt gets real generated albedo texture")
	require(asphalt.normal_enabled and asphalt.normal_texture != null,"asphalt has bump detail")
	require(asphalt.uv1_triplanar and asphalt.uv1_world_triplanar,"road material maps seamlessly in world space")
	require(asphalt.albedo_texture.get_width()==SURFACES.SIZE,"generated textures have expected dimensions")
	require(concrete.albedo_texture != null and concrete.roughness > asphalt.roughness,"sidewalk has its own PBR finish")

	var car: CharacterBody3D = CAR.new()
	root.add_child(car)
	var art: Node3D = car.get_node_or_null("HorizonCoupe") as Node3D
	require(art != null,"racing chassis is wired to actual drivable car")
	if art != null:
		var contacts: Array[float] = [0.09,-0.04,0.08,-0.03]
		art.call("simulate_chassis",18.0,0.5,-6.0,0.9,true,contacts,1.0/60.0)
		require((art.get("body_parts") as Array).size()>=12,"all body meshes are included in spring animation")
		require(absf(float(art.get("roll_angle"))) > 0.0,"visible body rolls when cornering")
		require(absf(float(art.get("pitch_angle"))) > 0.0,"visible body pitches when braking")
		require((art.get("wheel_rigs") as Array).size()==4,"independent wheel rigs remain intact")
	var recorded: Array[int] = []
	car.drift_reward_earned.connect(func(credits: int, _score: int) -> void: recorded.append(credits))
	car.drift_chain_score = 100.0
	car.drift_chain_duration = 2.0
	car.drift_release_clock = 0.85
	car.driving = false
	car._update_drift_score(0.1)
	require(recorded.size()==1 and recorded[0]>0,"skill chain pays once and clears")
	car._update_drift_score(0.1)
	require(recorded.size()==1,"finished chain cannot pay twice")
	require(car.drift_chain_score == 0.0,"score resets after banking")
	car.queue_free()
	print("HORIZON RACING NATIVE: %d pass, %d failures" % [checks,failures])
	quit(0 if failures==0 else 1)
