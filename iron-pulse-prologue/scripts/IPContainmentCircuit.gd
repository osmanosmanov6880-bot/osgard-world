extends Node3D
class_name IPContainmentCircuit
## IRON PULSE V9 — three REAL 3D operator coils across the existing world.
## Optional scenario-dependent route puzzle, physical status indicators.
## The rendering observes IPCrisisEngine; it cannot alter game resources.

const COIL_POSITIONS := {
    "alpha":Vector3(4.5,1.0,-19.0),
    "beta":Vector3(-4.5,1.0,-32.5),
    "gamma":Vector3(4.5,1.0,-50.0)
}
const COIL_IDS: Array[String] = ["alpha","beta","gamma"]

var terminals: Array[Dictionary] = []
var _inactive: StandardMaterial3D
var _ready: StandardMaterial3D
var _charged: StandardMaterial3D
var _online: StandardMaterial3D
var _industrial: StandardMaterial3D
var _dark: StandardMaterial3D
var _state: String = "offline"
var _quality: String = "hero"
var _active_count: int = 0
var _elapsed: float = 0.0
var _updated: bool = false
var hub_light: OmniLight3D

func _ready() -> void:
    name = "A7_ContainmentCoilNetwork"
    _make_materials()
    for id in COIL_IDS:
        _build_coil(id)
    hub_light = OmniLight3D.new()
    hub_light.name = "LiveStabilizationHubLight"
    hub_light.position = Vector3(9.0,7.2,-20.5)
    hub_light.light_color = Color(0.28,0.95,0.72)
    hub_light.omni_range = 11.0
    hub_light.light_energy = 0.72
    hub_light.shadow_enabled = false
    hub_light.visible = false
    add_child(hub_light)

func _metal(tint: Color, metallic: float, roughness: float) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = tint
    m.metallic = metallic
    m.roughness = roughness
    return m

func _lit(tint: Color,energy: float) -> StandardMaterial3D:
    var m := _metal(tint,0.18,0.44)
    m.emission_enabled = true
    m.emission = tint
    m.emission_energy_multiplier = energy
    return m

func _make_materials() -> void:
    _industrial = _metal(Color(0.26,0.33,0.37),0.81,0.49)
    _dark = _metal(Color(0.055,0.079,0.092),0.49,0.72)
    _inactive = _lit(Color(0.15,0.33,0.39),0.25)
    _ready = _lit(Color(0.98,0.53,0.22),0.88)
    _charged = _lit(Color(0.16,0.79,0.91),1.08)
    _online = _lit(Color(0.27,0.94,0.69),1.15)

func _box(parent: Node3D,label: String,loc: Vector3,size: Vector3,m: Material) -> MeshInstance3D:
    var item := MeshInstance3D.new()
    item.name = label
    var cube := BoxMesh.new()
    cube.size = size
    item.mesh = cube
    item.position = loc
    item.material_override = m
    parent.add_child(item)
    return item

func _build_coil(id: String) -> void:
    # Compact wall-mounted industrial controller. No collision changes to
    # old corridor, exit, player or any existing six + three terminals.
    var panel := Node3D.new()
    panel.name = "ContainmentCoil_" + id.to_upper()
    panel.position = COIL_POSITIONS[id]
    add_child(panel)
    _box(panel,"ForgedMachineBack",Vector3.ZERO,Vector3(1.65,1.82,0.38),_industrial)
    _box(panel,"SunkenControlScreen",Vector3(0.0,0.10,0.22),Vector3(1.45,1.39,0.055),_dark)
    var indicator := _box(panel,"PowerBusStatusLED",Vector3(0.0,0.70,0.27),Vector3(1.37,0.10,0.08),_inactive)
    _box(panel,"SideHeatSink_L",Vector3(-0.78,0.0,0.24),Vector3(0.10,1.33,0.11),_industrial)
    _box(panel,"SideHeatSink_R",Vector3(0.78,0.0,0.24),Vector3(0.10,1.33,0.11),_industrial)
    var shaft := Node3D.new()
    shaft.name = "PhysicalOperatorRotaryCoil"
    shaft.position = Vector3(0.0,0.04,0.33)
    panel.add_child(shaft)
    var torus := TorusMesh.new()
    torus.inner_radius = 0.32
    torus.outer_radius = 0.39
    torus.rings = 32
    torus.ring_segments = 10
    var actuator := MeshInstance3D.new()
    actuator.name = "MachinedContainmentArmature"
    actuator.mesh = torus
    actuator.rotation_degrees.x = 90.0
    actuator.material_override = _inactive
    shaft.add_child(actuator)
    _box(shaft,"RealCoilCrossbar",Vector3(0.0,0.0,0.065),Vector3(0.53,0.07,0.08),_industrial)
    var machine := Label3D.new()
    machine.name = "DiegeticCoilIdentifier"
    machine.text = "A7 / " + id.to_upper()
    machine.font_size = 44
    machine.pixel_size = 0.0023
    machine.position = Vector3(0.0,-0.57,0.37)
    machine.modulate = Color(0.86,0.91,0.91)
    panel.add_child(machine)
    var status := Label3D.new()
    status.name = "PhysicalCircuitState"
    status.text = "OFFLINE"
    status.font_size = 30
    status.pixel_size = 0.0021
    status.position = Vector3(0.0,-0.80,0.38)
    status.modulate = Color(0.63,0.74,0.78)
    panel.add_child(status)
    terminals.append({
        "id":id,"position":COIL_POSITIONS[id],
        "node":panel,"indicator":indicator,"actuator":actuator,
        "rotor":shaft,"status":status,"machine":machine
    })

func set_quality(value: String) -> void:
    _quality = "eco" if value == "eco" else "hero"
    hub_light.visible = _quality == "hero" and _state == "online"

func sync_engine(engine: IPCrisisEngine,time_seconds: float,reduced_motion: bool) -> void:
    _updated = true
    _elapsed = time_seconds
    _active_count = engine.containment_sequence.size()
    _state = "online" if engine.containment_online else "routing" if not engine.containment_sequence.is_empty() else "idle" if engine.core_scanned else "offline"
    for coil in terminals:
        var id: String = coil["id"]
        var done: bool = engine.containment_sequence.has(id)
        var next: bool = engine.core_scanned and not engine.containment_online and engine.next_containment_coil() == id
        var active: bool = engine.containment_online
        var material: StandardMaterial3D = _online if active else _charged if done else _ready if next else _inactive
        var indicator: MeshInstance3D = coil["indicator"]
        var actuator: MeshInstance3D = coil["actuator"]
        indicator.material_override = material
        actuator.material_override = material
        var state_label: Label3D = coil["status"]
        state_label.text = "ONLINE" if active else "LOCKED" if done else "READY" if next else "OFFLINE"
        var rotor: Node3D = coil["rotor"]
        if done and not reduced_motion and _quality == "hero":
            rotor.rotation.z = sin(time_seconds*0.65)*0.13
        else:
            rotor.rotation.z = 0.0
    hub_light.visible = _quality == "hero" and engine.containment_online

func readout() -> Dictionary:
    var statuses: Array[String] = []
    var real_points: Array = []
    for coil in terminals:
        var marker: Label3D = coil["status"]
        var p: Vector3 = coil["position"]
        statuses.append(marker.text)
        real_points.append([str(coil["id"]),p.x,p.z])
    return {
        "real_3d_coils":terminals.size(),
        "physical_3d_positions":real_points,
        "status_leds":terminals.size(),
        "mechanical_rotors":terminals.size(),
        "scene_state":_state,
        "coil_statuses":statuses,
        "active_count":_active_count,
        "quality":_quality,
        "updated_from_game_engine":_updated,
        "hub_light_visible":hub_light.visible
    }
