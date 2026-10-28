extends Node3D
class_name IPCascadeStations
## V9 — physical emergency protocol in the existing 3D reactor station.
## Four independent consoles, honest spatial navigation and scene feedback.
## This class renders game state only; the authoritative rules are in IPCrisisEngine.
const NODE_IDS: Array[String] = ["start","bridge","sync","lock"]
const POSITIONS: Array[Vector3] = [
    Vector3(4.5,1.0,-18.5),
    Vector3(-4.5,1.0,-40.5),
    Vector3(4.5,1.0,-52.0),
    Vector3(4.5,1.0,-25.0)
]
const LABELS: Array[String] = ["CASCADE / ARM","PHASE / BRIDGE","SYNC / TRANSFER","CORE / LOCK"]
const SHELL := Color(0.18,0.23,0.28)
const METAL := Color(0.46,0.54,0.59)
const BLUE := Color(0.18,0.78,0.92)
const GOLD := Color(1.0,0.70,0.29)
const GREEN := Color(0.23,0.91,0.58)
const RED := Color(0.98,0.27,0.21)

var stations: Array[Dictionary] = []
var _inactive_mat: StandardMaterial3D
var _target_mat: StandardMaterial3D
var _done_mat: StandardMaterial3D
var _fail_mat: StandardMaterial3D
var _status: String = "idle"
var _phase: int = 0
var _remaining: float = 0.0
var _last_motion: float = 0.0
var _active_station: String = "start"

func _ready() -> void:
    name = "A7_CascadeProtocolStations"
    _inactive_mat = _material(BLUE,0.55)
    _target_mat = _material(GOLD,1.70)
    _done_mat = _material(GREEN,0.85)
    _fail_mat = _material(RED,1.05)
    for index in range(NODE_IDS.size()):
        _create_station(index)
    update_status("idle",0,IPCrisisEngine.CASCADE_WINDOW,0.0,false)

func _material(tint: Color,emission_energy: float = 0.0) -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    mat.albedo_color = tint
    mat.metallic = 0.52
    mat.roughness = 0.42
    if emission_energy > 0.0:
        mat.emission_enabled = true
        mat.emission = tint
        mat.emission_energy_multiplier = emission_energy
    return mat

func _box(parent: Node3D,label: String,point: Vector3,dims: Vector3,mat: Material) -> MeshInstance3D:
    var node := MeshInstance3D.new()
    node.name = label
    var mesh := BoxMesh.new()
    mesh.size = dims
    node.mesh = mesh
    node.position = point
    node.material_override = mat
    parent.add_child(node)
    return node

func _create_station(index: int) -> void:
    var station := Node3D.new()
    station.name = "CascadeConsole_" + NODE_IDS[index]
    station.position = POSITIONS[index]
    add_child(station)
    var dark: StandardMaterial3D = _material(SHELL)
    var steel: StandardMaterial3D = _material(METAL)
    _box(station,"PressureRatedBase",Vector3(0,-0.24,0),
        Vector3(1.12,1.25,0.52),dark)
    _box(station,"MachinedBrow",Vector3(0,0.47,0.05),
        Vector3(1.40,0.16,0.68),steel)
    _box(station,"OperatorScreen",Vector3(0,0.09,0.286),
        Vector3(0.94,0.70,0.055),_material(Color(0.038,0.073,0.11)))
    _box(station,"RecessedRailLeft",Vector3(-0.54,-0.05,0.30),
        Vector3(0.065,0.89,0.09),steel)
    _box(station,"RecessedRailRight",Vector3(0.54,-0.05,0.30),
        Vector3(0.065,0.89,0.09),steel)
    var status_light: MeshInstance3D = _box(station,"CascadeStatusBand",
        Vector3(0,0.51,0.38),Vector3(1.02,0.10,0.09),_target_mat)
    var dial_pivot := Node3D.new()
    dial_pivot.name = "RealAnimatedPhaseDial"
    dial_pivot.position = Vector3(0,0.09,0.339)
    station.add_child(dial_pivot)
    var face := CylinderMesh.new()
    face.top_radius = 0.17
    face.bottom_radius = 0.17
    face.height = 0.045
    face.radial_segments = 24
    var dial := MeshInstance3D.new()
    dial.name = "MachinedDialRotor"
    dial.mesh = face
    dial.rotation_degrees.x = 90.0
    dial.material_override = steel
    dial_pivot.add_child(dial)
    _box(dial_pivot,"DialIndexNeedle",Vector3(0,0.12,0.032),
        Vector3(0.035,0.20,0.04),_target_mat)
    var sign := Label3D.new()
    sign.name = "InWorldStationLabel"
    sign.text = LABELS[index]
    sign.font_size = 38
    sign.pixel_size = 0.0022
    sign.position = Vector3(0,-0.32,0.365)
    sign.modulate = Color(0.90,0.95,0.97)
    station.add_child(sign)
    stations.append({
        "id":NODE_IDS[index],"position":POSITIONS[index],
        "node":station,"indicator":status_light,
        "dial":dial_pivot,"sign":sign
    })

func update_status(current: String,phase: int,remaining: float,elapsed: float,reduced_motion: bool) -> void:
    _status = current
    _phase = phase
    _remaining = remaining
    _active_station = ""
    if current == "idle":
        _active_station = "start"
    elif current == "active" and phase >= 0 and phase < IPCrisisEngine.CASCADE_SEQUENCE.size():
        _active_station = IPCrisisEngine.CASCADE_SEQUENCE[phase]
    for station in stations:
        var station_id: String = str(station["id"])
        var index: int = NODE_IDS.find(station_id)
        var completed: bool = current == "completed" or (current == "active" and ((index == 0) or index <= phase))
        var material: StandardMaterial3D = _target_mat if station_id == _active_station else _done_mat if completed else _fail_mat if current == "failed" else _inactive_mat
        var indicator: MeshInstance3D = station["indicator"]
        if indicator.material_override != material:
            indicator.material_override = material
        var rotor: Node3D = station["dial"]
        # Keep essential status visible even with reduced motion.
        if not reduced_motion and station_id == _active_station and current == "active":
            rotor.rotation.z = elapsed*1.40
        elif station_id != _active_station or reduced_motion:
            rotor.rotation.z = 0.0
    _last_motion = elapsed

func readout() -> Dictionary:
    return {
        "physical_3d_consoles":stations.size(),
        "station_ids":NODE_IDS.duplicate(),
        "station_positions":[
            [POSITIONS[0].x,POSITIONS[0].z],
            [POSITIONS[1].x,POSITIONS[1].z],
            [POSITIONS[2].x,POSITIONS[2].z],
            [POSITIONS[3].x,POSITIONS[3].z]
        ],
        "state":_status,
        "phase":_phase,
        "deadline":_remaining,
        "active_station":_active_station,
        "animated_3d_dials":stations.size()
    }
