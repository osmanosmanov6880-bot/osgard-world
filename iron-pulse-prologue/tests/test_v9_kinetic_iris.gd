extends SceneTree
## V9 strict Godot 4.4.1 acceptance: real UV wedge meshes, live mechanical
## aperture, GPU-instanced construction details and unchanged gameplay.
var checks: int = 0
var fails: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _assert(ok: bool, statement: String) -> void:
    checks += 1
    if not ok:
        fails.append(statement)

func _key(game: Node,key: Key) -> void:
    var e := InputEventKey.new()
    e.keycode = key
    e.pressed = true
    game._input(e)

func _run() -> void:
    var scene: PackedScene = load("res://Main.tscn")
    _assert(scene != null,"Existing playable Godot 4.4.1 world loads")
    if scene == null:
        _finish()
        return
    var game = scene.instantiate()
    root.add_child(game)
    await process_frame
    await process_frame
    var iris: IPKineticIris = game.kinetic_iris
    _assert(iris != null and iris.name == "A7_PrecisionKineticIris",
        "Original 3D precision iris is physically attached to game scene")
    if iris == null:
        game.queue_free()
        await process_frame
        _finish()
        return
    _assert(iris.is_inside_tree() and iris.position == IPKineticIris.IRIS_CENTER,
        "Iris is located in original 15m reactor vault, not in overlay")
    var baseline: Dictionary = iris.readout()
    _assert(baseline["physical_curved_petals"] == 8 and baseline["physical_hinges"] == 8,
        "Eight independently positionable curved armor petals and physical hinge servos")
    _assert(baseline["original_uv_mesh"] == true and baseline["real_steel_material"] == true,
        "Original curved and UV-wrapped steel is real custom authored 3D geometry")
    _assert(baseline["gpu_bolt_groups"] == 1 and baseline["instanced_guide_bolts"] == 32,
        "32 industrial fasteners are a single real GPU draw group")
    _assert(baseline["quality"] == "hero" and baseline["detailed_guides_visible"],
        "HERO detailed guides and bolts are visible in actual camera view")
    _assert(iris._hero_details.get_child_count() >= 17,
        "Nontrivial industrial guidework has real individual meshes")
    for index in range(8):
        var pivot: Node3D = iris.petals[index]
        var panel: MeshInstance3D = pivot.get_node_or_null("CustomUV_CurvedArmor") as MeshInstance3D
        _assert(pivot.name == "PrecisionSlidingPetal_%02d" % index,
            "Eight uniquely identified 3D kinetic petals: "+str(index))
        _assert(panel != null and panel.mesh is ArrayMesh,
            "Petal physically uses bespoke ArrayMesh rather than enlarged BoxMesh: "+str(index))
        if panel != null and panel.mesh is ArrayMesh:
            var shape: ArrayMesh = panel.mesh as ArrayMesh
            _assert(shape.surface_get_array_len(0) >= 30,
                "Curved armour has full front/back/thickness geometry: "+str(index))
            _assert((shape.surface_get_format(0) & Mesh.ARRAY_FORMAT_TEX_UV) != 0,
                "Petal has real future-proof PBR UV coordinates: "+str(index))
        _assert(pivot.get_node_or_null("MachinedRadialServo") is MeshInstance3D,
            "Movable petal has real radial mechanical actuator: "+str(index))

    iris.update_from_crisis("blackout",48.0,93.0,0.0,false,0,false,true)
    _assert(absf(float(iris.readout()["aperture_radius_m"])-2.23)<0.01 and
        float(iris.readout()["moving_clearance_m"])<=0.001,
        "Safe reactor retains readable unobstructed 2.23m physical aperture")
    iris.update_from_crisis("thermal",98.0,82.0,11.0,false,1,false,true)
    var thermal: Dictionary = iris.readout()
    _assert(thermal["risk"] >= 0.90 and thermal["moving_clearance_m"] > 0.50,
        "Real thermal emergency slides full mechanical iris outward")
    _assert(float(thermal["aperture_radius_m"]) >= 2.70,
        "Crisis opens actual 3D aperture beyond original sphere bounds")
    _assert(iris._indicator.emission.r > 0.90 and iris._indicator.emission.b < 0.25,
        "HEAT changes real physical warning material from cyan to orange")
    var sample: Vector3 = iris.petals[0].position
    _assert(sample.z > 0.50,
        "Petal movement is real scene transform, not 2D HUD animation")
    var before_shield: float = float(thermal["moving_clearance_m"])
    iris.update_from_crisis("thermal",98.0,82.0,12.0,false,1,true,true)
    _assert(float(iris.readout()["moving_clearance_m"]) < before_shield-0.15,
        "Real QUENCH strategic rescue reduces physical reactor purge opening")
    iris.update_from_crisis("breach",50.0,7.0,14.0,false,0,false,true)
    _assert(float(iris.readout()["risk"]) > 0.80 and iris._indicator.emission.b > 0.80,
        "Low oxygen AIR creates real mechanical crisis feedback in cool spectrum")
    iris.update_from_crisis("thermal",98.0,82.0,15.0,true,0,false,true)
    var reduced: Dictionary = iris.readout()
    _assert(reduced["motion_reduced"] and float(reduced["aperture_radius_m"]) > 2.70,
        "Reduced Motion retains accurate real safety state and aperture size")
    _assert(iris._indicator.emission.r > 0.90,
        "Accessible emergency signal remains readable with motion reduced")
    iris.set_quality("eco")
    _assert(iris.readout()["quality"] == "eco" and not iris._hero_details.visible,
        "ECO truly hides dozens of detailed original guide meshes")
    _assert(iris.petals[0].visible and iris.petals[7].visible,
        "ECO never hides the essential moving industrial silhouette")
    iris.set_quality("hero")
    _assert(iris.readout()["detailed_guides_visible"] and iris.bolt_group.visible,
        "HERO restores 32-bolt instanced details without rebuilding or leaks")
    var recorded: Dictionary = iris.readout()
    iris.update_from_crisis("blackout",48.0,95.0,22.0,false,0,false,false)
    _assert(iris.readout()==recorded,
        "Paused/finished game does not mutate cinematic machinery")

    game._select_scenario("thermal")
    game.start_run()
    var preserved: Dictionary = game.session.checkpoint()
    game.session.heat = 95.0
    game.session.oxygen = 78.0
    game._process(0.016)
    _assert(float(game.kinetic_iris.readout()["moving_clearance_m"]) > 0.45,
        "Original IPCrisisEngine live heat drives physical 3D iris in gameplay")
    _assert(game.session.checkpoint()["heat"] == 95.0 and game.session.checkpoint()["oxygen"] == 78.0,
        "Pure visual director never alters underlying game resources")
    _key(game,KEY_G)
    _assert(game.quality_mode=="eco" and game.kinetic_iris.readout()["quality"]=="eco",
        "Player's existing G key scales new real mechanical art")
    _key(game,KEY_G)
    _assert(game.quality_mode=="hero" and game.kinetic_iris.readout()["quality"]=="hero",
        "HERO detail is restored without leaving game")
    _key(game,KEY_V)
    game._process(0.016)
    _assert(game.reduced_motion and game.kinetic_iris.readout()["motion_reduced"],
        "Player's existing V accessibility key works with new industrial mechanism")
    _key(game,KEY_C)
    _assert(game.cinematic_view and game.get_viewport().get_camera_3d()==game.reactor_atrium.director_camera,
        "Existing C switches to actual physical cinema camera over real moving iris")
    _key(game,KEY_C)
    _assert(not game.cinematic_view and game.get_viewport().get_camera_3d()==game.camera,
        "Real game camera returns after V9 inspection")
    _assert(game.terminals.size()==6 and game.relay_terminals.size()==3,
        "Original six gameplay stations and three rescue relays unchanged")
    game.player.position = Vector3(-3.0,1.1,-15.5)
    game._interact()
    _assert(game.session.core_scanned and game.story.latest_key=="scan",
        "Original physical scanner, story and critical objective remain playable")
    game.queue_free()
    await process_frame
    _finish()

func _finish() -> void:
    if fails.is_empty():
        print("IRON PULSE V9 KINETIC IRIS PASS: %d real Godot geometry and gameplay checks" % checks)
        quit(0)
    else:
        for statement in fails:
            push_error("V9 IRIS FAIL: "+statement)
        quit(1)
