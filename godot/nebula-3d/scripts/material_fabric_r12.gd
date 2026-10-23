extends RefCounted
## NEBULA R12: three original repeatable physically based industrial surfaces.
## Shared, cached albedo / tangent normal / AO-roughness-metallic textures.
## No external services and no copy-per-building texture allocations.

const SIZE: int = 384
static var _materials: Dictionary = {}
static var _atlas_images: Dictionary = {}

static func _noise(x: int, y: int, seed: int) -> float:
    var n: int = (x * 73856093) ^ (y * 19349663) ^ (seed * 83492791)
    n = (n ^ (n >> 13)) & 2147483647
    return float(n % 65521) / 65520.0

static func _create(profile: int) -> StandardMaterial3D:
    var albedo := Image.create(SIZE, SIZE, false, Image.FORMAT_RGB8)
    var normal := Image.create(SIZE, SIZE, false, Image.FORMAT_RGB8)
    var orm := Image.create(SIZE, SIZE, false, Image.FORMAT_RGB8)
    var base := Color(0.41, 0.46, 0.48)
    if profile == 1:
        base = Color(0.66, 0.69, 0.66)
    elif profile == 2:
        base = Color(0.18, 0.24, 0.29)
    for y in SIZE:
        for x in SIZE:
            var cell_x: int = int(x / 96)
            var cell_y: int = int(y / 96)
            var local_x: int = x % 96
            var local_y: int = y % 96
            var fine: float = _noise(x, y, 11 + profile)
            var medium: float = _noise(int(x / 5), int(y / 5), 42 + profile)
            var area: float = _noise(cell_x, cell_y, 79 + profile)
            var scratch: float = sin(float(x) * 1.17 + float(y) * 0.075)
            var crossing: float = sin(float(y) * 1.98 + float(x) * 0.04)
            var seam: bool = local_x <= 1 or local_y <= 1
            var bolt: bool = ((local_x - 10) * (local_x - 10) + (local_y - 10) * (local_y - 10)) <= 12
            var edge: float = 1.0 - smoothstep(0.0, 8.0,
                float(mini(mini(local_x, 95 - local_x),
                mini(local_y, 95 - local_y))))
            var chipped: float = maxf(0.0, medium - 0.65) * edge
            var grime: float = maxf(0.0, 0.43 - medium) * 0.38
            var shade: Color = base * (0.83 + area * 0.23 +
                (fine - 0.5) * 0.095 + scratch * 0.035)
            var nx: float = (scratch + crossing * 0.15) * 0.047
            var ny: float = (fine - 0.5) * 0.073
            var rough: float = 0.31 + (1.0 - medium) * 0.23 + grime * 0.22
            var metal: float = 0.87
            if profile == 1:
                rough += 0.13
                metal = 0.34
            elif profile == 2:
                rough += 0.23
                metal = 0.49
            var occlusion: float = 0.94
            if seam:
                shade = Color(0.033, 0.045, 0.050)
                nx = -0.22 if local_x <= 1 else 0.0
                ny = -0.20 if local_y <= 1 else 0.0
                rough = 0.90
                occlusion = 0.38
            elif bolt:
                shade = Color(0.24, 0.27, 0.28)
                nx += 0.16
                ny -= 0.13
                metal = 0.84
                occlusion = 0.58
            else:
                shade = shade.darkened(grime)
                if chipped > 0.01:
                    shade = shade.lerp(Color(0.59, 0.61, 0.60),
                                      minf(0.66, chipped * 2.0))
                    rough = minf(0.91, rough + chipped * 0.62)
                if profile == 0 and edge > 0.44 and fine > 0.84:
                    shade = shade.lerp(Color(0.47, 0.29, 0.19), 0.17)
            albedo.set_pixel(x, y, shade)
            normal.set_pixel(x, y, Color(
                clampf(0.5 + nx, 0.0, 1.0),
                clampf(0.5 + ny, 0.0, 1.0), 1.0))
            orm.set_pixel(x, y, Color(occlusion,
                clampf(rough, 0.15, 0.95), metal))
    albedo.generate_mipmaps()
    normal.generate_mipmaps()
    orm.generate_mipmaps()
    var packed := ImageTexture.create_from_image(orm)
    var mat := StandardMaterial3D.new()
    mat.resource_name = [
        "R12 Wire-brushed machined titanium",
        "R12 Patinated ceramic panels",
        "R12 Satin carbon composite"
    ][profile]
    mat.albedo_texture = ImageTexture.create_from_image(albedo)
    mat.albedo_color = Color(0.96, 0.97, 0.98)
    mat.normal_enabled = true
    mat.normal_texture = ImageTexture.create_from_image(normal)
    mat.normal_scale = 0.48
    mat.ao_enabled = true
    mat.ao_texture = packed
    mat.ao_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
    mat.roughness = 1.0
    mat.roughness_texture = packed
    mat.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
    mat.metallic = 1.0
    mat.metallic_texture = packed
    mat.metallic_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_BLUE
    mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
    mat.uv1_scale = Vector3(2.0, 2.0, 1.0)
    _atlas_images[profile] = [albedo, normal, orm]
    return mat

static func get_material(profile: int) -> StandardMaterial3D:
    var id: int = clampi(profile, 0, 2)
    if not _materials.has(id):
        _materials[id] = _create(id)
    return _materials[id]

static func atlas_count() -> int:
    return _materials.size()

static func resolution() -> int:
    return SIZE
