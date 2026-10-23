extends RefCounted
## NEBULA R9 / shared physically-based micro-surface material library.
## Generates each atlas only once for all sectors. All channels are real
## textures: albedo, tangent normal and packed occlusion/roughness/metallic.
## Designed for Godot 4.7 GL Compatibility, no compute shaders or HDR hacks.

const RESOLUTION: int = 384
static var _atlases: Dictionary = {}
static var _coated: Dictionary = {}
static var _r17_baked_used: Dictionary = {}

static func _r17_baked_atlas(kind: int) -> Dictionary:
    # Godot imports the generated PNGs into PCK at build time.
    # In a fresh developer checkout (no baked textures), the original
    # 384px procedural generator remains a pixel-for-pixel fallback.
    var atlas: Dictionary = {}
    for channel in ["albedo", "normal", "orm"]:
        var file: String = "res://assets/r17_pbr/r9_%d_%s.png" % [kind, channel]
        if not ResourceLoader.exists(file):
            return {}
        var texture: Texture2D = ResourceLoader.load(file) as Texture2D
        if texture == null or texture.get_width() != RESOLUTION or texture.get_height() != RESOLUTION:
            return {}
        atlas[channel] = texture
    return atlas

static func baked_count() -> int:
    return _r17_baked_used.size()

static func _hash(x: int, y: int, seed: int) -> float:
    var value: int = (x * 374761393 + y * 668265263 + seed * 1442691) & 2147483647
    value = (value ^ (value >> 13)) * 1274126177 & 2147483647
    return float(value & 65535) / 65535.0

static func _atlas(kind: int) -> Dictionary:
    if _atlases.has(kind):
        return _atlases[kind]
    var prebuilt: Dictionary = _r17_baked_atlas(kind)
    if not prebuilt.is_empty():
        _atlases[kind] = prebuilt
        _r17_baked_used[kind] = true
        return prebuilt
    var albedo := Image.create(RESOLUTION, RESOLUTION, false, Image.FORMAT_RGB8)
    var normal := Image.create(RESOLUTION, RESOLUTION, false, Image.FORMAT_RGB8)
    var orm := Image.create(RESOLUTION, RESOLUTION, false, Image.FORMAT_RGB8)
    var warm_steel: bool = kind == 2
    var ceramic: bool = kind == 3
    var carbon: bool = kind == 0
    var base: Color = Color(0.37, 0.43, 0.48)
    if carbon:
        base = Color(0.23, 0.27, 0.32)
    elif warm_steel:
        base = Color(0.39, 0.37, 0.33)
    elif ceramic:
        base = Color(0.69, 0.72, 0.71)
    for y in RESOLUTION:
        for x in RESOLUTION:
            var gx: int = x % 96
            var gy: int = y % 96
            var cell_x: int = int(x / 96)
            var cell_y: int = int(y / 96)
            var fine: float = _hash(x, y, kind + 31)
            var chipped: float = _hash(int(x / 3), int(y / 3), kind + 61)
            var panel_tint: float = _hash(cell_x, cell_y, 12 + kind)
            var hairline: bool = gx <= 1 or gy <= 1
            var fastener: bool = (gx - 12) * (gx - 12) + (gy - 12) * (gy - 12) <= 12
            var hair_scratches: float = sin(float(x) * 0.57 + sin(float(y) * 0.018) * 3.0)
            var directional: float = sin(float(x) * 1.65 + float(y) * 0.011)
            var scar: float = maxf(0.0, directional - 0.93)
            var edge_distance: float = float(mini(mini(gx, gy), mini(95 - gx, 95 - gy)))
            var edge_wear: float = 1.0 - smoothstep(1.0, 8.0, edge_distance)
            var oxidation: float = (1.0 - fine) * 0.042
            var amplitude: float = 0.84 + panel_tint * 0.18
            var shade: Color = base * (amplitude + (fine - 0.5) * 0.09 + hair_scratches * 0.027)
            if hairline:
                shade = Color(0.025, 0.034, 0.044) if not ceramic else Color(0.15, 0.17, 0.18)
            elif fastener:
                shade = Color(0.17, 0.20, 0.22)
            elif chipped > 0.82 and edge_wear > 0.24:
                shade = shade.lerp(Color(0.59, 0.60, 0.58), 0.74)
            else:
                shade = shade.darkened(oxidation)
                if warm_steel and edge_wear > 0.45:
                    shade = shade.lerp(Color(0.51, 0.31, 0.18), 0.23 * edge_wear)
                if scar > 0.01:
                    shade = shade.lightened(minf(0.14, scar * 1.4))
            albedo.set_pixel(x, y, shade)
            var d_x: float = clampf(-hair_scratches * 0.043 + scar * 0.21, -0.27, 0.27)
            var d_y: float = clampf(-directional * 0.022 + (fine - 0.5) * 0.043, -0.25, 0.25)
            if hairline:
                d_x = -0.18 if gx <= 1 else 0.0
                d_y = -0.18 if gy <= 1 else 0.0
            normal.set_pixel(x, y, Color(0.5 + d_x, 0.5 + d_y, 1.0))
            var roughness: float = 0.36 + (fine - 0.5) * 0.21 + edge_wear * 0.22
            if ceramic:
                roughness = 0.55 + (fine - 0.5) * 0.15
            if carbon:
                roughness = 0.63 + (fine - 0.5) * 0.12
            var ambient_occlusion: float = 0.95 - edge_wear * 0.12
            if hairline:
                roughness = 0.81
                ambient_occlusion = 0.48
            var metallic: float = 0.16 if ceramic else 0.29 if carbon else 0.87
            if chipped > 0.82 and edge_wear > 0.24:
                metallic = 0.88
            orm.set_pixel(x, y, Color(ambient_occlusion, clampf(roughness, 0.12, 0.95), metallic))
    albedo.generate_mipmaps()
    normal.generate_mipmaps()
    orm.generate_mipmaps()
    var result := {
        "albedo": ImageTexture.create_from_image(albedo),
        "normal": ImageTexture.create_from_image(normal),
        "orm": ImageTexture.create_from_image(orm)
    }
    _atlases[kind] = result
    return result

static func coat(original: StandardMaterial3D, kind: int) -> StandardMaterial3D:
    var key: String = str(original.get_instance_id()) + "/" + str(kind)
    if _coated.has(key):
        return _coated[key]
    var maps: Dictionary = _atlas(kind)
    var mat := original.duplicate() as StandardMaterial3D
    mat.resource_name = "R9 / " + original.resource_name
    mat.albedo_texture = maps["albedo"]
    mat.normal_enabled = true
    mat.normal_texture = maps["normal"]
    mat.normal_scale = 0.36
    mat.ao_enabled = true
    mat.ao_texture = maps["orm"]
    mat.ao_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
    mat.roughness = 1.0
    mat.roughness_texture = maps["orm"]
    mat.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
    mat.metallic = 1.0
    mat.metallic_texture = maps["orm"]
    mat.metallic_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_BLUE
    mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
    mat.uv1_scale = Vector3.ONE
    _coated[key] = mat
    return mat

static func get_profile(original: StandardMaterial3D) -> int:
    var name: String = original.resource_name.to_lower()
    if "carbon" in name or "graphite" in name:
        return 0
    if "ceramic" in name:
        return 3
    if "copper" in name or "worn" in name or "tungsten" in name:
        return 2
    return 1

static func maps(kind: int) -> Dictionary:
    return _atlas(kind)

static func atlas_count() -> int:
    return _atlases.size()
