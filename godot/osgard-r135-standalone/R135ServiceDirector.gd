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
# A small playable maintenance sequence, entirely inside this simulated scene.
const MISSION_GOALS = ["PAUSE THE DRIVE", "OPEN SERVICE HATCH", "CLOSE SERVICE HATCH", "RESUME THE DRIVE"]
var mission_active: bool = false
var mission_completed: bool = false
var mission_step: int = 0
var mission_elapsed: float = 0.0
var mission_best_seconds: float = -1.0
var mission_attempts: int = 0
var mission_feedback: String = "PRESS START MISSION"

# W4: the optional advanced diagnostic challenge keeps the existing training
# mission fully intact. Every fault is simulated; no physical sensor is used.
const FAULT_TYPES = ["OPTICAL ALIGNMENT", "COOLING AIRFLOW", "SERVICE INTERLOCK"]
const FAULT_EVIDENCE = ["EDGE OFFSET +0.7 (SIM)", "AIRFLOW BELOW TARGET (SIM)", "CONTACT UNSEALED (SIM)"]
const FAULT_LESSONS = [
    "ALIGN OPTICS ONLY AFTER MOTOR STOP",
    "CHECK AIRFLOW WITH ACCESS HATCH OPEN",
    "VERIFY INTERLOCK SEAL BEFORE RESTART"
]
var cleared_cases: Array[bool] = [false, false, false]
const FAULT_VIEWS = [2, 3, 1]
const CHALLENGE_GOALS = ["STOP THE DRIVE", "OPEN THE SERVICE HATCH", "INSPECT THE CORRECT FAULT", "CLOSE THE SERVICE HATCH", "RESTART THE DRIVE"]
const CHALLENGE_ACTIONS = ["pause", "open", "scan", "close", "resume"]
const BEST_SCORE_PATH = "user://r135_challenge_record.cfg"
const RECORD_SCHEMA_VERSION: int = 2
# Arrays track optical, airflow and interlock independently across reloads.
var case_attempts: Array[int] = [0, 0, 0]
var case_best_scores: Array[int] = [0, 0, 0]
var case_best_seconds: Array[float] = [-1.0, -1.0, -1.0]
var case_total_mistakes: Array[int] = [0, 0, 0]
var last_record_save_ok: bool = true
var challenge_active: bool = false
var challenge_completed: bool = false
var challenge_step: int = 0
var challenge_fault_index: int = 0
var challenge_attempts: int = 0
var challenge_elapsed: float = 0.0
var challenge_errors: int = 0
var challenge_score: int = 0
var challenge_best_score: int = 0
var challenge_feedback: String = "DIAGNOSTICS READY — SELECT CHALLENGE"
var visual_faults: Node3D
var scene_label: Label3D

func configure(cam: Camera3D, environment: Environment) -> void:
    model_camera = cam
    world = environment
    _build_kinematics()
    _build_lighting()
    visual_faults = preload("res://R135VisualDiagnostics.gd").new()
    visual_faults.name = "R135SimulatedFaultIndicators"
    add_child(visual_faults)
    visual_faults.call("configure", head)
    _load_challenge_record()
    # Do not load ECO and then HERO at startup. Main.gd selects a preset once.

func set_reduced_motion(enabled: bool) -> void:
    # Accessibility affects only simulated marker animations, never physics.
    if visual_faults != null:
        visual_faults.set("reduced_motion", enabled)

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

func start_mission() -> void:
    challenge_active = false
    challenge_completed = false
    mission_active = true
    mission_completed = false
    mission_step = 0
    mission_elapsed = 0.0
    mission_attempts += 1
    mission_feedback = "TASK 1 / 4 - STOP DRIVE BEFORE OPENING HATCH"
    # A new simulated training run resets to a known closed mechanism,
    # never carrying an unfinished open-hatch pose into a running motor.
    _reset_simulated_hatch()
    motion_enabled = true

func _reset_simulated_hatch() -> void:
    # Explicit level reset; affects only in-game simulated geometry.
    lid_target = 0.0
    lid_progress = 0.0
    if access_lid != null:
        access_lid.rotation.z = 0.0

func mission_goal() -> String:
    if mission_completed:
        return "MISSION COMPLETE - SERVICE CYCLE RESTORED"
    if not mission_active:
        return "PRESS START MISSION TO INSPECT"
    return "TASK %d/4 - %s" % [mission_step + 1, MISSION_GOALS[mission_step]]

func _mission_event(action: String) -> void:
    if not mission_active or mission_completed:
        return
    var expected: String = ["pause", "open", "close", "resume"][mission_step]
    if action != expected:
        mission_feedback = "FOLLOW THE CURRENT OBJECTIVE"
        return
    mission_step += 1
    if mission_step >= MISSION_GOALS.size():
        mission_active = false
        mission_completed = true
        if mission_best_seconds < 0.0 or mission_elapsed < mission_best_seconds:
            mission_best_seconds = mission_elapsed
        mission_feedback = "INSPECTION CLEARED - DRIVE RESTORED"
    else:
        mission_feedback = "CHECKPOINT %d/4 CLEARED" % mission_step

func _load_challenge_record() -> void:
    var settings := ConfigFile.new()
    if settings.load(BEST_SCORE_PATH) != OK:
        # No file or corrupt legacy record: preserve safe fresh defaults.
        return
    challenge_best_score = clampi(int(settings.get_value("progress", "best_score", 0)), 0, 150)
    var saved_cases: Variant = settings.get_value("progress", "cleared_cases", [false, false, false])
    if saved_cases is Array:
        for i in range(cleared_cases.size()):
            if i < saved_cases.size() and typeof(saved_cases[i]) == TYPE_BOOL:
                cleared_cases[i] = saved_cases[i]
    # Old records had only best_score + cleared_cases. Do NOT fabricate
    # missing per-fault history or attribute the old global record to one fault.
    var stored_attempts: Variant = settings.get_value("progress", "case_attempts", [])
    var stored_scores: Variant = settings.get_value("progress", "case_best_scores", [])
    var stored_seconds: Variant = settings.get_value("progress", "case_best_seconds", [])
    var stored_mistakes: Variant = settings.get_value("progress", "case_total_mistakes", [])
    for i in range(FAULT_TYPES.size()):
        if stored_attempts is Array and i < stored_attempts.size():
            if typeof(stored_attempts[i]) in [TYPE_INT, TYPE_FLOAT]:
                case_attempts[i] = clampi(int(stored_attempts[i]), 0, 1000000)
        if stored_scores is Array and i < stored_scores.size():
            if typeof(stored_scores[i]) in [TYPE_INT, TYPE_FLOAT]:
                case_best_scores[i] = clampi(int(stored_scores[i]), 0, 150)
        if stored_seconds is Array and i < stored_seconds.size():
            if typeof(stored_seconds[i]) in [TYPE_INT, TYPE_FLOAT]:
                var time_value: float = float(stored_seconds[i])
                if not is_nan(time_value) and not is_inf(time_value) and time_value >= 0.0:
                    case_best_seconds[i] = minf(time_value, 360000.0)
        if stored_mistakes is Array and i < stored_mistakes.size():
            if typeof(stored_mistakes[i]) in [TYPE_INT, TYPE_FLOAT]:
                case_total_mistakes[i] = clampi(int(stored_mistakes[i]), 0, 1000000)

func _save_challenge_record() -> void:
    var settings := ConfigFile.new()
    settings.set_value("progress", "schema_version", RECORD_SCHEMA_VERSION)
    settings.set_value("progress", "best_score", challenge_best_score)
    settings.set_value("progress", "cleared_cases", cleared_cases)
    settings.set_value("progress", "case_attempts", case_attempts)
    settings.set_value("progress", "case_best_scores", case_best_scores)
    settings.set_value("progress", "case_best_seconds", case_best_seconds)
    settings.set_value("progress", "case_total_mistakes", case_total_mistakes)
    var result: Error = settings.save(BEST_SCORE_PATH)
    last_record_save_ok = result == OK
    if not last_record_save_ok:
        push_warning("R135 challenge record could not be saved on this device")

func start_challenge() -> void:
    mission_active = false
    mission_completed = false
    challenge_attempts += 1
    challenge_fault_index = (challenge_attempts - 1) % FAULT_TYPES.size()
    case_attempts[challenge_fault_index] = mini(case_attempts[challenge_fault_index] + 1, 1000000)
    _save_challenge_record()
    challenge_active = true
    challenge_completed = false
    challenge_step = 0
    challenge_elapsed = 0.0
    challenge_errors = 0
    challenge_score = 0
    challenge_feedback = "SIMULATED FAULT FOUND: " + FAULT_TYPES[challenge_fault_index]
    _reset_simulated_hatch()
    motion_enabled = true

func challenge_goal() -> String:
    if challenge_completed:
        return "DIAGNOSTIC COMPLETE — SCORE %d / 150" % challenge_score
    if not challenge_active:
        return "OPTIONAL CHALLENGE: 3 FAULT SCENARIOS"
    return "FAULT %d/3 | STEP %d/5: %s" % [
        challenge_fault_index + 1, challenge_step + 1, CHALLENGE_GOALS[challenge_step]
    ]

func _challenge_penalty(message: String) -> void:
    if not challenge_active:
        return
    challenge_errors += 1
    case_total_mistakes[challenge_fault_index] = mini(
        case_total_mistakes[challenge_fault_index] + 1, 1000000
    )
    _save_challenge_record()
    challenge_feedback = message + "  /  PENALTY %d" % challenge_errors

func _challenge_event(action: String, selected_view: int = -1) -> void:
    if not challenge_active or challenge_completed:
        return
    if action != CHALLENGE_ACTIONS[challenge_step]:
        _challenge_penalty("WRONG ORDER — " + CHALLENGE_GOALS[challenge_step])
        return
    if action == "scan":
        if motion_enabled or lid_target < 0.5 or lid_progress < 0.95:
            _challenge_penalty("WAIT FOR THE STOPPED, OPEN HATCH")
            return
        var required_view: int = FAULT_VIEWS[challenge_fault_index]
        if selected_view != required_view:
            _challenge_penalty("INCORRECT VIEW — TARGET VIEW %d" % required_view)
            return
    challenge_step += 1
    challenge_feedback = "CHECKPOINT %d/5 CLEARED" % challenge_step
    if challenge_step == CHALLENGE_GOALS.size():
        challenge_active = false
        challenge_completed = true
        challenge_score = clampi(150 - int(ceil(challenge_elapsed * 3.0)) - 12 * challenge_errors, 0, 150)
        if challenge_score > challenge_best_score:
            challenge_best_score = challenge_score
        cleared_cases[challenge_fault_index] = true
        case_best_scores[challenge_fault_index] = maxi(
            case_best_scores[challenge_fault_index], challenge_score
        )
        if case_best_seconds[challenge_fault_index] < 0.0 or challenge_elapsed < case_best_seconds[challenge_fault_index]:
            case_best_seconds[challenge_fault_index] = challenge_elapsed
        _save_challenge_record()
        challenge_feedback = "FAULT CLEARED — BEST SCORE %d" % challenge_best_score

func scan_diagnostic(view_index: int) -> void:
    if not challenge_active:
        challenge_feedback = "START DIAGNOSTICS TO SCAN A TARGET"
        return
    _challenge_event("scan", view_index)

func set_motion(active: bool) -> void:
    if motion_enabled == active:
        return
    # The drive never restarts with an unlocked or physically moving hatch,
    # regardless of training mode. Mission and diagnostic scenarios must
    # finish their ordered checkpoints before simulated power is restored.
    if active and (lid_target > 0.05 or lid_progress > 0.05):
        _challenge_penalty("SAFETY INTERLOCK: SEAL THE HATCH BEFORE STARTING")
        if mission_active:
            mission_feedback = "SAFETY INTERLOCK: WAIT UNTIL HATCH SEALED"
        return
    if active and challenge_active and challenge_step != 4:
        _challenge_penalty("SAFETY INTERLOCK: COMPLETE DIAGNOSTIC FIRST")
        return
    if active and mission_active and mission_step != 3:
        mission_feedback = "SAFETY INTERLOCK: COMPLETE MAINTENANCE FIRST"
        return
    motion_enabled = active
    _challenge_event("resume" if active else "pause")
    _mission_event("resume" if active else "pause")

func toggle_access_lid() -> void:
    if lid_target < 0.5 and motion_enabled:
        _challenge_penalty("SAFETY INTERLOCK: STOP DRIVE BEFORE OPENING")
        if mission_active:
            mission_feedback = "SAFETY INTERLOCK: STOP DRIVE BEFORE OPENING"
        return
    lid_target = 1.0-lid_target
    manual_inspections += 1
    var action: String = "open" if lid_target > 0.5 else "close"
    _challenge_event(action)
    _mission_event(action)

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
    if mission_active:
        mission_elapsed += step
    if challenge_active:
        challenge_elapsed += step
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
        status_beacons[i].visible = quality >= 1 or challenge_active or challenge_completed
        status_beacons[i].light_color = Color(0.23, 0.85, 0.51) if challenge_completed else Color(0.91, 0.40, 0.15)
        status_beacons[i].light_energy = (.17+.13*(.5+.5*sin(elapsed*1.9+float(i)*PI))) if motion_enabled else .09
    if visual_faults != null:
        visual_faults.call("update_visuals", challenge_fault_index, challenge_active, challenge_completed, challenge_step, challenge_elapsed)
    if scene_label != null and (challenge_active or challenge_completed):
        scene_label.text = "R135 / " + ("SIMULATED DIAGNOSTICS" if challenge_active else "SIMULATED FAULT CLEARED")
    elif scene_label != null:
        scene_label.text = "R135 / SIMULATED SERVICE SPINE - NO LIVE DATA"

func summary() -> Dictionary:
    var visuals: Dictionary = visual_faults.call("snapshot") if visual_faults != null else {}
    var cleared_count: int = 0
    for completed in cleared_cases:
        if completed:
            cleared_count += 1
    return {"schema":"OSGARD_R135_SCENE_STATE_V1","simulation_only":true,
        "physical_telemetry_connected":false,"quality":quality,"loaded":loaded_path,
        "loading_failures":load_failures,"load_count":load_count,
        "motion_enabled":motion_enabled,"phase_seconds":fposmod(elapsed,16.0),
        "inspect_count":manual_inspections,"fan_count":fan_rotors.size(),
        "mission_active":mission_active,"mission_completed":mission_completed,
        "mission_step":mission_step,"mission_goal":mission_goal(),
        "mission_elapsed":mission_elapsed,"mission_best_seconds":mission_best_seconds,
        "mission_attempts":mission_attempts,"mission_feedback":mission_feedback,
        "lid_progress":lid_progress,"lid_target":lid_target,
        "challenge_active":challenge_active,"challenge_completed":challenge_completed,
        "challenge_step":challenge_step,"challenge_goal":challenge_goal(),
        "challenge_fault":FAULT_TYPES[challenge_fault_index],
        "challenge_fault_index":challenge_fault_index,
        "challenge_target_view":FAULT_VIEWS[challenge_fault_index],
        "challenge_elapsed":challenge_elapsed,"challenge_errors":challenge_errors,
        "challenge_score":challenge_score,"challenge_best_score":challenge_best_score,
        "challenge_evidence":FAULT_EVIDENCE[challenge_fault_index],
        "challenge_learning":FAULT_LESSONS[challenge_fault_index],
        "challenge_time_penalty":int(ceil(challenge_elapsed * 3.0)),
        "challenge_error_penalty":12 * challenge_errors,
        "cleared_case_count":cleared_count,
        "cleared_case_flags":cleared_cases.duplicate(),
        "record_schema_version":RECORD_SCHEMA_VERSION,
        "case_attempts":case_attempts.duplicate(),
        "case_best_scores":case_best_scores.duplicate(),
        "case_best_seconds":case_best_seconds.duplicate(),
        "case_total_mistakes":case_total_mistakes.duplicate(),
        "local_record_save_ok":last_record_save_ok,
        "training_status":"ALL 3 SIMULATION CASES CLEARED" if cleared_count == 3 else "SIMULATION CASES %d/3" % cleared_count,
        "challenge_feedback":challenge_feedback,
        "fault_marker_count":int(visuals.get("fault_marker_count", 0)),
        "fault_marker_visible_count":int(visuals.get("fault_marker_visible_count", 0)),
        "fault_label_visible_count":int(visuals.get("fault_label_visible_count", 0)),
        "fault_marker_active_index":int(visuals.get("fault_marker_active_index", -1)),
        "fault_visual_state":str(visuals.get("fault_visual_state", "idle")),
        "active_caption_depth_override":bool(visuals.get("active_caption_depth_override", false))}
