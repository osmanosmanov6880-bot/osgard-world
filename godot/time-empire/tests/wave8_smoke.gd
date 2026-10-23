extends SceneTree
var failures: int=0
func _init() -> void:
    call_deferred("_run")
func _check(value:bool,description:String) -> void:
    if value:
        print("WAVE8 PASS: ",description)
    else:
        failures+=1
        push_error("WAVE8 FAIL: "+description)
func _run() -> void:
    var packed:=load("res://scenes/main.tscn") as PackedScene
    _check(packed!=null,"Godot city scene")
    if packed==null:
        quit(1)
        return
    var game:=packed.instantiate() as Node3D
    game.save_path="user://wave8_city_test.json"
    root.add_child(game)
    await process_frame
    var finish:=game.get_node_or_null("Wave8Finish") as Node3D
    _check(finish!=null,"Wave8 coastal infrastructure instantiated")
    if finish!=null:
        _check(finish.get_node_or_null("Wave8PhysicalLandfall/ContinentalCausewayDeck") is MeshInstance3D,"bridge deck physically connects island and mainland")
        _check(int(finish.get("supports"))>=14,"bridge foundations anchored in sea bed")
        var rails:=finish.get_node_or_null("Wave8ActiveMonorail/GPUTrackSleepers") as MultiMeshInstance3D
        _check(rails!=null and rails.multimesh.instance_count>=90,"tram sleepers are GPU-instanced geometry")
        _check(finish.get_node_or_null("Wave8ActiveMonorail/AutonomousTram_00") is Node3D,"physical animated transit vehicle")
        _check(finish.get_node_or_null("Wave8HarborTerminal/CargoDeck") is MeshInstance3D,"port has a physical cargo platform")
        _check(finish.get_node_or_null("Wave8HarborTerminal/DeepWaterQuaySupport") is MeshInstance3D, "deep water quay support piles are present")
        var deck:=finish.get_node_or_null("Wave8PhysicalLandfall/ContinentalCausewayDeck") as MeshInstance3D
        if deck!=null:
            var mat:=deck.material_override as StandardMaterial3D
            _check(mat!=null and mat.albedo_texture!=null,"imported PBR concrete atlas")
            _check(mat!=null and mat.normal_texture!=null and mat.normal_enabled,"fine-detail physical normal map")
    _check(game.get_node_or_null("Wave7Region/ContinentalTerrain") is MeshInstance3D,"Wave7 sculpted terrain retained")
    _check(game.get_node_or_null("Wave6HardwareBenchmark")!=null,"true Windows GPU benchmark retained")
    _check(game.production_rate>=2.0 and game.district_count>=0,"economy and saves remain intact")
    game.queue_free()
    await process_frame
    var save_location:=ProjectSettings.globalize_path("user://wave8_city_test.json")
    if FileAccess.file_exists(save_location):
        DirAccess.remove_absolute(save_location)
    print("WAVE8_CITY_SMOKE:","PASS" if failures==0 else "FAIL")
    quit(0 if failures==0 else 1)
