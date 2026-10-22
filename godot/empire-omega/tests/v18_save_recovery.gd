extends SceneTree
## Uses isolated disposable files; does not modify a player's campaign save.
## Requires Godot 4.4.1, not executed by the portable Python suite.
var checks := 0
var errors := 0
const TEST_PRIMARY = "user://osgard_v18_native_primary.json"
const TEST_PENDING = "user://osgard_v18_native_staged.json"
const TEST_BACKUP = "user://osgard_v18_native_backup.json"

func _initialize() -> void:
	call_deferred("_run")

func check(value: bool, description: String) -> void:
	checks += 1
	if value:
		print("SAVE RECOVERY PASS: ",description)
	else:
		errors += 1
		push_error("SAVE RECOVERY FAIL: " + description)

func discard(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func corrupt(path: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string("{not valid json}")
		file.close()

func _run() -> void:
	var sim: Variant = root.get_node_or_null("GameState")
	check(sim != null,"game state singleton exists")
	if sim == null:
		quit(2)
		return
	var old_primary: String = sim.save_path
	var old_pending: String = sim.pending_save_path
	var old_backup: String = sim.backup_save_path
	var old_state: Dictionary = sim.data.duplicate(true)
	sim.save_path = TEST_PRIMARY
	sim.pending_save_path = TEST_PENDING
	sim.backup_save_path = TEST_BACKUP
	for path in [TEST_PRIMARY, TEST_PENDING, TEST_BACKUP]:
		discard(path)
	check(not sim.load_game(),"empty storage does not report a loaded campaign")
	check(sim.last_load_source == "","no phantom load success")
	sim.data = sim.new_game()
	sim.data["treasury"] = 1111
	check(sim.save_game(),"first save creates a valid primary snapshot")
	check(sim.last_save_ok,"save success is only true after committing the file")
	check(sim._read_valid_save(TEST_PRIMARY).get("state", {}).get("treasury", -1) == 1111,"primary snapshot is readable")
	sim.data["treasury"] = 2222
	check(sim.save_game(),"second save commits a new primary")
	check(sim._read_valid_save(TEST_BACKUP).get("state", {}).get("treasury", -1) == 1111,"backup contains previous valid snapshot")
	corrupt(TEST_PRIMARY)
	sim.data["treasury"] = 5555
	check(sim.load_game(),"corrupt primary restores backup")
	check(sim.last_load_source == "backup" and int(sim.data["treasury"]) == 1111,"recovery provenance and resources are correct")
	sim.data["treasury"] = 3333
	check(sim.save_game(),"saving after recovery is allowed")
	check(sim._read_valid_save(TEST_BACKUP).get("state", {}).get("treasury", -1) == 1111,"corrupt primary cannot destroy verified backup")
	check(sim._read_valid_save(TEST_PRIMARY).get("state", {}).get("treasury", -1) == 3333,"new primary contains current state")
	discard(TEST_PRIMARY)
	sim.data["treasury"] = 9999
	check(sim.load_game(),"missing primary automatically restores backup")
	check(int(sim.data["treasury"]) == 1111,"restored snapshot retains original resources")
	var saved_state: Dictionary = sim.data.duplicate(true)
	corrupt(TEST_BACKUP)
	check(not sim.load_game(),"all damaged files cause a clean failure")
	check(sim.last_load_source == "" and sim.data == saved_state,"failed load cannot overwrite active campaign")
	discard(TEST_BACKUP)
	sim.data = sim.new_game()
	sim.data["treasury"] = 4444
	var staged: FileAccess = FileAccess.open(TEST_PENDING, FileAccess.WRITE)
	if staged != null:
		staged.store_string(JSON.stringify(sim._save_state_payload()))
		staged.close()
	sim.data["treasury"] = 5555
	check(sim.load_game(),"valid staged snapshot can recover interrupted first save")
	check(sim.last_load_source == "staged" and int(sim.data["treasury"]) == 4444,"staged recovery preserves newest valid state")
	discard(TEST_PENDING)
	sim.data["population"] = -100
	check(not sim.save_game(),"invalid in-memory state is not written")
	check(not sim.last_save_ok,"failed save is never reported as success")
	check(sim._read_valid_save(TEST_PRIMARY).is_empty(),"invalid write did not create a new primary")
	for path in [TEST_PRIMARY, TEST_PENDING, TEST_BACKUP]:
		discard(path)
	sim.save_path = old_primary
	sim.pending_save_path = old_pending
	sim.backup_save_path = old_backup
	sim.data = old_state
	print("GODOT SAVE RECOVERY: %d / %d checks" % [checks - errors, checks])
	quit(0 if errors == 0 else 1)
