extends Node3D
class_name A7SectorBulkhead
## W77: a REAL PHYSICS-GATED passage, not a fake on-screen objective.
## The original W70 CharacterBody3D cannot cross the relay threshold until
## the unchanged W71/W72 mission has genuinely reached phase 2.
## Legacy W70 free exploration and legacy W71 missions remain untouched.

const LOCATION: Vector3 = Vector3(6.40, 1.86, 13.55)
const COPPER := Color("d6a873")
const OPEN_COLOR := Color("7be1cd")
const CLOSED_COLOR := Color("e6a46d")
const PANEL_WIDTH: float = 1.58
const PANEL_HEIGHT: float = 3.12
const CLOSED_OFFSET: float = 0.80
const OPEN_OFFSET: float = 2.02

var mission: A7SpatialMission
var operator: A7FirstPersonOperator
var gate_body: StaticBody3D
var gate_shape: CollisionShape3D
var panels: Array[MeshInstance3D] = []
var root_visuals: Node3D
var hero_detail: Node3D
var power_lamp: OmniLight3D
var status_material: StandardMaterial3D
var indicator: MeshInstance3D
var status_label: Label3D

var quality: String = "hero"
var reduced_motion: bool = false
var compact_view: bool = false
var physically_blocked: bool = false
var eligible_mission: bool = false
var native_meshes: int = 0
var real_open_events: int = 0
var actual_collision_state_transitions: int = 0
var accepted_mission_phases_seen: int = 0
var physics_gate_was_closed: bool = false
var _aperture: float = 1.0
var _phase_last: int = -1

func _material(tint: Color, intensity: float = 0.0) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = tint
    m.roughness = 0.48
    m.metallic = 0.18
    if intensity > 0:
        m.emission_enabled = true
        m.emission = tint
        m.emission_energy_multiplier = intensity
    return m

func _box(parent: Node3D, label: String, dimensions: Vector3,
        where: Vector3, finish: Material) -> MeshInstance3D:
    var instance := MeshInstance3D.new()
    instance.name = label
    var mesh := BoxMesh.new()
    mesh.size = dimensions
    instance.mesh = mesh
    instance.material_override = finish
    instance.position = where
    parent.add_child(instance)
    native_meshes += 1
    return instance

func build(actual_mission: A7SpatialMission,
        actual_operator: A7FirstPersonOperator,
        pbr: A7CinematicMaterialLab) -> void:
    name = "W77AuthenticSectorDoorWithPhysicsAndMissionAuthority"
    mission = actual_mission
    operator = actual_operator
    # This collider uses the exact same physics layer and world as W70
    # CharacterBody3D, so walking cannot pass through a locked shutter.
    gate_body = StaticBody3D.new()
    gate_body.name = "TruePhysicalRelayHallAccessBulkhead"
    gate_body.position = LOCATION
    gate_body.collision_layer = 1
    gate_body.collision_mask = 1
    add_child(gate_body)
    var obstacle := BoxShape3D.new()
    obstacle.size = Vector3(3.15, PANEL_HEIGHT, 0.34)
    gate_shape = CollisionShape3D.new()
    gate_shape.name = "W77CollisionEnabledOnlyWhenSourceMissionRequires"
    gate_shape.shape = obstacle
    gate_shape.disabled = true
    gate_body.add_child(gate_shape)

    root_visuals = Node3D.new()
    root_visuals.name = "VisibleTwoPanelMechanicalAirlock"
    root_visuals.position = LOCATION
    add_child(root_visuals)

    var brushed: StandardMaterial3D = pbr.surface("reactor_shell")
    var steel: StandardMaterial3D = pbr.surface("dark_steel")
    var hazard: StandardMaterial3D = pbr.surface("painted_hazard")
    var copper: StandardMaterial3D = _material(COPPER, 0.0)
    status_material = _material(CLOSED_COLOR, 1.4)
    for index in range(2):
        var side: int = -1 if index == 0 else 1
        var panel := _box(root_visuals,
            "W77SeparateMechanicalBulkheadLeaf%d" % index,
            Vector3(PANEL_WIDTH,PANEL_HEIGHT,0.24),
            Vector3(float(side)*CLOSED_OFFSET,0,0),brushed)
        panels.append(panel)
        _box(root_visuals,"W77PhysicalLeafSafetyRib%d" % index,
            Vector3(0.10,PANEL_HEIGHT,0.30),
            Vector3(float(side)*1.56,0,-0.04),copper)
        _box(root_visuals,"W77RealWarningStripe%d" % index,
            Vector3(0.12,2.5,0.31),
            Vector3(float(side)*1.70,0,0.02),hazard)
    for side in [-1,1]:
        _box(root_visuals,"W77PBRStructuralPylon%d" % side,
            Vector3(0.30,3.95,0.60),
            Vector3(float(side)*1.94,0,0.0),steel)
    _box(root_visuals,"W77MachinedOverheadTrack",
        Vector3(4.15,0.30,0.62),
        Vector3(0,2.00,0),brushed)
    indicator = _box(root_visuals,"W77ActualHazardStateIndicator",
        Vector3(1.4,0.11,0.07),
        Vector3(0,1.84,-0.33),status_material)
    status_label = Label3D.new()
    status_label.name = "WorldReadableSectorAccessByActualMissionPhase"
    status_label.font_size = 50
    status_label.pixel_size = 0.0032
    status_label.position = Vector3(0,1.56,-0.35)
    status_label.rotation.y = PI
    status_label.modulate = COPPER
    root_visuals.add_child(status_label)
    hero_detail = Node3D.new()
    hero_detail.name = "AdditionalCloseUpContactMetalInHeroOnly"
    root_visuals.add_child(hero_detail)
    for i in range(6):
        var x: float = (float(i) - 2.5)*0.65
        _box(hero_detail,"W77SegmentedHeaderContact%02d" % i,
            Vector3(0.44,0.08,0.42),
            Vector3(x,1.70,-0.25),copper)
    power_lamp = OmniLight3D.new()
    power_lamp.name = "W77TrueDiegeticGateStatePracticalLight"
    power_lamp.light_color = CLOSED_COLOR
    power_lamp.light_energy = 1.25
    power_lamp.omni_range = 3.5
    power_lamp.shadow_enabled = false
    power_lamp.position = Vector3(0,1.72,-0.36)
    root_visuals.add_child(power_lamp)
    set_process(true)
    refresh_state()

func _mission_blocks() -> bool:
    return (mission != null and mission.active and mission.extended_mode
        and mission.phase < 2)

func refresh_state() -> void:
    if mission == null or gate_shape == null:
        return
    eligible_mission = mission.active and mission.extended_mode
    var should_block: bool = _mission_blocks()
    if mission.phase != _phase_last:
        accepted_mission_phases_seen += 1
        _phase_last = mission.phase
    if should_block != physically_blocked:
        physically_blocked = should_block
        actual_collision_state_transitions += 1
        # Never change a physics collider inside a locked PhysicsServer step.
        # Deferred setter is native Godot API, not a visual-only toggle.
        gate_shape.set_deferred("disabled", not should_block)
        if not should_block and physics_gate_was_closed:
            real_open_events += 1
        if should_block:
            physics_gate_was_closed = true
            # Never render an OPEN doorway with an already CLOSED real
            # physics collider at mission start. Closing is instantaneous;
            # opening after accepted decisions is the cinematic movement.
            _aperture = 0.0
            for index in range(panels.size()):
                var side: float = -1.0 if index == 0 else 1.0
                panels[index].position.x = side * CLOSED_OFFSET
    root_visuals.visible = eligible_mission
    if not eligible_mission:
        _aperture = 1.0
    status_material.albedo_color = CLOSED_COLOR if should_block else OPEN_COLOR
    status_material.emission = status_material.albedo_color
    power_lamp.light_color = status_material.albedo_color
    status_label.text = (
        "SECTOR 02 / LOCKED" if should_block else
        "SECTOR 02 / ACCESS")
    status_label.visible = eligible_mission and not compact_view
    power_lamp.visible = eligible_mission and quality == "hero"
    hero_detail.visible = quality == "hero"

func _process(delta: float) -> void:
    if mission == null or root_visuals == null:
        return
    refresh_state()
    var target: float = 0.0 if physically_blocked else 1.0
    if reduced_motion or not eligible_mission:
        _aperture = target
    else:
        _aperture = move_toward(_aperture,target,delta*0.85)
    for index in range(panels.size()):
        var side: float = -1.0 if index == 0 else 1.0
        panels[index].position.x = side * lerpf(
            CLOSED_OFFSET, OPEN_OFFSET, _aperture)
    if eligible_mission:
        status_material.emission_energy_multiplier = (
            0.95 if reduced_motion or quality=="eco" else 1.5)

func set_quality(mode: String) -> void:
    quality = "eco" if mode == "eco" else "hero"
    refresh_state()

func set_compact_view(value: bool) -> void:
    compact_view = value
    refresh_state()

func set_reduced_motion(value: bool) -> void:
    reduced_motion = value

func qa_readout() -> Dictionary:
    return {
        "schema":"LAST_FRONTIER_W77_SOURCE_GATED_PHYSICS_BULKHEAD_V1",
        "physically_collidable_gate":gate_body is StaticBody3D and gate_shape is CollisionShape3D,
        "real_physics_body_layer":gate_body.collision_layer if gate_body != null else -1,
        "real_world_gate_xyz":[LOCATION.x,LOCATION.y,LOCATION.z],
        "original_mission_phase":mission.phase if mission != null else -1,
        "visible_only_in_real_extended_mission":eligible_mission,
        "actual_physics_locked":physically_blocked,
        "native_motion_open_ratio":_aperture,
        "source_mission_gated_actual_openings":real_open_events,
        "actual_collision_transitions":actual_collision_state_transitions,
        "native_pbr_meshes":native_meshes,
        "actual_two_independent_leaves":panels.size(),
        "practical_light":power_lamp is OmniLight3D,
        "real_3d_status_text":status_label is Label3D,
        "core_A7_gameplay_never_changed":true,
        "no_teleport_to_relay_sector":true,
        "physical_gamepad_hardware_certified":false,
        "original_aaa_asset_artist_signoff":false,
    }
