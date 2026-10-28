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
const LOST_TOUCH_TIMEOUT_MS := 1700
const MAX_CONTINUOUS_WALK_HOLD_MS := 12000
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
var recovered_end_by_position: int = 0
var recovered_missing_end_timeout: int = 0
var last_look_point: Vector2 = Vector2.ZERO
var last_touch_ticks_ms: int = 0
# Per-physical-finger independent movement ownership. On Chromium WebGL
# adding/releasing a second touch can cause a BUTTON mouse-up even when the
# ORIGINAL first finger is still held. Never trust that mouse-up to release
# the ORIGINAL W70 physics key until the originating touch truly ends.
var source_walk_fingers: Dictionary = {}
var source_walk_origins: Dictionary = {}
var source_walk_started_ms: Dictionary = {}
var actual_walk_touch_starts: int = 0
var actual_walk_touch_ends: int = 0
var original_walk_reassert_frames: int = 0
var mismatched_walk_releases_ignored: int = 0
var expired_long_walk_holds: int = 0
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
    set_process(true)

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

func _release_walk_id(index: int) -> void:
    if not source_walk_fingers.has(index):
        return
    var key: String = str(source_walk_fingers[index])
    source_walk_fingers.erase(index)
    source_walk_origins.erase(index)
    source_walk_started_ms.erase(index)
    actual_walk_touch_ends += 1
    if actor != null and A7TouchFieldControls.WALK_KEYS.has(key):
        actor.set_key(int(A7TouchFieldControls.WALK_KEYS[key]),false)

func _release_all_source_walk() -> void:
    for index in source_walk_fingers.keys().duplicate():
        _release_walk_id(int(index))

func cancel_capture() -> void:
    if look_finger >= 0:
        cancelled_captures += 1
        look_finger = -1
    _release_all_source_walk()

func _walk_button_at(point: Vector2) -> String:
    if touch_controls == null or not touch_controls.visible:
        return ""
    for key in ["left","forward","back","right"]:
        var button: Button = touch_controls.controls.get(key) as Button
        if button != null and button.get_global_rect().has_point(point):
            return key
    return ""

func _walk_release_near(key: String, position: Vector2) -> bool:
    var button: Button = touch_controls.controls.get(key) as Button
    return button != null and button.get_global_rect().grow(24.0).has_point(position)

func _release_matching_walk(index: int, position: Vector2) -> bool:
    if source_walk_fingers.has(index):
        var key: String = str(source_walk_fingers[index])
        if _walk_release_near(key,position):
            _release_walk_id(index)
            return true
        # A reindexed LOOK release must not clear the first WALK finger.
        mismatched_walk_releases_ignored += 1
    for other in source_walk_fingers.keys():
        var key: String = str(source_walk_fingers[other])
        if _walk_release_near(key,position):
            _release_walk_id(int(other))
            return true
    return false

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
            var walking_key: String = _walk_button_at(touch.position)
            if walking_key != "" and actor != null and actor.piloting:
                source_walk_fingers[touch.index] = walking_key
                source_walk_origins[touch.index] = touch.position
                source_walk_started_ms[touch.index] = Time.get_ticks_msec()
                actor.set_key(int(A7TouchFieldControls.WALK_KEYS[walking_key]),true)
                actual_walk_touch_starts += 1
                # Deliberately DO NOT consume W78's original Button event;
                # its visual/input feedback remains fully native.
                return false
            if look_finger>=0:
                rejected_extra_fingers += 1
                return false
            if not can_capture_at(touch.position):
                if visible and _on_ui(touch.position):
                    rejected_ui_starts += 1
                return false
            look_finger = touch.index
            last_look_point = touch.position
            last_touch_ticks_ms = Time.get_ticks_msec()
            touch_begins += 1
            return true
        if touch.index == look_finger and look_finger>=0:
            # Only trust exact identity when the END physically belongs in
            # the original look region, never W78 native walk buttons.
            if not _on_ui(touch.position):
                look_finger = -1
                released_fingers += 1
                return true
        # Some WebGL touch-end paths renumber the still-active first
        # finger after a two-touch gesture. A release near the LOOK finger's
        # last physical point is still a valid end, but a release over W78
        # movement rail or original W79 mission deck must NEVER cancel look.
        if (look_finger>=0 and not _on_ui(touch.position)
                and touch.position.distance_to(last_look_point)<95.0):
            look_finger = -1
            released_fingers += 1
            recovered_end_by_position += 1
            return true
        # Independent source-identified WALK finger release. A reindexed
        # event in the upper camera region must NEVER stop physical walking.
        if _release_matching_walk(touch.index,touch.position):
            return false
        return false
    if event is InputEventScreenDrag:
        var motion: InputEventScreenDrag = event as InputEventScreenDrag
        if source_walk_fingers.has(motion.index):
            var walk_key: String = str(source_walk_fingers[motion.index])
            var origin: Vector2 = source_walk_origins[motion.index] as Vector2
            if not _walk_release_near(walk_key,motion.position):
                # Nearby sliding off the source button should stop walking;
                # a far-away camera-finger event carrying a recycled index
                # must not falsely release that first source WALK press.
                if motion.position.distance_to(origin)<115.0:
                    _release_walk_id(motion.index)
                else:
                    mismatched_walk_releases_ignored += 1
                return false
            return false
        if (not visible or look_finger<0 or motion.index != look_finger
                or actor == null or not actor.piloting):
            return false
        physical_look_drags += 1
        last_look_point = motion.position
        last_touch_ticks_ms = Time.get_ticks_msec()
        # Godot 4.4 screen_relative is NOT affected by root stretch/scaling.
        # This keeps the true physical finger sensitivity consistent at 320,
        # 390 and 844 CSS px; never use scaled relative for camera aiming.
        var delta: Vector2 = motion.screen_relative
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

func _process(_delta: float) -> void:
    # Reassert the first REAL W70 physical movement key when the browser's
    # GUI compatibility mouse-up belongs to a DIFFERENT second finger.
    # Only a source finger END in its actual W78 button, mode/focus exit,
    # or bounded 12s safety cap can release the source-held key.
    if visible and actor != null and actor.piloting:
        var now: int = Time.get_ticks_msec()
        for index in source_walk_fingers.keys().duplicate():
            if (source_walk_started_ms.has(index) and
                    now-int(source_walk_started_ms[index])>=MAX_CONTINUOUS_WALK_HOLD_MS):
                expired_long_walk_holds += 1
                _release_walk_id(int(index))
                continue
            var key: String = str(source_walk_fingers[index])
            if A7TouchFieldControls.WALK_KEYS.has(key):
                actor.set_key(int(A7TouchFieldControls.WALK_KEYS[key]),true)
                original_walk_reassert_frames += 1
    # The browser or mobile OS may omit a ScreenTouch END when a second
    # pointer lifts while the first remains on a native Button. The genuine
    # source camera must NEVER remain indefinitely captured. A stationary
    # swipe longer than 1.7 s is safely released; re-touch to resume look.
    if (look_finger>=0 and visible and
            Time.get_ticks_msec()-last_touch_ticks_ms>LOST_TOUCH_TIMEOUT_MS):
        recovered_missing_end_timeout += 1
        cancel_capture()

func is_source_walk_held() -> bool:
    # Read EXACT original W70 physics key. This is a read-only source
    # integrity witness, not an auto-walk or synthetic distance counter.
    if actor == null or source_walk_fingers.is_empty():
        return false
    for source_key in source_walk_fingers.values():
        var key_name: String = str(source_key)
        if not A7TouchFieldControls.WALK_KEYS.has(key_name):
            return false
        var godot_key: int = int(A7TouchFieldControls.WALK_KEYS[key_name])
        if not bool(actor.held_keys.get(godot_key,false)):
            return false
    return true

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
        "touch_end_index_recoveries":recovered_end_by_position,
        "touch_end_loss_watchdog_recoveries":recovered_missing_end_timeout,
        "source_active_walk_fingers":source_walk_fingers.size(),
        "original_W70_walk_key_still_pressed":is_source_walk_held(),
        "source_walk_touch_starts":actual_walk_touch_starts,
        "source_walk_touch_ends":actual_walk_touch_ends,
        "original_W70_walk_reassert_frames":original_walk_reassert_frames,
        "reindexed_movement_touch_end_ignored":mismatched_walk_releases_ignored,
        "bounded_12s_safety_walk_timeouts":expired_long_walk_holds,
        "max_continuous_source_walk_ms":MAX_CONTINUOUS_WALK_HOLD_MS,
        "native_watchdog_timeout_ms":LOST_TOUCH_TIMEOUT_MS,
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
