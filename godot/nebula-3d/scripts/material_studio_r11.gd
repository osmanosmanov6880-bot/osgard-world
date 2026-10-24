extends RefCounted
## R11 shared 512px 3-channel PBR industrial metal atlas.
## Two 512px RGB textures and one packed AO/roughness/metallic texture.
## Offline-style deterministic fabrication at start; cached across districts.

const SIZE: int = 512
static var _cache: Dictionary = {}
static var _r20_baked_used: bool = false

static func baked_count() -> int:
    return 1 if _r20_baked_used else 0

static func _r20_load_exact_deck() -> Dictionary:
    var images: Dictionary = {}
    for channel in ["albedo", "normal", "orm"]:
        var name: String = "res://assets/r20_baked/deck_" + channel + ".png"
        if not ResourceLoader.exists(name):
            return {}
        var texture: Texture2D = ResourceLoader.load(name) as Texture2D
        if texture == null or texture.get_width() != SIZE or texture.get_height() != SIZE:
            return {}
        images[channel] = texture
    return images

static func _assemble(albedo_tex: Texture2D, normal_tex: Texture2D, packed: Texture2D) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.resource_name = "R11 Weathered brushed industrial steel"
    material.albedo_texture = albedo_tex
    material.albedo_color = Color(0.87, 0.92, 0.95)
    material.normal_enabled = true
    material.normal_texture = normal_tex
    material.normal_scale = 0.39
    material.ao_enabled = true
    material.ao_texture = packed
    material.ao_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
    material.roughness = 1.0
    material.roughness_texture = packed
    material.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
    material.metallic = 1.0
    material.metallic_texture = packed
    material.metallic_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_BLUE
    material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
    return material

static func _hash(x: int, y: int, salt: int) -> float:
    var n: int = (x * 73856093) ^ (y * 19349663) ^ (salt * 83492791)
    n = (n ^ (n >> 13)) & 2147483647
    return float(n % 65521) / 65520.0

static func make_weathered_deck() -> StandardMaterial3D:
    if _cache.has("deck"):
        return _cache["deck"]
    var packed_assets: Dictionary = _r20_load_exact_deck()
    if not packed_assets.is_empty():
        _r20_baked_used = true
        var ready: StandardMaterial3D = _assemble(
            packed_assets["albedo"], packed_assets["normal"], packed_assets["orm"])
        _cache["deck"] = ready
        return ready
    var diffuse := Image.create(SIZE, SIZE, false, Image.FORMAT_RGB8)
    var bump := Image.create(SIZE, SIZE, false, Image.FORMAT_RGB8)
    var orm := Image.create(SIZE, SIZE, false, Image.FORMAT_RGB8)
    for y in SIZE:
        for x in SIZE:
            var tile_x: int = int(x / 64)
            var tile_y: int = int(y / 64)
            var lx: int = x % 64
            var ly: int = y % 64
            var fine: float = _hash(x, y, 17)
            var broad: float = _hash(int(x / 7), int(y / 7), 27)
            var seed: float = _hash(tile_x, tile_y, 91)
            var seam: bool = lx <= 1 or ly <= 1
            var cross: bool = lx == 15 or lx == 31 or lx == 47
            var edge: float = 1.0 - smoothstep(0.0, 8.0, float(mini(mini(lx, ly), mini(63 - lx, 63 - ly))))
            var stain: float = maxf(0.0, 0.43 - broad) * 0.49
            var oxidation: float = maxf(0.0, fine - 0.84) * edge * 0.65
            var streak: float = sin(float(x) * 0.34 + sin(float(y) * 0.055) * 1.9)
            var color := Color(0.30, 0.34, 0.37) * (0.82 + seed * 0.19 + streak * 0.045)
            color = color.lerp(Color(0.12, 0.14, 0.16), stain)
            color = color.lerp(Color(0.54, 0.32, 0.19), oxidation)
            if seam:
                color = Color(0.032, 0.038, 0.047)
            elif cross:
                color = color.darkened(0.18)
            elif edge > 0.37 and fine > 0.68:
                color = color.lightened(0.20)
            var dx: float = 0.50 + streak * 0.05
            var dy: float = 0.50 + (fine - 0.5) * 0.08
            if seam:
                dx -= 0.20 if lx < 2 else 0.0
                dy -= 0.20 if ly < 2 else 0.0
            var rough: float = clampf(0.37 + stain * 0.48 + seed * 0.13 + edge * 0.12, 0.27, 0.88)
            if seam:
                rough = 0.94
            var occlusion: float = 0.42 if seam else 0.93 - edge * 0.08
            var metal: float = 0.70 if oxidation > 0.04 else 0.86
            diffuse.set_pixel(x, y, color)
            bump.set_pixel(x, y, Color(clampf(dx, 0, 1), clampf(dy, 0, 1), 1.0))
            orm.set_pixel(x, y, Color(occlusion, rough, metal))
    diffuse.generate_mipmaps()
    bump.generate_mipmaps()
    orm.generate_mipmaps()
    var material: StandardMaterial3D = _assemble(
        ImageTexture.create_from_image(diffuse),
        ImageTexture.create_from_image(bump),
        ImageTexture.create_from_image(orm))
    _cache["deck"] = material
    return material

static func atlas_count() -> int:
    return _cache.size()
