extends RefCounted
## CITY REIGN R177 — first 6 REAL mission actions observed in the live game.
## In-memory ONLY. No SDK, telemetry network, device identifiers, analytics
## cookies, email, user file access, save mutations or self-awarded rewards.
## This measures active foreground playable seconds, NOT wall-clock or fun.
const EPISODE=preload("res://scripts/city_reign_episode_sequence.gd")
const FIRST_SIX: int=EPISODE.TOTAL_STEPS
const TARGET_MIN_SECONDS: float=300.0
const TARGET_MAX_SECONDS: float=600.0
const MAX_SECONDS: float=7200.0
const MAX_EVENTS: int=12
const MAX_FRAME_DELTA: float=0.5
const LANGUAGE = {
	"ru":{"progress":"ПРОХОЖДЕНИЕ ПЕРВЫХ ШЕСТИ","resumed":"ЧАСТИЧНЫЙ ПРОГРЕСС",
		"complete":"ПЕРВЫЕ ШЕСТЬ ЗАВЕРШЕНЫ",
		"hold":"НЕ ПОДТВЕРЖДЕНО ПОЛНОЕ ПРОХОЖДЕНИЕ",
		"now":"АКТИВНОЕ ВРЕМЯ"},
	"en":{"progress":"FIRST SIX PLAYTEST","resumed":"PARTIAL SESSION",
		"complete":"FIRST SIX FINISHED",
		"hold":"FULL RUN NOT VERIFIED",
		"now":"ACTIVE PLAY TIME"},
	"zh":{"progress":"前六项任务测试","resumed":"部分进度",
		"complete":"前六项任务已完成",
		"hold":"完整通关尚未验证",
		"now":"有效游玩时间"}
}
var started: bool=false
var initial_step: int=0
var last_step: int=0
var elapsed_active: float=0.0
var last_step_started_at: float=0.0
var completed_at: float=-1.0
var first_run: bool=false
var contiguous: bool=true
var skipped_count: int=0
var excluded_frames: int=0
var background_frames: int=0
var menu_frames: int=0
var events: Array[Dictionary]=[]
var start_reason: String="scene"
var over_budget: bool=false

static func actual_step(state: Dictionary) -> int:
	return clampi(int(state.get("mission",0)),0,FIRST_SIX)

func begin(state: Dictionary,reason: String="scene") -> void:
	initial_step=actual_step(state)
	last_step=initial_step
	started=true
	first_run=initial_step==0
	contiguous=true
	skipped_count=0
	excluded_frames=0
	background_frames=0
	menu_frames=0
	over_budget=false
	elapsed_active=0.0
	last_step_started_at=0.0
	completed_at=-1.0
	events.clear()
	start_reason=reason if ["scene","reset","load","migrated"].has(reason) else "scene"

func observe(delta: float,state: Dictionary,menu_open: bool=false,
		foreground: bool=true) -> void:
	if not started:
		begin(state)
	if not foreground:
		background_frames+=1
	elif menu_open:
		menu_frames+=1
	elif not is_finite(delta) or delta<0.0 or delta>MAX_FRAME_DELTA:
		excluded_frames+=1
	elif completed_at<0.0 and elapsed_active<MAX_SECONDS:
		elapsed_active=minf(MAX_SECONDS,elapsed_active+delta)
		if elapsed_active>=MAX_SECONDS:
			over_budget=true
	var step: int=actual_step(state)
	if step==last_step:
		return
	if step<last_step:
		# A new saved career or restart must not inherit another session's
		# time. A loaded stage>0 can never count as a full first run.
		begin(state,"load")
		return
	if step>last_step+1:
		contiguous=false
		skipped_count+=step-last_step-1
	# Never fabricate six legitimate mission_updated events from a jump.
	if events.size()<MAX_EVENTS:
		events.append({
			"from":last_step,"to":step,"active_elapsed_s":elapsed_active,
			"step_duration_s":maxf(0.0,elapsed_active-last_step_started_at),
			"source":"actual MissionManager/GameState mission index"
		})
	last_step=step
	last_step_started_at=elapsed_active
	if step>=FIRST_SIX:
		completed_at=elapsed_active

func full_run_observed() -> bool:
	return (started and first_run and contiguous and
		last_step>=FIRST_SIX and events.size()==FIRST_SIX and
		completed_at>=0.0 and not over_budget)

func report() -> Dictionary:
	var verified: bool=full_run_observed()
	var result: Dictionary={
		"schema":"city-reign-r177-first-six-observer-v1",
		"source":"Godot live main scene + actual GameState mission index only",
		"engine":"Godot 4.4.1",
		"status":"complete" if verified else ("incomplete" if last_step<FIRST_SIX else "unverified"),
		"first_six_verified":verified,
		"timing_goal_5_to_10_minutes_met":null,
		"timing_goal_evaluated":false,
		"full_human_playtest_attested":false,
		"initial_source_mission":initial_step,
		"current_source_mission":last_step,
		"source_reset_reason":start_reason,
		"contiguous_real_stage_changes":contiguous,
		"skipped_source_steps":skipped_count,
		"active_foreground_play_seconds":elapsed_active,
		"step_transitions":events.duplicate(true),
		"invalid_long_frame_count":excluded_frames,
		"backgrounded_frame_count":background_frames,
		"menu_excluded_frame_count":menu_frames,
		"max_session_duration_reached":over_budget,
		"has_network_telemetry":false,
		"contains_location_or_device_identifiers":false,
		"local_manual_export_only":true,
		"note":"Measures active, foreground, unblocked in-game frame time. Not wall-clock, real-device FPS, enjoyability or certified human first-play testing."
	}
	if verified:
		result["timing_goal_evaluated"]=true
		result["timing_goal_5_to_10_minutes_met"]=completed_at>=TARGET_MIN_SECONDS and completed_at<=TARGET_MAX_SECONDS
		result["completed_active_seconds"]=completed_at
	return result

func status_text(locale: String="ru") -> String:
	var lang: String=locale if LANGUAGE.has(locale) else "ru"
	var l: Dictionary=LANGUAGE[lang]
	var heading: String=str(l["complete"]) if full_run_observed() else (
		str(l["resumed"]) if not first_run else str(l["progress"]))
	var progress: String=str(last_step)+"/"+str(FIRST_SIX)
	var seconds: int=roundi(elapsed_active)
	var minutes: int=seconds/60
	var remainder: int=seconds%60
	var status: String=heading+" · "+progress+" · "+str(l["now"])+" %d:%02d" % [minutes,remainder]
	if last_step>=FIRST_SIX and not full_run_observed():
		status+=" · "+str(l["hold"])
	return status

func invariants_hold() -> bool:
	if events.size()>MAX_EVENTS or elapsed_active<0.0 or elapsed_active>MAX_SECONDS:
		return false
	if not started or last_step<0 or last_step>FIRST_SIX:
		return false
	if first_run!=(initial_step==0):
		return false
	var prev: int=initial_step
	for e in events:
		var to_step: int=int(e["to"])
		if int(e["from"])!=prev or to_step<=prev or to_step>FIRST_SIX:
			return false
		prev=to_step
	return prev==last_step
