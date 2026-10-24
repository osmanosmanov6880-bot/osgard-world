extends SceneTree
## R20: Bake the original R11 deck surface and R5 city glass on the CI CPU.
## The actual procedural generators stay in source for development fallback.
## Output: 3x512x512 weathered steel + 2x256x512 day/night facade PNGs.
const Studio = preload("res://scripts/material_studio_r11.gd")
const Architecture = preload("res://scripts/premium_architecture.gd")
const OUT = "res://assets/r20_baked/"
var written: int = 0
var byte_count: int = 0

func _initialize() -> void:
    var root_dir := DirAccess.open("res://")
    if root_dir == null:
        printerr("NEBULA_R20_BAKE_FAILURE: no project root")
        quit(1)
        return
    var mk: Error = root_dir.make_dir_recursive("assets/r20_baked")
    if mk != OK:
        printerr("NEBULA_R20_BAKE_FAILURE: mkdir error=%d" % mk)
        quit(1)
        return
    var deck: StandardMaterial3D = Studio.make_weathered_deck()
    var metal: Dictionary = {
        "deck_albedo": deck.albedo_texture,
        "deck_normal": deck.normal_texture,
        "deck_orm": deck.roughness_texture
    }
    for name in metal:
        if not _save(name, metal[name], Vector2i(512,512)):
            quit(1)
            return
    var facade: StandardMaterial3D = Architecture.new().make_facade_material()
    var glazing: Dictionary = {
        "facade_albedo": facade.albedo_texture,
        "facade_emission": facade.emission_texture
    }
    for name in glazing:
        if not _save(name, glazing[name], Vector2i(256,512)):
            quit(1)
            return
    if written != 5:
        printerr("NEBULA_R20_BAKE_FAILURE: expected 5 textures")
        quit(1)
        return
    print("NEBULA_R20_BAKE_SUCCESS: images=%d pixels=%d bytes=%d" %
        [written, 3 * 512 * 512 + 2 * 256 * 512, byte_count])
    quit(0)

func _save(name: String, texture: Variant, expected: Vector2i) -> bool:
    if not texture is Texture2D:
        printerr("NEBULA_R20_BAKE_FAILURE: texture not available " + name)
        return false
    var img: Image = (texture as Texture2D).get_image()
    if img == null or Vector2i(img.get_width(), img.get_height()) != expected:
        printerr("NEBULA_R20_BAKE_FAILURE: unexpected dimensions " + name)
        return false
    var target: String = OUT + name + ".png"
    if img.save_png(target) != OK:
        printerr("NEBULA_R20_BAKE_FAILURE: failed to write " + name)
        return false
    var file := FileAccess.open(target, FileAccess.READ)
    if file == null or file.get_length() < 400:
        printerr("NEBULA_R20_BAKE_FAILURE: truncated PNG " + name)
        return false
    written += 1
    byte_count += file.get_length()
    file.close()
    return true
