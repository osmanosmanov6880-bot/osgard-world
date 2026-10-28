extends Node3D
class_name A7MissionWayfinder
## W76: real in-world navigation; passive read-only guidance for the
## original authored W71/W72 five-objective physics mission.
## Never moves the player, certifies progress, or alters core decisions.

const COPPER := Color("e5b67b")
const CYAN := Color("8de9e0")
const LOW := Color("304957")
const CORE := Vector3(4.10, 1.2, 2.14)
const RELAY := Vector3(8.0, 1.2, 20.0)

var mission: A7SpatialMission
var operator: A7FirstPersonOperator
var root_visuals: Node3D
var target_ring: MeshInstance3D
var target_shaft: MeshInstance3D
var target_text: Label3D
var trail: Array[MeshInstance3D] = []
var trail_material: StandardMaterial3D
var target_material: StandardMaterial3D
var light: OmniLight3D
var quality: String = "hero"
var compact: bool = false
var reduced_motion: bool = false
var goal: Vector3 = CORE
var goal_kind: String = "none"
var real_distance: float = -1.0
var actual_distance_checks: int = 0
var last_phase: int = -1
var native_meshes: int = 0
var active_indicator_seconds: float = 0.0
var _wave: float = 0.0

func _mat(tone: Color, brightness: float) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = tone
    m.metallic = 0.25
    m.roughness = 0.40
    m.emission_enabled = true
    m.emission = tone
    m.emission_energy_multiplier = brightness
    return m

func _box(parent: Node3D, name_: String,
        size_: Vector3, at: Vector3, mat: Material) -> MeshInstance3D:
    var item := MeshInstance3D.new()
    item.name = name_
    var mesh := BoxMesh.new()
    mesh.size = size_
    item.mesh = mesh
    item.material_override = mat
    item.position = at
    parent.add_child(item)
    native_meshes += 1
    return item

func build(actual_mission: A7SpatialMission,
        actual_operator: A7FirstPersonOperator) -> void:
    mission = actual_mission
    operator = actual_operator
    name = "W76PhysicalMissionWayfindingWithoutAutoplay"
    root_visuals = Node3D.new()
    root_visuals.name = "SpatialGoalLightAndActualBridgeGuides"
    add_child(root_visuals)
    trail_material = _mat(LOW, 0.12)
    target_material = _mat(COPPER, 1.25)

    target_ring = MeshInstance3D.new()
    target_ring.name = "W76ActualThreeDimensionalGoalRing"
    var ring := TorusMesh.new()
    ring.inner_radius = 0.52
    ring.outer_radius = 0.59
    ring.rings = 36
    ring.ring_segments = 12
    target_ring.mesh = ring
    target_ring.material_override = target_material
    root_visuals.add_child(target_ring)
    native_meshes += 1

    target_shaft = _box(root_visuals,
        "W76ReactorSectorWayfindingPylon",
        Vector3(0.045, 2.0, 0.045), Vector3.ZERO, target_material)
    target_text = Label3D.new()
    target_text.name = "W76RealWorldObjectiveLabel"
    target_text.font_size = 44
    target_text.pixel_size = 0.004
    target_text.modulate = COPPER
    target_text.no_depth_test = false
    root_visuals.add_child(target_text)

    # Source-aligned with W70 actual 13-segment physically collidable deck.
    # No waypoint teleports, collision masks, or invisible mission advancement.
    for i in range(13):
        var z: float = 6.10 + float(i) * 1.02
        var tile: MeshInstance3D = _box(root_visuals,
            "W76LiveReadOnlyTravelArrow%02d" % i,
            Vector3(0.12, 0.024, 0.46),
            Vector3(6.4, 0.43, z), trail_material)
        trail.append(tile)
    light = OmniLight3D.new()
    light.name = "W76PhysicalCurrentObjectivePracticalLight"
    light.light_color = CYAN
    light.light_energy = 0.95
    light.omni_range = 3.8
    light.shadow_enabled = false
    root_visuals.add_child(light)
    set_process(true)
    _reconcile()

func _choose_goal() -> String:
    if mission == null or not mission.active or mission.phase in [5,6]:
        return "none"
    if mission.phase in [0,1,4]:
        return "core"
    return "relay"

func _reconcile() -> void:
    if root_visuals == null or mission == null or operator == null:
        return
    var kind: String = _choose_goal()
    goal_kind = kind
    root_visuals.visible = kind != "none"
    if kind == "none":
        real_distance = -1.0
        last_phase = mission.phase
        return
    goal = CORE if kind == "core" else RELAY
    if operator.body != null:
        real_distance = operator.body.global_position.distance_to(goal)
        actual_distance_checks += 1
    else:
        real_distance = -1.0
    last_phase = mission.phase
    target_ring.position = goal + Vector3(0, 1.58, 0)
    target_shaft.position = goal + Vector3(0, 1.12, 0)
    target_text.position = goal + Vector3(0, 2.35, 0)
    target_text.text = ("01 / A7 CORE" if kind == "core" else "02 / A7 RELAY")
    target_text.visible = not compact and quality == "hero"
    light.position = goal + Vector3(0, 2.04, 0)
    light.visible = quality == "hero"
    # The relay catwalk is highlighted only when the objective is actually
    # in the other sector. The core return uses opposite direction.
    for arrow in trail:
        arrow.visible = kind == "relay" and quality == "hero"
    target_material.emission = COPPER if kind == "core" else CYAN

func _process(delta: float) -> void:
    _reconcile()
    if not root_visuals.visible:
        return
    active_indicator_seconds += delta
    if reduced_motion:
        target_ring.scale = Vector3.ONE
        target_material.emission_energy_multiplier = 0.75
        return
    _wave += minf(delta, 0.08)
    var pulse: float = 0.5 + 0.5 * sin(_wave * 2.25)
    target_ring.scale = Vector3.ONE * (1.0 + 0.05 * pulse)
    target_material.emission_energy_multiplier = (
        (0.75 + 0.75 * pulse) if quality == "hero" else 0.45)

func set_quality(mode: String) -> void:
    quality = "eco" if mode == "eco" else "hero"
    _reconcile()

func set_compact_view(value: bool) -> void:
    compact = value
    _reconcile()

func set_reduced_motion(value: bool) -> void:
    reduced_motion = value

func localized_hint(locale: String) -> String:
    if goal_kind == "none":
        return ("МИССИЯ НЕ АКТИВНА" if locale == "ru" else
            "NO ACTIVE MISSION")
    var label: String = ("РЕАКТОР" if goal_kind == "core" else "РЕЛЕЙНЫЙ ЗАЛ")
    if locale == "en":
        label = "REACTOR" if goal_kind == "core" else "RELAY HALL"
    if real_distance < 0:
        return label
    return ("%s · %.1f м" if locale == "ru" else
        "%s · %.1f m") % [label, real_distance]

func qa_readout() -> Dictionary:
    return {
        "schema":"LAST_FRONTIER_W76_REAL_3D_MISSION_WAYFINDER_V1",
        "actual_native_wayfinding_meshes":native_meshes,
        "real_target_ring":target_ring is MeshInstance3D,
        "actual_collidable_catwalk_aligned_markers":trail.size(),
        "original_mission_phase":mission.phase if mission != null else -1,
        "original_mission_active":mission.active if mission != null else false,
        "current_target":goal_kind,
        "actual_goal_xyz":[goal.x,goal.y,goal.z],
        "real_physical_player_distance":real_distance,
        "sampled_real_distance_frames":actual_distance_checks,
        "read_only_mission_authority":true,
        "never_teleports_or_advances_original_game":true,
        "eco":quality == "eco",
        "reduced_motion":reduced_motion,
        "not_human_approved_aaa_art":true,
    }
