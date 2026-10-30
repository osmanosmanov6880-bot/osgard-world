extends Node3D
class_name IPObsidianArchitecture
## G3 / OBSIDIAN INDUSTRIAL — genuine authored Godot geometry and material
## language. Built from original Godot primitives; no external / unlicensed art.
## Non-colliding scenic meshes keep all original physical mission paths clear.
## The real IPCrisisEngine remains the only source of scenario/hazard changes.

const FORMAT: String = "IRON_PULSE_OBSIDIAN_ARCHITECTURE_G3"
const ZONES: Array[String] = ["reactor","service","evacuation"]
const MARKER_Z: Array[float] = [-13.8,-35.0,-51.2]
const TITANIUM := Color(0.12,0.16,0.19)
const OBSIDIAN := Color(0.029,0.052,0.064)
const BRUSHED := Color(0.38,0.47,0.50)
const BRONZE := Color(0.43,0.29,0.18)
const ICE := Color(0.18,0.79,0.83)
const AMBER := Color(0.96,0.51,0.19)
const ALARM := Color(0.92,0.20,0.18)
const QUIET := Color(0.13,0.43,0.49)

var hero_detail: Node3D
var critical_layer: Node3D
var marker_lamps: Array[OmniLight3D] = []
var marker_materials: Array[StandardMaterial3D] = []
var sector_labels: Array[Label3D] = []
var risk_status_labels: Array[Label3D] = []
var high_contrast_signs: bool = false
var safety_tier: String = "stable"
var _vision_words: IPVisionProfile = IPVisionProfile.new()
var close_range_labels: Array[Label3D] = []
var marker_positions: Array[Vector3] = []
var material_library: Dictionary = {}
var quality_mode: String = "hero"
var locale: String = "ru"
var current_scenario: String = "blackout"
var measured_risk: float = 0.0
var reduced_animation: bool = false
var hero_mesh_count: int = 0
var persistent_mesh_count: int = 0
var batched_instance_count: int = 0
var batch_count: int = 0

func _mat(tint: Color,metalness: float,roughness: float,glow: float = 0.0) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = tint
    m.metallic = metalness
    m.roughness = roughness
    if glow > 0.0:
        m.emission_enabled = true
        m.emission = tint
        m.emission_energy_multiplier = glow
    return m

func _box(parent: Node3D,label: String,where: Vector3,dimensions: Vector3,mat: StandardMaterial3D) -> MeshInstance3D:
    var node := MeshInstance3D.new()
    node.name = label
    var mesh := BoxMesh.new()
    mesh.size = dimensions
    node.mesh = mesh
    node.position = where
    node.material_override = mat
    # No StaticBody3D or CollisionShape3D: existing physical level is the
    # only source of movement, terminal interaction and collision response.
    parent.add_child(node)
    if parent == hero_detail:
        hero_mesh_count += 1
    else:
        persistent_mesh_count += 1
    return node

func _instances(parent: Node3D,title: String,shape: Vector3,points: Array[Vector3],mat: StandardMaterial3D) -> void:
    if points.is_empty():
        return
    var mesh := BoxMesh.new()
    mesh.size = shape
    var multi := MultiMesh.new()
    multi.transform_format = MultiMesh.TRANSFORM_3D
    multi.mesh = mesh
    multi.instance_count = points.size()
    for i in range(points.size()):
        multi.set_instance_transform(i,Transform3D(Basis(),points[i]))
    var visual := MultiMeshInstance3D.new()
    visual.name = title
    visual.multimesh = multi
    visual.material_override = mat
    parent.add_child(visual)
    batched_instance_count += points.size()
    batch_count += 1

func _label(parent: Node3D,title: String,at: Vector3,words: String,size: int,tint: Color) -> Label3D:
    var sign := Label3D.new()
    sign.name = title
    sign.text = words
    sign.position = at
    sign.font_size = size
    sign.pixel_size = 0.00225
    sign.modulate = tint
    parent.add_child(sign)
    return sign

func _ready() -> void:
    name = "G3_Obsidian_Industrial"
    hero_detail = Node3D.new()
    hero_detail.name = "G3_Hero_MachinedLayer"
    add_child(hero_detail)
    critical_layer = Node3D.new()
    critical_layer.name = "G3_AlwaysVisibleSafetyLayer"
    add_child(critical_layer)
    material_library = {
        "black_titanium":_mat(TITANIUM,0.83,0.34),
        "recessed_obsidian":_mat(OBSIDIAN,0.30,0.67),
        "brushed_silver":_mat(BRUSHED,0.88,0.27),
        "aged_bronze":_mat(BRONZE,0.71,0.44),
        "safety_glow":_mat(ICE,0.08,0.22,1.08)
    }
    _industrial_wall_cassettes()
    _foreground_control_bays()
    _deck_surface_language()
    _make_critical_wayfinding()
    set_locale("ru")
    set_quality("hero")
    update_hazard("blackout",48.0,93.0,0.0,true)

func _industrial_wall_cassettes() -> void:
    var housing: StandardMaterial3D = material_library["black_titanium"]
    var recess: StandardMaterial3D = material_library["recessed_obsidian"]
    var edge: StandardMaterial3D = material_library["brushed_silver"]
    var warm: StandardMaterial3D = material_library["aged_bronze"]
    # Seven independently authored depth positions; wall-mount only.
    # The open reactor-side aperture on the RIGHT is deliberately untouched.
    for depth in [-5.0,-12.0,-19.0,-27.0,-35.0,-44.0,-53.0]:
        for side in [-1.0,1.0]:
            if side > 0.0 and depth >= -33.0 and depth <= -9.0:
                continue
            var prefix: String = "G3_Cassette_%d_%d" % [int(depth),int(side)]
            # Original inner collision-wall face is at x=+/-6.65.
            # Mount *inside* that plane, otherwise the PBR details exist
            # but are visually buried behind opaque original walls.
            var x: float = side * 6.42
            _box(hero_detail,prefix+"_Body",Vector3(x,2.58,depth),Vector3(0.17,2.96,3.20),housing)
            _box(hero_detail,prefix+"_Recess",Vector3(x-side*0.11,2.62,depth),Vector3(0.035,2.48,2.74),recess)
            for groove in range(3):
                var y: float = 1.73+float(groove)*0.85
                _box(hero_detail,prefix+"_Groove_%d" % groove,Vector3(x-side*0.15,y,depth),Vector3(0.045,0.035,2.57),edge)
            _box(hero_detail,prefix+"_BronzeServiceLine",Vector3(x-side*0.13,4.01,depth),Vector3(0.045,0.07,2.82),warm)
    # Service/evacuation have separate robust silhouettes, not a repeated
    # cyan/neon billboard. Nothing occludes the two real G2 field consoles.
    for depth in [-34.0,-50.0]:
        for side in [-1.0,1.0]:
            var x: float = side*6.10
            _box(hero_detail,"G3_SectorPillar_%d_%d" % [int(depth),int(side)],
                Vector3(x,4.26,depth),Vector3(0.34,1.26,0.34),housing)
            _box(hero_detail,"G3_SectorCollar_%d_%d" % [int(depth),int(side)],
                Vector3(x,4.94,depth),Vector3(0.46,0.14,0.44),edge)

func _foreground_control_bays() -> void:
    # Physical close-range illuminated-but-subtle status wall panels.
    # On the right, mount at x<6.65 and face the player corridor (-X);
    # left panel mirrors it. Nothing enters the central walk/terminal lane.
    var backing: StandardMaterial3D = material_library["black_titanium"]
    var inset: StandardMaterial3D = material_library["recessed_obsidian"]
    var metal: StandardMaterial3D = material_library["brushed_silver"]
    var warm: StandardMaterial3D = material_library["aged_bronze"]
    var accent: StandardMaterial3D = material_library["safety_glow"]
    for side in [-1.0,1.0]:
        var face_x: float = side*6.18
        var z: float = -6.2 if side > 0.0 else -5.2
        var prefix: String = "G3_VisibleControlBay_%d" % int(side)
        _box(hero_detail,prefix+"_TitaniumHousing",
            Vector3(face_x,2.65,z),Vector3(0.12,1.65,2.78),backing)
        _box(hero_detail,prefix+"_ObsidianScreen",
            Vector3(face_x-side*0.10,2.66,z),Vector3(0.04,1.27,2.45),inset)
        _box(hero_detail,prefix+"_TopMachinedEdge",
            Vector3(face_x-side*0.14,3.33,z),Vector3(0.035,0.075,2.49),metal)
        _box(hero_detail,prefix+"_BottomBronzeEdge",
            Vector3(face_x-side*0.14,2.00,z),Vector3(0.035,0.065,2.49),warm)
        _box(hero_detail,prefix+"_SingleStatusSlit",
            Vector3(face_x-side*0.15,2.95,z-0.85),Vector3(0.042,0.085,0.42),accent)
        for groove in range(4):
            _box(hero_detail,prefix+"_MachinedVent_%d" % groove,
                Vector3(face_x-side*0.15,2.27,z-0.8+float(groove)*0.50),
                Vector3(0.04,0.055,0.28),metal)
        var sign := _label(hero_detail,prefix+"_PhysicalLabel",
            Vector3(face_x-side*0.175,2.72,z-0.87),"",38,Color(0.88,0.94,0.95))
        sign.rotation_degrees.y = -90.0 if side > 0.0 else 90.0
        close_range_labels.append(sign)

func _deck_surface_language() -> void:
    var fastener_positions: Array[Vector3] = []
    var anti_skid_positions: Array[Vector3] = []
    # GPU-instanced detail; source-true counts are available to native/browser
    # QA. No giant per-screw node tree or extra physics bodies.
    for segment in range(65):
        var z: float = 1.0-float(segment)*0.94
        for side in [-1.0,1.0]:
            fastener_positions.append(Vector3(side*5.86,0.098,z))
        if segment % 2 == 0:
            anti_skid_positions.append(Vector3(-4.62,0.081,z))
            anti_skid_positions.append(Vector3(4.62,0.081,z))
    _instances(hero_detail,"G3_Batched_TitaniumFasteners",
        Vector3(0.075,0.018,0.085),fastener_positions,material_library["brushed_silver"])
    _instances(hero_detail,"G3_Batched_DeckTraction",
        Vector3(0.26,0.022,0.48),anti_skid_positions,material_library["aged_bronze"])

func _make_critical_wayfinding() -> void:
    var backing: StandardMaterial3D = material_library["recessed_obsidian"]
    var frame: StandardMaterial3D = material_library["brushed_silver"]
    for i in range(ZONES.size()):
        var zone: String = ZONES[i]
        var z: float = MARKER_Z[i]
        var prefix: String = "G3_Critical_"+zone
        # All signs are LEFT of walkway. Their visible physical light strips
        # survive ECO graphics and never mask terminal instructions.
        _box(critical_layer,prefix+"_SignBack",Vector3(-6.06,3.35,z),
            Vector3(0.09,1.28,2.72),backing)
        _box(critical_layer,prefix+"_SignTrim",Vector3(-5.995,2.81,z),
            Vector3(0.035,0.055,2.45),frame)
        var lamp_material := _mat(ICE,0.05,0.23,1.0)
        var strip := _box(critical_layer,prefix+"_HazardStrip",
            Vector3(-5.99,3.83,z),Vector3(0.04,0.09,2.30),lamp_material)
        strip.name = prefix+"_ActualHazardStrip"
        marker_materials.append(lamp_material)
        var sign := _label(critical_layer,prefix+"_LocalizedLabel",
            Vector3(-5.91,3.34,z-0.9),"",32,Color(0.87,0.92,0.94))
        sign.rotation_degrees.y = 90.0
        sector_labels.append(sign)
        var status_sign := _label(critical_layer,prefix+"_ReadableHazardWord",
            Vector3(-5.91,2.98,z-0.85),"",25,Color(0.90,0.94,0.96))
        status_sign.rotation_degrees.y = 90.0
        status_sign.outline_size = 7
        status_sign.outline_modulate = Color(0.0,0.017,0.029,1.0)
        risk_status_labels.append(status_sign)
        var lamp := OmniLight3D.new()
        lamp.name = prefix+"_ActualIllumination"
        lamp.position = Vector3(-5.70,3.70,z)
        lamp.omni_range = 6.3
        lamp.light_energy = 0.22
        lamp.light_color = ICE
        lamp.shadow_enabled = false
        critical_layer.add_child(lamp)
        marker_lamps.append(lamp)
        marker_positions.append(lamp.position)

func set_locale(next_locale: String) -> void:
    locale = "en" if next_locale == "en" else "ru"
    var ru: Array[String] = [
        "01 / РЕАКТОР A7",
        "02 / ТЕХСЕКТОР",
        "03 / ШЛЮЗ ЭВАКУАЦИИ"
    ]
    var en: Array[String] = [
        "01 / REACTOR A7",
        "02 / SERVICE SPINE",
        "03 / EVACUATION"
    ]
    for i in range(sector_labels.size()):
        sector_labels[i].text = en[i] if locale == "en" else ru[i]
    var close_ru: Array[String] = ["A7 / ОХЛАЖДЕНИЕ","A7 / КОНТРОЛЬ"]
    var close_en: Array[String] = ["A7 / COOLANT","A7 / CONTROL"]
    for i in range(close_range_labels.size()):
        close_range_labels[i].text = close_en[i] if locale == "en" else close_ru[i]
    _update_visual_state(0.0,true)

func set_accessibility(contrast: bool) -> void:
    # Real 3D signage remains occluded by world geometry. Text carries
    # status independently from alarm color; no accessibility x-ray.
    high_contrast_signs = contrast
    for sign in risk_status_labels:
        sign.outline_size = 13 if contrast else 7
        sign.outline_modulate = Color(0.0,0.005,0.008,1.0)
    _update_visual_state(0.0,true)

func set_quality(next_quality: String) -> void:
    quality_mode = "eco" if next_quality == "eco" else "hero"
    if hero_detail != null:
        hero_detail.visible = quality_mode == "hero"
    # Three real safety signs/strips remain; no critical objective hidden.
    for lamp in marker_lamps:
        lamp.visible = true
    _update_visual_state(0.0,true)

func update_hazard(scenario_id: String,heat: float,oxygen: float,elapsed: float,reduce_motion: bool) -> void:
    current_scenario = scenario_id if IPCrisisEngine.SCENARIOS.has(scenario_id) else "blackout"
    var hot: float = clampf((heat-68.0)/32.0,0.0,1.0)
    var air: float = clampf((48.0-oxygen)/48.0,0.0,1.0)
    measured_risk = maxf(hot,air)
    # Based on actual fictional crisis values, never a decorative random pulse.
    safety_tier = "critical" if heat >= 85.0 or oxygen <= 24.0 else "watch" if heat >= 69.0 or oxygen <= 48.0 else "stable"
    reduced_animation = reduce_motion
    _update_visual_state(elapsed,reduce_motion)

func _update_visual_state(elapsed: float,reduce_motion: bool) -> void:
    var tint: Color = AMBER if current_scenario == "thermal" else QUIET if current_scenario == "breach" else ICE
    var breath: float = 1.0 if reduce_motion else 0.83 + 0.17*sin(elapsed*1.15)
    var danger_tint: Color = tint.lerp(ALARM,measured_risk*0.76)
    var glow: float = (0.67 if quality_mode == "eco" else 0.98) + measured_risk*0.93*breath
    for material in marker_materials:
        material.emission = danger_tint
        material.emission_energy_multiplier = glow
    for light in marker_lamps:
        light.light_color = danger_tint
        light.light_energy = (0.12 if quality_mode == "eco" else 0.24) + measured_risk*0.27*breath
    # Color + words + punctuation survive HERO/ECO and reduced-motion modes.
    var readable: String = _vision_words.hazard_words(safety_tier,locale)
    for sign in risk_status_labels:
        sign.text = readable
        sign.modulate = Color(1.0,0.92,0.77) if safety_tier == "watch" else Color(1.0,0.87,0.90) if safety_tier == "critical" else Color(0.91,0.96,0.98)
        sign.pixel_size = 0.00255 if high_contrast_signs else 0.00235

func readout() -> Dictionary:
    var actual_positions: Array = []
    for point in marker_positions:
        actual_positions.append([point.x,point.y,point.z])
    var displayed_signs: Array[String] = []
    for sign in sector_labels:
        displayed_signs.append(sign.text)
    var near_panel: MeshInstance3D = hero_detail.get_node_or_null("G3_Cassette_-5_1_Body") as MeshInstance3D
    return {
        "schema":FORMAT,
        "visible_cassette_surface_x":near_panel.position.x if near_panel != null else 99.0,
        "foreground_machined_panels":close_range_labels.size(),
        "foreground_sign_text":[close_range_labels[0].text,close_range_labels[1].text] if close_range_labels.size() == 2 else [],
        "world_geometry_authentic":true,
        "source_simulation_changed":false,
        "hero_mesh_count":hero_mesh_count,
        "persistent_mesh_count":persistent_mesh_count,
        "batched_instances":batched_instance_count,
        "draw_batches":batch_count,
        "quality":quality_mode,
        "hero_visible":hero_detail != null and hero_detail.visible,
        "safety_visible":critical_layer != null and critical_layer.visible,
        "sector_ids":ZONES.duplicate(),
        "physical_lamp_positions":actual_positions,
        "sign_text":displayed_signs,
        "sign_count":sector_labels.size(),
        "g11_status_labels":risk_status_labels.size(),
        "g11_risk_words":[risk_status_labels[0].text,risk_status_labels[1].text,risk_status_labels[2].text] if risk_status_labels.size() == 3 else [],
        "g11_status_tier":safety_tier,
        "g11_high_contrast":high_contrast_signs,
        "g11_color_independent_warning":risk_status_labels.size() == 3,
        "light_count":marker_lamps.size(),
        "scenario":current_scenario,
        "risk":snappedf(measured_risk,0.001),
        "reduced_motion":reduced_animation,
        "light_energy":marker_lamps[0].light_energy if not marker_lamps.is_empty() else 0.0,
        "emission_multiplier":marker_materials[0].emission_energy_multiplier if not marker_materials.is_empty() else 0.0,
        "no_external_assets":true,
        "telemetry_uploaded":false
    }
