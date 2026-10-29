extends SceneTree
## G4 tests deterministic injected deltas only for unit math; never
## represent these artificial samples as measurements from actual devices.
var checks: int=0
var failures: Array[String]=[]

func _initialize() -> void:
    call_deferred("_run")

func _assert(ok: bool,why: String) -> void:
    checks += 1
    if not ok:
        failures.append(why)

func _press(game: Node,key: Key) -> void:
    var event:=InputEventKey.new()
    event.keycode=key
    event.pressed=true
    game._input(event)

func _finish() -> void:
    if failures.is_empty():
        print("IRON PULSE G4 LOCAL DEVICE LAB PASS: %d bounded local-metric, input, privacy, checkpoint and native HUD checks" % checks)
        quit(0)
        return
    for failure in failures:
        push_error("G4 DEVICE FAIL: "+failure)
    quit(1)

func _run() -> void:
    var size:=Vector2i(1280,720)
    var lab:=IPDeviceLab.new()
    _assert(lab.state=="idle" and lab.snapshot()["frames_captured"]==0,
        "Device tracking must default OFF with 0 captured frames")
    _assert(not lab.begin("hero","ru",size,false),
        "Cannot start a diagnostic on intro/paused/not-playable state")
    _assert(not lab.begin("ultra","ru",size,true),
        "Unknown graphics profile cannot poison actual hardware comparison")
    _assert(not lab.begin("hero","ru",Vector2i(1,1),true),
        "Invalid viewport cannot generate a fake 60Hz result")
    _assert(not lab.save_local_report() and lab.report().is_empty(),
        "No report, user:// file or upload before a real opt-in session")
    _assert(lab.begin("hero","ru",size,true) and lab.state=="recording",
        "Player opt-in starts bounded source-client main-loop measurement")
    for i in range(2500):
        lab.observe(0.040,true,"hero",size)
    var live: Dictionary=lab.snapshot(true)
    _assert(live["frames_captured"]==2500 and live["active_seconds"]>=99.9,
        "Active frame deltas accumulate, not wall-clock or fictional benchmark")
    _assert(live["p95_ms"]==40.0 and live["median_ms"]==40.0 and
        live["p99_ms"]==40.0 and live["average_ms"]==40.0,
        "P50/P95/P99/mean use correctly sorted actual accepted samples")
    _assert(live["estimated_fps"]==25.0 and live["hitches_over_50ms"]==0,
        "Estimated FPS transparently computed from observed frame deltas")
    _assert(live["comparable_local_run"]==false and
        not live["hardware_physically_verified"],
        "An uncompleted session may not declare a benchmark/certification")
    _assert(lab.finish() and not lab.finish() and lab.state=="complete",
        "Finish is one-way and does not synthesize further frames")
    var final: Dictionary=lab.snapshot(true)
    _assert(final["comparable_local_run"] and not final["hardware_physically_verified"] and
        not final["independent_hardware_certification"],
        "Even a long stable LOCAL run never certifies physical hardware")
    _assert(final["sample_truncated"]==false and final["quality_changed"]==false and
        final["viewport_changed"]==false and final["stored_frame_samples"]==2500,
        "A comparable local run must remain single-viewport and single-quality")
    _assert(lab.report()["privacy"].contains("no IP") and
        lab.report()["next_gate"].contains("manual on-device"),
        "Local privacy and outstanding physical testing are explicit")
    _assert(lab.save_local_report() and lab.last_local_save_ok and
        FileAccess.file_exists(IPDeviceLab.REPORT_PATH),
        "Explicit export writes a real user:// JSON report without a network")
    var saved: Variant=JSON.parse_string(FileAccess.get_file_as_string(IPDeviceLab.REPORT_PATH))
    _assert(saved is Dictionary and saved.get("schema")==IPDeviceLab.FORMAT and
        saved.get("frames_captured")==2500 and saved.get("telemetry_uploaded")==false,
        "Saved JSON comes from exact source samples and says no telemetry upload")
    _assert(not saved.has("ip_address") and not saved.has("gpu_vendor") and
        not saved.has("device_id") and not saved.has("user_id"),
        "Report stores no fingerprint, external IP or user-account identifiers")
    _assert(lab.begin("eco","en",size,true) and lab.snapshot(true)["frames_captured"]==0,
        "New session resets old history, without silent lifetime surveillance")

    var disturbed:=IPDeviceLab.new()
    _assert(disturbed.begin("hero","en",size,true),"Independent second session starts explicitly")
    disturbed.observe(0.016,true,"hero",size)
    disturbed.observe(0.041,false,"hero",size)
    disturbed.observe(INF,true,"hero",size)
    disturbed.observe(-1.0,true,"hero",size)
    disturbed.observe(3.0,true,"hero",size)
    disturbed.observe(0.36,true,"hero",size)
    disturbed.observe(0.050,true,"eco",Vector2i(390,844))
    disturbed.finish()
    var disturbed_report: Dictionary=disturbed.snapshot(true)
    _assert(disturbed_report["frames_captured"]==3 and disturbed_report["paused_frames_excluded"]==1 and
        disturbed_report["invalid_deltas_excluded"]==2 and disturbed_report["background_interruption_count"]==1,
        "Paused frames, nonfinite/negative samples and app suspension never count as ordinary frames")
    _assert(disturbed_report["stalls_over_250ms"]==1 and disturbed_report["hitches_over_50ms"]==2,
        "Real active 360ms stutter is counted, not silently filtered as a nice FPS")
    _assert(disturbed_report["quality_changed"] and disturbed_report["viewport_changed"] and
        disturbed_report["quality_end"]=="eco" and not disturbed_report["comparable_local_run"],
        "A resize and HERO-to-ECO transition invalidate clean A/B comparison")
    _assert(not disturbed_report["hardware_physically_verified"] and
        not disturbed_report["telemetry_uploaded"] and
        not disturbed_report["device_fingerprint_collected"],
        "No deterministic test injects false hardware certification or network telemetry")

    var first:=IPDeviceLab.new()
    _assert(first.begin("eco","en",size,true),"Independent interrupted session begins")
    for i in range(18025):
        first.observe(0.01,true,"eco",size)
    var limited: Dictionary=first.snapshot(true)
    _assert(limited["stored_frame_samples"]==IPDeviceLab.MAX_SAMPLES and
        limited["frames_captured"]==18025 and limited["sample_truncated"],
        "Bounded 18k sample ring never grows without limit on a phone")
    first.finish()
    _assert(not first.snapshot(true)["comparable_local_run"],
        "Truncated sample history is labelled incomparable instead of falsely certifying the full run")

    var limit:=IPDeviceLab.new()
    limit.begin("eco","en",size,true)
    for i in range(1201):
        limit.observe(0.50,true,"eco",size)
    _assert(limit.state=="complete" and limit.auto_completed and
        limit.snapshot(true)["active_seconds"]>=IPDeviceLab.MAX_SECONDS and
        not limit.snapshot(true)["hardware_physically_verified"],
        "A long opt-in run is capped at ten measured minutes and still not hardware-certified")

    var scene: PackedScene=load("res://Main.tscn")
    _assert(scene!=null,"G3.1 original real 3D project remains importable")
    if scene==null:
        _finish()
        return
    var game=scene.instantiate()
    root.add_child(game)
    await process_frame
    await process_frame
    _assert(game.device_lab_panel!=null and
        game.device_lab_start_button.custom_minimum_size.y>=48 and
        game.device_lab_export_button.custom_minimum_size.y>=48 and
        game.device_lab_close_button.custom_minimum_size.y>=48,
        "Native G4 lab has three genuine accessible large Godot buttons")
    _assert(game.touch_device_lab_button!=null and
        game.touch_device_lab_button.get_global_rect().size.y>=44,
        "Mobile lab button is real 51px Godot touchscreen input")
    _assert(not game.device_lab_panel.visible and game.device_lab.state=="idle",
        "No profiling overlay or hidden sampling on the intro")
    var initial_game: Dictionary=game.session.checkpoint()
    _press(game,KEY_F8)
    _assert(game.device_lab_panel.visible and not game.device_lab_export_button.disabled==false,
        "F8 opens a native lab but cannot export nonexisting results")
    _press(game,KEY_F9)
    _assert(game.device_lab.state=="idle" and not game.started,
        "F9 cannot create synthetic performance from an intro screen")
    _press(game,KEY_F8)
    _assert(not game.device_lab_panel.visible,"F8 closes lab without starting a mission")
    game.start_run()
    var checkpoint: Dictionary=game.session.checkpoint()
    _press(game,KEY_F9)
    _assert(game.device_lab.state=="recording" and not game.device_lab_panel.visible and
        not game.paused and game.session.checkpoint()==checkpoint,
        "Actual F9 begins local client sampling while preserving all game physics/saves")
    for i in range(90):
        game.device_lab.observe(0.016,true,game.quality_mode,size)
    _press(game,KEY_F8)
    _assert(game.device_lab.state=="complete" and game.device_lab_panel.visible and
        game.paused and game.device_lab.snapshot(true)["frames_captured"]>=90,
        "Physical F8 terminates measurement and opens a paused actual results UI")
    _assert(not game.device_lab_export_button.disabled and
        game.device_lab_label.text.contains("P95") and
        game.session.checkpoint()==checkpoint,
        "Native lab displays measured percentiles and cannot alter game state")
    game.device_lab_export_button.pressed.emit()
    _assert(game.device_lab.last_local_save_ok and
        game.device_lab_export_note.text.contains("СОХРАН"),
        "Genuine export button performs explicit JSON save on the local device")
    _press(game,KEY_ESCAPE)
    _assert(not game.device_lab_panel.visible and not game.paused and
        game.session.checkpoint()==checkpoint,
        "ESC returns to original playable 3D mission without changing save")
    _press(game,KEY_L)
    _press(game,KEY_F8)
    _assert(game.locale=="en" and game.device_lab_label.text.contains("DEVICE LAB") and
        game.device_lab_export_button.text.contains("LOCAL JSON"),
        "All device test HUD buttons and explanations localize on the actual game")
    game.device_lab_close_button.pressed.emit()
    _assert(not game.device_lab_panel.visible and not game.paused,
        "Closing translated native lab restores player control")
    _assert(game._checkpoint_payload()["schema"]=="IRON_PULSE_CAMPAIGN_V6" and
        not game._checkpoint_payload().has("device_lab") and
        game.field_stations.size()==2 and game.terminals.size()==6,
        "G4 saves no metrics inside V6/V9 gameplay and keeps both G2 strategies")
    _assert(game.performance_audit.release_gate()["production_ready"]==false and
        not game.device_lab.snapshot(true)["hardware_physically_verified"],
        "On-device laboratory cannot bypass the original production-release HOLD")
    game.queue_free()
    await process_frame
    _finish()
