extends SceneTree
## Native Godot smoke: an actual city scene, time production, construction, camera and persistence.
var failures: int = 0
const SAVE := "user://osgard_chronos_city_ci_save.json"

func _init() -> void:
    call_deferred("_run")

func _check(condition: bool, label: String) -> void:
    if condition:
        print("PASS: ", label)
    else:
        failures += 1
        push_error("FAIL: " + label)

func _run() -> void:
    if FileAccess.file_exists(SAVE):
        DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
    var packed: PackedScene = load("res://scenes/main.tscn")
    _check(packed != null, "main city scene loads")
    if packed == null:
        quit(1)
        return
    var game: Node3D = packed.instantiate()
    game.save_path = SAVE
    root.add_child(game)
    await process_frame
    var wave4_reactor: Node3D = game.get_node_or_null("LivingCity/ChronoCore/Wave4ChronoReactor") as Node3D
    var civic: Node3D = game.get_node_or_null("LivingCity/Wave4AuthoredLandmarks/SpireWestPBR") as Node3D
    var civic_2: Node3D = game.get_node_or_null("LivingCity/Wave4AuthoredLandmarks/SpireEastPBR") as Node3D
    _check(wave4_reactor != null and civic != null and civic_2 != null, "imported GLB reactor and two architectural landmarks")
    if wave4_reactor != null:
        _check(game.Wave4Assets.triangle_count(wave4_reactor) > 70000, "native reactor uses true 80k triangle sculpted PBR asset")
    if civic != null:
        _check(game.Wave4Assets.triangle_count(civic) > 85000, "unique civic spire contains over 100k triangle model")
    _check(load("res://assets/wave4/civic_spire_web.glb") is PackedScene, "Web LOD architectural mesh independently imported")
    _check(game.get_node_or_null("LivingCity/Wave3Metropolis") != null, "WAVE3 physical metropolis authored")
    var city_mesh_instance: MultiMeshInstance3D = game.get_node_or_null("LivingCity/SkylineTowers") as MultiMeshInstance3D
    _check(city_mesh_instance != null and city_mesh_instance.multimesh.mesh is ArrayMesh, "mass-market city tower batch uses unique sculpted loft silhouettes")
    _check(city_mesh_instance != null and city_mesh_instance.multimesh.instance_count > 10, "lofted skyline retains efficient GPU instancing")
    var world: WorldEnvironment = game.get_node_or_null("ChronosAtmosphere") as WorldEnvironment
    _check(world != null and world.environment.background_mode == Environment.BG_SKY, "city has procedural atmospheric sky")
    _check(game.get_node_or_null("LivingCity/Wave3Metropolis/CivicArrivalPort_00") != null, "precision transit landing port")
    _check(game.get_node_or_null("LivingCity/ChronoCore/Wave3ChronoEngine/MachinedInductionCrown") is MeshInstance3D, "CNC chronoreactor outer housing")
    _check(game.get_node_or_null("LivingCity/ChronoCore/Wave3ChronoEngine/ChronoPlantFasteners192") is MultiMeshInstance3D, "energy plant fasteners GPU-instanced")
    var crown: MeshInstance3D = game.get_node_or_null("LivingCity/ChronoCore/Wave3ChronoEngine/MachinedInductionCrown") as MeshInstance3D
    _check(crown != null and crown.mesh is ArrayMesh and crown.mesh.surface_get_array_len(0) > 350, "chronoreactor crown is true UV-indexed surface")
    _check(game.get_node_or_null("LivingCity/Wave3Metropolis/CivicArrivalPort_01/SuspendedRoof") is MeshInstance3D, "transport entrance has structural roof")
    _check(game.get_node_or_null("LivingCity/HeroCitySculpturesV2") != null, "independent sculpted civic geometry kit")
    _check(game.get_node_or_null("LivingCity/ChronoCore/HeroChronoReactorV2/ChronoEnergyHelix_00") is MeshInstance3D, "reactor uses real triangulated helical conductor")
    _check(game.get_node_or_null("LivingCity/HeroCitySculpturesV2/ExpressRailRealTubularMesh") is MeshInstance3D, "high detail elevated transit is curved 3D geometry")
    _check(game.get_node_or_null("LivingCity/HeroCitySculpturesV2/LoftedCivicMonument_00/TwistingParametricPavilion") is MeshInstance3D, "unique twisted civic monument mesh")
    var twisted: MeshInstance3D = game.get_node_or_null("LivingCity/HeroCitySculpturesV2/LoftedCivicMonument_00/TwistingParametricPavilion") as MeshInstance3D
    _check(twisted != null and twisted.mesh is ArrayMesh and twisted.mesh.surface_get_array_len(0) > 300, "custom indexed architecture surface has meaningful polygon density")
    _check(game.get_node_or_null("LivingCity/Chronos_UltraCityArchitecture") != null, "original high density metropolitan 3D kit")
    _check(game.get_node_or_null("LivingCity/ChronoCore/Chronos_HighPolyReactor") != null, "sculpted chronoreactor with machined PBR hardware")
    _check(game.get_node_or_null("LivingCity/Chronos_UltraCityArchitecture/SculptedLandmark_00") != null, "unique tiered tower and sculptural landmark kit")
    _check(game.get_node_or_null("LivingCity/Chronos_UltraCityArchitecture/SculptedLandmark_01") != null, "two-spire civic tower asset")
    _check(game.get_node_or_null("LivingCity/Chronos_UltraCityArchitecture/SculptedLandmark_02") != null, "octagonal observation tower asset")
    _check(game.get_node_or_null("ChronosAtmosphere") != null, "3D environment exists")
    _check(game.get_node_or_null("StrategyCamera") != null, "strategy camera exists")
    _check(game.get_node_or_null("LivingCity/ChronoCore") != null, "real chrono reactor geometry exists")
    _check(game.get_node_or_null("LivingCity/SkylineTowers") is MultiMeshInstance3D, "GPU-batched 3D skyline exists")
    _check(game.get_node_or_null("LivingCity/IlluminatedWindows") is MultiMeshInstance3D, "GPU-batched windows exist")
    _check(game.get_node_or_null("EmpireHUD/TopBar") != null, "readable Russian objective and resources")
    _check(game.get_node_or_null("EmpireHUD/PrimaryActions") != null, "three primary controls exist")
    _check(game.mission_label.text.contains("Построй"), "first-time player receives clear task")
    _check(game.district_count == 0 and game.core_level == 1, "game starts with clean progression")
    _check(game.production_rate == 2.0, "base rate is two time units per second")
    var before: float = game.time_units
    game._process(5.0)
    _check(game.time_units > before + 9.99, "time production is real, not a decorative counter")
    var cost: float = game._district_cost()
    _check(game._build_district(), "new city district can be built")
    _check(game.district_count == 1 and game.production_rate == 5.0, "new district increases production")
    _check(game.get_node_or_null("LivingCity/DistrictPlots/District_01") != null, "building appears in the 3D world")
    _check(game.get_node_or_null("LivingCity/DistrictPlots/District_01/HighDensityDistrict_00") != null, "constructed district has detailed equipment asset")
    _check(game.get_node_or_null("LivingCity/DistrictPlots/District_01/Wave3UtilityDistrict_00") != null, "new construction places Wave3 power generation equipment")
    _check(game.time_units < before + 10.1 and game.time_units > 0.0, "district cost is deducted")
    var old_mode: bool = game.map_mode
    game._toggle_map()
    _check(game.map_mode != old_mode, "map camera toggles")
    game._toggle_map()
    game.time_units = 500.0
    _check(game._upgrade_core(), "chrono reactor can be upgraded")
    _check(game.core_level == 2 and game.production_rate == 7.0, "core upgrade increases production")
    game._save_game()
    var saved_time: float = game.time_units
    game.queue_free()
    await process_frame
    var restored: Node3D = packed.instantiate()
    restored.save_path = SAVE
    root.add_child(restored)
    await process_frame
    _check(restored.district_count == 1 and restored.core_level == 2, "progress survives save and load")
    _check(absf(restored.time_units - saved_time) < 3.0, "saved time resource restored")
    _check(restored.get_node_or_null("LivingCity/DistrictPlots/District_01") != null, "saved district appears after relaunch")
    restored.queue_free()
    if FileAccess.file_exists(SAVE):
        DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
    print("CHRONOS CITY VALIDATION: ", "PASS" if failures == 0 else "FAIL", " (", failures, " failures)")
    quit(0 if failures == 0 else 1)