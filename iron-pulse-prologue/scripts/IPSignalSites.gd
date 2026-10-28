extends Node3D
class_name IPSignalSites
## V9 — Four distinct diegetic machines in the actual playable level.
## Each spatial location can be reached by the CharacterBody3D. Physics
## barriers, existing 6 main systems and the 3 V7 rescue relays are unchanged.
const LOCATIONS: Array[Dictionary] = [
    {"id":"resonance","position":Vector3(4.8,1.02,-18.0),"tag":"A7 / CORE FREQUENCY","glyph":"01"},
    {"id":"atmosphere","position":Vector3(-4.6,1.02,-42.0),"tag":"LIFE / AIR TELEMETRY","glyph":"02"},
    {"id":"transit","position":Vector3(4.6,1.02,-51.0),"tag":"EXIT / TRANSIT SIGNAL","glyph":"03"},
    {"id":"directive","position":Vector3(4.8,1.02,-46.0),"tag":"EXODUS / FINAL DIRECTIVE","glyph":"04"}
]
const STEEL := Color(0.24,0.30,0.35)
const FRAME := Color(0.08,0.13,0.18)
const ICE := Color(0.14,0.77,0.85)
const AMBER := Color(0.94,0.53,0.22)
const GREEN := Color(0.16,0.79,0.55)

var sites: Array[Dictionary] = []
var _ready_mat: StandardMaterial3D
var _done_mat: StandardMaterial3D
var _locked_mat: StandardMaterial3D
var _hero_details: Node3D
var _quality: String = "hero"
var _active_count: int = 0
var _directive_ready: bool = false
var _directive_completed: bool = false
var _receiver_phase: float = 0.0

func _ready() -> void:
    name = "A7_ExodusDirectiveNetwork"
    _ready_mat = _material(ICE,true)
    _done_mat = _material(GREEN,true)
    _locked_mat = _material(AMBER,true)
    _hero_details = Node3D.new()
    _hero_details.name = "OptionalPrecisionDetail"
    add_child(_hero_details)
    for data in LOCATIONS:
        _make_physical_site(data)
    set_quality("hero")

func _material(tint: Color,glow: bool = false) -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    mat.albedo_color = tint
    mat.metallic = 0.42 if not glow else 0.12
    mat.roughness = 0.49 if not glow else 0.33
    if glow:
        mat.emission_enabled = true
        mat.emission = tint
        mat.emission_energy_multiplier = 0.86
    return mat

func _box(parent: Node3D,name_id: String,at: Vector3,size: Vector3,mat: Material) -> MeshInstance3D:
    var mesh := BoxMesh.new()
    mesh.size = size
    var n := MeshInstance3D.new()
    n.name = name_id
    n.mesh = mesh
    n.position = at
    n.material_override = mat
    parent.add_child(n)
    return n

func _make_receiver_station(node: Node3D,id: String,hull: Material) -> Node3D:
    # Four authored in-world scanning gyroscopes. Each has a true curved
    # TorusMesh, three machined spokes and a cylindrical axle, not UI artwork.
    var receiver := Node3D.new()
    receiver.name = "AnimatedSignalGyroscope_" + id
    receiver.position = Vector3(0,1.18,0.06)
    node.add_child(receiver)
    var torus := TorusMesh.new()
    torus.inner_radius = 0.40
    torus.outer_radius = 0.445
    torus.rings = 32
    torus.ring_segments = 9
    var halo := MeshInstance3D.new()
    halo.name = "ActualCurveSignalRing"
    halo.mesh = torus
    halo.material_override = _ready_mat
    halo.rotation_degrees.x = 90.0
    receiver.add_child(halo)
    var axle := CylinderMesh.new()
    axle.top_radius = 0.095
    axle.bottom_radius = 0.095
    axle.height = 0.16
    axle.radial_segments = 16
    var boss := MeshInstance3D.new()
    boss.name = "MachinedHarmonicAxle"
    boss.mesh = axle
    boss.rotation_degrees.x = 90.0
    boss.material_override = hull
    receiver.add_child(boss)
    for spoke_index in range(3):
        var spoke := _box(receiver,"ResonantMachinedSpoke_%d" % spoke_index,
            Vector3(0,0.16,0.0),Vector3(0.075,0.31,0.065),hull)
        spoke.rotation_degrees.z = float(spoke_index)*120.0
    return receiver

func _make_physical_site(data: Dictionary) -> void:
    var id: String = str(data["id"])
    var node := Node3D.new()
    node.name = "SignalStation_" + id
    node.position = data["position"]
    add_child(node)
    var hull := _material(STEEL)
    var graphite := _material(FRAME)
    _box(node,"ImpactResistantBase",Vector3(0,-0.32,0),Vector3(1.56,0.25,0.92),graphite)
    _box(node,"VerticalMachinedHousing",Vector3.ZERO,Vector3(1.47,1.66,0.52),hull)
    _box(node,"StatusRecess",Vector3(0,0.08,0.28),Vector3(1.28,1.25,0.055),graphite)
    _box(node,"StatusDisplay",Vector3(0,-0.11,0.33),Vector3(1.1,0.47,0.048),_material(Color(0.09,0.26,0.30),true))
    var strip := _box(node,"LiveSignalStatus",Vector3(0,0.62,0.33),Vector3(1.24,0.09,0.07),_ready_mat)
    var flare := _box(node,"MechanicalGuidanceStrip",Vector3(0,-0.58,0.34),Vector3(1.16,0.09,0.07),_locked_mat)
    var sign := Label3D.new()
    sign.name = "SourceAuthoredMachineLabel"
    sign.text = str(data["tag"])
    sign.font_size = 36
    sign.pixel_size = 0.00205
    sign.position = Vector3(0,0.20,0.38)
    sign.modulate = Color(0.84,0.91,0.94)
    node.add_child(sign)
    var number := Label3D.new()
    number.name = "MissionSequenceNumber"
    number.text = str(data["glyph"])
    number.font_size = 66
    number.pixel_size = 0.0024
    number.position = Vector3(-0.01,-0.14,0.41)
    number.modulate = ICE
    node.add_child(number)
    var receiver: Node3D = _make_receiver_station(node,id,hull)
    for index in range(5):
        var fin := _box(_hero_details,"CNC_CoolingFin_%s_%d" % [id,index],
            Vector3(node.position.x+0.62,0.2-float(index)*0.22,node.position.z-0.32),
            Vector3(0.15,0.10,0.47),hull)
        fin.rotation_degrees.x = 7.0
    sites.append({
        "id":id,"position":data["position"],"node":node,
        "status":strip,"accent":flare,"number":number,
        "receiver":receiver
    })

func nearest(world_position: Vector3,reach: float = 2.55) -> Dictionary:
    var nearest_site: Dictionary = {}
    var shortest: float = reach
    for site in sites:
        var pos: Vector3 = site["position"]
        var dist: float = Vector2(world_position.x,world_position.z).distance_to(Vector2(pos.x,pos.z))
        if dist < shortest:
            shortest = dist
            nearest_site = site
    return nearest_site

func update_campaign(campaign: IPSignalCampaign,core_scanned: bool = false) -> void:
    _active_count = campaign.collected.size()
    _directive_ready = campaign.route_unlocked()
    _directive_completed = campaign.completed()
    for site in sites:
        var id: String = site["id"]
        var light: MeshInstance3D = site["status"]
        var number: Label3D = site["number"]
        var receiver: Node3D = site["receiver"]
        var receiver_halo: MeshInstance3D = receiver.get_node("ActualCurveSignalRing") as MeshInstance3D
        var completed: bool = campaign.collected.has(id) or (id == "directive" and campaign.completed())
        var accessible: bool = campaign.route_unlocked() if id == "directive" else core_scanned and not completed and not campaign.completed()
        light.material_override = _done_mat if completed else _ready_mat if accessible else _locked_mat
        receiver_halo.material_override = light.material_override
        number.modulate = GREEN if completed else ICE if accessible else AMBER

func set_quality(mode: String) -> void:
    _quality = "eco" if mode == "eco" else "hero"
    if _hero_details != null:
        _hero_details.visible = _quality == "hero"
    for station in sites:
        (station["receiver"] as Node3D).visible = _quality == "hero"

func animate_live(elapsed: float,reduced_motion: bool,active: bool = true) -> void:
    # No decorative spin while paused, in reduced-motion mode or ECO. This
    # preserves actual diagnostic status and mechanical geometry for players.
    if not active or reduced_motion or _quality != "hero":
        return
    _receiver_phase = elapsed
    for index in range(sites.size()):
        var rotor: Node3D = sites[index]["receiver"]
        rotor.rotation.z = 0.18*sin(elapsed*0.47+float(index)*1.1)


func diagnostic() -> Dictionary:
    var locations: Array = []
    for site in sites:
        var location: Vector3 = site["position"]
        locations.append([str(site["id"]),location.x,location.z])
    return {
        "real_signal_consoles":sites.size(),
        "physical_sites":locations,
        "hero_precision_fins":20,
        "actual_curved_receivers":sites.size(),
        "receiver_phase":_receiver_phase,
        "quality":_quality,
        "collected_count":_active_count,
        "final_unlocked":_directive_ready,
        "final_committed":_directive_completed
    }
