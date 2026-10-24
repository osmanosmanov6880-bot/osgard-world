extends SceneTree
## R13: every mobile one-shot touch MUST reach real Node._input(), not merely
## the held InputMap state. Actual Main enters vehicles in _input(event);
## HUD opens pause in _input(event). R11 proved only held GAS/STEER input.
const TOUCH = preload("res://scripts/horizon_touch_controls.gd")

class ActionProbe:
  extends Node
  var actions: Array[String] = []
  func _input(event: InputEvent) -> void:
    if event is InputEventAction:
      var command: InputEventAction = event as InputEventAction
      actions.append(str(command.action) + (":down" if command.pressed else ":up"))

var passed := 0
var failed := 0
func check(ok: bool, message: String) -> void:
  if ok: passed += 1
  else:
    failed += 1
    push_error("R13 TOUCH COMMAND FAILED: "+message)

func _initialize() -> void:
  call_deferred("_run")

func touch(button: TouchScreenButton, finger: int, pressed: bool) -> void:
  var event := InputEventScreenTouch.new()
  event.index = finger
  event.position = button.position + Vector2.ONE * (48.0*button.scale.x)
  event.pressed = pressed
  root.push_input(event,true)

func frames(count: int = 2) -> void:
  for i in range(count): await physics_frame

func _run() -> void:
  var probe := ActionProbe.new()
  root.add_child(probe)
  var pad: CanvasLayer = TOUCH.new()
  root.add_child(pad)
  pad.call("set_preview",true)
  pad.call("set_mode",false,false)
  await frames()
  var expected := ["enter_vehicle","interact","pause_game"]
  for i in range(expected.size()):
    var action: String = expected[i]
    var button: TouchScreenButton = pad.get_node("Touch_"+action) as TouchScreenButton
    check(button != null,"actual virtual command button: "+action)
    if button == null: continue
    check(not button.passby_press,"one-shot commands require intentional button touch: "+action)
    var initial: int = probe.actions.size()
    touch(button,i,true)
    await frames()
    check(button.is_pressed(),"native button registers finger: "+action)
    check(Input.is_action_pressed(action),"pressed action reaches InputMap: "+action)
    check(probe.actions.slice(initial).count(action+":down")==1,
      "exactly one dispatched _input command event: "+action)
    touch(button,i,false)
    await frames()
    check(not Input.is_action_pressed(action),"native action released: "+action)
    check(probe.actions.slice(initial).count(action+":up")==1,
      "one-shot command release sent to _input: "+action)
  var gas: TouchScreenButton = pad.get_node("Touch_move_forward") as TouchScreenButton
  var wheel: TouchScreenButton = pad.get_node("Touch_move_left") as TouchScreenButton
  check(gas.passby_press and wheel.passby_press,"continuous axes retain slide-to-press driving")
  var baseline: int = probe.actions.size()
  touch(gas,4,true)
  touch(wheel,5,true)
  await frames()
  check(Input.is_action_pressed("move_forward") and Input.is_action_pressed("move_left"),
    "gas and steering both respond to independent fingers")
  check(probe.actions.size()==baseline,"continuous driving never dispatches duplicate _input events")
  touch(gas,4,false)
  touch(wheel,5,false)
  await frames()
  check(not Input.is_action_pressed("move_forward"),"acceleration released")
  check(not Input.is_action_pressed("move_left"),"steering released")
  pad.call("set_mode",false,true)
  await frames()
  check(not (pad.get_node("Touch_enter_vehicle") as TouchScreenButton).visible,
    "car button hidden while menu blocks game")
  pad.call("set_mode",false,false)
  await frames()
  var enter: TouchScreenButton = pad.get_node("Touch_enter_vehicle") as TouchScreenButton
  check(enter.visible,"car button returns after menu closes")
  var left_label: Label = pad.get_node("Touch_move_left/Caption") as Label
  var right_label: Label = pad.get_node("Touch_move_right/Caption") as Label
  check(left_label.text.length()>=2 and right_label.text.length()>=2,
    "left and right use readable localized text instead of unsupported arrow glyphs")
  pad.queue_free()
  probe.queue_free()
  print("HORIZON R13 MOBILE COMMAND NATIVE: %d passed, %d failed" % [passed,failed])
  quit(0 if failed==0 else 1)
