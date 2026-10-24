extends Node3D
## OSGARD R135 / service spine. Fully simulated rig, no remote equipment commands.
## The optical carriage is a deterministic 16 s state cycle, updated on physics ticks.
## All visible telemetry is LAB / SIMULATION; no production status is inferred.
const ECO_PATH: String = "res://models/r135/service_spine_eco.glb"
const HERO_PATH: String = "res://models/r135/service_spine_hero.glb"

var quality: int = -1
var model_root: Node3D
var loaded_path: String = ""
var load_count: int = 0
var load_failures: int = 0
var motion_enabled: bool = true
var elapsed: float = 0.0
var motor_speed: Array[float] = []
var fan_rotors: Array[Node3D] = []
var model_camera: Camera3D
var world: Environment
var boom: Node3D
var head: Node3D
var left_jaw: Node3D
var right_jaw: Node3D
var access_lid: Node3D
var lid_target: float = 0.0
var lid_progress: float = 0.0
var service_lights: Array[SpotLight3D] = []
var status_beacons: Array[OmniLight3D] = []
var surface_reflections: ReflectionProbe
var manual_inspections: int = 0
var scene_label: Label3D

func configure(cam: Camera3D, environment: Environment) -> void:
    model_camera = cam
    world = environment
    _build_kinematics()
    _build_lighting()
    # Do not load ECO and then HERO at startup. Main.gd selects a preset once.

func _mat(color: Color, metal: float, rough: float, emissive: bool = false) -> StandardMaterial3D:
    var mat: StandardMaterial3D = StandardMaterial3D.new()
    mat.albedo_color = color
    mat.metallic = metal
    mat.roughness = rough
    if emissive:
        mat.emission_enabled = true
        mat.emission = color
        mat.emission_energy_multiplier = 1.3
    return mat

func _make_box(parent: Node3D, part_name: String, center: Vector3, size: Vector3, surface: Material) -> MeshInstance3D:
    var part: MeshInstance3D = MeshInstance3D.new()
    part.name = part_name
    var body: BoxMesh = BoxMesh.new()
    body.size = size
    part.mesh = body
    part.material_override = surface
    part.position = center
    parent.add_child(part)
    return part

func _make_cylinder(parent: Node3D, part_name: String, center: Vector3, radius: float, height: float, surface: Material) -> MeshInstance3D:
    var part: MeshInstance3D = MeshInstance3D.new()
    part.name = part_name
    var body: CylinderMesh = CylinderMesh.new()
    body.top_radius = radius
    body.bottom_radius = radius
    body.height = height
    body.radial_segments = 20
    part.mesh = body
    part.material_override = surface
    part.position = center
    parent.add_child(part)
    return part

func _build_kinematics() -> void:
    var alloy: Material = _mat(Color(.42,.52,.58),.89,.27)
    var housing: Material = _mat(Color(.10,.16,.20),.70,.39)
    var orange: Material = _mat(Color(.88,.44,.16),.19,.37)
    var optical: Material = _mat(Color(.18,.71,.89),.0,.26,true)
    # 4 independent transforms: bridge travel / vertical head / gripper / service lid.
    boom = Node3D.new()
    boom.name = "R135_BridgeDrive_16s_Cycle_SIMULATION"
    boom.position = Vector3(-4.55,3.78,5.37)
    add_child(boom)
    _make_box(boom,"Machined_Bridge_Saddle",Vector3.ZERO,Vector3(.72,.17,.42),alloy)
    for dx in [-0.28, 0.28]:
        _make_box(boom,"Bearing_Carriage",Vector3(dx,-.10,0),Vector3(.17,.10,.34),housing)
    _make_box(boom,"Service_Status_Marking",Vector3(0,.092,0),Vector3(.18,.008,.31),orange)
    head = Node3D.new()
    head.name = "Vertical_Optical_Service_Head"
    head.position = Vector3(0,-.22,0)
    boom.add_child(head)
    _make_box(head,"Optical_Inspection_Cabinet",Vector3(0,-.12,0),Vector3(.32,.23,.28),housing)
    _make_cylinder(head,"Inspection_Lens",Vector3(0,-.29,.12),.073,.06,optical)
    for sgn in [-1, 1]:
        var name: String = "Left" if sgn < 0 else "Right"
        var jaw: Node3D = Node3D.new()
        jaw.name = "R135_"+name+"_Servo_Jaw"
        jaw.position = Vector3(.16*float(sgn),-.43,0)
        head.add_child(jaw)
        _make_box(jaw,"Machined_Gripper_Finger",Vector3(0,-.046,0),Vector3(.06,.22,.09),alloy)
        _make_box(jaw,"Nonmarring_Polymer_Pad",Vector3(-.021*float(sgn),-.12,0),Vector3(.035,.08,.09),housing)
        if sgn < 0:
            left_jaw = jaw
        else:
            right_jaw = jaw
    access_lid = Node3D.new()
    access_lid.name = "R135_Inspectable_Spine_Hatch_Hinge"
    access_lid.position = Vector3(-4.98,.13,5.92)
    add_child(access_lid)
    _make_box(access_lid,"Capped_Service_Deck",Vector3(.43,0,0),Vector3(.86,.056,.65),alloy)
    _make_box(access_lid,"Latch",Vector3(.78,.055,0),Vector3(.11,.058,.22),orange)
    # Fan hubs are animated; static ducts and housings are part of the GLB.
    for i in range(6):
        var rotor: Node3D = Node3D.new()
        rotor.name = "R135_Supply_Fan_%02d" % i
        rotor.position = Vector3(-4.65+float(i%3)*3.1,3.4,4.53+float(i/3)*1.0)
        add_child(rotor)
        var hub: MeshInstance3D = _make_cylinder(rotor,"Fan_Bearing",Vector3.ZERO,.062,.075,housing)
        hub.rotation.x = PI*.5
        for blade in range(6):
            var a: float = TAU*float(blade)/6.0
            var fin: MeshInstance3D = _make_box(rotor,"Fan_Blade",Vector3(sin(a)*.16,cos(a)*.16,0),Vector3(.095,.18,.017),alloy)
            fin.rotation.z = -a
        fan_rotors.append(rotor)
        motor_speed.append(0.0)

func _build_lighting() -> void:
    for index in range(5):
        var fixture: SpotLight3D = SpotLight3D.new()
        fixture.name = "R135_CRI90_Service_Spot_%02d" % index
        fixture.position = Vector3(-4.65+index*2.26,4.05,5.65)
        fixture.rotation_degrees = Vector3(-90,0,0)
        fixture.light_color = Color(.94,.94,1.0) if index%2 else Color(1.0,.87,.70)
        fixture.light_energy = 0.88
        fixture.spot_range = 4.8
        fixture.spot_angle = 46
        fixture.shadow_enabled = false
        add_child(fixture)
        service_lights.append(fixture)
    for index in range(2):
        var warning: OmniLight3D = OmniLight3D.new()
        warning.name = "R135_SIMULATED_Status_Beacon_%02d" % index
        warning.position = Vector3(-5.3+10.6*float(index),2.81,5.94)
        warning.omni_range = 2.5
        warning.light_color = Color(.91,.40,.15)
        warning.light_energy = 0.15
        add_child(warning)
        status_beacons.append(warning)
    surface_reflections = ReflectionProbe.new()
    surface_reflections.name = "R135_Bounded_Service_Reflection"
    surface_reflections.position = Vector3(0,1.7,5.10)
    surface_reflections.size = Vector3(11.8,3.6,2.9)
    surface_reflections.intensity = 0.45
    surface_reflections.visible = false
    add_child(surface_reflections)
    scene_label = Label3D.new()
    scene_label.text = "R135 / SIMULATED SERVICE SPINE - NO LIVE DATA"
    scene_label.font_size = 48
    scene_label.pixel_size = .0018
    scene_label.position = Vector3(0,3.37,6.41)
    scene_label.modulate = Color(.64,.85,.91)
    add_child(scene_label)

func _swap_glb(path: String) -> void:
    if loaded_path == path:
        return
    # Keep original mesh on failure; do not destroy a working scene first.
    var resource: Resource = load(path)
    if not resource is PackedScene:
        load_failures += 1
        push_error("R135 missing GLB: "+path)
        return
    var instance: Node3D = (resource as PackedScene).instantiate() as Node3D
    if instance == null:
        load_failures += 1
        return
    instance.name = "R135_PBR_STATIC_SERVICE_SPINE"
    add_child(instance)
    var previous: Node3D = model_root
    model_root = instance
    loaded_path = path
    load_count += 1
    if previous != null:
        previous.queue_free()

func set_quality(index: int) -> void:
    quality = clampi(index,0,2)
    _swap_glb(ECO_PATH if quality==0 else HERO_PATH)
    for i in range(service_lights.size()):
        service_lights[i].visible = quality>0 or i%2==0
        service_lights[i].shadow_enabled = quality==2 and i==2
    for light in status_beacons:
        light.visible = quality>=1
    if surface_reflections != null:
        surface_reflections.visible = quality==2
    # The Main quality pipeline retains ownership of SSR/SSAO and dynamic resolution.

func set_motion(active: bool) -> void:
    motion_enabled = active

func toggle_access_lid() -> void:
    lid_target = 1.0-lid_target
    manual_inspections += 1

static func smooth_unit(t: float) -> float:
    var x: float = clampf(t,0.0,1.0)
    return x*x*(3.0-2.0*x)

static func motion_cycle(t: float) -> Dictionary:
    # 16s cycle, bounded travel. Every translation stops at end of its interval.
    # 0-3 approach; 3-5 lower; 5-6.5 grip; 6.5-9 examine;
    # 9-10.5 release; 10.5-12 lift; 12-15 return; 15-16 dwell.
    var p: float = fposmod(t,16.0)
    var travel: float = 0.0
    if p < 3.0:
        travel = smooth_unit(p/3.0)
    elif p < 12.0:
        travel = 1.0
    elif p < 15.0:
        travel = 1.0-smooth_unit((p-12.0)/3.0)
    var drop: float = smooth_unit((p-3.0)/2.0)*(1.0-smooth_unit((p-10.5)/1.5))
    var grip: float = smooth_unit((p-5.0)/1.5)*(1.0-smooth_unit((p-9.0)/1.5))
    return {"phase_seconds":p,"travel":travel,"drop":drop,"grip":grip}

func _physics_process(delta: float) -> void:
    var step: float = clampf(delta,0.0,.05)
    if motion_enabled:
        elapsed += step
    var state: Dictionary = motion_cycle(elapsed)
    if boom != null:
        boom.position.x = -4.55 + 9.12*float(state["travel"])
    if head != null:
        head.position.y = -.22-.52*float(state["drop"])
    if left_jaw != null and right_jaw != null:
        left_jaw.position.x = -.16+.062*float(state["grip"])
        right_jaw.position.x = .16-.062*float(state["grip"])
    lid_progress = move_toward(lid_progress,lid_target,step*.6)
    if access_lid != null:
        access_lid.rotation.z = -1.14*smooth_unit(lid_progress)
    for i in range(fan_rotors.size()):
        var desired: float = (8.3+float(i%3)*1.3) if motion_enabled else 0.0
        motor_speed[i] = move_toward(motor_speed[i],desired,step*7.0)
        fan_rotors[i].rotation.z = fposmod(fan_rotors[i].rotation.z+motor_speed[i]*step,TAU)
    for i in range(status_beacons.size()):
        status_beacons[i].light_energy = (.17+.13*(.5+.5*sin(elapsed*1.9+float(i)*PI))) if motion_enabled else .09

func summary() -> Dictionary:
    return {"schema":"OSGARD_R135_SCENE_STATE_V1","simulation_only":true,
        "physical_telemetry_connected":false,"quality":quality,"loaded":loaded_path,
        "loading_failures":load_failures,"load_count":load_count,
        "motion_enabled":motion_enabled,"phase_seconds":fposmod(elapsed,16.0),
        "inspect_count":manual_inspections,"fan_count":fan_rotors.size()}
