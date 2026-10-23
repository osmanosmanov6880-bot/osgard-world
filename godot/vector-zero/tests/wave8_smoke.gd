extends SceneTree
var failures: int=0
func _init() -> void:
    call_deferred("_run")
func _check(value:bool, description:String) -> void:
    if value:
        print("WAVE8 PASS: ", description)
    else:
        failures+=1
        push_error("WAVE8 FAIL: "+description)
func _run() -> void:
    var packed:=load("res://scenes/main.tscn") as PackedScene
    _check(packed!=null,"real Godot scene")
    if packed==null:
        quit(1)
        return
    var game:=packed.instantiate() as Node3D
    root.add_child(game)
    await process_frame
    var finish:=game.get_node_or_null("Wave8Finish") as Node3D
    _check(finish!=null,"Wave8 polish module is instantiated")
    if finish!=null:
        var cnc:=finish.get_node_or_null("Wave8MachinedContaminment/CoolingManifold_Left/CNC_PressureShell") as MeshInstance3D
        _check(cnc!=null and cnc.mesh is ArrayMesh,"real CNC custom-indexed shell exists")
        if cnc!=null and cnc.mesh is ArrayMesh:
            _check(cnc.mesh.surface_get_array_len(0)>500,"CNC mechanical shell has geometric density")
            var material:=cnc.material_override as StandardMaterial3D
            _check(material!=null and material.albedo_texture!=null,"authored PBR albedo texture imported")
            _check(material!=null and material.normal_texture!=null and material.normal_enabled,"authored micro-normal map imported")
            _check(material!=null and material.roughness_texture!=null and material.metallic_texture!=null,"roughness and metallic maps separate")
        var bolts:=finish.get_node_or_null("Wave8MachinedContaminment/CNCInstancedFasteners") as MultiMeshInstance3D
        _check(bolts!=null and bolts.multimesh.instance_count>=140,"industrial fasteners are GPU instanced")
        _check(finish.get_node_or_null("Wave8SafetyTelemetry")!=null,"physical inspection lighting and scanner")
        _check(int(finish.get("pooled_bolts"))>=140,"actual instance count recorded")
    _check(game.get_node_or_null("Wave7Lab")!=null,"Wave7 CNC physics arena preserved")
    _check(game.get_node_or_null("Wave6HardwareBenchmark")!=null,"reproducible hardware profiler preserved")
    _check(game.STAGES.size()==3 and game.state=="aiming","all three original gameplay stages preserved")
    game.queue_free()
    await process_frame
    print("WAVE8_VECTOR_SMOKE:","PASS" if failures==0 else "FAIL")
    quit(0 if failures==0 else 1)
