extends CanvasLayer
## HORIZON R6 - real multitouch input for the existing Godot game actions.
## This is not a simulated on-screen keyboard: TouchScreenButton has native
## multi-finger ownership and feeds the SAME InputMap used by the car and player.

const SIZE: int = 96
const ACTIONS = ["move_left","move_right","move_backward","move_forward","jump","enter_vehicle","interact","pause_game"]
const LABELS = {
  "ru": {
    "move_left":"◀","move_right":"▶","move_backward":"ТОРМ","move_forward":"ГАЗ",
    "jump_driving":"РУЧН.","jump_walking":"ПРЫГ","enter_vehicle":"АВТО","interact":"F","pause_game":"Ⅱ"
  },
  "en": {
    "move_left":"◀","move_right":"▶","move_backward":"BRAKE","move_forward":"GO",
    "jump_driving":"PARK","jump_walking":"JUMP","enter_vehicle":"CAR","interact":"F","pause_game":"Ⅱ"
  },
  "zh": {
    "move_left":"◀","move_right":"▶","move_backward":"刹车","move_forward":"前进",
    "jump_driving":"手刹","jump_walking":"跳跃","enter_vehicle":"车辆","interact":"F","pause_game":"Ⅱ"
  }
}
const WALK_BACK_LABELS = {"ru":"НАЗАД","en":"BACK","zh":"后退"}

var _buttons: Dictionary = {}
var _labels: Dictionary = {}
var _preview := false
var _driving := false
var _blocked := false
var _locale := ""
var _screen_size := Vector2.ZERO

func _ready() -> void:
  layer = 3
  for action in ACTIONS:
    assert(InputMap.has_action(action), "Missing required native InputMap action: "+action)
    var button := TouchScreenButton.new()
    button.name = "Touch_"+action
    button.action = action
    button.visibility_mode = TouchScreenButton.VISIBILITY_TOUCHSCREEN_ONLY
    button.passby_press = true
    button.texture_normal = _disc(action,false)
    button.texture_pressed = _disc(action,true)
    var shape := CircleShape2D.new()
    shape.radius = 44.0
    button.shape = shape
    button.shape_centered = true
    add_child(button)
    var caption := Label.new()
    caption.name = "Caption"
    caption.position = Vector2(0.0,30.0)
    caption.size = Vector2(SIZE,36)
    caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
    caption.add_theme_font_size_override("font_size",12)
    caption.add_theme_color_override("font_color",Color("F3F8FC"))
    button.add_child(caption)
    _buttons[action] = button
    _labels[action] = caption
  get_viewport().size_changed.connect(_layout)
  _layout()
  set_mode(false,false)

func _disc(action: String, pressed: bool) -> Texture2D:
  var image := Image.create(SIZE,SIZE,false,Image.FORMAT_RGBA8)
  image.fill(Color(0,0,0,0))
  var accent := Color("E5B977") if action in ["jump","enter_vehicle"] else Color("7BE6F1")
  if action == "pause_game": accent = Color("C8D4E4")
  var fill := accent.darkened(0.78 if not pressed else 0.53)
  for y in range(SIZE):
    for x in range(SIZE):
      var distance: float = Vector2(float(x)-47.5,float(y)-47.5).length()
      if distance > 45.0: continue
      var fade: float = clampf((45.0-distance)/2.2,0.0,1.0)
      var outline: bool = distance >= 41.5
      var color: Color = accent if outline else fill
      image.set_pixel(x,y,Color(color.r,color.g,color.b,fade*(0.94 if outline else 0.84)))
  return ImageTexture.create_from_image(image)

func _layout() -> void:
  var viewport_size: Vector2 = get_viewport().get_visible_rect().size
  if viewport_size.x < 1.0 or viewport_size.y < 1.0: return
  _screen_size = viewport_size
  var scale_factor: float = clampf(minf(viewport_size.x/390.0,viewport_size.y/760.0),0.72,1.12)
  # Large enough for fingers while avoiding overlaps even on narrow phones.
  var margin: float = 53.0*scale_factor
  var spacing: float = 78.0*scale_factor
  var lower: float = viewport_size.y-58.0*scale_factor
  var upper: float = viewport_size.y-142.0*scale_factor
  var coords := {
    "move_left":Vector2(margin,lower),
    "move_right":Vector2(margin+spacing,lower),
    "move_backward":Vector2(viewport_size.x-margin-spacing,lower),
    "move_forward":Vector2(viewport_size.x-margin,lower),
    "jump":Vector2(viewport_size.x-margin,upper),
    "enter_vehicle":Vector2(viewport_size.x-margin-spacing,upper),
    "interact":Vector2(viewport_size.x-margin-spacing*2.0,upper),
    "pause_game":Vector2(margin,upper)
  }
  for action in ACTIONS:
    var button: TouchScreenButton = _buttons.get(action)
    if button == null: continue
    button.scale = Vector2.ONE*(scale_factor*0.74)
    button.position = coords[action]-Vector2.ONE*(float(SIZE)*button.scale.x*0.5)

func set_preview(enabled: bool) -> void:
  # Only used by the native QA harness; normal users see touchscreen-only controls.
  _preview = enabled
  for button in _buttons.values():
    (button as TouchScreenButton).visibility_mode = TouchScreenButton.VISIBILITY_ALWAYS if enabled else TouchScreenButton.VISIBILITY_TOUCHSCREEN_ONLY
  set_mode(_driving,_blocked)

func _current_locale() -> String:
  # Some headless SceneTree harnesses preload scripts without autoload identifiers.
  # The real game has /root/GameState; default to Russian when it is unavailable.
  var state: Node = get_node_or_null('/root/GameState')
  if state == null: return 'ru'
  var raw: Variant = state.get('locale')
  return str(raw) if LABELS.has(str(raw)) else 'ru'

func set_mode(driving: bool, blocked: bool) -> void:
  var changed: bool = _driving != driving or _locale != _current_locale()
  _driving = driving
  _blocked = blocked
  var active: bool = (DisplayServer.is_touchscreen_available() or _preview) and not blocked
  for button in _buttons.values():
    (button as TouchScreenButton).visible = active
  if changed: _refresh_labels()

func _refresh_labels() -> void:
  _locale = _current_locale()
  var lang: Dictionary = LABELS[_locale]
  for action in ACTIONS:
    var caption: Label = _labels.get(action)
    if caption == null: continue
    if action == "jump":
      caption.text = str(lang["jump_driving"] if _driving else lang["jump_walking"])
    elif action == "move_backward" and not _driving:
      caption.text = str(WALK_BACK_LABELS[_locale])
    elif action == "move_forward" and not _driving:
      caption.text = "ВПЕРЁД" if _locale == "ru" else ("WALK" if _locale == "en" else "前进")
    else:
      caption.text = str(lang[action])
