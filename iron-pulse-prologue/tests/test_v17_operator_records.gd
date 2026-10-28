extends SceneTree
## V17: honest private archive, atomic corruption handling, original Godot UI.
var checks: int = 0
var problems: Array[String] = []
const SAVE: String = "user://iron_pulse_v17_ci_operator_records.json"
const OTHER_SAVE: String = "user://iron_pulse_v17_ci_existing_campaign.json"

func _initialize() -> void:
    call_deferred("_run")

func _assert(ok: bool,why: String) -> void:
    checks += 1
    if not ok:
        problems.append(why)

func _press(game: Node,key: Key) -> void:
    var event := InputEventKey.new()
    event.pressed = true
    event.keycode = key
    game._input(event)

func _true_win() -> IPCrisisEngine:
    var e := IPCrisisEngine.new()
    e.reset("blackout")
    e.scan_core()
    e.choose_priority("crew")
    e.repair_coolant()
    e.cycle_bus(1)
    e.tick(25.0)
    e.cycle_bus(1)
    e.cycle_bus(1)
    e.activate_override()
    e.escape()
    return e

func _true_failure() -> IPCrisisEngine:
    var e := IPCrisisEngine.new()
    e.reset("thermal")
    e.heat = 99.0
    e.tick(10.0)
    return e

func _run() -> void:
    var disk := IPCheckpointStore.new()
    disk.clear(SAVE)
    disk.clear(OTHER_SAVE)
    var archive := IPRunArchive.new()
    archive.archive_path=SAVE
    _assert(archive.entries.is_empty() and archive.next_sequence==1,"Never create fake seeded personal records")
    _assert(not archive.load_archive(),"Absent local file is not a fabricated save")
    var working := IPCrisisEngine.new()
    working.reset("blackout")
    var before_open: Dictionary=working.checkpoint()
    _assert(not archive.record_finished(working),"Unfinished original engine must never create result")
    _assert(working.checkpoint()==before_open and not FileAccess.file_exists(SAVE),
        "Rejected attempt neither mutates gameplay nor creates local file")

    var first: IPCrisisEngine=_true_win()
    _assert(first.won and not first.lost and first.grade() in ["S","A","B"],
        "The archived run is a real finished source-engine rescue")
    var checkpoint_before: Dictionary=first.checkpoint()
    _assert(archive.record_finished(first),"A valid original victory persists atomically")
    _assert(first.checkpoint()==checkpoint_before,"Recording does not mutate completed game")
    var totals: Dictionary=archive.readout()
    _assert(totals["stored"]==1 and totals["wins"]==1 and totals["failures"]==0 and totals["local_only"],
        "One real victory becomes one private local record")
    _assert(not totals["authenticity_certified"],"Local file checksum never claims cryptographic authenticity")
    _assert(archive.summary("ru").contains("АРХИВ ОПЕРАТОРА") and archive.summary("en").contains("OPERATOR RECORDS"),
        "Native records have full RU/EN copy")
    _assert(archive.summary("ru").contains("GRID") and not archive.summary("en").contains("ONLINE LEADERBOARD"),
        "Personal best is source-bound and never a fabricated global rank")

    var reload := IPRunArchive.new()
    reload.archive_path=SAVE
    _assert(reload.load_archive() and reload.entries.size()==1 and reload.next_sequence==2,
        "Run survives a full cold reload with checksum and strict validation")
    _assert(reload.entries[0]["run_number"]==1 and reload.entries[0]["outcome"]=="VICTORY" and
        reload.entries[0]["history"].back()=="crew_evacuated","Cold reload preserves actual engine evidence and sequence")

    # A valid wrapper containing invalid data must be rejected *atomically*.
    var poison: Dictionary=disk.load_checkpoint(SAVE)
    poison["entries"][0]["heat"]=99999.0
    _assert(disk.save(poison,SAVE),"Test harness can construct a checksum-valid malformed payload")
    var remembered: Dictionary=reload.entries[0].duplicate(true)
    _assert(not reload.load_archive() and reload.entries[0]==remembered,
        "Semantic corruption is rejected without partially overwriting loaded history")
    var unsupported: Dictionary=disk.load_checkpoint(SAVE)
    unsupported["schema"]="INCOMPATIBLE_V999"
    _assert(disk.save(unsupported,SAVE) and not reload.load_archive() and reload.entries.size()==1,
        "Unsupported file version fails closed and preserves in-memory records")
    # Re-establish the good archive through the normal atomic store.
    var good: Dictionary={"schema":IPRunArchive.FORMAT,"next_sequence":archive.next_sequence,
        "entries":archive.entries.duplicate(true)}
    _assert(disk.save(good,SAVE) and reload.load_archive(),"Valid run data can be recovered via normal local save path")

    var loss: IPCrisisEngine=_true_failure()
    _assert(loss.lost and not loss.won,"Failure originated in real source engine thermal physics")
    var loss_before: Dictionary=loss.checkpoint()
    _assert(reload.record_finished(loss),"Failed operation is kept with real UNRATED result")
    _assert(reload.entries.back()["grade"]=="UNRATED" and
        reload.entries.back()["reason"]=="reactor_overheat" and reload.entries.back()["outcome"]=="FAILURE",
        "No artificial high grades or victory on failed run")
    _assert(loss.checkpoint()==loss_before and reload.readout()["failures"]==1,
        "Recording actual loss does not alter reactor and counters are honest")

    # The archive is intentionally BOUNDED (last sixteen, not global adoption).
    for i in range(19):
        var genuine: IPCrisisEngine = _true_win() if i%2==0 else _true_failure()
        _assert(reload.record_finished(genuine),"Each subsequent entry comes from completed engine run #%d" % i)
    _assert(reload.entries.size()==IPRunArchive.MAX_RECORDS and reload.next_sequence==22,
        "Only newest sixteen actual runs remain after twenty-one legitimate completions")
    _assert(reload.entries[0]["run_number"]==6 and reload.entries.back()["run_number"]==21,
        "Overflow retains ordering and monotonically increasing local run numbers")
    var persisted := IPRunArchive.new()
    persisted.archive_path=SAVE
    _assert(persisted.load_archive() and persisted.entries.size()==16 and persisted.next_sequence==22,
        "Reload retains bounded history, local sequential IDs and exact count")
    _assert(persisted.summary("en").contains("RUNS 16/16") and
        persisted.summary("ru").contains("ЛИЧНЫЙ РЕКОРД"),
        "Bilingual overview uses actual stored entries and per-scenario personal best")

    # Corrupt the checksum, not JSON syntax: the Godot JSON parser itself
    # logs fatal-looking parse errors on intentionally invalid tokens.
    # A complete valid wrapper with a false digest must fail silently
    # without treating an expected input rejection as an engine crash.
    var file: FileAccess=FileAccess.open(SAVE,FileAccess.WRITE)
    _assert(file!=null,"Checksum test accesses local records file")
    if file!=null:
        var bad_digest: Dictionary={
            "format":IPCheckpointStore.FORMAT,
            "version":IPCheckpointStore.VERSION,
            "payload_json":"{}",
            "sha256":"0000000000000000000000000000000000000000000000000000000000000000"
        }
        file.store_string(JSON.stringify(bad_digest))
        file.flush()
        file.close()
    _assert(not persisted.load_archive() and persisted.entries.size()==16 and persisted.is_corrupt,
        "Checksum tampering fails closed without deleting valid loaded records")
    var still_closed: Dictionary=persisted.entries.back().duplicate(true)
    _assert(not persisted.record_finished(first) and persisted.entries.back()==still_closed,
        "Corrupted original cannot be silently overwritten by a new completed game")
    # Path restriction and failed I/O must not change live memory.
    var old_path: String=persisted.archive_path
    persisted.archive_path="user://../outside_records.json"
    var count_before: int=persisted.entries.size()
    _assert(not persisted.record_finished(first) and persisted.entries.size()==count_before,
        "Path traversal cannot write or alter archive memory")
    persisted.archive_path=old_path
    _assert(disk.clear(SAVE),"Cleanup corrupted test record")
    var reconstructed: Dictionary={"schema":IPRunArchive.FORMAT,
        "next_sequence":persisted.next_sequence,"entries":persisted.entries.duplicate(true)}
    _assert(disk.save(reconstructed,SAVE),"Recovery writes a fully validated bounded archive")

    # Native 3D integration: show the actual records before gameplay, then
    # finish a real mission and verify storage and touchscreen controls.
    var packed: PackedScene=load("res://Main.tscn")
    _assert(packed!=null,"Original Godot 3D game remains loadable")
    if packed==null:
        _finish()
        return
    var game=packed.instantiate()
    game.run_archive.archive_path=SAVE
    root.add_child(game)
    await process_frame
    await process_frame
    _assert(game.run_archive.load_archive(),"Native app opens existing local personal history")
    _assert(game.archive_intro_button.custom_minimum_size.y>=44 and
        not game.archive_panel.visible and game.archive_close_button.custom_minimum_size.y>=44,
        "Native 44px+ intro/close controls exist, history starts closed")
    _press(game,KEY_O)
    _assert(game.archive_panel.visible and game.archive_label.text.contains("АРХИВ ОПЕРАТОРА"),
        "Real O keyboard input opens genuine in-game history from intro")
    _assert(not game.started,"Reading the archive cannot start a mission")
    _press(game,KEY_L)
    _assert(game.locale=="en" and game.archive_label.text.contains("LOCAL SAVES"),
        "Open records panel responds to the existing RU/EN toggle")
    _press(game,KEY_ESCAPE)
    _assert(not game.archive_panel.visible,"ESC closes operator records and returns to menu")

    game.start_run()
    var live: Dictionary=game.session.checkpoint()
    _press(game,KEY_O)
    _assert(not game.archive_panel.visible and game.session.checkpoint()==live,
        "Archive hotkey cannot interrupt or alter a live mission")
    game.session.scan_core()
    game.session.choose_priority("crew")
    game.session.repair_coolant()
    game.session.cycle_bus(1)
    game.session.tick(25.0)
    game.session.cycle_bus(1)
    game.session.cycle_bus(1)
    game.session.activate_override()
    game.session.escape()
    _assert(game.session.won,"Native UI test completed real original GRID victory")
    game._show_end()
    _assert(game.archive_last_save_ok and game.run_archive.entries.size()==16 and
        game.run_archive.entries.back()["run_number"]==22,
        "Actual Godot win persists the 22nd real result, retaining bounded archive")
    game._show_end()
    _assert(game.run_archive.next_sequence==23,"Repeated end-state rendering cannot double count a victory")
    var final_snapshot: Dictionary=game.session.checkpoint()
    _press(game,KEY_O)
    _assert(game.archive_panel.visible and game.archive_label.text.contains("RUNS 16/16"),
        "Completed mission opens the updated local archive through actual O input")
    _assert(game.session.checkpoint()==final_snapshot,"Reading records cannot mutate a finished mission")
    game.archive_close_button.pressed.emit()
    _assert(not game.archive_panel.visible,"Native touch close control dismisses records")
    game.archive_end_button.pressed.emit()
    _assert(game.archive_panel.visible,"Native 52px end-screen button opens the records")
    game.archive_erase_button.pressed.emit()
    _assert(game.archive_erase_armed and game.run_archive.entries.size()==16,
        "First erase click is only a request and must never delete records")
    game.archive_erase_button.pressed.emit()
    _assert(not game.archive_erase_armed and game.run_archive.entries.is_empty() and
        not FileAccess.file_exists(SAVE),"Second deliberate confirmation deletes only local operator records")
    _assert(game.session.checkpoint()==final_snapshot and game.session.won,
        "Deleting archive cannot edit current completed game")
    game.archive_close_button.pressed.emit()
    game._restart()
    var standard: Dictionary=game._checkpoint_payload()
    _assert(standard.get("schema")=="IRON_PULSE_CAMPAIGN_V6" and
        not standard.has("operator_records") and not standard.has("run_archive"),
        "Original V6/V9 checkpoint schema is still intact")
    game.queue_free()
    await process_frame

    # Erasing records must never affect a separate old campaign save.
    var campaign_payload: Dictionary={"schema":"IRON_PULSE_CAMPAIGN_V6","preserved":true}
    _assert(disk.save(campaign_payload,OTHER_SAVE),"Control campaign snapshot can be stored separately")
    var blank:=IPRunArchive.new()
    blank.archive_path=SAVE
    _assert(blank.erase() and disk.load_checkpoint(OTHER_SAVE)==campaign_payload,
        "Explicit archive erase does not touch an existing saved campaign")
    disk.clear(SAVE)
    disk.clear(OTHER_SAVE)
    _finish()

func _finish() -> void:
    if problems.is_empty():
        print("IRON PULSE V17 OPERATOR RECORDS PASS: %d original engine, local persistence and UI checks" % checks)
        quit(0)
        return
    for issue in problems:
        push_error("V17 OPERATOR RECORDS FAIL: "+issue)
    quit(1)
