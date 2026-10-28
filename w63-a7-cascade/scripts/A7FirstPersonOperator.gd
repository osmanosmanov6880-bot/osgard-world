extends Node3D
class_name A7FirstPersonOperator
## W70 — actual first-person physics navigation in the ORIGINAL W67 A7 world.
## Native CharacterBody3D + CapsuleShape3D + StaticBody3D collisions.
## This is a game-only spectator/inspection mechanic, NOT a way to override
## the A7CascadeCore game, never controls any real infrastructure.

const WALK_SPEED := 3.2
const GRAVITY := 19.0
const HEAD_HEIGHT := 0.69
const START_POSITION := Vector3(6.4, 1.33, 6.4)
const COPPER := Color("f1ba7d")
const BLUE := Color("87dce5")

var body: CharacterBody3D
var head_camera: Camera3D
var headlamp: SpotLight3D
var collision_world: Node3D
var collision_shapes: Array[CollisionShape3D] = []
var floor_body: StaticBody3D
var bridge_collision: StaticBody3D
var walkway_visuals: Node3D
var walkway_detail: Node3D
var safety_lights: Array[OmniLight3D] = []
var walkway_visual_meshes: int = 0
var world_sign: Label3D
var compact_view: bool = false
var piloting: bool = false
var reduced_motion: bool = false
var quality: String = "hero"
var held_keys: Dictionary = {}
var tap_key: int = -1
var tap_remaining: float = 0.0
var move_distance: float = 0.0
var collided_frames: int = 0
var frame_updates: int = 0
var inspect_count: int = 0
var last_inspection: String = ""
var mouse_look_events: int = 0
var inspection_console_core: Vector3 = Vector3(4.10, 1.2, 2.14)
var inspection_console_relay: Vector3 = Vector3(8.0, 1.2, 20.0)

func _static_box(id: String, dims: Vector3, at: Vector3) -> StaticBody3D:
    var obstacle := StaticBody3D.new()
    obstacle.name = id
    obstacle.position = at
    collision_world.add_child(obstacle)
    var shape := BoxShape3D.new()
    shape.size = dims
    var collision := CollisionShape3D.new()
    collision.name = id + "_Physics"
    collision.shape = shape
    obstacle.add_child(collision)
    collision_shapes.append(collision)
    return obstacle

func _static_cylinder(id: String, radius: float, height: float,
        at: Vector3) -> StaticBody3D:
    var obstacle := StaticBody3D.new()
    obstacle.name = id
    obstacle.position = at
    collision_world.add_child(obstacle)
    var shape := CylinderShape3D.new()
    shape.radius = radius
    shape.height = height
    var collision := CollisionShape3D.new()
    collision.name = id + "_Physics"
    collision.shape = shape
    obstacle.add_child(collision)
    collision_shapes.append(collision)
    return obstacle

func _walk_box(parent: Node3D, id: String, dims: Vector3, at: Vector3,
        finish: Material) -> MeshInstance3D:
    var mesh := BoxMesh.new()
    mesh.size = dims
    var item := MeshInstance3D.new()
    item.name = id
    item.mesh = mesh
    item.material_override = finish
    item.position = at
    parent.add_child(item)
    walkway_visual_meshes += 1
    return item

func _practical_light(id: String, at: Vector3, tint: Color,
        energy: float) -> OmniLight3D:
    var lamp := OmniLight3D.new()
    lamp.name = id
    lamp.position = at
    lamp.light_color = tint
    lamp.light_energy = energy
    lamp.omni_range = 6.6
    lamp.shadow_enabled = false
    walkway_visuals.add_child(lamp)
    safety_lights.append(lamp)
    return lamp

func _build_visible_route(material_source: A7CinematicMaterialLab) -> void:
    # W70.1: a true architectural composition, not a painted screenshot.
    # Texture references come from the W68 source-verified PBR cache.
    walkway_visuals = Node3D.new()
    walkway_visuals.name = "W70ReadablePhysicalOperatorCatwalk"
    add_child(walkway_visuals)
    walkway_detail = Node3D.new()
    walkway_detail.name = "W70HighFrequencyWalkwayDetail"
    walkway_visuals.add_child(walkway_detail)
    var grate: StandardMaterial3D = material_source.surface("floor_grate")
    var steel: StandardMaterial3D = material_source.surface("reactor_shell")
    var dark: StandardMaterial3D = material_source.surface("dark_steel")
    var hazard: StandardMaterial3D = material_source.surface("painted_hazard")
    var amber := StandardMaterial3D.new()
    amber.albedo_color = COPPER
    amber.emission_enabled = true
    amber.emission = COPPER
    amber.emission_energy_multiplier = 1.3
    amber.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    var cyan := StandardMaterial3D.new()
    cyan.albedo_color = BLUE
    cyan.emission_enabled = true
    cyan.emission = BLUE
    cyan.emission_energy_multiplier = 1.7
    cyan.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    # W67 visible catwalk has x=6.40 and z=5.1..19.7.
    # Real floor collision is now aligned to that actual deck surface.
    for segment in range(13):
        var z: float = 6.10 + float(segment) * 1.02
        _walk_box(walkway_visuals, "PhysicallyWalkedPBRGrate%02d" % segment,
            Vector3(3.35, 0.055, 0.72), Vector3(6.4, 0.347, z), grate)
        _walk_box(walkway_detail, "IndustrialStepEndPlate%02d" % segment,
            Vector3(3.40, 0.07, 0.12), Vector3(6.4, 0.355, z + 0.39), steel)
        _walk_box(walkway_visuals, "CenterDiagnosticTravelArrow%02d" % segment,
            Vector3(0.095, 0.018, 0.31), Vector3(6.4, 0.386, z),
            cyan if segment % 3 == 0 else amber)
        for side in [-1, 1]:
            var x: float = 6.4 + float(side)*1.60
            _walk_box(walkway_visuals, "ContinuousLightGuard%d_%02d" % [side,segment],
                Vector3(0.067, 0.065, 0.91), Vector3(x, 1.39, z),
                cyan if segment % 4 == 0 else amber)
            _walk_box(walkway_detail, "HardwareRailBracket%d_%02d" % [side,segment],
                Vector3(0.28, 0.32, 0.17), Vector3(x, 1.11, z), steel)

    # Strong spatial vanishing points: overhead industrial arches and real
    # practical lights give scale cues instead of a flat empty dark corridor.
    for bay in range(5):
        var z: float = 7.00 + float(bay)*2.55
        for side in [-1, 1]:
            var x: float = 6.4 + float(side)*1.95
            _walk_box(walkway_visuals, "CatwalkElectricalPylon%d_%02d" % [side,bay],
                Vector3(0.30, 4.1, 0.34), Vector3(x, 2.28, z), dark)
            _walk_box(walkway_detail, "PylonAmberSafetyFoot%d_%02d" % [side,bay],
                Vector3(0.39, 0.22, 0.43), Vector3(x, 0.49, z), hazard)
            _walk_box(walkway_visuals, "PylonGroundGlow%d_%02d" % [side,bay],
                Vector3(0.15, 0.11, 0.09), Vector3(x, 1.80, z), amber)
        _walk_box(walkway_visuals, "ArchedIndustrialOverheadTruss%02d" % bay,
            Vector3(4.12, 0.29, 0.38), Vector3(6.4, 4.43, z), steel)
        _walk_box(walkway_visuals, "CeilingCyanServiceLamp%02d" % bay,
            Vector3(1.65, 0.09, 0.27), Vector3(6.4, 4.24, z), cyan)
        if bay < 4:
            _practical_light("ActualPracticalCatwalkLight%02d" % bay,
                Vector3(6.4, 3.95, z + 0.8),
                Color("d9ecf5") if bay%2 == 0 else COPPER,
                1.25)
    # An unmissable industrial sign signals the transition to actual relay hall.
    world_sign = Label3D.new()
    world_sign.name = "ActualWorldSectorTwoGatewaySign"
    world_sign.text = "A7  /  02  POWER RELAY"
    world_sign.font_size = 58
    world_sign.pixel_size = 0.0043
    world_sign.modulate = COPPER
    world_sign.position = Vector3(6.4, 3.25, 18.9)
    world_sign.rotation.y = PI
    walkway_visuals.add_child(world_sign)

func build(material_source: A7CinematicMaterialLab) -> void:
    name = "W70RealFirstPersonOperatorWithPhysics"
    collision_world = Node3D.new()
    collision_world.name = "CollisionWorldAlignedToW67IndustrialRooms"
    add_child(collision_world)
    # Physical footprint follows W67's real visible deck and machine regions.
    floor_body = _static_box("TRUE_A7_GROUND",
        Vector3(22.7, 0.38, 32.4), Vector3(0, -0.36, 9.5))
    bridge_collision = _static_box("ACTUAL_WALKABLE_A7_BRIDGE",
        Vector3(3.55, 0.34, 14.50), Vector3(6.4, 0.16, 12.4))
    _build_visible_route(material_source)
    for side in [-1, 1]:
        _static_box("WestEastSafetyWall%d" % side,
            Vector3(0.64, 5.0, 32.8),
            Vector3(float(side) * 11.65, 2.15, 9.5))
    for end in [-1, 1]:
        _static_box("NorthSouthSafetyWall%d" % end,
            Vector3(23.4, 5.0, 0.64),
            Vector3(0, 2.15, 9.5 + float(end) * 16.6))
    _static_cylinder("RealReactorMachineCollision", 2.08, 4.80,
        Vector3(0, 2.25, -0.25))
    # Capacitors in the truly separate second sector block passage.
    for capacitor in range(3):
        _static_cylinder("RelayPowerCapacitorCollision%d" % capacitor,
            0.77, 4.90,
            Vector3(5.20 + float(capacitor) * 2.80, 2.45, 16.45))
    # A real narrow obstacle, between core and relay, requires steering.
    _static_box("OperatorGuidedSafetyBarrier",
        Vector3(0.84, 1.55, 1.05), Vector3(6.85, 0.58, 11.7))
    _static_box("CoreRealOperatorConsoleCollision",
        Vector3(1.55, 1.65, 0.85), Vector3(4.10, 0.80, 1.16))
    _static_box("RelayRealOperatorConsoleCollision",
        Vector3(1.72, 1.35, 0.80), Vector3(8.0, 0.70, 20.85))

    body = CharacterBody3D.new()
    body.name = "PhysicalFirstPersonPlayerBody"
    body.position = START_POSITION
    body.rotation.y = PI  # Face toward the relay wing along +Z.
    body.collision_layer = 1
    body.collision_mask = 1
    body.floor_snap_length = 0.25
    add_child(body)
    var capsule := CapsuleShape3D.new()
    capsule.radius = 0.33
    capsule.height = 1.75
    var player_collision := CollisionShape3D.new()
    player_collision.name = "OriginalPhysicsOperatorCapsule"
    player_collision.shape = capsule
    body.add_child(player_collision)
    collision_shapes.append(player_collision)

    head_camera = Camera3D.new()
    head_camera.name = "ActualPlayableEyeLevelCamera"
    head_camera.position = Vector3(0, HEAD_HEIGHT, 0)
    head_camera.fov = 74.0
    head_camera.near = 0.09
    head_camera.far = 95.0
    body.add_child(head_camera)

    # Local machine-reading light, physically located on the head camera;
    # stays in ECO but at reduced intensity, never blinding the whole scene.
    headlamp = SpotLight3D.new()
    headlamp.name = "OperatorNativeHeadlamp"
    headlamp.position = Vector3(0, -0.04, -0.10)
    headlamp.light_color = Color("e5f0ed")
    headlamp.light_energy = 2.0
    headlamp.spot_range = 14.5
    headlamp.spot_angle = 34.0
    headlamp.shadow_enabled = false
    head_camera.add_child(headlamp)
    set_active(false)
    set_process(true)
    set_physics_process(false)

func set_active(enabled: bool) -> void:
    piloting = enabled
    held_keys.clear()
    tap_key = -1
    tap_remaining = 0.0
    if body != null:
        body.velocity = Vector3.ZERO
    if head_camera != null:
        head_camera.current = enabled
    set_physics_process(enabled)

func set_quality(mode: String) -> void:
    quality = "eco" if mode == "eco" else "hero"
    if headlamp != null:
        headlamp.light_energy = 0.35 if quality == "eco" else 2.0
        headlamp.spot_range = 7.0 if quality == "eco" else 14.5
    if walkway_detail != null:
        walkway_detail.visible = quality == "hero"
    for lamp in safety_lights:
        lamp.light_energy = 0.36 if quality == "eco" else 1.25

func set_compact_view(enabled: bool) -> void:
    compact_view = enabled
    if world_sign != null:
        world_sign.visible = not compact_view

func set_reduced_motion(enabled: bool) -> void:
    reduced_motion = enabled
    if enabled and head_camera != null:
        head_camera.position.y = HEAD_HEIGHT

func set_key(key: int, down: bool) -> void:
    if not piloting:
        return
    if not [KEY_W, KEY_A, KEY_S, KEY_D].has(key):
        return
    held_keys[key] = down

func nudge(key: int) -> void:
    # Keyboard-independent accessible touch/button equivalent. Motion uses
    # the same CharacterBody3D.move_and_slide(), never teleporting.
    if not piloting:
        return
    if not [KEY_W, KEY_A, KEY_S, KEY_D].has(key):
        return
    tap_key = key
    tap_remaining = 0.30

func rotate_view(delta: Vector2) -> void:
    if not piloting or body == null:
        return
    body.rotate_y(-delta.x * 0.0021)
    head_camera.rotation.x = clampf(
        head_camera.rotation.x - delta.y * 0.0021,
        deg_to_rad(-65.0), deg_to_rad(65.0))
    mouse_look_events += 1

func inspect_nearby() -> String:
    if not piloting:
        return ""
    var core_dist: float = body.position.distance_to(inspection_console_core)
    var relay_dist: float = body.position.distance_to(inspection_console_relay)
    var target: String = ""
    if core_dist < 3.20:
        target = "CORE"
    elif relay_dist < 4.00:
        target = "RELAY"
    if target != "":
        last_inspection = target
        inspect_count += 1
    return target

func _axis() -> Vector2:
    var right: bool = bool(held_keys.get(KEY_D, false)) or (
        tap_key == KEY_D and tap_remaining > 0.0)
    var left: bool = bool(held_keys.get(KEY_A, false)) or (
        tap_key == KEY_A and tap_remaining > 0.0)
    var forward: bool = bool(held_keys.get(KEY_W, false)) or (
        tap_key == KEY_W and tap_remaining > 0.0)
    var back: bool = bool(held_keys.get(KEY_S, false)) or (
        tap_key == KEY_S and tap_remaining > 0.0)
    return Vector2(float(int(right)-int(left)), float(int(back)-int(forward))).normalized()

func _physics_process(delta: float) -> void:
    if not piloting or body == null:
        return
    frame_updates += 1
    var axis: Vector2 = _axis()
    var local: Vector3 = Vector3(axis.x, 0, axis.y)
    var direction: Vector3 = body.transform.basis * local
    body.velocity.x = direction.x * WALK_SPEED
    body.velocity.z = direction.z * WALK_SPEED
    if body.is_on_floor():
        body.velocity.y = -0.18
    else:
        body.velocity.y = maxf(-25.0, body.velocity.y - GRAVITY * delta)
    var before: Vector3 = body.global_position
    body.move_and_slide()
    if body.get_slide_collision_count() > 0:
        collided_frames += 1
    var horizontal: Vector2 = Vector2(
        body.global_position.x - before.x, body.global_position.z - before.z)
    move_distance += horizontal.length()
    # Subtle simulated gait only when enabled; motion-sensitive users may
    # disable it while keeping fully functional physically controlled walking.
    if head_camera != null:
        var bob: float = 0.0
        if not reduced_motion and axis.length() > 0.0 and body.is_on_floor():
            bob = sin(move_distance * 9.2) * 0.014
        head_camera.position.y = HEAD_HEIGHT + bob
    if tap_remaining > 0.0:
        tap_remaining = maxf(0.0, tap_remaining - delta)
        if tap_remaining == 0.0:
            tap_key = -1

func qa_readout() -> Dictionary:
    return {
        "schema": "LAST_FRONTIER_W70_ACTUAL_FIRST_PERSON_GODOT_PHYSICS_V1",
        "real_character_body": body is CharacterBody3D,
        "real_capsule": body != null and
            body.get_node("OriginalPhysicsOperatorCapsule") is CollisionShape3D,
        "real_floor_static_body": floor_body is StaticBody3D,
        "independent_collision_shapes": collision_shapes.size(),
        "real_bridge_collision": bridge_collision is StaticBody3D,
        "real_visible_catwalk_meshes": walkway_visual_meshes,
        "real_practical_catwalk_lights": safety_lights.size(),
        "reused_original_w68_pbr_profiles": true,
        "actual_world_sector_gateway_sign": world_sign != null,
        "compact_world_sign_hidden": compact_view and world_sign != null and not world_sign.visible,
        "uses_move_and_slide": true,
        "physical_camera": head_camera is Camera3D,
        "genuine_headlamp": headlamp is SpotLight3D,
        "enabled": piloting,
        "body_position": [snappedf(body.position.x, 0.001),
            snappedf(body.position.y, 0.001),
            snappedf(body.position.z, 0.001)] if body != null else [],
        "horizontal_distance_m": snappedf(move_distance, 0.001),
        "physics_frames": frame_updates,
        "collision_contact_frames": collided_frames,
        "inspection_interactions": inspect_count,
        "last_inspection": last_inspection,
        "mouse_look_events": mouse_look_events,
        "headlamp_energy": headlamp.light_energy if headlamp != null else 0.0,
        "quality": quality,
        "reduced_motion": reduced_motion,
        "gameplay_authority": false,
        "physical_gpu_certified": false,
    }
