extends RefCounted
class_name A7CinematicMaterialLab
## W68 / entirely original deterministic CPU-authored PBR microtexture library.
## Uses genuine ImageTexture and StandardMaterial3D; zero remote images,
## zero third-party assets, and no baked/mockup screenshot fragments.

const RESOLUTION := 96
const PRESETS := {
    "reactor_shell": {"hex": "a9b4b9", "metal": 0.22, "rough": 0.57, "seed": 2001},
    "dark_steel": {"hex": "596775", "metal": 0.19, "rough": 0.69, "seed": 2199},
    "oxide": {"hex": "a27d61", "metal": 0.12, "rough": 0.77, "seed": 2273},
    "ceramic": {"hex": "d1d7d1", "metal": 0.03, "rough": 0.72, "seed": 2411},
    "rubber": {"hex": "354550", "metal": 0.01, "rough": 0.91, "seed": 2519},
    "painted_hazard": {"hex": "e5af69", "metal": 0.04, "rough": 0.62, "seed": 2689},
    "floor_grate": {"hex": "65757c", "metal": 0.17, "rough": 0.79, "seed": 2819},
}

var _cache: Dictionary = {}
var generated: int = 0
var pixels_written: int = 0

func surface(profile: String) -> StandardMaterial3D:
    if _cache.has(profile):
        return _cache[profile] as StandardMaterial3D
    if not PRESETS.has(profile):
        return surface("dark_steel")
    var settings: Dictionary = PRESETS[profile]
    var noise := FastNoiseLite.new()
    noise.seed = int(settings["seed"])
    noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
    noise.frequency = 0.052
    noise.fractal_type = FastNoiseLite.FRACTAL_FBM
    noise.fractal_octaves = 3
    var image := Image.create(RESOLUTION, RESOLUTION, false, Image.FORMAT_RGBA8)
    var rust: bool = profile == "oxide" or profile == "dark_steel"
    var scratch: bool = profile != "rubber" and profile != "ceramic"
    for yy in range(RESOLUTION):
        for xx in range(RESOLUTION):
            var broad: float = noise.get_noise_2d(float(xx), float(yy))
            var fleck: float = noise.get_noise_2d(float(xx) * 3.1, float(yy) * 3.1)
            var stripe: bool = (yy * 17 + xx * 3 + int(settings["seed"])) % 97 < 2
            var grain: float = 0.89 + broad * 0.15 + fleck * 0.08
            if scratch and stripe:
                grain -= 0.18
            var pit: bool = rust and broad < -0.32 and fleck < -0.07
            var tone: float = clampf(grain - (0.16 if pit else 0.0), 0.49, 1.0)
            var color := Color(tone, tone * (0.95 if pit else 1.0),
                tone * (0.85 if pit else 1.0), 1.0)
            image.set_pixel(xx, yy, color)
            pixels_written += 1
    image.generate_mipmaps()
    var texture: ImageTexture = ImageTexture.create_from_image(image)
    var material := StandardMaterial3D.new()
    material.albedo_color = Color(str(settings["hex"]))
    material.albedo_texture = texture
    material.metallic = float(settings["metal"])
    material.roughness = float(settings["rough"])
    material.uv1_scale = Vector3(2.0, 2.0, 2.0)
    material.uv1_triplanar = false
    _cache[profile] = material
    generated += 1
    return material

func qa_readout() -> Dictionary:
    return {
        "schema": "LAST_FRONTIER_W68_ORIGINAL_PBR_MATERIALS_V1",
        "textures_generated": generated,
        "unique_profiles": PRESETS.size(),
        "resolution": RESOLUTION,
        "pixels_written": pixels_written,
        "all_original_pixels": true,
        "external_assets_loaded": false,
        "textures_real_image_texture": not _cache.is_empty() and
            (_cache.values()[0] as StandardMaterial3D).albedo_texture is ImageTexture,
        "physical_gpu_certified": false,
    }
