extends Node3D
class_name IPWorldSectors
## V5 — three physically distinct, original procedural world zones.
## All meshes are fictional scenic geometry and never touch real hardware.
## Repeated decoration is MultiMesh; all architectural shapes are non-colliding.

const SECTORS: Array[String] = ["reactor", "service", "evacuation"]
const IVORY := Color(0.71,0.79,0.83)
const CYAN := Color(0.18,0.78,0.85)
const GOLD := Color(0.89,0.61,0.26)
const CORAL := Color(0.88,0.34,0.30)

var hero_details: Node3D
var sign_nodes: Array[Label3D] = []
var hazard_bands: Array[MeshInstance3D] = []
var hazard_lamps: Array[OmniLight3D] = []
var landmark_ids: Array[String] = []
var geometry_count: int = 0
var instanced_detail_count: int = 0
var quality_mode: String = "hero"
var danger_level: float = 0.0

func _ready() -> void:
    name = "ThreeSectorWorld"
    hero_details = Node3D.new()
    hero_details.name = "HERO_SectorGeometry"
    add_child(hero_details)
    _reactor_gallery()
    _service_spine()
    _evacuation_lock()
    _make_repeating_deck_detail()

func _mat(color: Color, emissive: bool = false, metallic: float = 0.35) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.metallic = metallic
    material.roughness = 0.47
    if emissive:
        material.emission_enabled = true
        material.emission = color
        material.emission_energy_multiplier = 1.1
    return material

func _box(parent: Node3D, pos: Vector3, dims: Vector3, material: Material, label: String = "") -> MeshInstance3D:
    var node := MeshInstance3D.new()
    node.name = label if label != "" else "IndustrialTrim"
    var mesh := BoxMesh.new()
    mesh.size = dims
    node.mesh = mesh
    node.position = pos
    node.material_override = material
    parent.add_child(node)
    geometry_count += 1
    return node

func _cylinder(parent: Node3D, pos: Vector3, radius: float, height: float, material: Material, label: String) -> MeshInstance3D:
    var node := MeshInstance3D.new()
    node.name = label
    var mesh := CylinderMesh.new()
    mesh.top_radius = radius
    mesh.bottom_radius = radius
    mesh.height = height
    mesh.radial_segments = 16
    node.mesh = mesh
    node.position = pos
    node.material_override = material
    parent.add_child(node)
    geometry_count += 1
    return node

func _ring(parent: Node3D, pos: Vector3, radius: float, material: Material, label: String) -> MeshInstance3D:
    var node := MeshInstance3D.new()
    node.name = label
    var mesh := TorusMesh.new()
    mesh.inner_radius = radius
    mesh.outer_radius = radius + 0.19
    mesh.rings = 24
    mesh.ring_segments = 10
    node.mesh = mesh
    node.rotation_degrees.x = 90.0
    node.position = pos
    node.material_override = material
    parent.add_child(node)
    geometry_count += 1
    return node

func _sector_sign(z: float, words: String, accent: Color, sector: String) -> void:
    var panel := Node3D.new()
    panel.name = "SectorMarker_" + sector
    panel.position = Vector3(0,0,z)
    add_child(panel)
    _box(panel,Vector3(0,4.85,0),Vector3(4.45,0.78,0.16),_mat(Color(0.055,0.11,0.16)),sector + "DirectoryPanel")
    var border := _box(panel,Vector3(0,4.45,0.13),Vector3(4.2,0.055,0.09),_mat(accent,true),sector + "DirectoryUnderline")
    hazard_bands.append(border)
    var sign := Label3D.new()
    sign.name = "SectorName_" + sector
    sign.text = words
    sign.font_size = 46
    sign.pixel_size = 0.00225
    sign.position = Vector3(0,4.87,0.16)
    sign.modulate = IVORY
    panel.add_child(sign)
    sign_nodes.append(sign)
    var lamp := OmniLight3D.new()
    lamp.name = "SectorLamp_" + sector
    lamp.position = Vector3(0,4.55,z)
    lamp.omni_range = 9.0
    lamp.light_energy = 0.50
    lamp.light_color = accent
    lamp.shadow_enabled = false
    add_child(lamp)
    hazard_lamps.append(lamp)
    landmark_ids.append(sector)

func _reactor_gallery() -> void:
    var steel := _mat(Color(0.23,0.33,0.40))
    var glossy := _mat(Color(0.42,0.56,0.64))
    var cyan := _mat(CYAN,true,0.12)
    # Distinct rotating-lab gallery silhouette, placed beside the central path.
    _cylinder(hero_details,Vector3(-5.8,2.8,-19.5),0.65,5.0,steel,"GalleryCoolantDrum_L")
    # Original right vessel blocked the security camera's direct plasma-core
    # line of sight. Relocate the *real mesh* to the far industrial service bay.
    _cylinder(hero_details,Vector3(16.25,2.8,-12.5),0.65,5.0,steel,"GalleryCoolantDrum_R")
    for i in 3:
        _ring(hero_details,Vector3(-5.8,3.2,-19.5+float(i)*0.55),1.04,glossy,"GalleryContainmentRing_L_%d" % i)
        _ring(hero_details,Vector3(16.25,3.2,-12.5+float(i)*0.55),1.04,glossy,"GalleryContainmentRing_R_%d" % i)
    # The old 10m-long bridge covered the cinematic view with an enormous
    # flat foreground rectangle; keep the industrial structure on the left.
    _box(hero_details,Vector3(-3.8,5.05,-19.5),Vector3(3.1,0.25,0.33),steel,"GalleryCatwalkBeam")
    _box(hero_details,Vector3(-3.8,4.85,-19.5),Vector3(3.0,0.055,0.14),cyan,"GalleryObservationRibbon")
    _sector_sign(-9.7,"01 / REACTOR GALLERY",CYAN,"reactor")

func _service_spine() -> void:
    var steel := _mat(Color(0.31,0.30,0.31))
    var dark := _mat(Color(0.15,0.21,0.26))
    var amber := _mat(GOLD,true,0.11)
    for offset in [-2.0,2.0]:
        _cylinder(hero_details,Vector3(-5.2,2.5,-35.0+offset),0.42,4.1,steel,"ServicePressureTank_L")
        _cylinder(hero_details,Vector3(5.2,2.5,-35.0+offset),0.42,4.1,steel,"ServicePressureTank_R")
    _box(hero_details,Vector3(0,5.20,-35.0),Vector3(11.5,0.46,1.25),dark,"ServiceSuspendedManifold")
    for i in 6:
        var z := -32.0-float(i)*1.10
        _box(hero_details,Vector3(-5.65,1.9,z),Vector3(0.28,2.45,0.30),steel,"ServiceHeatSink_L_%d" % i)
        _box(hero_details,Vector3(5.65,1.9,z),Vector3(0.28,2.45,0.30),steel,"ServiceHeatSink_R_%d" % i)
        if i % 2 == 0:
            _box(hero_details,Vector3(0,5.00,z),Vector3(10.5,0.07,0.17),amber,"ServicePressureGauge_%d" % i)
    _sector_sign(-29.5,"02 / SERVICE SPINE",GOLD,"service")

func _evacuation_lock() -> void:
    var armor := _mat(Color(0.35,0.41,0.44))
    var graphite := _mat(Color(0.14,0.19,0.24))
    var orange := _mat(GOLD,true,0.10)
    for z in [-50.0,-55.5]:
        _box(hero_details,Vector3(-5.9,2.55,z),Vector3(0.72,5.05,0.63),armor,"ExitBulkheadPier_L")
        _box(hero_details,Vector3(5.9,2.55,z),Vector3(0.72,5.05,0.63),armor,"ExitBulkheadPier_R")
        _box(hero_details,Vector3(0,5.15,z),Vector3(11.7,0.65,0.9),graphite,"ExitReinforcedLintel")
        _box(hero_details,Vector3(0,4.70,z),Vector3(10.8,0.12,0.21),orange,"ExitHazardRibbon")
    for side in [-1.0,1.0]:
        for i in 4:
            var z := -49.0-float(i)*2.15
            _box(hero_details,Vector3(side*4.95,0.15,z),Vector3(0.55,0.16,0.35),orange,"ExitFloorReflector")
    _sector_sign(-48.0,"03 / EVACUATION LOCK",CORAL,"evacuation")

func _make_repeating_deck_detail() -> void:
    var transforms: Array[Transform3D] = []
    # 108 mechanical floor fasteners rendered with one GPU draw group.
    for side in [-1.0,1.0]:
        for index in 54:
            var z := -4.0-float(index)*0.95
            var point := Vector3(side*5.38,0.125,z)
            transforms.append(Transform3D(Basis(),point))
    var mesh := BoxMesh.new()
    mesh.size = Vector3(0.11,0.04,0.17)
    var multi := MultiMesh.new()
    multi.transform_format = MultiMesh.TRANSFORM_3D
    multi.mesh = mesh
    multi.instance_count = transforms.size()
    for index in range(transforms.size()):
        multi.set_instance_transform(index,transforms[index])
    var renderer := MultiMeshInstance3D.new()
    renderer.name = "OneDrawCallDeckFasteners"
    renderer.multimesh = multi
    renderer.material_override = _mat(Color(0.66,0.73,0.77))
    hero_details.add_child(renderer)
    instanced_detail_count = transforms.size()

func current_sector(global_z: float) -> String:
    if global_z > -24.0:
        return "reactor"
    if global_z > -44.0:
        return "service"
    return "evacuation"

func set_quality(next_mode: String) -> void:
    quality_mode = "eco" if next_mode == "eco" else "hero"
    hero_details.visible = quality_mode == "hero"
    for lamp in hazard_lamps:
        lamp.light_energy = 0.19 if quality_mode == "eco" else 0.50

func update_hazard(scenario_id: String, heat: float, oxygen: float, reduce_motion: bool) -> void:
    var heat_risk: float = clampf((heat-58.0)/42.0,0.0,1.0)
    var oxygen_risk: float = clampf((65.0-oxygen)/65.0,0.0,1.0)
    danger_level = maxf(heat_risk,oxygen_risk)
    var tint: Color = GOLD if scenario_id == "thermal" else CYAN if scenario_id == "breach" else CORAL
    for lamp in hazard_lamps:
        lamp.light_color = tint
        lamp.light_energy = (0.20 if quality_mode == "eco" else 0.48) + danger_level*0.25
    for band in hazard_bands:
        var material: StandardMaterial3D = band.material_override as StandardMaterial3D
        if material != null:
            material.emission = tint
            material.emission_energy_multiplier = 1.0 + danger_level*(0.22 if reduce_motion else 0.58)

func readout() -> Dictionary:
    return {
        "zones":SECTORS.duplicate(),
        "zone_count":SECTORS.size(),
        "landmark_ids":landmark_ids.duplicate(),
        "sign_count":sign_nodes.size(),
        "geometry_count":geometry_count,
        "instanced_detail_count":instanced_detail_count,
        "single_draw_deck":hero_details.get_node_or_null("OneDrawCallDeckFasteners") != null,
        "hazard_lamps":hazard_lamps.size(),
        "danger_level":danger_level,
        "quality":quality_mode,
        "hero_visible":hero_details.visible
    }
