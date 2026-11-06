extends SubViewportContainer
## R44: an ACTUAL 3D ship inspection viewport inside the Aurora garage.
## Uses the same authored imported NX airframe mesh as the live flight ship.
## Isolated camera/world: inspecting never moves or unlocks the flight ship.
const NXHeroScene = preload("res://assets/models/nx08_interceptor_r8.gltf")
const HullVariantsR45Script = preload("res://scripts/hull_variants_r45.gd")
const FleetAirframesR55Script = preload("res://scripts/fleet_airframes_r55.gd")
const FormationBaysR47Script = preload("res://scripts/formation_bays_r47.gd")
const AuroraHangarZeroR54Script = preload("res://scripts/hangar_environment_r54.gd")

const VALID_HULLS = [
    "ship_scout", "ship_interceptor", "ship_guardian"
]

var preview_viewport: SubViewport
var ship_pivot: Node3D
var real_airframe: Node3D
var distinct_hull_r45: Node3D
var primary_airframe_r55: Node3D
var formation_bays_r47: Node3D
var inspection_camera: Camera3D
var hangar_set_r54: Node3D
var camera_distance_r54: float = 22.8
var camera_direction_r54: Vector3 = Vector3(12.0, 7.5, -18.2).normalized()
var last_compact_r54: bool = false
var selected_hull: String = "ship_scout"
var orbit_angle: float = -0.48
var elapsed: float = 0.0
var dragging: bool = false
var previous_pointer_x: float = 0.0

func _ready() -> void:
    name = "R44_RealShip3DInspection"
    mouse_filter = Control.MOUSE_FILTER_STOP
    focus_mode = Control.FOCUS_ALL
    stretch = true
    stretch_shrink = 1
    clip_contents = true
    _make_real_viewport()
    resized.connect(_r54_fit_quality)
    get_viewport().size_changed.connect(_r54_fit_quality)
    _r54_fit_quality()
    set_process(true)

func _material(color: Color, metal: float, rough: float,
        emission: float = 0.0) -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mat.metallic = metal
    mat.roughness = rough
    if emission > 0.0:
        mat.emission_enabled = true
        mat.emission = color
        mat.emission_energy_multiplier = emission
    return mat

func _part(parent: Node3D, name_part: String, mesh: Mesh,
        offset: Vector3, material: Material) -> MeshInstance3D:
    var instance := MeshInstance3D.new()
    instance.name = name_part
    instance.mesh = mesh
    instance.position = offset
    instance.material_override = material
    parent.add_child(instance)
    return instance

func _make_real_viewport() -> void:
    preview_viewport = SubViewport.new()
    preview_viewport.name = "R44_Isolated3DWorld"
    preview_viewport.own_world_3d = true
    preview_viewport.transparent_bg = false
    preview_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
    # stretch=true automatically tracks actual screen pixels, not a fake
    # fixed 640x350 render. Keep a 1:1 native-resolution preview.
    preview_viewport.msaa_3d = Viewport.MSAA_4X
    add_child(preview_viewport)

    var world_root := Node3D.new()
    world_root.name = "R44_DockSet"
    preview_viewport.add_child(world_root)
    # R54: a complete enclosed maintenance hall in this isolated 3D scene.
    hangar_set_r54 = AuroraHangarZeroR54Script.new()
    world_root.add_child(hangar_set_r54)

    var background := WorldEnvironment.new()
    background.name = "R44_DockAtmosphere"
    var environment := Environment.new()
    environment.background_mode = Environment.BG_COLOR
    environment.background_color = Color(0.014, 0.024, 0.038)
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.ambient_light_color = Color(0.50, 0.62, 0.72)
    environment.ambient_light_energy = 0.42
    background.environment = environment
    world_root.add_child(background)

    var floor_mesh := CylinderMesh.new()
    floor_mesh.top_radius = 9.1
    floor_mesh.bottom_radius = 9.1
    floor_mesh.height = 0.32
    floor_mesh.radial_segments = 48
    _part(world_root, "R44_ActualMaintenanceDais", floor_mesh,
        Vector3(0.0, -2.1, 0.0),
        _material(Color(0.055, 0.095, 0.14), 0.65, 0.40))

    var rail_mesh := TorusMesh.new()
    rail_mesh.inner_radius = 8.0
    rail_mesh.outer_radius = 8.13
    rail_mesh.rings = 48
    rail_mesh.ring_segments = 8
    _part(world_root, "R44_CyanServiceRing", rail_mesh,
        Vector3(0.0, -1.91, 0.0),
        _material(Color(0.09, 0.55, 0.73), 0.25, 0.29, 1.5))

    var deck_metal := _material(Color(0.085, 0.14, 0.20), 0.70, 0.39)
    var deck_light := _material(Color(0.08, 0.27, 0.39), 0.22, 0.45, 0.65)
    for row in range(-4, 5):
        var stripe := BoxMesh.new()
        stripe.size = Vector3(15.4, 0.025, 0.028)
        _part(world_root, "R44_DockGridRow_%02d" % (row + 4),
            stripe, Vector3(0.0, -1.91, float(row) * 1.75), deck_light)
    for col in range(-4, 5):
        var stripe := BoxMesh.new()
        stripe.size = Vector3(0.028, 0.025, 15.4)
        _part(world_root, "R44_DockGridColumn_%02d" % (col + 4),
            stripe, Vector3(float(col) * 1.75, -1.91, 0.0), deck_metal)

    formation_bays_r47 = FormationBaysR47Script.new()
    world_root.add_child(formation_bays_r47)

    ship_pivot = Node3D.new()
    ship_pivot.name = "R44_OrbitingInspectionPlatform"
    world_root.add_child(ship_pivot)
    real_airframe = NXHeroScene.instantiate() as Node3D
    real_airframe.name = "R44_ActualImportedNX08Mesh"
    ship_pivot.add_child(real_airframe)
    distinct_hull_r45 = HullVariantsR45Script.new()
    distinct_hull_r45.name = "R45_VisibleFleetVariant"
    ship_pivot.add_child(distinct_hull_r45)
    distinct_hull_r45.set_hull(selected_hull)
    primary_airframe_r55 = FleetAirframesR55Script.new()
    primary_airframe_r55.name = "R55_RealIndependentlySculptedShipViewer"
    ship_pivot.add_child(primary_airframe_r55)
    primary_airframe_r55.set_hull(selected_hull)
    real_airframe.visible = false
    distinct_hull_r45.visible = false
    ship_pivot.rotation.y = orbit_angle

    var key_light := DirectionalLight3D.new()
    key_light.name = "R44_SoftKeyLight"
    key_light.rotation_degrees = Vector3(-58, -34, 0)
    key_light.light_color = Color(0.78, 0.91, 1.0)
    key_light.light_energy = 1.1
    key_light.shadow_enabled = false
    world_root.add_child(key_light)

    var cold_light := OmniLight3D.new()
    cold_light.name = "R44_BlueRim"
    cold_light.position = Vector3(-6.2, 5.0, 3.4)
    cold_light.light_color = Color(0.23, 0.73, 1.0)
    cold_light.light_energy = 2.5
    cold_light.omni_range = 24.0
    cold_light.shadow_enabled = false
    world_root.add_child(cold_light)

    var warm_light := OmniLight3D.new()
    warm_light.name = "R44_AmberHangarFill"
    warm_light.position = Vector3(5.8, 4.8, -6.0)
    warm_light.light_color = Color(1.0, 0.64, 0.31)
    warm_light.light_energy = 1.35
    warm_light.omni_range = 24.0
    warm_light.shadow_enabled = false
    world_root.add_child(warm_light)

    inspection_camera = Camera3D.new()
    inspection_camera.name = "R44_IndependentShipCamera"
    inspection_camera.position = camera_direction_r54 * camera_distance_r54
    inspection_camera.fov = 40.0
    inspection_camera.near = 0.1
    inspection_camera.far = 120.0
    world_root.add_child(inspection_camera)
    inspection_camera.look_at(Vector3(0.0, 0.0, 0.0), Vector3.UP)
    inspection_camera.current = true

func _r54_fit_quality() -> void:
    if not is_instance_valid(preview_viewport):
        return
    # Godot SubViewportContainer.stretch tracks actual Control dimensions
    # automatically. Never manually assign a frozen 640x350 canvas.
    var view_size: Vector2 = get_viewport().get_visible_rect().size
    var compact: bool = view_size.x < 760.0 or view_size.y < 590.0
    last_compact_r54 = compact
    stretch_shrink = 1
    preview_viewport.msaa_3d = (
        Viewport.MSAA_2X if compact else Viewport.MSAA_4X)
    if is_instance_valid(hangar_set_r54):
        hangar_set_r54.set_quality_tier(1 if compact else 0)
    if is_instance_valid(primary_airframe_r55):
        primary_airframe_r55.set_low_detail(compact)

func zoom_r54(direction: int) -> void:
    camera_distance_r54 = clampf(
        camera_distance_r54 + float(clampi(direction, -1, 1)) * 2.1,
        16.0, 32.0)
    if is_instance_valid(inspection_camera):
        inspection_camera.position = camera_direction_r54 * camera_distance_r54
        inspection_camera.look_at(Vector3.ZERO, Vector3.UP)

func _process(delta: float) -> void:
    if not is_visible_in_tree() or not is_instance_valid(ship_pivot):
        return
    elapsed += minf(delta, 0.05)
    if not dragging:
        orbit_angle = wrapf(orbit_angle + minf(delta, 0.05) * 0.14,
            -PI, PI)
    ship_pivot.rotation.y = orbit_angle
    ship_pivot.position.y = 0.11 * sin(elapsed * 0.83)

func set_ship_type(id: String) -> void:
    # R55 draws three independent core meshes, matching actual flight craft.
    # Existing imported NX08 mesh remains intact for safe rollback.
    selected_hull = id if VALID_HULLS.has(id) else "ship_scout"
    if is_instance_valid(distinct_hull_r45):
        distinct_hull_r45.set_hull(selected_hull)
    if is_instance_valid(primary_airframe_r55):
        primary_airframe_r55.set_hull(selected_hull)

func set_workbench_modules_r56(armor: int, shield_rank: int,
        radar_rank: int) -> void:
    if is_instance_valid(primary_airframe_r55):
        primary_airframe_r55.set_modules_r56(armor, shield_rank, radar_rank)

func set_wingmen_r47(ids: Array) -> void:
    if is_instance_valid(formation_bays_r47):
        formation_bays_r47.set_formation(ids)

func rotate_step(direction: int) -> void:
    orbit_angle = wrapf(orbit_angle + float(clampi(direction, -1, 1)) * 0.40,
        -PI, PI)
    if is_instance_valid(ship_pivot):
        ship_pivot.rotation.y = orbit_angle

func _gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.pressed and (
            event.button_index == MOUSE_BUTTON_WHEEL_UP or
            event.button_index == MOUSE_BUTTON_WHEEL_DOWN):
        zoom_r54(-1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1)
        accept_event()
    elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
        dragging = event.pressed
        previous_pointer_x = event.position.x
        accept_event()
    elif event is InputEventMouseMotion and dragging:
        orbit_angle = wrapf(orbit_angle +
            (event.position.x - previous_pointer_x) * 0.008, -PI, PI)
        previous_pointer_x = event.position.x
        accept_event()
    elif event is InputEventScreenTouch:
        dragging = event.pressed
        previous_pointer_x = event.position.x
        accept_event()
    elif event is InputEventScreenDrag and dragging:
        orbit_angle = wrapf(orbit_angle + event.relative.x * 0.008,
            -PI, PI)
        accept_event()
