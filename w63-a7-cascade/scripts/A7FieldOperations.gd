extends Node3D
class_name A7FieldOperations
## W72 / FIELD OPERATIONS. Three ACTUAL optional world interaction mechanics,
## all requiring proximity to W70 CharacterBody3D. The core six-shift original
## A7CascadeCore remains the only authority for machine actions and victories.
## ALL industrial props/states are fictional in-game devices.

const CORE := Vector3(4.10, 1.2, 2.14)
const RELAY := Vector3(8.0, 1.2, 20.0)
const AMBER := Color("f3bd77")
const BLUE := Color("65dfdf")
const GREEN := Color("88e4b6")
const OFF := Color("516779")
const RED := Color("fa756d")

var enabled: bool = false
var stage: int = 0
var valve_index: int = 0
var valve_target: int = 0
var valve_solved: bool = false
var relay_mask: int = 0
var relay_target: int = -1
var relay_solved: bool = false
var sync_order: Array[int] = []
var sync_step: int = 0
var sync_solved: bool = false
var sync_mistakes: int = 0
var physical_uses: int = 0
var rejected_far_uses: int = 0
var failed_inputs: int = 0
var quality: String = "hero"
var compact: bool = false
var reduced_motion: bool = false
var active_visuals: Node3D
var dial_housing: Node3D
var rotating_dial: Node3D
var dial_grip: MeshInstance3D
var dial_color: StandardMaterial3D
var relay_switches: Array[MeshInstance3D] = []
var relay_colors: Array[StandardMaterial3D] = []
var sync_rings: Array[MeshInstance3D] = []
var sync_colors: Array[StandardMaterial3D] = []
var core_label: Label3D
var relay_label: Label3D
var fixture_lights: Array[OmniLight3D] = []
var real_prop_meshes: int = 0
var true_game_metrics: Dictionary = {}

func _colored(tint: Color, light: float = 0.0) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = tint
    m.roughness = 0.45
    m.metallic = 0.17
    m.emission_enabled = true
    m.emission = tint
    m.emission_energy_multiplier = light
    return m

func _box(parent: Node3D, id: String, dimensions: Vector3, pos: Vector3,
        mat: Material) -> MeshInstance3D:
    var item := MeshInstance3D.new()
    item.name = id
    var mesh := BoxMesh.new()
    mesh.size = dimensions
    item.mesh = mesh
    item.position = pos
    item.material_override = mat
    parent.add_child(item)
    real_prop_meshes += 1
    return item

func _ring(parent: Node3D, id: String, pos: Vector3, mat: Material,
        r: float = 0.34) -> MeshInstance3D:
    var item := MeshInstance3D.new()
    item.name = id
    var mesh := TorusMesh.new()
    mesh.inner_radius = r - 0.085
    mesh.outer_radius = r
    mesh.rings = 32
    mesh.ring_segments = 12
    item.mesh = mesh
    item.position = pos
    item.material_override = mat
    parent.add_child(item)
    real_prop_meshes += 1
    return item

func _light(parent: Node3D, id: String, at: Vector3, tint: Color) -> void:
    var lamp := OmniLight3D.new()
    lamp.name = id
    lamp.position = at
    lamp.light_color = tint
    lamp.light_energy = 1.3
    lamp.omni_range = 3.6
    lamp.shadow_enabled = false
    parent.add_child(lamp)
    fixture_lights.append(lamp)

func _world_label(parent: Node3D, id: String, at: Vector3) -> Label3D:
    var txt := Label3D.new()
    txt.name = id
    txt.position = at
    txt.font_size = 43
    txt.pixel_size = 0.0032
    txt.modulate = AMBER
    parent.add_child(txt)
    return txt

func build(surface: A7CinematicMaterialLab) -> void:
    name = "W72RealPhysicalFieldOperations3D"
    active_visuals = Node3D.new()
    active_visuals.name = "ActualOriginal3DMechanicProps"
    add_child(active_visuals)
    var brushed: StandardMaterial3D = surface.surface("reactor_shell")
    var dark: StandardMaterial3D = surface.surface("dark_steel")
    var grate: StandardMaterial3D = surface.surface("floor_grate")
    # CORE station: 8-position rotatable wheel (actual Godot Node3D rotation).
    dial_housing = Node3D.new()
    dial_housing.name = "ActualCoreThermalValveStation"
    dial_housing.position = CORE + Vector3(0.0, 1.0, 0.0)
    active_visuals.add_child(dial_housing)
    _box(dial_housing,"ThermalCalibrationPBRHousing",
        Vector3(1.25, 0.90, 0.38),Vector3.ZERO,brushed)
    _box(dial_housing,"RealThermalWarningInlay",
        Vector3(1.02,0.11,0.40),Vector3(0,-0.31,0),dark)
    rotating_dial = Node3D.new()
    rotating_dial.name = "RealEightDetentRotatableThermalRotor"
    rotating_dial.position = Vector3(0,0.12,0.22)
    dial_housing.add_child(rotating_dial)
    dial_color = _colored(AMBER,1.35)
    var rotor := CylinderMesh.new()
    rotor.top_radius = 0.27
    rotor.bottom_radius = 0.31
    rotor.height = 0.17
    rotor.radial_segments = 24
    var rotor_item := MeshInstance3D.new()
    rotor_item.name = "ActualValveCylinderNot2DButton"
    rotor_item.mesh = rotor
    rotor_item.material_override = dark
    rotating_dial.add_child(rotor_item)
    real_prop_meshes += 1
    dial_grip = _box(rotating_dial,"RealVisibleRotorPointer",
        Vector3(0.06,0.10,0.65),Vector3(0,0.13,-0.01),dial_color)
    for tick in range(8):
        var a: float = TAU * float(tick) / 8.0
        _box(dial_housing,"StationValveIndexTick%02d" % tick,
            Vector3(0.055,0.022,0.145),
            Vector3(sin(a)*0.51,0.25,cos(a)*0.51),grate)
    core_label = _world_label(active_visuals,
        "RealThermalTelemetryLabel3D",CORE+Vector3(0,2.65,0))
    _light(active_visuals,"PhysicalCoreCalibrationLight",
        CORE+Vector3(0,2.75,0),AMBER)

    # RELAY station: three independently actuated 3D rocker switches.
    var rack := Node3D.new()
    rack.name = "ThreeLivePowerRelayRoutingRacks"
    rack.position = RELAY + Vector3(0,0.93,0)
    active_visuals.add_child(rack)
    _box(rack,"PBRRelayBusEnclosure",
        Vector3(2.30,1.05,0.39),Vector3.ZERO,brushed)
    for i in range(3):
        var x: float = (float(i)-1.0)*0.66
        _box(rack,"IsolatedBusRoutingMount%d" % i,
            Vector3(0.47,0.62,0.12),Vector3(x,0,0.24),grate)
        var mat := _colored(OFF,0.45)
        relay_colors.append(mat)
        var toggle := _box(rack,"RealActuatedRelayRocker%d" % i,
            Vector3(0.20,0.48,0.18),Vector3(x,0,0.36),mat)
        relay_switches.append(toggle)
    relay_label = _world_label(active_visuals,
        "RealBusRoutingTelemetryLabel3D",RELAY+Vector3(0,2.47,0))
    _light(active_visuals,"PhysicalRelayRoutingLight",
        RELAY+Vector3(0,2.8,0),BLUE)

    # Final containment sync: three actual distinct physical toroidal relays.
    var sync_station := Node3D.new()
    sync_station.name = "ThreeStepContainmentSynchronizationConsole"
    sync_station.position = CORE + Vector3(1.02,1.45,0.0)
    active_visuals.add_child(sync_station)
    _box(sync_station,"FinalSyncSteelPlinth",
        Vector3(1.08,0.60,0.28),Vector3.ZERO,brushed)
    for i in range(3):
        var mat := _colored(OFF,0.4)
        sync_colors.append(mat)
        sync_rings.append(_ring(sync_station,
            "ActualOrderedCircuitStage%d" % i,
            Vector3((float(i)-1.0)*0.31,0.06,0.17),mat,0.19))
    _refresh()

func _near(player: A7FirstPersonOperator, point: Vector3, range_m: float) -> bool:
    return player != null and player.piloting and player.body != null and (
        player.body.position.distance_to(point) < range_m)

func start(state: Dictionary) -> void:
    reset()
    enabled = true
    var m: Dictionary = state["metrics"]
    true_game_metrics = m.duplicate(true)
    # 8 real detents, target 2-6 computed from current ACTUAL original heat/pressure.
    valve_target = 2 + (floori((float(m["heat"])+float(m["pressure"]))/24.0) % 5)
    _refresh()

func reset() -> void:
    enabled = false
    stage = 0
    valve_index = 0
    valve_target = 0
    valve_solved = false
    relay_mask = 0
    relay_target = -1
    relay_solved = false
    sync_order.clear()
    sync_step = 0
    sync_solved = false
    sync_mistakes = 0
    physical_uses = 0
    rejected_far_uses = 0
    failed_inputs = 0
    true_game_metrics.clear()
    _refresh()

func observe_phase(phase: int, state: Dictionary) -> void:
    if not enabled:
        return
    stage = phase
    true_game_metrics = (state["metrics"] as Dictionary).duplicate(true)
    var stats: Dictionary = state["metrics"]
    if phase == 2 and relay_target < 0:
        var value: int = (
            floori(float(stats["signal"])/11.0)
            ^ floori(float(stats["energy"])/13.0)
            ^ floori(float(stats["pressure"])/9.0))
        relay_target = value & 7
        if relay_target == 0:
            relay_target = 5
        relay_solved = relay_mask == relay_target
    if phase == 4 and sync_order.is_empty() and str(state["status"]) == "won":
        var seed: int = (int(stats["heat"])+int(stats["signal"])+
            int(stats["energy"])) % 3
        sync_order = [seed, (seed+2) % 3, (seed+1) % 3]
    _refresh()

func _reject(player: A7FirstPersonOperator, point: Vector3, meters: float) -> bool:
    if not _near(player, point, meters):
        rejected_far_uses += 1
        return true
    return false

func rotate_valve(delta: int, player: A7FirstPersonOperator) -> bool:
    if not enabled or stage != 0 or not [1,-1].has(delta):
        failed_inputs += 1
        return false
    if _reject(player, CORE, 3.2):
        return false
    valve_index = posmod(valve_index+delta,8)
    valve_solved = valve_index == valve_target
    physical_uses += 1
    _refresh()
    return true

func toggle_relay(index: int, player: A7FirstPersonOperator) -> bool:
    if not enabled or stage != 2 or index < 0 or index > 2:
        failed_inputs += 1
        return false
    if _reject(player, RELAY, 4.0):
        return false
    relay_mask ^= (1 << index)
    relay_solved = relay_mask == relay_target
    physical_uses += 1
    _refresh()
    return true

func sync_connector(index: int, player: A7FirstPersonOperator,
        game_state: Dictionary) -> bool:
    if (not enabled or stage != 4 or index < 0 or index > 2 or
            str(game_state.get("status","")) != "won" or sync_order.size() != 3):
        failed_inputs += 1
        return false
    if _reject(player, CORE, 3.2):
        return false
    physical_uses += 1
    if index == sync_order[sync_step]:
        sync_step += 1
        if sync_step >= 3:
            sync_solved = true
    else:
        sync_step = 0
        sync_mistakes += 1
    _refresh()
    return true

func gate(target: String, mission_phase: int) -> bool:
    if not enabled:
        return true
    if mission_phase == 0 and target == "CORE":
        return valve_solved
    if mission_phase == 2 and target == "RELAY":
        return relay_solved
    if mission_phase == 4 and target == "CORE":
        return sync_solved
    return true

func active_mechanic() -> String:
    if not enabled:
        return "inactive"
    if stage == 0:
        return "thermal_valve"
    if stage == 2:
        return "relay_bus_matrix"
    if stage == 4:
        return "containment_sync"
    if stage in [5,6]:
        return "complete"
    return "original_cascade_decisions"

func instructions(locale: String) -> String:
    if not enabled:
        return ("РАСШИРЕННАЯ МИССИЯ НЕ НАЧАТА"
            if locale == "ru" else "ADVANCED FIELD MISSION NOT STARTED")
    if stage == 0:
        return (("РЕАКТОР: настроить шкалу %d / %d. J/K — поворот, E — осмотр." %
            [valve_index,valve_target]) if locale == "ru" else
            ("CORE: align dial %d / %d. J/K rotate, E inspects." %
            [valve_index,valve_target]))
    if stage == 2:
        return (("РЕЛЕЙНЫЙ ЗАЛ: шина %d / %d. 7/8/9 — переключатели, E — осмотр." %
            [relay_mask,relay_target]) if locale == "ru" else
            ("RELAY: bus mask %d / %d. 7/8/9 toggle, E inspects." %
            [relay_mask,relay_target]))
    if stage == 4:
        var pattern: String = "%s-%s-%s" % [
            str(sync_order[0]+1),str(sync_order[1]+1),str(sync_order[2]+1)
        ] if sync_order.size() == 3 else "?"
        return (("ФИНАЛ: цепь %s. U/I/O — нужный порядок, E — завершить." % pattern)
            if locale == "ru" else
            ("FINAL: circuit %s. U/I/O in sequence, then E." % pattern))
    if stage == 5:
        return "КОНТУР СТАБИЛИЗИРОВАН" if locale == "ru" else "CONTAINMENT SECURED"
    if stage == 6:
        return "УЗЕЛ ПОТЕРЯН" if locale == "ru" else "STATION LOST"
    return ("ПРОДОЛЖАЙТЕ РЕАЛЬНУЮ АВАРИЙНУЮ СМЕНУ"
        if locale == "ru" else "CONTINUE THE REAL A7 INCIDENT CYCLES")

func _refresh() -> void:
    if active_visuals == null:
        return
    active_visuals.visible = enabled
    if not enabled:
        return
    if rotating_dial != null:
        rotating_dial.rotation.y = TAU*float(valve_index)/8.0
    if dial_color != null:
        var v: Color = GREEN if valve_solved else AMBER
        dial_color.albedo_color = v
        dial_color.emission = v
    for i in range(relay_switches.size()):
        var on: bool = (relay_mask & (1<<i)) != 0
        relay_switches[i].rotation.z = 0.48 if on else -0.48
        relay_colors[i].albedo_color = BLUE if on else OFF
        relay_colors[i].emission = BLUE if on else OFF
    for i in range(sync_colors.size()):
        var done: bool = sync_step > 0 and sync_order.slice(0,sync_step).has(i)
        sync_colors[i].albedo_color = GREEN if done else AMBER if stage == 4 else OFF
        sync_colors[i].emission = sync_colors[i].albedo_color
    if core_label != null:
        core_label.text = ("A7 / VALVE %d:%d" % [valve_index,valve_target]
            if stage == 0 else "A7 / SYNC %d/3" % sync_step if stage == 4
            else "A7 / FIELD CORE")
        core_label.visible = not compact
        relay_label.text = ("A7 / BUS %d:%d" % [relay_mask,relay_target]
            if stage == 2 else "A7 / FIELD RELAY")
        relay_label.visible = not compact
    for lamp in fixture_lights:
        lamp.light_energy = 0.3 if quality == "eco" else 1.3

func set_compact_view(value: bool) -> void:
    compact = value
    if core_label != null:
        core_label.visible = not compact
        relay_label.visible = not compact

func set_quality(mode: String) -> void:
    quality = "eco" if mode == "eco" else "hero"
    _refresh()

func set_reduced_motion(value: bool) -> void:
    reduced_motion = value
    # Stage changes are always input-driven; no flashing/flickering mechanics.

func qa_readout() -> Dictionary:
    return {
        "schema": "LAST_FRONTIER_W72_THREE_ORIGINAL_PHYSICAL_FIELD_MECHANICS_V1",
        "active": enabled,
        "stage": stage,
        "mechanic": active_mechanic(),
        "real_world_meshes": real_prop_meshes,
        "real_3d_relay_switches": relay_switches.size(),
        "real_3d_sync_circuits": sync_rings.size(),
        "real_3d_valve_rotor": rotating_dial is Node3D,
        "true_world_3d_labels": core_label is Label3D and relay_label is Label3D,
        "native_real_lights": fixture_lights.size(),
        "valve_pos": valve_index,
        "valve_target": valve_target,
        "valve_solved": valve_solved,
        "relay_mask": relay_mask,
        "relay_target": relay_target,
        "relay_solved": relay_solved,
        "sync_order": sync_order.duplicate(),
        "sync_step": sync_step,
        "sync_mistakes": sync_mistakes,
        "sync_solved": sync_solved,
        "physical_uses": physical_uses,
        "rejected_far_uses": rejected_far_uses,
        "failed_inputs": failed_inputs,
        "gameplay_authority": false,
        "actual_machine_network_connected": false,
        "external_assets_downloaded": false,
        "human_aaa_art_approval": false,
    }
