extends Node3D
## NEBULA R60 — genuine short-lived physically simulated aircraft wrecks.
## Real RigidBody3D debris born at the actual damaged player's coordinates.
## Deterministic bounded pieces + no mission currency or reward authority.
const VALID_SHIPS: Array[String] = [
    "ship_scout", "ship_interceptor", "ship_guardian"]
const DEBRIS_COUNT: int = 9
const LIFETIME_SEC: float = 13.0
const FADE_BEGIN_SEC: float = 9.0
const MAX_INHERITED_VELOCITY: float = 165.0
const PART_NAMES: Array[String] = [
    "DamagedFuselage", "PortWingRoot", "StarboardWingRoot",
    "PortOuterWing", "StarboardOuterWing", "TailStrut",
    "BurntEngine", "CanopyFrame", "BrokenArmorPlating"]
var age: float = 0.0
var player_hull: String = "ship_scout"
var last_actual_impact: Vector3 = Vector3.ZERO
var debris: Array[RigidBody3D] = []
var explosion_flash: MeshInstance3D
var debris_materials: Array[StandardMaterial3D] = []
var count_physics_frames: int = 0

static func valid_ship(id: String) -> bool:
    return VALID_SHIPS.has(id)

static func safe_origin(candidate: Vector3) -> Vector3:
    if not candidate.is_finite():
        return Vector3(0, 20, 70)
    return Vector3(clampf(candidate.x, -1800, 1800),
        clampf(candidate.y, 4.5, 280),
        clampf(candidate.z, -1800, 1800))

static func safe_velocity(candidate: Vector3) -> Vector3:
    return candidate.limit_length(MAX_INHERITED_VELOCITY) if (
        candidate.is_finite()) else Vector3.ZERO

static func safe_color(candidate: Color) -> Color:
    # Color.is_finite() does not exist in Godot 4.7.2.
    if (is_nan(candidate.r) or is_inf(candidate.r) or
            is_nan(candidate.g) or is_inf(candidate.g) or
            is_nan(candidate.b) or is_inf(candidate.b) or
            is_nan(candidate.a) or is_inf(candidate.a)):
        return Color(0.35, 0.43, 0.48)
    return candidate

func spawn_crash(at: Vector3, movement: Vector3,
        hull_id: String, metal_color: Color) -> bool:
    if not valid_ship(hull_id) or not at.is_finite():
        return false
    if not debris.is_empty():
        return false
    player_hull = hull_id
    last_actual_impact = safe_origin(at)
    global_position = last_actual_impact
    age = 0.0
    var source_velocity: Vector3 = safe_velocity(movement)
    # Preserve legitimate paint colors while rejecting non-finite RGBA.
    var surface_color: Color = safe_color(metal_color)
    # Nine independent colliding physics objects, all placed within a few
    # meters of the *real* crash. The city stays collision layer 1; the
    # player cannot die again from this VFX (debris collision_layer = 0).
    for index in DEBRIS_COUNT:
        var part := RigidBody3D.new()
        part.name = "R60_PhysicalCrashDebris_%02d_%s" % [
            index + 1, PART_NAMES[index]]
        part.collision_layer = 0
        part.collision_mask = 1
        part.gravity_scale = 0.38
        part.linear_damp = 0.40
        part.angular_damp = 0.72
        part.mass = 0.7 + float(index) * 0.11
        var side: float = -1.0 if index % 2 == 0 else 1.0
        var spread: Vector3 = Vector3(
            side * (0.6 + float(index % 4) * 0.26),
            0.15 + float(index % 3) * 0.22,
            -0.8 + float(index % 5) * 0.36)
        var size3d: Vector3 = Vector3(
            0.32 + float(index % 3) * 0.34,
            0.11 + float(index % 2) * 0.15,
            0.54 + float(index % 4) * 0.34)
        if index == 0:
            size3d = Vector3(1.3, 0.35, 3.1)
        if index == 1 or index == 2:
            size3d = Vector3(2.4, 0.14, 1.1)
        var mesh := BoxMesh.new()
        mesh.size = size3d
        var surface := StandardMaterial3D.new()
        surface.albedo_color = surface_color.lerp(
            Color(0.09, 0.12, 0.14), float(index % 4) * 0.17)
        surface.metallic = 0.76
        surface.roughness = 0.36 + float(index % 2) * 0.12
        debris_materials.append(surface)
        var visual := MeshInstance3D.new()
        visual.name = "R60_ActualTorn3DMetal_%02d" % index
        visual.mesh = mesh
        visual.material_override = surface
        part.add_child(visual)
        var hitbox := CollisionShape3D.new()
        hitbox.name = "R60_PhysicalDebrisCollision"
        var collider := BoxShape3D.new()
        collider.size = size3d
        hitbox.shape = collider
        part.add_child(hitbox)
        add_child(part)
        part.position = spread
        var kick: Vector3 = Vector3(
            side * (7.0 + float(index) * 1.8),
            4.0 + float(index % 3) * 2.4,
            (-1.0 if index % 3 == 0 else 1.0) * (
                5.0 + float(index) * 0.9))
        part.linear_velocity = source_velocity * 0.22 + kick
        part.angular_velocity = Vector3(
            1.5 + float(index) * 0.35, side * 3.0, side * 1.8)
        debris.append(part)
    var glow_material := StandardMaterial3D.new()
    glow_material.albedo_color = Color(1.0, 0.48, 0.12, 0.66)
    glow_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    glow_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    glow_material.emission_enabled = true
    glow_material.emission = Color(1.0, 0.48, 0.12)
    glow_material.emission_energy_multiplier = 2.7
    var shock := SphereMesh.new()
    shock.radius = 1.0
    shock.height = 2.0
    explosion_flash = MeshInstance3D.new()
    explosion_flash.name = "R60_Genuine3DCrashFlash"
    explosion_flash.mesh = shock
    explosion_flash.material_override = glow_material
    explosion_flash.scale = Vector3.ONE * 3.6
    add_child(explosion_flash)
    return true

func _process(dt: float) -> void:
    if debris.is_empty():
        return
    age += clampf(dt, 0.0, 0.25)
    if is_instance_valid(explosion_flash):
        explosion_flash.visible = age < 0.7
        explosion_flash.scale = Vector3.ONE * (
            3.6 + 9.0 * minf(age, 0.7))
        var shader_material: StandardMaterial3D = (
            explosion_flash.material_override as StandardMaterial3D)
        if is_instance_valid(shader_material):
            shader_material.albedo_color.a = clampf(0.65 - age, 0.0, 0.65)
    if age > FADE_BEGIN_SEC:
        var alpha: float = 1.0 - (age - FADE_BEGIN_SEC) / (
            LIFETIME_SEC - FADE_BEGIN_SEC)
        for mat in debris_materials:
            if not is_instance_valid(mat):
                continue
            mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
            mat.albedo_color.a = clampf(alpha, 0.0, 1.0)
    if age >= LIFETIME_SEC:
        queue_free()

func _physics_process(_dt: float) -> void:
    if not debris.is_empty():
        count_physics_frames += 1

func actual_debris_count() -> int:
    var total: int = 0
    for part in debris:
        if is_instance_valid(part) and part.get_node_or_null(
                "R60_PhysicalDebrisCollision") is CollisionShape3D:
            total += 1
    return total
