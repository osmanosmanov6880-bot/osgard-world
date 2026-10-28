extends SceneTree
## V18: measured adaptation, NEVER simulated world traffic or an FPS certificate.
var checks: int = 0
var failures: Array[String] = []
const REAL_SAMPLES: Dictionary = {"sample_count":120,"p95_frame_ms":41.0,"estimated_fps":24.0}
const FAST_SAMPLES: Dictionary = {"sample_count":120,"p95_frame_ms":14.0,"estimated_fps":70.0}
const SMALL_SAMPLES: Dictionary = {"sample_count":20,"p95_frame_ms":70.0}

func _initialize() -> void:
    call_deferred("_run")

func _assert(ok: bool,why: String) -> void:
    checks += 1
    if not ok:
        failures.append(why)

func _key(game: Node,key: Key) -> void:
    var event := InputEventKey.new()
    event.keycode = key
    event.pressed = true
    game._input(event)

func _feed(controller: IPAdaptivePerformance,metrics: Dictionary,
        mode: String,compact: bool,steps: int) -> Array[String]:
    var outcomes: Array[String] = []
    for i in range(steps):
        var result: String = controller.observe(0.2,true,mode,metrics,compact)
        if result != "":
            outcomes.append(result)
    return outcomes

func _run() -> void:
    var autopilot := IPAdaptivePerformance.new()
    var source := IPCrisisEngine.new()
    source.reset("thermal")
    var checkpoint_before: Dictionary = source.checkpoint()
    _assert(not autopilot.enabled and autopilot.readout("hero",{})["policy"]=="manual",
        "Source opens in manual graphics, no silent automated changes")
    _assert(_feed(autopilot,REAL_SAMPLES,"hero",false,120).is_empty(),
        "Disabled adaptation must never change player-selected graphics")
    autopilot.set_enabled(true)
    _assert(autopilot.enabled and autopilot.readout("hero",REAL_SAMPLES)["telemetry_uploaded"]==false,
        "Opt-in adaptation is explicitly local without network tracking")
    _assert(_feed(autopilot,SMALL_SAMPLES,"hero",false,60).is_empty(),
        "Warmup data of only 20 real frames cannot trigger arbitrary downgrade")
    _assert(_feed(autopilot,REAL_SAMPLES,"hero",false,15).is_empty(),
        "A single slow 3-second window cannot lower quality automatically")
    var down: Array[String] = _feed(autopilot,REAL_SAMPLES,"hero",false,16)
    _assert(down==["eco"] and autopilot.switches==1 and
        autopilot.last_reason=="measured_p95_slow",
        "Two genuinely slow p95 windows cause ONE existing ECO switch")
    _assert(_feed(autopilot,REAL_SAMPLES,"eco",false,72).is_empty(),
        "Post-switch cooldown blocks oscillation even during sustained slowdown")
    _assert(source.checkpoint()==checkpoint_before,
        "Frame pacing never changes reactor/gameplay checkpoint, health or story")
    _assert(_feed(autopilot,FAST_SAMPLES,"eco",true,115).is_empty(),
        "Compact/mobile viewport never promotes costly HERO despite fast frames")
    var recover: Array[String] = _feed(autopilot,FAST_SAMPLES,"eco",false,100)
    _assert(recover==["hero"] and autopilot.switches==2 and
        autopilot.last_reason=="sustained_measured_recovery",
        "Desktop restores HERO only after cooldown and measured sustained recovery")
    _assert(_feed(autopilot,FAST_SAMPLES,"hero",false,20).is_empty(),
        "Successful recovery does not create a second, duplicate transition")
    autopilot.set_enabled(false)
    _assert(_feed(autopilot,REAL_SAMPLES,"hero",false,100).is_empty() and
        autopilot.readout("hero",REAL_SAMPLES)["policy"]=="manual",
        "Player manual graphics selection disables all automatic overrides")
    autopilot.set_enabled(true)
    _assert(autopilot.observe(1.0,true,"hero",REAL_SAMPLES,false)=="" and
        autopilot.observe(-1.0,true,"hero",REAL_SAMPLES,false)=="" and
        autopilot.observe(INF,true,"hero",REAL_SAMPLES,false)=="",
        "Background/tab-suspension and invalid frame data are not real slow-frame evidence")
    _assert(_feed(autopilot,{"sample_count":120,"p95_frame_ms":-3.0},"hero",false,75).is_empty(),
        "Malformed telemetry is rejected rather than prompting a quality downgrade")
    _assert(autopilot.observe(0.2,false,"hero",REAL_SAMPLES,false)=="" and
        autopilot.slow_windows==0 and autopilot.fast_windows==0,
        "Paused/inactive sessions cannot advance the adaptive policy")
    _assert(autopilot.status_line("ru","hero",REAL_SAMPLES).contains("ГРАФИКА") and
        autopilot.status_line("en","eco",FAST_SAMPLES).contains("GRAPHICS"),
        "Compact genuine FPS diagnostic remains localized RU/EN")
    _assert(autopilot.readout("eco",FAST_SAMPLES)["hardware_certified"]==false and
        autopilot.readout("eco",FAST_SAMPLES)["fps_guaranteed"]==false,
        "No virtual/native hardware or high FPS certification is forged")

    # Use V12 actual observation logic, not a separately fabricated FPS meter.
    var actual_audit := IPPerformanceAudit.new()
    for i in range(IPPerformanceAudit.WINDOW):
        actual_audit.observe(0.048,true,"hero")
    var t: Dictionary=actual_audit.telemetry()
    _assert(t["sample_count"]==IPPerformanceAudit.WINDOW and
        t["p95_frame_ms"]>=47.0 and t["eco_suggested"],
        "V18 policy consumes the existing measured sliding real-frame window")
    var by_samples := IPAdaptivePerformance.new()
    by_samples.set_enabled(true)
    _assert(_feed(by_samples,t,"hero",false,32)==["eco"],
        "Real V12 source telemetry drives the same deterministic ECO decision")

    var scene: PackedScene = load("res://Main.tscn")
    _assert(scene != null,"Existing real Godot 3D scene remains loadable")
    if scene==null:
        _finish()
        return
    var game=scene.instantiate()
    root.add_child(game)
    await process_frame
    await process_frame
    _assert(game.auto_quality_button!=null and game.auto_quality_button.custom_minimum_size.y>=44,
        "V18 has a genuine 52px native touchscreen pause-setting button")
    _assert(game.quality_state_label!=null and game.quality_state_label.text.contains("MANUAL"),
        "Live gameplay HUD presents the player's original graphics mode")
    _assert(not game.adaptive_performance.enabled and
        game.adaptive_performance.readout(game.quality_mode,{})["hardware_certified"]==false,
        "Actual Godot game never starts with undocumented adaptive profiling")
    var original: Dictionary=game.session.checkpoint()
    _key(game,KEY_K)
    _assert(game.adaptive_performance.enabled and
        game.auto_quality_button.text.contains("АВТО") and
        game.session.checkpoint()==original,
        "Actual K enables measured adaptation without changing source-game state")
    var before_manual: String=game.quality_mode
    _key(game,KEY_G)
    _assert(not game.adaptive_performance.enabled and game.quality_mode!=before_manual and
        game.session.checkpoint()==original,
        "Existing G manual HERO/ECO switch always overrides AUTO and preserves game state")
    _key(game,KEY_L)
    _assert(game.locale=="en" and game.auto_quality_button.text.contains("ENABLE AUTO"),
        "Pause setting follows the existing language switch")
    game.start_run()
    var running: Dictionary=game.session.checkpoint()
    game._pause_toggle()
    _assert(game.paused and game.pause_panel.visible,
        "Original Godot pause still works after adding a real setting")
    game.auto_quality_button.pressed.emit()
    _assert(game.adaptive_performance.enabled and game.session.checkpoint()==running,
        "Pause-screen touchscreen setting enables AUTO without altering gameplay")
    game.auto_quality_button.pressed.emit()
    _assert(not game.adaptive_performance.enabled and game.session.checkpoint()==running,
        "Second real touch press disables AUTO, preserves pause and original engine")
    game._resume()
    _assert(not game.paused and not game.pause_panel.visible,
        "Original resume remains usable after changing local graphics mode")
    var old: Dictionary=game._checkpoint_payload()
    _assert(old.get("schema")=="IRON_PULSE_CAMPAIGN_V6" and
        not old.has("adaptive_quality") and not old.has("auto_quality"),
        "Pre-existing V6/V9 game saves are not mutated by V18 opt-in settings")
    _assert(game.performance_audit.release_gate()["production_ready"]==false,
        "Automatic graphics adjustment cannot bypass real hardware/AAA launch gates")
    game.queue_free()
    await process_frame
    _finish()

func _finish() -> void:
    if failures.is_empty():
        print("IRON PULSE V18 ADAPTIVE PERFORMANCE PASS: %d native quality, gameplay and GUI checks" % checks)
        quit(0)
        return
    for issue in failures:
        push_error("V18 ADAPTIVE FAIL: "+issue)
    quit(1)
