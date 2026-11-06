extends Node3D
## NEBULA R54: actual enclosed maintenance hangar in the isolated ship
## preview World3D. No texture files, network resources or flight collisions.
## All set dressing is genuine mesh geometry visible in the 3D viewport.

const GRAPHITE := Color(0.060, 0.081, 0.109)
const STEEL := Color(0.16, 0.21, 0.27)
const DECK := Color(0.095, 0.125, 0.17)
const WHITE := Color(0.73, 0.84, 0.92)
const CYAN := Color(0.11, 0.58, 0.70)
const AMBER := Color(0.95, 0.53, 0.23)
const DARK := Color(0.020, 0.031, 0.047)

var detail_nodes: Array[Node3D] = []
var service_crane: Node3D
var elapsed: float = 0.0
var shadow_key: SpotLight3D
var local_lights: Array[Light3D] = []

func _ready() -> void:
    name = "R54_AuroraEnclosedIndustrialHangar"
    _construct()
    set_process(true)

func _mat(tint: Color, metal: float = 0.65, rough: float = 0.41,
        glow: float = 0.0) -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    mat.albedo_color = tint
    mat.metallic = metal
    mat.roughness = rough
    if glow > 0.0:
        mat.emission_enabled = true
        mat.emission = tint
        mat.emission_energy_multiplier = glow
    return mat

func _box(parent: Node3D, part_name: String, dims: Vector3,
        at: Vector3, material: Material) -> MeshInstance3D:
    var instance := MeshInstance3D.new()
    instance.name = part_name
    var geom := BoxMesh.new()
    geom.size = dims
    instance.mesh = geom
    instance.position = at
    instance.material_override = material
    parent.add_child(instance)
    return instance

func _cylinder(parent: Node3D, part_name: String, radius: float,
        length: float, at: Vector3, material: Material,
        radial_segments: int = 18) -> MeshInstance3D:
    var part := MeshInstance3D.new()
    part.name = part_name
    var cylinder := CylinderMesh.new()
    cylinder.top_radius = radius
    cylinder.bottom_radius = radius
    cylinder.height = length
    cylinder.radial_segments = radial_segments
    part.mesh = cylinder
    part.position = at
    part.material_override = material
    parent.add_child(part)
    return part

func _label(parent: Node3D, title: String, at: Vector3,
        text_color: Color, pixel_scale: float = 0.008) -> Label3D:
    var text := Label3D.new()
    text.name = "R54_RealHangarWayfinding"
    text.text = title
    text.font_size = 100
    text.pixel_size = pixel_scale
    text.modulate = text_color
    text.position = at
    # In the bay the approach camera looks towards +Z.
    text.rotation.y = PI
    parent.add_child(text)
    return text

func _place_light(at: Vector3, tint: Color, energy: float,
        radius: float) -> OmniLight3D:
    var lamp := OmniLight3D.new()
    lamp.position = at
    lamp.light_color = tint
    lamp.light_energy = energy
    lamp.omni_range = radius
    lamp.shadow_enabled = false
    add_child(lamp)
    local_lights.append(lamp)
    return lamp

func _construct() -> void:
    var black_metal := _mat(DARK, 0.82, 0.50)
    var graphite := _mat(GRAPHITE, 0.77, 0.39)
    var armor := _mat(STEEL, 0.79, 0.32)
    var floor_mat := _mat(DECK, 0.68, 0.56)
    var trim := _mat(Color(0.25, 0.32, 0.39), 0.83, 0.32)
    var cool_lens := _mat(CYAN, 0.20, 0.28, 2.4)
    var warm_lens := _mat(AMBER, 0.15, 0.25, 2.1)
    var reflective := _mat(Color(0.38, 0.49, 0.54), 0.88, 0.21)
    var white_lens := _mat(WHITE, 0.10, 0.33, 1.65)

    # Full-span floor: industrial deck, real service trenches and perimeter.
    _box(self, "R54_Real72mHangarDeck", Vector3(72.0, 0.45, 66.0),
        Vector3(0.0, -2.85, 3.0), floor_mat)
    _box(self, "R54_EquipmentFoundation", Vector3(24.0, 0.25, 22.0),
        Vector3(0.0, -2.57, -0.4), graphite)
    for z in range(-4, 6):
        var span_z: float = float(z) * 5.6
        var seam := _box(self, "R54_FloorPanelJoint_%02d" % (z + 4),
            Vector3(69.0, 0.015, 0.085),
            Vector3(0.0, -2.615, span_z), black_metal)
        detail_nodes.append(seam)
    for side in [-1, 1]:
        var x: float = float(side)
        _box(self, "R54_InsetCraneRail_%s" % str(side),
            Vector3(0.58, 0.09, 59.0),
            Vector3(x * 13.8, -2.52, 1.0), reflective)
        _box(self, "R54_ServiceTrench_%s" % str(side),
            Vector3(1.25, 0.045, 50.0),
            Vector3(x * 17.8, -2.58, 0.0), black_metal)
        _box(self, "R54_MarkingRunway_%s" % str(side),
            Vector3(0.16, 0.026, 42.0),
            Vector3(x * 12.4, -2.53, 0.0), warm_lens)

    # Rear pressure doors, not a sky-colored panel. Deep layered doors,
    # independent guide rails and a strong vertical scale reference.
    _box(self, "R54_RealRearHangarWall",
        Vector3(70.0, 24.0, 2.0), Vector3(0.0, 8.0, 34.0), black_metal)
    for panel_index in 6:
        var x: float = -22.0 + float(panel_index) * 8.8
        var door := _box(self, "R54_ArmoredDoorLeaf_%02d" % panel_index,
            Vector3(8.55, 17.0, 1.0),
            Vector3(x, 6.25, 32.85), graphite)
        detail_nodes.append(door)
        _box(self, "R54_DoorSpine_%02d" % panel_index,
            Vector3(0.25, 16.7, 0.5),
            Vector3(x + 4.06, 6.25, 32.2), trim)
        _box(self, "R54_DoorSignal_%02d" % panel_index,
            Vector3(0.22, 10.4, 0.35),
            Vector3(x + 3.8, 5.4, 32.0), cool_lens)
    _box(self, "R54_OverdoorReinforcedBeam",
        Vector3(62.0, 1.7, 4.0),
        Vector3(0.0, 16.5, 31.5), armor)
    _label(self, "A U R O R A   //   H A N G A R   0 0",
        Vector3(0.0, 18.35, 30.0), WHITE, 0.012)

    # Both side walls have real depth and massive repetitive load-bearing bays.
    for side in [-1, 1]:
        var x: float = float(side)
        _box(self, "R54_ActualSideWall_%s" % str(side),
            Vector3(2.0, 24.0, 65.0),
            Vector3(x * 35.0, 8.0, 3.0), graphite)
        _box(self, "R54_SideCatwalk_%s" % str(side),
            Vector3(7.0, 0.36, 53.0),
            Vector3(x * 30.6, 10.2, 2.0), armor)
        _box(self, "R54_UpperHandrail_%s" % str(side),
            Vector3(0.22, 2.1, 53.0),
            Vector3(x * 26.9, 11.45, 2.0), trim)
        _box(self, "R54_OverheadServiceBus_%s" % str(side),
            Vector3(1.4, 0.7, 59.0),
            Vector3(x * 32.0, 18.5, 2.2), armor)
        for bay_index in 6:
            var z: float = -22.0 + float(bay_index) * 9.5
            _box(self, "R54_LoadColumn_%s_%02d" % [str(side), bay_index],
                Vector3(2.7, 22.0, 2.7),
                Vector3(x * 33.6, 8.0, z), armor)
            _box(self, "R54_HazardLamp_%s_%02d" % [str(side), bay_index],
                Vector3(0.22, 0.6, 2.4),
                Vector3(x * 31.8, 3.0, z), warm_lens)
            _box(self, "R54_LowerServiceCabinet_%s_%02d" % [str(side), bay_index],
                Vector3(2.6, 3.2, 2.8),
                Vector3(x * 31.5, -0.8, z + 3.2), black_metal)
        _label(self, "BAY 0%s  /  SERVICE ACTIVE" % (
            "1" if side == -1 else "2"), Vector3(x * 25.0, 9.3, 28.2),
            AMBER, 0.008)

    # Three gantry trusses establish an actual roof and industrial silhouette.
    _box(self, "R54_HeavyCeilingSlab", Vector3(70.0, 1.1, 64.0),
        Vector3(0.0, 21.5, 2.0), black_metal)
    for row in 3:
        var z: float = -19.0 + float(row) * 21.0
        _box(self, "R54_RoofBoxGirder_%02d" % row,
            Vector3(66.0, 1.3, 1.8),
            Vector3(0.0, 18.2, z), armor)
        for arm in [-1, 1]:
            _box(self, "R54_RoofDiagonal_%d_%02d" % [arm, row],
                Vector3(17.0, 0.35, 0.42),
                Vector3(float(arm) * 18.0, 16.0, z), trim)
        var task_lamp := _box(self, "R54_OverheadTasklight_%02d" % row,
            Vector3(10.0, 0.12, 0.7),
            Vector3(0.0, 17.4, z + 0.8), white_lens)
        detail_nodes.append(task_lamp)
    # Central travelling inspection bridge, with a real hanging maintenance arm.
    service_crane = Node3D.new()
    service_crane.name = "R54_TravellingInspectionCrane"
    service_crane.position = Vector3(-13.0, 0.0, 1.0)
    add_child(service_crane)
    _box(service_crane, "R54_CraneCarrier",
        Vector3(4.4, 0.8, 12.0),
        Vector3(0.0, 15.4, 0.0), armor)
    _box(service_crane, "R54_HydraulicLiftTrack",
        Vector3(0.7, 9.2, 0.7),
        Vector3(0.0, 10.5, 0.0), reflective)
    _box(service_crane, "R54_SuspendedDiagnosticArm",
        Vector3(5.4, 0.6, 1.5),
        Vector3(2.2, 6.0, 0.0), graphite)
    _box(service_crane, "R54_ScannerAperture",
        Vector3(2.1, 0.3, 1.1),
        Vector3(4.6, 5.6, 0.0), cool_lens)

    # Two service tractors, maintenance steps and reserved allied pads.
    for side in [-1, 1]:
        var x: float = float(side)
        var tractor := Node3D.new()
        tractor.name = "R54_RealHangarServiceVehicle_%s" % str(side)
        tractor.position = Vector3(x * 19.0, -2.0, -11.5)
        add_child(tractor)
        _box(tractor, "R54_ArmoredTowCab",
            Vector3(3.2, 2.0, 5.4), Vector3.ZERO, armor)
        _box(tractor, "R54_TowScreen",
            Vector3(2.15, 0.75, 0.09), Vector3(0, 0.55, -2.75), cool_lens)
        for wheel in [-1, 1]:
            var wheel_pos := float(wheel)
            for tandem in [-1, 1]:
                var z: float = float(tandem)
                var tire := _cylinder(tractor,
                    "R54_RealWheel_%s_%s" % [str(wheel), str(tandem)],
                    0.65, 0.50,
                    Vector3(wheel_pos * 1.75, -0.75, z * 1.5), black_metal, 14)
                tire.rotation.z = PI * 0.5
                detail_nodes.append(tire)
        _box(self, "R54_AlliedParkingLine_%s" % str(side),
            Vector3(10.0, 0.045, 0.11),
            Vector3(x * 21.0, -2.49, 13.0), cool_lens)
    for side in [-1, 1]:
        var x: float = float(side)
        _box(self, "R54_EscapeLane_%s" % str(side),
            Vector3(0.18, 0.04, 14.0),
            Vector3(x * 7.9, -2.49, -18.0), warm_lens)
        _box(self, "R54_HydraulicSupportFoot_%s" % str(side),
            Vector3(1.6, 2.2, 2.0),
            Vector3(x * 8.5, -1.45, 8.0), reflective)
    _label(self, "NX FLEET  /  DEPLOYMENT AUTHORIZED",
        Vector3(0.0, 8.4, 32.0), AMBER, 0.007)

    # One shadowed maintenance spotlight and two unshadowed colored fills,
    # kept deliberately low to sustain WebGL / mobile budgets.
    shadow_key = SpotLight3D.new()
    shadow_key.name = "R54_ActualShadowCastingInspectionSpot"
    shadow_key.position = Vector3(-7.0, 15.2, -7.0)
    shadow_key.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
    shadow_key.spot_range = 33.0
    shadow_key.spot_angle = 56.0
    shadow_key.light_color = WHITE
    shadow_key.light_energy = 2.1
    shadow_key.shadow_enabled = true
    add_child(shadow_key)
    _place_light(Vector3(15.0, 7.5, 5.0), CYAN, 1.35, 25.0)
    _place_light(Vector3(-18.0, 7.0, 14.0), AMBER, 0.95, 23.0)

func set_quality_tier(tier: int) -> void:
    # Tier 0 = desktop hero; 1 = compact/touch. Geometry remains intact.
    var compact: bool = tier > 0
    if is_instance_valid(shadow_key):
        shadow_key.shadow_enabled = not compact
    for node in detail_nodes:
        if is_instance_valid(node):
            node.visible = not compact
    if local_lights.size() > 1 and is_instance_valid(local_lights[1]):
        local_lights[1].visible = not compact

func _process(delta: float) -> void:
    if not is_visible_in_tree() or not is_instance_valid(service_crane):
        return
    elapsed += minf(delta, 0.05)
    service_crane.position.x = -13.0 + sin(elapsed * 0.22) * 0.65
