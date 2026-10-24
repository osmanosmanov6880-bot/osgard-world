extends SceneTree
## HORIZON R7 quick gameplay actions actually enter Godot's input pipeline.
const TOUCH = preload("res://scripts/horizon_touch_controls.gd")
var passed := 0
var failed := 0
class ActionProbe extends Node:
	var pressed: Array[String] = []
	func _input(event: InputEvent) -> void:
		if event is InputEventAction and event.pressed:
			pressed.append(event.action)

func verify(ok: bool, info: String) -> void:
	if ok: passed += 1
	else:
		failed += 1
		push_error("HORIZON R7 QUICK ACTION: "+info)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var controls: CanvasLayer = TOUCH.new()
	root.add_child(controls)
	var probe := ActionProbe.new()
	root.add_child(probe)
	controls.call("set_preview",true)
	controls.call("set_mode",true,false)
	var menu: PanelContainer = controls.get_node("QuickActionsPanel")
	var toggle: Button = controls.get_node("QuickActionsToggle")
	var quick: Dictionary = controls.get("_quick_buttons")
	var actions = ["drive_trial","show_map","governor","field_journal","save_game","language"]
	verify(quick.size()==6,"six real non-movement game commands")
	verify(toggle.visible,"accessible button shown on touch")
	verify(not menu.visible,"action menu starts closed")
	for action in actions:
		verify(quick.has(action),"exposes "+action)
		verify(InputMap.has_action(action),"uses registered original action "+action)
		var button: Button = quick.get(action)
		verify(button != null and not button.text.is_empty(),"localized action label "+action)
	controls.call("_toggle_quick_actions")
	verify(menu.visible,"menu opens from real native button")
	var buttons_hidden := true
	for node in controls.get_children():
		if node is TouchScreenButton and node.visible: buttons_hidden=false
	verify(buttons_hidden,"opening quick menu blocks accidental gas and steering")
	controls.call("_activate_quick","drive_trial")
	verify(not menu.visible,"one-shot action menu closes after mission command")
	await process_frame
	verify(probe.pressed.has("drive_trial"),"driving academy reaches actual input event pipeline")
	controls.call("_toggle_quick_actions")
	controls.call("set_mode",true,true)
	verify(not toggle.visible and not menu.visible,"modal pause or strategy fully blocks menu")
	probe.pressed.clear()
	controls.call("_activate_quick","save_game")
	await process_frame
	verify(probe.pressed.is_empty(),"blocked menu cannot trigger save or mutate game")
	controls.call("set_mode",false,false)
	verify(toggle.visible,"menu recovers after closing modal")
	controls.call("_activate_quick","show_map")
	await process_frame
	verify(probe.pressed.has("show_map"),"map toggle reaches native input pipeline")
	controls.queue_free()
	probe.queue_free()
	print("HORIZON R7 QUICK ACTION NATIVE: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
