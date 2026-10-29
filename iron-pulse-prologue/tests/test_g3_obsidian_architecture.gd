extends SceneTree
## G3: real authored meshes, titanium PBR, physical sector safety geometry,
## consistent offline crisis response, performance/accessibility and saves.
## Checks the actual Godot Main.tscn — never an HTML approximation.
var checks: int = 0
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _assert(value: bool,description: String) -> void:
    checks += 1
    if not value:
        failures.append(description)

func _finish() -> void:
    if failures.is_empty():
        print("IRON PULSE G3 OBSIDIAN ARCHITECTURE PASS: %d actual 3D art, source lighting, locale, quality, safety and save checks" % checks)
        quit(0)
        return
    for problem in failures:
        push_error("G3 ARCH FAIL: "+problem)
    quit(1)

func _run() -> void:
    var game_scene: PackedScene=load("res://Main.tscn")
    _assert(game_scene!=null,"Existing Godot mission scene can still be imported")
    if game_scene==null:
        _finish()
        return
    var game=game_scene.instantiate()
    root.add_child(game)
    await process_frame
    await process_frame

    var art: IPObsidianArchitecture=game.obsidian_world
    _assert(art!=null and art.name=="G3_Obsidian_Industrial",
        "Real Main.tscn mounts a source-defined original 3D industrial stage")
    _assert(art.hero_detail!=null and art.critical_layer!=null,
        "GPU detail and gameplay-critical safety cues live in separate layers")
    _assert(game.get_node_or_null("G3_Obsidian_Industrial/G3_Hero_MachinedLayer")!=null,
        "Actual authored 3D mesh detail exists on scene tree")
    _assert(game.get_node_or_null("G3_Obsidian_Industrial/G3_AlwaysVisibleSafetyLayer")!=null,
        "Critical hazard labels survive cheap graphics")
    _assert(art.hero_mesh_count>=90 and art.persistent_mesh_count>=9,
        "G3 constructs substantial visible industrial structures, not a UI label")
    var cassette: MeshInstance3D=art.hero_detail.get_node_or_null("G3_Cassette_-5_1_Body") as MeshInstance3D
    _assert(cassette!=null and absf(cassette.position.x)<6.65 and
        is_equal_approx(cassette.position.x,6.42),
        "PBR architectural cassette must project IN FRONT of original opaque wall")
    _assert(art.close_range_labels.size()==2 and
        art.hero_detail.get_node_or_null("G3_VisibleControlBay_1_TitaniumHousing")!=null,
        "Near camera two proper physical machinery faces, not buried decoration")
    _assert(art.batch_count==2 and art.batched_instance_count>=190,
        "True 3D machined bolts and traction decking are GPU-instanced")
    var group_a: MultiMeshInstance3D=art.hero_detail.get_node_or_null("G3_Batched_TitaniumFasteners") as MultiMeshInstance3D
    var group_b: MultiMeshInstance3D=art.hero_detail.get_node_or_null("G3_Batched_DeckTraction") as MultiMeshInstance3D
    _assert(group_a!=null and group_b!=null and
        group_a.multimesh.instance_count==130 and group_b.multimesh.instance_count==66,
        "Expected exact 130+66 real GPU instances, not invented draw calls")
    _assert(art.find_children("*","CollisionShape3D",true,false).is_empty() and
        art.find_children("*","StaticBody3D",true,false).is_empty(),
        "Decorative art cannot create softlocks or change physical collision")
    _assert(art.get_node_or_null("G3_AlwaysVisibleSafetyLayer/G3_Critical_service_SignBack")!=null and
        art.get_node_or_null("G3_AlwaysVisibleSafetyLayer/G3_Critical_evacuation_ActualHazardStrip")!=null,
        "Real safety markers are physically built for service and evacuation sectors")
    _assert(art.sector_labels.size()==3 and art.marker_lamps.size()==3 and
        art.marker_materials.size()==3,
        "Three separate hazard signs have three actual light sources and material instances")
    _assert(art.marker_positions[0].z<-13.0 and art.marker_positions[1].z<-34.0 and
        art.marker_positions[2].z<-50.0,
        "G3 safety lighting is physically spread across three playable sectors")

    var titanium: StandardMaterial3D=art.material_library["black_titanium"]
    var bronze: StandardMaterial3D=art.material_library["aged_bronze"]
    var obsidian: StandardMaterial3D=art.material_library["recessed_obsidian"]
    _assert(titanium.metallic>=0.8 and titanium.roughness<0.45 and
        bronze.metallic>0.6 and obsidian.roughness>0.60,
        "True in-engine PBR material language: polished titanium, restrained bronze, matte obsidian")
    _assert(titanium!=obsidian and obsidian!=bronze,
        "Different material resources, not one flat neon shader assigned to all objects")
    _assert(art.current_scenario=="blackout" and art.quality_mode=="hero",
        "Actual scene defaults to original operation and HERO")
    var start: Dictionary=art.readout()
    _assert(start["schema"]==IPObsidianArchitecture.FORMAT and
        start["world_geometry_authentic"] and not start["source_simulation_changed"] and
        start["no_external_assets"] and not start["telemetry_uploaded"],
        "Read-only audit truthfully identifies actual on-device source geometry")
    _assert(start["hero_mesh_count"]==art.hero_mesh_count and
        start["batched_instances"]==group_a.multimesh.instance_count+group_b.multimesh.instance_count,
        "Browser readout metrics count actual Godot source objects")
    _assert(start["sign_count"]==3 and start["light_count"]==3 and
        start["physical_lamp_positions"].size()==3,
        "All three emitted readout locations correspond to physical lights")
    _assert(float(start["visible_cassette_surface_x"])<6.65 and
        start["foreground_machined_panels"]==2,
        "Read-only browser record exposes actual visible geometry beyond wall surface")

    art.set_locale("en")
    _assert(art.close_range_labels[0].text.contains("COOLANT") and
        art.close_range_labels[1].text.contains("CONTROL"),
        "High-detail wall-machine labels genuinely change with RU/EN")
    _assert(art.locale=="en" and str(art.sector_labels[0].text).contains("REACTOR") and
        str(art.sector_labels[1].text).contains("SERVICE") and
        str(art.sector_labels[2].text).contains("EVACUATION"),
        "In-world source geometry signs truly localize to English")
    art.set_locale("ru")
    _assert(art.close_range_labels[0].text.contains("ОХЛАЖДЕНИЕ") and
        art.close_range_labels[1].text.contains("КОНТРОЛЬ"),
        "Physical foreground signs use real Russian glyphs")
    _assert(art.locale=="ru" and str(art.sector_labels[0].text).contains("РЕАКТОР") and
        str(art.sector_labels[1].text).contains("ТЕХСЕКТОР") and
        str(art.sector_labels[2].text).contains("ШЛЮЗ"),
        "The same actual 3D labels switch back to Russian")

    var before_engine: Dictionary=game.session.checkpoint()
    art.update_hazard("blackout",48.0,93.0,0.0,true)
    var calm_energy: float=art.marker_lamps[0].light_energy
    var calm_emission: float=art.marker_materials[0].emission_energy_multiplier
    _assert(art.readout()["risk"]==0.0 and calm_energy>0.0,
        "Physically lit hazard signage is subtle but readable at low risk")
    art.update_hazard("thermal",95.0,80.0,1.0,true)
    var hot: Dictionary=art.readout()
    _assert(hot["scenario"]=="thermal" and hot["risk"]>0.8 and
        art.marker_lamps[0].light_energy>calm_energy and
        art.marker_materials[0].emission_energy_multiplier>calm_emission,
        "Original real core heat makes danger luminance measurably stronger")
    var muted_energy: float=art.marker_lamps[0].light_energy
    art.update_hazard("thermal",95.0,80.0,94.0,true)
    _assert(is_equal_approx(muted_energy,art.marker_lamps[0].light_energy),
        "Reduced-motion keeps emergency signage steady regardless of wall time")
    art.update_hazard("breach",42.0,7.0,18.0,true)
    _assert(art.readout()["scenario"]=="breach" and art.readout()["risk"]>0.80,
        "Real oxygen depletion drives crisis lighting even at safe temperature")
    _assert(game.session.checkpoint()==before_engine,
        "G3 visual updates never alter engine savegame or a player's choices")

    art.set_quality("eco")
    var eco: Dictionary=art.readout()
    _assert(eco["quality"]=="eco" and not eco["hero_visible"] and
        eco["safety_visible"] and art.critical_layer.visible,
        "ECO hides expensive decorative meshes, never critical hazard wayfinding")
    _assert(not art.hero_detail.visible and art.marker_lamps.size()==3 and
        art.marker_lamps[0].visible,
        "Physical safety lights remain while GPU dressing is removed")
    art.set_quality("hero")
    _assert(art.hero_detail.visible and art.critical_layer.visible and
        art.readout()["quality"]=="hero",
        "HERO restores the entire original decorative 3D layer")

    game._toggle_language()
    _assert(game.locale=="en" and art.locale=="en" and
        str(art.sector_labels[1].text).contains("SERVICE"),
        "Existing L keyboard language path updates live 3D signs")
    game._toggle_language()
    _assert(game.locale=="ru" and art.locale=="ru" and
        str(art.sector_labels[1].text).contains("ТЕХСЕКТОР"),
        "Bilingual signage is reversible without resetting mission")
    game._apply_graphics_profile("eco")
    _assert(game.quality_mode=="eco" and not art.hero_detail.visible and
        art.critical_layer.visible,
        "Original native G AUTO/MANUAL graphics path controls the added physical detail")
    game._apply_graphics_profile("hero")
    _assert(game.quality_mode=="hero" and art.hero_detail.visible,
        "Original HERO profile still restores all authored geometry")
    _assert(game.session.checkpoint()==before_engine,
        "Switching graphics or language does not create fake gameplay state")
    _assert(game._checkpoint_payload().get("schema")=="IRON_PULSE_CAMPAIGN_V6" and
        not game._checkpoint_payload().has("g3_art"),
        "G3 leaves saved V6/V9 game schema completely unchanged")
    _assert(game.field_stations.size()==2 and game.relay_terminals.size()==3 and
        game.terminals.size()==6,
        "G2 field protocols, V7 rescue stations and original six objective terminals survive")

    game.start_run()
    game.session.scan_core()
    game.session.activate_field_protocol("sink")
    art.update_hazard(game.session.scenario_id,game.session.heat,game.session.oxygen,4.0,true)
    _assert(art.current_scenario==game.session.scenario_id and
        game.session.field_protocol=="sink" and game.session.core_scanned,
        "Original actual G2 strategy still operates with G3 visual upgrade")
    _assert(art.get_node_or_null("G3_AlwaysVisibleSafetyLayer/G3_Critical_reactor_LocalizedLabel")!=null,
        "The new industrial safety signage remains in the real playable mission")
    game.queue_free()
    await process_frame
    _finish()
