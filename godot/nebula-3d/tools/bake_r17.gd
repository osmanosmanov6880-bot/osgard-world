extends SceneTree
## R17 reproducible build-time atlas baker.
## Runs in native Godot on the CI runner BEFORE editor import & Web export.
## Uses exactly the original R9/R12 material generators, saving their
## real pixels with no look/quality change. No third-party Python image libs.

const R9 = preload("res://scripts/surface_library_r9.gd")
const R12 = preload("res://scripts/material_fabric_r12.gd")
const OUTPUT: String = "res://assets/r17_pbr/"
const CHANNELS = ["albedo", "normal", "orm"]
const R9_PROFILES: int = 4
const R12_PROFILES: int = 3

var total_images: int = 0
var total_bytes: int = 0

func _initialize() -> void:
    var root_dir := DirAccess.open("res://")
    if root_dir == null:
        printerr("NEBULA_R17_BAKE_FAILURE: no project root")
        quit(1)
        return
    var mkdir_result: Error = root_dir.make_dir_recursive("assets/r17_pbr")
    if mkdir_result != OK:
        printerr("NEBULA_R17_BAKE_FAILURE: mkdir error %d" % mkdir_result)
        quit(1)
        return
    for kind in R9_PROFILES:
        var textures: Dictionary = R9.maps(kind)
        for channel in CHANNELS:
            if not _save("r9_%d_%s" % [kind, channel], textures.get(channel)):
                quit(1)
                return
    for profile in R12_PROFILES:
        var mat: StandardMaterial3D = R12.get_material(profile)
        var textures: Dictionary = {
            "albedo": mat.albedo_texture,
            "normal": mat.normal_texture,
            "orm": mat.roughness_texture,
        }
        for channel in CHANNELS:
            if not _save("r12_%d_%s" % [profile, channel], textures.get(channel)):
                quit(1)
                return
    if total_images != 21:
        printerr("NEBULA_R17_BAKE_FAILURE: incomplete atlas set")
        quit(1)
        return
    print("NEBULA_R17_BAKE_SUCCESS: images=%d pixels=%d compressed_bytes=%d" %
        [total_images, total_images * 384 * 384, total_bytes])
    quit(0)

func _save(stem: String, texture: Variant) -> bool:
    if not texture is Texture2D:
        printerr("NEBULA_R17_BAKE_FAILURE: no texture " + stem)
        return false
    var image: Image = (texture as Texture2D).get_image()
    if image == null or image.get_width() != 384 or image.get_height() != 384:
        printerr("NEBULA_R17_BAKE_FAILURE: unexpected image dimensions " + stem)
        return false
    var location: String = OUTPUT + stem + ".png"
    var save_status: Error = image.save_png(location)
    if save_status != OK:
        printerr("NEBULA_R17_BAKE_FAILURE: could not write %s code %d" %
            [stem, save_status])
        return false
    var stat: FileAccess = FileAccess.open(location, FileAccess.READ)
    if stat == null or stat.get_length() < 400:
        printerr("NEBULA_R17_BAKE_FAILURE: truncated image " + stem)
        return false
    total_images += 1
    total_bytes += stat.get_length()
    stat.close()
    return true
