extends SceneTree
## CITY REIGN B65-B66: LIVE real-game on-foot F inspection of genuinely
## bought infrastructure, no pretend mission, no forged finance snapshots.
const VISIT = preload("res://scripts/city_reign_live_site_inspection.gd")
const MAIN = preload("res://scripts/main.gd")
const WORKS = preload("res://scripts/city_reign_civic_outcomes.gd")
const PARK = preload("res://scripts/city_reign_park_furniture.gd")
var ok: int = 0
var bad: int = 0

func verify(value: bool,description: String) -> void:
	if value: ok += 1
	else:
		bad += 1
		push_error("CITY REIGN B65 IN-WORLD PHYSICAL INSPECTION FAILED: "+description)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var sim: Node = root.get_node_or_null("GameState")
	verify(sim!=null,"real original GameState autoload must exist")
	if sim==null:
		quit(2)
		return
	var original: Dictionary = sim.get("data").duplicate(true)
	var old_lang: String = str(sim.get("locale"))
	var state: Dictionary = sim.call("new_game")
	verify(VISIT.source_invariants(),
		"source live street inspection exactly matches original funded road and park coordinates")
	verify(VISIT.SITES.size()==3,
		"only 3 original commissioned civic destinations are visitable")
	for place in [
		Vector3(104.0,0.0,-87.0),
		WORKS.KIOSK_AT,
		PARK.PARK_AT+Vector3(8.0,0,0)]:
		verify(VISIT.near_completed(state,place,false,false)=="",
			"unfunded public works cannot be inspected as already built")
	var state_before: Dictionary = state.duplicate(true)
	sim.set("data",state)
	verify(bool(sim.call("start_initiative","open_records")),
		"budget inspection must begin with ORIGINAL REAL resource debit")
	state = sim.get("data")
	verify(VISIT.near_completed(state,WORKS.KIOSK_AT,false,false)=="",
		"construction phase MUST NOT fabricate delivered public-finance landmark")
	for i in range(2):
		verify(bool(sim.call("advance_turn")),
			"original public records construction really advances turn "+str(i))
	state = sim.get("data")
	verify((state["projects_done"] as Array).has("open_records") and
		VISIT.near_completed(state,WORKS.KIOSK_AT,false,false)=="open_records",
		"only after real completion does player visit authentic built public records")
	verify(VISIT.near_completed(state,WORKS.KIOSK_AT,true,false)=="" and
		VISIT.near_completed(state,WORKS.KIOSK_AT,false,true)=="",
		"player must walk on actual sidewalk, never inspect via flying car or interior")
	verify(VISIT.near_completed(state,WORKS.KIOSK_AT+Vector3(11,0,0),false,false)=="",
		"real interaction stays strictly within 8.5 meter pavement proximity")
	var financial: Dictionary = state.duplicate(true)
	for lang in ["ru","en","zh"]:
		var message: String = VISIT.report(state,"open_records",lang)
		verify(message.contains(str(state["treasury"])) and
			message.contains(str(state["trust"][0])) and message.length()>30,
			"real live finance inspection reports authentic saved treasury and forum trust: "+lang)
	verify(state==financial,
		"reading real project does not change any financial/mission/save state")
	# Test both other legitimate completed-save paths as read-only fixtures.
	var saved_done: Array = state["projects_done"]
	state["projects_done"] = ["safe_crossings"]
	for center in WORKS.CROSSINGS:
		verify(VISIT.near_completed(state,center,false,false)=="safe_crossings",
			"all four ACTUAL painted zebra crossings are genuinely visitable on foot")
	var crossing_text: String = VISIT.report(state,"safe_crossings","en")
	verify(crossing_text.contains("4 crossings") and crossing_text.contains("17.3"),
		"live road speed inspect matches REAL funded NPC traffic target")
	verify(VISIT.near_completed(state,WORKS.KIOSK_AT,false,false)=="",
		"an unbought city finance pavilion is never made visible by paid crossings")
	state["projects_done"] = ["community_park"]
	var entrance: Vector3 = PARK.PARK_AT+Vector3(8.0,0,0)
	verify(VISIT.near_completed(state,entrance,false,false)=="community_park",
		"the true source resident park and benches can be inspected without map cheats")
	state["day_clock"]=18.0
	verify(VISIT.report(state,"community_park","en").contains("evening walks"),
		"original 18h city clock provides grounded real park evening narrative")
	state["day_clock"]=8.0
	verify(VISIT.report(state,"community_park","en").contains("park open"),
		"source 8h city clock correctly ends nighttime visitor story")
	state["projects_done"]=saved_done
	verify(VISIT.report(state,"community_park","en")=="",
		"not actually funded park never yields falsely successful visitor report")
	verify(VISIT.report(state,"not-a-real-project","en")=="",
		"unexpected arbitrary project IDs cannot mint a visiting interaction")
	verify(VISIT.near_completed(state,Vector3.INF,false,false)=="",
		"malformed physical player coordinates cannot trigger fake site actions")
	var actual_source: String = FileAccess.get_file_as_string(
		"res://scripts/main.gd")
	verify(actual_source.contains("CITY_REIGN_SITE_VISIT.near_completed(") and
		actual_source.contains("CITY_REIGN_SITE_VISIT.report(") and
		actual_source.contains("if not driving:"),
		"source shipped main scene genuinely wires original F to physical site inspection")
	verify(MAIN is Script and MAIN.can_instantiate(),
		"actual native main.tscn script still compiles with read-only F inspection")
	verify(int(state_before["treasury"])>0 and
		sim.get("data")["projects_done"].size()==1,
		"real first-payment source remains valid and no extra civic projects were fabricated")
	sim.set("data",original)
	sim.set("locale",old_lang)
	print("CITY REIGN B65 SOURCE REAL STREET INSPECTION: %d PASS %d FAIL" % [ok,bad])
	quit(0 if bad==0 else 1)
