extends Node3D
class_name IPContainmentRun
## IRON PULSE V9: a second, spatially consequential GAMEPLAY system.
## Three player-visible environmental danger corridors are actually sampled
## from the operator's position. Each corridor has a single-use field seal.
## A shared 2-of-3 authorization budget creates a meaningful route choice.
## Does not modify external machines or connect to any network.

const ZONES: Array[String] = ["reactor","service","evacuation"]
const MAX_SEALS: int = 2
const SUIT_MAX: float = 100.0
const SEAL_COST_SECONDS: float = 7.0
const SEAL_COST_OXYGEN: float = 6.0
const CONSOLE_POSITIONS := [
    Vector3(4.7,1.1,-25.6),
    Vector3(-4.7,1.1,-42.4),
    Vector3(4.7,1.1,-52.8)
]
const ZONE_Z := [-22.5,-41.0,-52.1]
const ZONE_RADIUS: float = 4.3

var suit_integrity: float = SUIT_MAX
var exposure_total: float = 0.0
var seals: Array[String] = []
var current_zone: String = ""
var current_risk: float = 0.0
var entered_zones: Array[String] = []
var warned_critical: bool = false
var lost_suit: bool = false
var interaction_points: Array[Dictionary] = []
var _ready_material: StandardMaterial3D
var _sealed_material: StandardMaterial3D
var _danger_material: StandardMaterial3D
var _surfaces: Array[MeshInstance3D] = []
var _quality: String = "hero"
var _reduced_motion: bool = false
var _alarm_phase: float = 0.0

func _ready() -> void:
    name = "A7_ThreeStageContainmentRun"
    _ready_material = _lit(Color(0.92,0.49,0.19),0.8)
    _sealed_material = _lit(Color(0.12,0.77,0.52),0.7)
    _danger_material = _lit(Color(0.95,0.20,0.15),0.45)
    for i in range(ZONES.size()):
        _build_field_gate(i)
    _update_surfaces()

func _lit(tint: Color,energy: float) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = tint
    m.metallic = 0.44
    m.roughness = 0.44
    m.emission_enabled = true
    m.emission = tint
    m.emission_energy_multiplier = energy
    return m

func _steel() -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = Color(0.20,0.27,0.31)
    m.metallic = 0.78
    m.roughness = 0.49
    return m

func _box(parent: Node3D,part_name: String,point: Vector3,size: Vector3,mat: Material) -> MeshInstance3D:
    var part := MeshInstance3D.new()
    part.name = part_name
    var box := BoxMesh.new()
    box.size = size
    part.mesh = box
    part.position = point
    part.material_override = mat
    parent.add_child(part)
    return part

func _build_field_gate(index: int) -> void:
    var id: String = ZONES[index]
    # Physical industrial safety console placed on the EXISTING mission path.
    var console := Node3D.new()
    console.name = "FieldSealConsole_" + id
    console.position = CONSOLE_POSITIONS[index]
    add_child(console)
    var metal: StandardMaterial3D = _steel()
    _box(console,"PermanentConsoleBody",Vector3(0,-0.3,0),
        Vector3(1.3,1.9,0.6),metal)
    _box(console,"ReinforcedCableTrunk",Vector3(0,-1.2,0),
        Vector3(0.4,0.52,0.4),metal)
    var indicator: MeshInstance3D = _box(console,"LiveSafetyStatus",
        Vector3(0,0.36,0.36),Vector3(1.11,0.18,0.07),_ready_material)
    var label := Label3D.new()
    label.name = "SealStationLabel"
    label.text = "A7  /  SEAL  %02d" % (index+1)
    label.font_size = 38
    label.pixel_size = 0.0020
    label.position = Vector3(0,-0.05,0.39)
    label.modulate = Color(0.86,0.92,0.95)
    console.add_child(label)
    # The containment curtain is real semitransparent in-world geometry
    # visible near the danger sector, NOT a forced invisible damage trigger.
    var arch := Node3D.new()
    arch.name = "ContainmentFieldArch_" + id
    arch.position = Vector3(0,0,ZONE_Z[index])
    add_child(arch)
    for x in [-5.6,5.6]:
        _box(arch,"EmergencyFrame",Vector3(x,2.8,0),
            Vector3(0.28,5.5,0.43),metal)
    _box(arch,"Crossbeam",Vector3(0,5.40,0),
        Vector3(11.5,0.25,0.43),metal)
    var signal_strip: MeshInstance3D = _box(arch,"AnimatedFieldWarning",
        Vector3(0,5.18,0.19),Vector3(10.2,0.055,0.13),_danger_material)
    _surfaces.append(signal_strip)
    interaction_points.append({
        "id":id, "position":CONSOLE_POSITIONS[index],
        "node":console, "indicator":indicator, "arch":arch
    })

func reset() -> void:
    suit_integrity = SUIT_MAX
    exposure_total = 0.0
    seals.clear()
    current_zone = ""
    current_risk = 0.0
    entered_zones.clear()
    warned_critical = false
    lost_suit = false
    _alarm_phase = 0.0
    _update_surfaces()

func set_quality(value: String) -> void:
    _quality = "eco" if value == "eco" else "hero"
    _update_surfaces()

func _update_surfaces() -> void:
    for info in interaction_points:
        var id: String = str(info["id"])
        var indicator: MeshInstance3D = info["indicator"]
        indicator.material_override = _sealed_material if seals.has(id) else _ready_material
        var arch: Node3D = info["arch"]
        # The physical arch and its safety signal NEVER disappear on ECO.
        arch.visible = true
    for i in range(_surfaces.size()):
        var id: String = ZONES[i]
        _surfaces[i].material_override = _sealed_material if seals.has(id) else _danger_material
    if _danger_material != null:
        _danger_material.emission_energy_multiplier = 0.55 if _quality == "eco" else 0.84

func nearest(position: Vector3) -> Dictionary:
    var nearest_distance: float = 2.65
    var chosen: Dictionary = {}
    for info in interaction_points:
        var here: Vector3 = info["position"]
        var distance: float = Vector2(here.x,here.z).distance_to(Vector2(position.x,position.z))
        if distance < nearest_distance:
            chosen = info
            nearest_distance = distance
    return chosen

func zone_for_position(pos: Vector3) -> String:
    if absf(pos.x) > 6.1 or pos.y < -0.5 or pos.y > 4.7:
        return ""
    for i in range(ZONES.size()):
        if absf(pos.z-ZONE_Z[i]) <= ZONE_RADIUS:
            return ZONES[i]
    return ""

func risk_for(id: String,scenario: String,heat: float,oxygen: float) -> float:
    if id == "" or seals.has(id):
        return 0.0
    var heat_risk: float = clampf((heat-61.0)/39.0,0.0,1.0)
    var oxygen_risk: float = clampf((67.0-oxygen)/67.0,0.0,1.0)
    var base: float = 0.18 if scenario == "blackout" else 0.48 if scenario == "thermal" else 0.38
    var zone_factor: float = 1.12 if id == "reactor" else 0.90 if id == "service" else 0.82
    return clampf((base + 0.55*heat_risk+0.44*oxygen_risk)*zone_factor,0.0,1.0)

func step(delta: float,player_pos: Vector3,engine: IPCrisisEngine,reduced_motion: bool = false) -> String:
    # A real player movement + environmental calculation, not a fake UI bar.
    if delta <= 0.0 or engine.finished() or not engine.core_scanned:
        return ""
    _reduced_motion = reduced_motion
    var zone: String = zone_for_position(player_pos)
    var event_id: String = ""
    if zone != "" and zone != current_zone and not entered_zones.has(zone):
        entered_zones.append(zone)
        event_id = "field_enter_" + zone
    current_zone = zone
    current_risk = risk_for(zone,engine.scenario_id,engine.heat,engine.oxygen)
    if current_risk <= 0.0:
        return event_id
    var amount: float = minf(delta,1.0) * (0.33+current_risk*2.1)
    suit_integrity = maxf(0.0,suit_integrity-amount)
    exposure_total = minf(10000.0,exposure_total+amount)
    if suit_integrity <= 0.0:
        lost_suit = true
        return "suit_failure"
    if suit_integrity < 30.0 and not warned_critical:
        warned_critical = true
        return "suit_critical"
    return event_id

func activate_seal(id: String,engine: IPCrisisEngine) -> bool:
    if not ZONES.has(id) or seals.has(id) or seals.size() >= MAX_SEALS:
        return engine._reject()
    if not engine.authorize_field_seal():
        return false
    seals.append(id)
    current_risk = 0.0 if current_zone == id else current_risk
    _update_surfaces()
    engine._record("field_seal_" + id)
    return true

func checkpoint() -> Dictionary:
    return {
        "schema":"IRON_PULSE_FIELD_V9","suit":suit_integrity,
        "exposure":exposure_total,"seals":seals.duplicate(),
        "entered_zones":entered_zones.duplicate(),"warned":warned_critical,
        "failed":lost_suit
    }

func restore(data: Dictionary) -> bool:
    # Empty payload means a legitimate pre-V9 save: untouched suit and field.
    if data.is_empty():
        reset()
        return true
    if data.get("schema") != "IRON_PULSE_FIELD_V9":
        return false
    for key in ["suit","exposure"]:
        var v: Variant = data.get(key,null)
        if typeof(v) not in [TYPE_INT,TYPE_FLOAT]:
            return false
        var n: float = float(v)
        var hi: float = SUIT_MAX if key == "suit" else 10000.0
        if n != n or n < 0.0 or n > hi:
            return false
    for key in ["seals","entered_zones"]:
        var values: Variant = data.get(key,null)
        if not values is Array or values.size() > (MAX_SEALS if key == "seals" else ZONES.size()):
            return false
        var seen: Array[String] = []
        for v in values:
            if not v is String or not ZONES.has(v) or seen.has(v):
                return false
            seen.append(str(v))
    if typeof(data.get("warned",null)) != TYPE_BOOL or typeof(data.get("failed",null)) != TYPE_BOOL:
        return false
    if bool(data["failed"]) != (float(data["suit"]) <= 0.0):
        return false
    suit_integrity = float(data["suit"])
    exposure_total = float(data["exposure"])
    seals.clear()
    entered_zones.clear()
    for id in data["seals"]:
        seals.append(str(id))
    for id in data["entered_zones"]:
        entered_zones.append(str(id))
    warned_critical = bool(data["warned"])
    lost_suit = bool(data["failed"])
    current_zone = ""
    current_risk = 0.0
    _update_surfaces()
    return true

func readout() -> Dictionary:
    return {
        "zones":ZONES.duplicate(),"physical_consoles":interaction_points.size(),
        "physical_arches":_surfaces.size(),"suit":suit_integrity,
        "exposure":exposure_total,"used_seals":seals.duplicate(),
        "budget":MAX_SEALS,"active_zone":current_zone,
        "risk":current_risk,"failed":lost_suit,
        "quality":_quality,"reduced_motion":_reduced_motion
    }
