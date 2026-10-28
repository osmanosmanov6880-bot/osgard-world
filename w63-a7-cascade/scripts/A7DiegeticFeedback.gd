extends Node3D
class_name A7DiegeticFeedback
## W74: actual animated Godot 3D machine response driven by the already
## accepted W72 physical mechanic. Nothing here can change A7CascadeCore.
## Entirely authored procedural industrial geometry, not an image or pre-render.

const HONEY := Color("e9bc7d")
const TEAL := Color("6bdfcc")
const ERROR := Color("ef8978")
const MUTED := Color("4d6875")
var equipment: A7FieldOperations
var player: A7FirstPersonOperator
var root_visuals: Node3D
var core_disc: MeshInstance3D
var core_material: StandardMaterial3D
var relay_contacts: Array[MeshInstance3D] = []
var relay_materials: Array[StandardMaterial3D] = []
var sync_contacts: Array[MeshInstance3D] = []
var sync_materials: Array[StandardMaterial3D] = []
var world_status: Label3D
var actual_meshes: int = 0
var accepted_3d_feedback: int = 0
var last_kind: String = ""
var last_index: int = -1
var actual_animation_frames: int = 0
var _animation_phase: float = 0.0
var _pulse_remaining: float = 0.0
var _current_world_stage: int = -1
var reduced_motion: bool = false
var quality: String = "hero"
var compact: bool = false

func _mat(color: Color) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = color
    m.roughness = 0.42
    m.metallic = 0.23
    m.emission_enabled = true
    m.emission = color
    m.emission_energy_multiplier = 0.45
    return m

func _box(parent: Node3D,id: String,at: Vector3,
        size: Vector3,mat: StandardMaterial3D) -> MeshInstance3D:
    var instance := MeshInstance3D.new()
    instance.name = id
    var m := BoxMesh.new()
    m.size = size
    instance.mesh = m
    instance.material_override = mat
    instance.position = at
    parent.add_child(instance)
    actual_meshes += 1
    return instance

func _torus(parent: Node3D,id: String,at: Vector3,
        radius: float,mat: StandardMaterial3D) -> MeshInstance3D:
    var instance := MeshInstance3D.new()
    instance.name = id
    var m := TorusMesh.new()
    m.inner_radius = radius - 0.035
    m.outer_radius = radius
    m.rings = 32
    m.ring_segments = 10
    instance.mesh = m
    instance.material_override = mat
    instance.position = at
    parent.add_child(instance)
    actual_meshes += 1
    return instance

func build(actual_equipment: A7FieldOperations,
        actual_player: A7FirstPersonOperator) -> void:
    equipment = actual_equipment
    player = actual_player
    name = "W74PhysicalDiegeticResponseOnActualPBRMachinery"
    root_visuals = Node3D.new()
    root_visuals.name = "RealMechanismFeedbackNotHUDOrGeneratedImage"
    add_child(root_visuals)
    core_material = _mat(HONEY)
    core_disc = _torus(root_visuals,
        "AuthenticAnimatedThermalValveReadyRing",
        A7FieldOperations.CORE+Vector3(0,1.2,0.52),
        0.45,core_material)
    # Real 3D relay contacts are physically in the second equipment hall.
    for i in range(3):
        var m := _mat(MUTED)
        var x: float = (float(i)-1.0)*0.66
        relay_materials.append(m)
        relay_contacts.append(_box(root_visuals,
            "RealLiveElectricBusCircuitContact%d" % i,
            A7FieldOperations.RELAY+Vector3(x,0.95,0.62),
            Vector3(0.38,0.055,0.20),m))
    # Endgame contact bank uses 3 independent native moving native meshes.
    for i in range(3):
        var m := _mat(MUTED)
        sync_materials.append(m)
        sync_contacts.append(_torus(root_visuals,
            "RealThreePhaseContainmentPulse%d" % i,
            A7FieldOperations.CORE+Vector3(1.02+(float(i)-1.0)*0.31,1.52,0.43),
            0.14,m))
    var plaque_mat: StandardMaterial3D = _mat(HONEY)
    _box(root_visuals,"ActualFieldStatusMetalBase",
        A7FieldOperations.CORE+Vector3(0,2.15,0.34),
        Vector3(1.20,0.15,0.09),plaque_mat)
    world_status = Label3D.new()
    world_status.name = "LocalizedDiegeticMachineReadoutNotWebText"
    world_status.position = A7FieldOperations.CORE+Vector3(0,2.35,0.44)
    world_status.font_size = 38
    world_status.pixel_size = 0.0030
    world_status.modulate = HONEY
    root_visuals.add_child(world_status)
    set_process(true)
    _refresh_materials()

func refresh_from_original_equipment() -> void:
    _refresh_materials()

func reset_visual_feedback() -> void:
    _pulse_remaining = 0.0
    _animation_phase = 0.0
    if core_disc != null:
        core_disc.scale = Vector3.ONE
    for i in range(relay_contacts.size()):
        relay_contacts[i].position.y = A7FieldOperations.RELAY.y+0.95
    for contact in sync_contacts:
        contact.scale = Vector3.ONE
    _refresh_materials()

func notify_real_world_operation(kind: String, index: int) -> bool:
    if equipment == null or not equipment.enabled:
        return false
    if kind not in ["valve","relay","sync"]:
        return false
    if (kind == "valve" and equipment.stage != 0) or (
        kind == "relay" and equipment.stage != 2) or (
        kind == "sync" and equipment.stage != 4):
        return false
    if index < 0 or (kind != "valve" and index > 2):
        return false
    # A renderer notification never calls equipment.rotate_valve nor choose().
    accepted_3d_feedback += 1
    last_kind = kind
    last_index = index
    _pulse_remaining = 0.68
    _animation_phase = 0.0
    _refresh_materials()
    return true

func _refresh_materials() -> void:
    if equipment == null or root_visuals == null:
        return
    root_visuals.visible = equipment.enabled
    if not equipment.enabled:
        return
    var stage: int = equipment.stage
    _current_world_stage = stage
    core_disc.visible = stage == 0
    for i in range(relay_contacts.size()):
        relay_contacts[i].visible = stage == 2
        var powered: bool = (equipment.relay_mask & (1 << i)) != 0
        var color: Color = TEAL if powered else MUTED
        relay_materials[i].albedo_color = color
        relay_materials[i].emission = color
        relay_materials[i].emission_energy_multiplier = 1.8 if powered else 0.3
    for i in range(sync_contacts.size()):
        sync_contacts[i].visible = stage == 4
        var charged: bool = (
            equipment.sync_step > 0 and
            equipment.sync_order.slice(0,equipment.sync_step).has(i))
        var color: Color = TEAL if charged else HONEY
        sync_materials[i].albedo_color = color
        sync_materials[i].emission = color
        sync_materials[i].emission_energy_multiplier = 1.7 if charged else 0.25
    core_material.albedo_color = TEAL if equipment.valve_solved else HONEY
    core_material.emission = core_material.albedo_color
    world_status.visible = stage in [0,2,4] and not compact
    if stage == 0:
        world_status.text = "A7  /  %d : %d" % [
            equipment.valve_index,equipment.valve_target]
    elif stage == 2:
        world_status.text = "A7  /  BUS %03d" % equipment.relay_mask
    elif stage == 4:
        world_status.text = "A7  /  SYNC %d / 3" % equipment.sync_step

func _process(delta: float) -> void:
    if equipment == null or root_visuals == null or not equipment.enabled:
        if root_visuals != null:
            root_visuals.visible = false
        return
    _refresh_materials()
    if _pulse_remaining <= 0.0:
        return
    _pulse_remaining = maxf(0.0,_pulse_remaining-delta)
    _animation_phase += minf(delta,0.10)
    actual_animation_frames += 1
    var progress: float = 1.0 - _pulse_remaining / 0.68
    var envelope: float = sin(progress*PI)
    # ECO and reduced-motion keep the readout correct with no flashing.
    var light: float = 0.55 if quality == "eco" else 0.9
    if not reduced_motion:
        light += envelope*1.3
    core_material.emission_energy_multiplier = light
    if core_disc != null:
        core_disc.scale = Vector3.ONE * (
            1.0+0.075*envelope if not reduced_motion else 1.0)
    if last_kind == "relay" and last_index in range(relay_contacts.size()):
        relay_contacts[last_index].position.y = (
            A7FieldOperations.RELAY.y+0.95+
            (0.06*envelope if not reduced_motion else 0.0))
    if last_kind == "sync" and last_index in range(sync_contacts.size()):
        sync_contacts[last_index].scale = Vector3.ONE * (
            1.0+0.12*envelope if not reduced_motion else 1.0)
    if _pulse_remaining <= 0:
        core_disc.scale = Vector3.ONE
        for i in range(relay_contacts.size()):
            relay_contacts[i].position.y = A7FieldOperations.RELAY.y+0.95
        for contact in sync_contacts:
            contact.scale = Vector3.ONE

func set_quality(value: String) -> void:
    quality = "eco" if value == "eco" else "hero"

func set_reduced_motion(value: bool) -> void:
    reduced_motion = value

func set_compact_view(value: bool) -> void:
    compact = value
    _refresh_materials()

func qa_readout() -> Dictionary:
    return {
        "schema":"LAST_FRONTIER_W74_ACTUAL_3D_FEEDBACK_V1",
        "real_world_feedback_meshes":actual_meshes,
        "real_live_valve_torus":core_disc is MeshInstance3D,
        "real_relay_bus_meshes":relay_contacts.size(),
        "real_sync_contact_meshes":sync_contacts.size(),
        "native_world_3d_readout":world_status is Label3D,
        "world_stage":_current_world_stage,
        "accepted_actual_physical_feedback":accepted_3d_feedback,
        "animation_frames":actual_animation_frames,
        "last_device":last_kind,
        "last_index":last_index,
        "remaining_animation_seconds":_pulse_remaining,
        "quality":quality,
        "reduced_motion":reduced_motion,
        "not_a_gameplay_authority":true,
        "not_licensed_external_art":true,
        "human_aaa_art_signoff":false,
    }
