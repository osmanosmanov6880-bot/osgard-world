extends Node
## Persistent local preferences; no credentials, user identifiers or network calls.
## Keyboard and controller bindings are registered centrally in InputMap.

signal preferences_changed

const PATH = "user://osgard_empire_settings.cfg"
const DEFAULT_KEYS = {
	"move_forward": KEY_W, "move_backward": KEY_S,
	"move_left": KEY_A, "move_right": KEY_D,
	"jump": KEY_SPACE, "sprint": KEY_SHIFT,
	"interact": KEY_F, "talk_citizen": KEY_J, "city_case": KEY_C, "dispatch_service": KEY_R, "enter_vehicle": KEY_E,
	"governor": KEY_TAB, "pause_game": KEY_ESCAPE,
	"advance_turn": KEY_N, "buy_business": KEY_B,
	"show_map": KEY_M, "field_journal": KEY_H, "drive_trial": KEY_T, "enter_interior": KEY_I, "diagnostics": KEY_F3, "save_game": KEY_F5,
	"load_game": KEY_F9, "language": KEY_L, "pay_traffic_fines": KEY_P
}
const PAD_BUTTONS = {
	"jump": JOY_BUTTON_A, "sprint": JOY_BUTTON_LEFT_STICK,
	"interact": JOY_BUTTON_X, "enter_vehicle": JOY_BUTTON_Y,
	"governor": JOY_BUTTON_BACK, "pause_game": JOY_BUTTON_START,
	"show_map": JOY_BUTTON_DPAD_UP
}
const STICK_AXES = {
	"move_forward": [JOY_AXIS_LEFT_Y, -1.0],
	"move_backward": [JOY_AXIS_LEFT_Y, 1.0],
	"move_left": [JOY_AXIS_LEFT_X, -1.0],
	"move_right": [JOY_AXIS_LEFT_X, 1.0]
}
const GRAPHICS_MODES = ["low", "standard", "cinematic"]

var keys: Dictionary = DEFAULT_KEYS.duplicate(true)
var volume := 0.75
var mouse_sensitivity := 0.003
var graphics := "standard"
var reduced_motion := false

func _ready() -> void:
	load_preferences()
	_install_input_map()
	_apply_volume()

func _install_input_map() -> void:
	for action in DEFAULT_KEYS:
		if not InputMap.has_action(action):
			InputMap.add_action(action,0.22)
		InputMap.action_erase_events(action)
		var key := InputEventKey.new()
		key.physical_keycode = int(keys.get(action,DEFAULT_KEYS[action]))
		InputMap.action_add_event(action,key)
		if PAD_BUTTONS.has(action):
			var pad := InputEventJoypadButton.new()
			pad.button_index = PAD_BUTTONS[action]
			InputMap.action_add_event(action,pad)
		if STICK_AXES.has(action):
			var stick := InputEventJoypadMotion.new()
			stick.axis = STICK_AXES[action][0]
			stick.axis_value = STICK_AXES[action][1]
			InputMap.action_add_event(action,stick)

func rebind(action: String, code: int) -> bool:
	if not DEFAULT_KEYS.has(action) or code <= 0 or code > 16777215:
		return false
	for other in keys:
		if other != action and int(keys[other]) == code:
			return false
	keys[action] = code
	_install_input_map()
	save_preferences()
	preferences_changed.emit()
	return true

func reset_bindings() -> void:
	keys = DEFAULT_KEYS.duplicate(true)
	_install_input_map()
	save_preferences()
	preferences_changed.emit()

func binding_name(action: String) -> String:
	return OS.get_keycode_string(int(keys.get(action,0)))

func set_volume(value: float) -> void:
	volume = clampf(value,0.0,1.0)
	_apply_volume()
	save_preferences()
	preferences_changed.emit()

func _apply_volume() -> void:
	var master := AudioServer.get_bus_index("Master")
	if master >= 0:
		AudioServer.set_bus_volume_db(master,linear_to_db(maxf(0.0001,volume)))

func set_graphics(value: String) -> void:
	if not GRAPHICS_MODES.has(value):
		return
	graphics = value
	save_preferences()
	preferences_changed.emit()

func set_mouse_sensitivity(value: float) -> void:
	mouse_sensitivity = clampf(value,0.001,0.012)
	save_preferences()
	preferences_changed.emit()

func set_reduced_motion(value: bool) -> void:
	reduced_motion = value
	save_preferences()
	preferences_changed.emit()

func set_locale(value: String) -> void:
	if not ["ru","en","zh"].has(value):
		return
	GameState.locale = value
	save_preferences()
	preferences_changed.emit()

func load_preferences() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	var new_keys := DEFAULT_KEYS.duplicate(true)
	for action in DEFAULT_KEYS:
		var stored: Variant = cfg.get_value("keys",action,DEFAULT_KEYS[action])
		if stored is int and int(stored) > 0 and int(stored) <= 16777215:
			new_keys[action] = int(stored)
	# Recover an invalid / conflicting config without losing every valid binding.
	var seen := {}
	for action in DEFAULT_KEYS:
		var key: int = int(new_keys[action])
		if seen.has(key):
			new_keys[action] = DEFAULT_KEYS[action]
		else:
			seen[key] = true
	keys = new_keys
	volume = clampf(float(cfg.get_value("general","volume",0.75)),0.0,1.0)
	mouse_sensitivity = clampf(float(cfg.get_value("general","mouse_sensitivity",0.003)),0.001,0.012)
	var selected: String = str(cfg.get_value("general","graphics","standard"))
	graphics = selected if GRAPHICS_MODES.has(selected) else "standard"
	reduced_motion = bool(cfg.get_value("general","reduced_motion",false))
	var locale: String = str(cfg.get_value("general","locale","ru"))
	GameState.locale = locale if ["ru","en","zh"].has(locale) else "ru"

func save_preferences() -> bool:
	var cfg := ConfigFile.new()
	for action in DEFAULT_KEYS:
		cfg.set_value("keys",action,int(keys[action]))
	cfg.set_value("general","volume",volume)
	cfg.set_value("general","mouse_sensitivity",mouse_sensitivity)
	cfg.set_value("general","graphics",graphics)
	cfg.set_value("general","reduced_motion",reduced_motion)
	cfg.set_value("general","locale",GameState.locale)
	return cfg.save(PATH) == OK
