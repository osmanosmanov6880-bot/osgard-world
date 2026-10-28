extends Node3D
class_name IPWayfinding
## IRON PULSE V10 — one legible marker in the REAL 3D environment.
## Objective markers are not an overlay, do not see through the walls and
## never change gameplay. Optional H toggle persists in offline checkpoints.
const GLOW := Color(0.20,0.80,0.88)
const HALO_RADIUS: float = 0.62

var enabled: bool = true
var marker: Node3D
var halo: MeshInstance3D
var center: MeshInstance3D
var nameplate: Label3D
var _stations: Dictionary = {}
var _target_id: String = ""
var _target_distance: float = 0.0
var _motion_phase: float = 0.0
var _reduced_motion: bool = false
var _quality: String = "hero"
var _locale: String = "ru"

func _ready() -> void:
    name = "A7_InWorldObjectiveMarker"
    marker = Node3D.new()
    marker.name = "ObjectiveOnly_3DSignpost"
    add_child(marker)
    var material := StandardMaterial3D.new()
    material.albedo_color = GLOW
    material.metallic = 0.20
    material.roughness = 0.42
    material.emission_enabled = true
    material.emission = GLOW
    material.emission_energy_multiplier = 0.72
    halo = MeshInstance3D.new()
    halo.name = "ObjectiveHaloGeometry"
    var ring := TorusMesh.new()
    ring.inner_radius = HALO_RADIUS-0.06
    ring.outer_radius = HALO_RADIUS
    ring.rings = 32
    ring.ring_segments = 10
    halo.mesh = ring
    halo.material_override = material
    halo.rotation_degrees = Vector3(0,0,90)
    marker.add_child(halo)
    center = MeshInstance3D.new()
    center.name = "ObjectiveCenter"
    var diamond := SphereMesh.new()
    diamond.radius = 0.11
    diamond.height = 0.22
    center.mesh = diamond
    center.material_override = material
    marker.add_child(center)
    nameplate = Label3D.new()
    nameplate.name = "ObjectiveDistanceMeters"
    nameplate.text = ""
    nameplate.font_size = 36
    nameplate.pixel_size = 0.0023
    nameplate.position = Vector3(0,0.88,0)
    nameplate.modulate = Color(0.80,0.93,0.95)
    nameplate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    marker.add_child(nameplate)
    marker.visible = false

func configure(terminals: Array[Dictionary]) -> void:
    _stations.clear()
    for station in terminals:
        if station.has("id") and station.has("position"):
            _stations[str(station["id"])] = station["position"]

func goal_id(objective: String,player_pos: Vector3) -> String:
    if objective == "charge":
        return "bus_a" if player_pos.x <= 0.0 else "bus_b"
    return objective if _stations.has(objective) else ""

func update_goal(
        objective: String,player_pos: Vector3,elapsed: float,
        reduced_motion: bool,quality: String,locale: String,
        active: bool,cinematic: bool
    ) -> void:
    _quality = "eco" if quality == "eco" else "hero"
    _locale = "en" if locale == "en" else "ru"
    _reduced_motion = reduced_motion
    _target_id = goal_id(objective,player_pos)
    if _target_id == "":
        marker.visible = false
        _target_distance = 0.0
        return
    var point: Vector3 = _stations[_target_id]
    _target_distance = Vector2(point.x-player_pos.x,point.z-player_pos.z).length()
    marker.position = point+Vector3(0,2.75,0)
    # Markers remain constrained by natural 3D scene occlusion. Never x-ray.
    marker.visible = active and enabled and not cinematic and _target_distance >= 2.6
    if not marker.visible:
        return
    _motion_phase = 0.0 if reduced_motion else elapsed*1.3
    var glow_scale: float = 1.0 if reduced_motion else 1.0+0.055*sin(_motion_phase)
    halo.scale = Vector3.ONE*glow_scale
    center.scale = Vector3.ONE*(1.0 if _quality == "eco" else 1.12)
    nameplate.visible = _quality == "hero"
    nameplate.text = ("OBJECTIVE" if _locale == "en" else "ЦЕЛЬ") + "  %d m" % roundi(_target_distance)

func toggle() -> bool:
    enabled = not enabled
    if not enabled and marker != null:
        marker.visible = false
    return enabled

func readout() -> Dictionary:
    return {
        "enabled":enabled,
        "visible":marker != null and marker.visible,
        "physical_3d_halo":halo != null and halo.mesh is TorusMesh,
        "world_anchor": [marker.global_position.x,marker.global_position.y,marker.global_position.z] if marker != null else [],
        "target":_target_id,
        "distance_m":snappedf(_target_distance,0.1),
        "quality":_quality,
        "locale":_locale,
        "reduced_motion":_reduced_motion,
        "halo_scale":halo.scale.x if halo != null else 1.0
    }
