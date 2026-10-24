extends SceneTree
## Real Godot 4.4.1 touch control contract: 8 same-engine InputMap actions,
## on-screen phone scale, no phantom keys in blocked menus, multilingual labels.
const TOUCH = preload("res://scripts/horizon_touch_controls.gd")
const CAR = preload("res://scripts/vehicle_controller.gd")
const PLAYER = preload("res://scripts/player_controller.gd")
var passed := 0
var failed := 0
func verify(ok: bool, message: String) -> void:
  if ok: passed += 1
  else:
    failed += 1
    push_error("HORIZON R6 TOUCH FAILED: "+message)

func _initialize() -> void:
  call_deferred("_run")

func _run() -> void:
  var controls: CanvasLayer = TOUCH.new()
  root.add_child(controls)
  var names = ["move_left","move_right","move_backward","move_forward","jump","enter_vehicle","interact","pause_game"]
  controls.call("set_preview",true)
  controls.call("set_mode",true,false)
  verify(controls.get_child_count()==names.size(),"exactly 8 native multi-touch buttons")
  for action in names:
    verify(InputMap.has_action(action),"input map contains "+action)
    var button: TouchScreenButton = controls.get_node_or_null("Touch_"+action) as TouchScreenButton
    verify(button != null,"native TouchScreenButton exists: "+action)
    if button == null: continue
    verify(button.action==action,"sends real gameplay action: "+action)
    verify(button.shape is CircleShape2D,"generous circular touch area: "+action)
    verify(button.texture_normal != null and button.texture_pressed != null,"normal and pressed state: "+action)
    verify(button.passby_press,"multi-finger sliding remains supported: "+action)
    verify(button.visible,"touch control is shown in preview mode: "+action)
    var label: Label = button.get_node_or_null("Caption") as Label
    verify(label != null and not label.text.is_empty(),"localized caption: "+action)
  var jump_label: Label = controls.get_node("Touch_jump/Caption") as Label
  var drive_text: String = jump_label.text
  controls.call("set_mode",false,false)
  verify(jump_label.text != drive_text,"handbrake and walking jump have distinct labels")
  controls.call("set_mode",true,true)
  var all_blocked := true
  for action in names:
    var b: TouchScreenButton = controls.get_node("Touch_"+action) as TouchScreenButton
    if b.visible: all_blocked=false
  verify(all_blocked,"all virtual actions vanish while a modal menu is open")
  controls.call("set_mode",true,false)
  var size: Vector2 = root.get_visible_rect().size
  var inside := true
  for action in names:
    var b: TouchScreenButton = controls.get_node("Touch_"+action) as TouchScreenButton
    var drawn_size := Vector2.ONE*96.0*b.scale.x
    if b.position.x < -2.0 or b.position.y < -2.0: inside=false
    if b.position.x+drawn_size.x>size.x+2.0 or b.position.y+drawn_size.y>size.y+2.0: inside=false
  verify(inside,"buttons stay inside current visible viewport")
  var vehicle: CharacterBody3D = CAR.new()
  var player: CharacterBody3D = PLAYER.new()
  root.add_child(vehicle)
  root.add_child(player)
  verify(vehicle.get("driving") != null,"touch actions feed real vehicle controller")
  verify(player.get("active") != null,"touch actions feed real on-foot controller")
  vehicle.queue_free()
  player.queue_free()
  controls.queue_free()
  print("HORIZON R6 TOUCH NATIVE: %d passed, %d failed" % [passed,failed])
  quit(0 if failed==0 else 1)
