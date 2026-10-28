extends Control
class_name A7DualTouchLook
## W83: REAL indexed ScreenTouch / ScreenDrag look atop the original Godot 3D.
## Supports holding existing physical walk (W78) with another finger while
## camera drag changes ORIGINAL W70 CharacterBody3D yaw and Camera3D pitch.
## Never touches A7 choices, machine solutions, checkpoints or body positions.

signal real_camera_drag_started

const COPPER := Color("e5b982")
const MAX_DRAG_PIXELS := 90.0
const LOOK_SENSITIVITY := 0.85
var stage: Control
var actor: A7FirstPersonOperator
var touch_controls: A7TouchFieldControls
var mission_deck: A7MobileMissionDeck
var navigation: A7MissionNavCockpit
var fullscreen_host: A7FullBleedViewport
var hint_label: Label
var look_finger: int = -1
var touch_begins: int = 0
var physical_look_drags: int = 0
var real_camera_rotations: int = 0
var rejected_ui_starts: int = 0
var rejected_extra_fingers: int = 0
var clamped_motion_frames: int = 0
var released_fingers: int = 0
var cancelled_captures: int = 0
var captured_pixels: float = 0.0
var actual_screen_size: Vector2 = Vector2.ZERO
var original_w70_actor_id: int = 0
var localized_language: String = "ru"

func build(original_live_stage: Control, original_actor: A7FirstPersonOperator,
        original_controls: A7TouchFieldControls,
        original_deck: A7MobileMissionDeck,
        original_navigation: A7MissionNavCockpit,
        original_host: A7FullBleedViewport) -> void:
    name = "W83ActualMultifingerNativeGodotCameraDrag"
    stage = original_live_stage
    actor = original_actor
    touch_controls = original_controls
    mission_deck = original_deck
    navigation = original_navigation
    fullscreen_host = original_host
    original_w70_actor_id = actor.body.get_instance_id()
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    hint_label = Label.new()
    hint_label.name = "W83RealSwipeToTurnCameraHint"
    hint_label.anchor_left = 1.0
    hint_label.anchor_right = 1.0
    hint_label.offset_left = -152.0
    hint_label.offset_right = -10.0
    hint_label.offset_top = 140.0
    hint_label.offset_bottom = 162.0
    hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    hint_label.add_theme_font_size_override("font_size",11)
    hint_label.add_theme_color_override("font_color",COPPER)
    hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    hint_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
    hint_label.clip_text = true
    add_child(hint_label)
    visible = false

func set_context(immersive_mobile: bool, language: String,
        screen_size: Vector2) -> void:
    localized_language = "en" if language == "en" else "ru"
    if actual_screen_size != screen_size:
        # Orientation/resize invalidates the captured finger's screen sector.
        cancel_capture()
    actual_screen_size = screen_size
    var should_show: bool = immersive_mobile and actor != null and (
        actor.piloting) and fullscreen_host != null and fullscreen_host.active
    if not should_show:
        cancel_capture()
    visible = should_show
    if hint_label != null:
        hint_label.text = ("СВАЙП · ОБЗОР" if localized_language=="ru"
            else "SWIPE · LOOK")
        # On short 844x390, the original compact mission commands begin
        # at ~160px; keep the readable world free of floating text clutter.
        hint_label.visible = should_show and screen_size.y>=640.0

func cancel_capture() -> void:
    if look_finger >= 0:
        cancelled_captures += 1
        look_finger = -1

func _on_ui(point: Vector2) -> bool:
    if (touch_controls != null and touch_controls.visible and
            touch_controls.rail.get_global_rect().has_point(point)):
        return true
    if (mission_deck != null and mission_deck.visible and
            mission_deck.panel.get_global_rect().has_point(point)):
        return true
    if (navigation != null and navigation.visible and
            navigation.frame.get_global_rect().has_point(point)):
        return true
    if (fullscreen_host != null and fullscreen_host.active and
            fullscreen_host.toolbar.get_global_rect().has_point(point)):
        return true
    return false

func can_capture_at(point: Vector2) -> bool:
    if (not visible or stage == null or actor == null or
            not actor.piloting or look_finger>=0):
        return false
    var rect: Rect2 = stage.get_global_rect()
    if not rect.has_point(point):
        return false
    # Right-side free 3D gaze area; never use the screen's W78 bottom rail,
    # W79 decision dock, W82 live mission text or W80 MENU/RU-EN.
    if point.x < rect.position.x + maxf(132.0,rect.size.x*0.44):
        return false
    if point.y < rect.position.y + 56.0:
        return false
    if (mission_deck != null and mission_deck.visible and
            point.y >= mission_deck.panel.get_global_rect().position.y-8.0):
        return false
    if _on_ui(point):
        return false
    return true

func handle_screen_event(event: InputEvent) -> bool:
    if event is InputEventScreenTouch:
        var touch: InputEventScreenTouch = event as InputEventScreenTouch
        if touch.pressed:
            if look_finger>=0:
                rejected_extra_fingers += 1
                return false
            if not can_capture_at(touch.position):
                if visible and _on_ui(touch.position):
                    rejected_ui_starts += 1
                return false
            look_finger = touch.index
            touch_begins += 1
            return true
        if touch.index == look_finger and look_finger>=0:
            look_finger = -1
            released_fingers += 1
            return true
        return false
    if event is InputEventScreenDrag:
        var motion: InputEventScreenDrag = event as InputEventScreenDrag
        if (not visible or look_finger<0 or motion.index != look_finger
                or actor == null or not actor.piloting):
            return false
        physical_look_drags += 1
        var delta: Vector2 = motion.relative
        if delta.length()>MAX_DRAG_PIXELS:
            delta = delta.limit_length(MAX_DRAG_PIXELS)
            clamped_motion_frames += 1
        if delta.length_squared()>0.04:
            # Source original W70 method only: no player teleport/score edits.
            actor.rotate_view(delta*LOOK_SENSITIVITY)
            real_camera_rotations += 1
            captured_pixels += delta.length()
            real_camera_drag_started.emit()
        return true
    return false

func qa_readout() -> Dictionary:
    return {
        "schema":"LAST_FRONTIER_W83_TRUE_GODOT_INDEXED_MULTITOUCH_V1",
        "enabled":visible,
        "original_source_characterbody_preserved":actor != null and
            actor.body != null and actor.body.get_instance_id()==original_w70_actor_id,
        "original_actor_id":original_w70_actor_id,
        "real_touch_starts":touch_begins,
        "real_screen_drag_events":physical_look_drags,
        "original_W70_camera_rotations":real_camera_rotations,
        "finger_index":look_finger,
        "extra_fingers_rejected":rejected_extra_fingers,
        "UI_controls_never_captured":rejected_ui_starts,
        "touch_release_events":released_fingers,
        "cancelled_fingers_on_mode_or_resize":cancelled_captures,
        "bounded_drag_events":clamped_motion_frames,
        "source_pixels_turned":snappedf(captured_pixels,0.01),
        "actual_source_yaw":snappedf(actor.body.rotation.y,0.001)
            if actor != null and actor.body != null else 0.0,
        "actual_source_pitch":snappedf(actor.head_camera.rotation.x,0.001)
            if actor != null and actor.head_camera != null else 0.0,
        "physical_touch_hardware_approved":false,
        "no_autoplay_or_fake_game_decisions":true,
    }
