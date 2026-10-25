extends SceneTree
## No imagined municipal metrics: prove bars are bound to real inputs.
const METRICS = preload("res://scripts/horizon_r93_real_civic_kpis.gd")
var passed := 0
var failed := 0
func verify(ok: bool,note: String) -> void:
	if ok: passed+=1
	else:
		failed+=1
		push_error("R93 LIVE METRIC FAILED: "+note)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var panel: VBoxContainer = METRICS.new()
	root.add_child(panel)
	var state := {"energy":5,"water":7,"food":6,"road_quality":82,"stability":63}
	var forecast := {"energy":93,"water":77,"food":86}
	panel.call("configure",state,forecast,"ru")
	var values: Dictionary = panel.get("metric_values")
	verify(values.size()==5,"five semantic city indicators")
	verify(values["energy"]==93 and values["water"]==77 and values["food"]==86,
		"forecasts are chosen over historical stored city values")
	verify(values["roads"]==82 and values["stability"]==63,
		"roads and stability are from the original authoritative state")
	verify(panel.get_child_count()==5,"exact five real rows, not fake decorative bars")
	for id in ["energy","water","food","roads","stability"]:
		var row := panel.get_node_or_null("R93_"+id)
		verify(row != null,"named actual Godot row exists: "+id)
		if row!=null:
			var indicator: ProgressBar = row.get_node_or_null("R93Bar_"+id) as ProgressBar
			verify(indicator!=null and int(indicator.value)==int(values[id]),
				"visual fill matches the original integer metric: "+id)
	state["road_quality"]=144
	state["stability"]=-11
	panel.call("configure",state,forecast,"en")
	var new_values: Dictionary = panel.get("metric_values")
	verify(new_values["roads"]==100 and new_values["stability"]==0,
		"out-of-range external save data is visually bounded")
	verify(panel.get_child_count()==5,"refresh replaces content rather than leaking panels")
	panel.queue_free()
	await process_frame
	print("R93 real civic indicators native: %d PASS %d FAIL" % [passed,failed])
	quit(0 if failed==0 else 1)
