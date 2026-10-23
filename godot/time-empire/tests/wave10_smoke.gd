extends SceneTree
var failures := 0
const SAVE := "user://osgard_wave10_city_ci_save.json"

func _init() -> void:
    call_deferred("_run")

func _check(ok: bool, label: String) -> void:
    if ok:
        print("WAVE10 CHRONOS PASS: ",label)
    else:
        push_error("WAVE10 CHRONOS FAIL: "+label)
        failures += 1

func _run() -> void:
    if FileAccess.file_exists(SAVE):
        DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
    var packed := load("res://scenes/main.tscn") as PackedScene
    _check(packed != null,"existing strategy scene imported")
    if packed == null:
        quit(1)
        return
    var game := packed.instantiate() as Node3D
    game.save_path = SAVE
    root.add_child(game)
    await process_frame
    var art := game.get_node_or_null("Wave10CityDirector") as Node3D
    _check(art != null,"wave10 director installed")
    var trees := game.get_node_or_null("Wave7Region/Wave10ClusteredFoliageGPU") as MultiMeshInstance3D
    _check(trees != null and trees.multimesh.instance_count > 100,"clustered forest GPU batch with 100+ trees")
    _check(trees != null and trees.multimesh.mesh is ArrayMesh,"leaf geometry is a real triangulated mesh")
    var stems := game.get_node_or_null("Wave7Region/Wave10WoodTrunksGPU") as MultiMeshInstance3D
    _check(stems != null and stems.multimesh.instance_count > 100,"tree trunks GPU batch")
    var old := game.get_node_or_null("Wave7Region/CoastalTreeCanopies") as MultiMeshInstance3D
    _check(old != null and not old.visible,"simple foliage hidden to avoid overlap")
    _check(game.production_rate == 2.0,"time economy preserved")
    _check(game._build_district(),"construction gameplay still works")
    _check(game.district_count == 1 and game.production_rate == 5.0,"built district generates +3/sec")
    _check(art != null and float(art.get("build_pulse")) > 0.0,"construction reveal animation triggered")
    game.queue_free()
    if FileAccess.file_exists(SAVE):
        DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
    print("WAVE10 CHRONOS FINAL: ","PASS" if failures==0 else "FAIL")
    quit(0 if failures==0 else 1)
