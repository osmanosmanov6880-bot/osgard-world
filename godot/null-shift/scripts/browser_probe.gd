extends Node

# Opt-in diagnostics for a real Web export. The only JavaScript entry point reads
# a fresh snapshot. No input, save, scene mutation or gameplay command is exposed.
var game_root: Node
var snapshot_callback: JavaScriptObject
var instance_id := ""

func configure(root: Node) -> void:
	game_root = root
	instance_id = str(root.get_instance_id())

func _ready() -> void:
	if not OS.has_feature("web") or not bool(JavaScriptBridge.eval("new URLSearchParams(location.search).get('test') === '1'")):
		return
	snapshot_callback = JavaScriptBridge.create_callback(_read_snapshot)
	var browser_window := JavaScriptBridge.get_interface("window")
	browser_window.__NULL_SHIFT_GODOT_READ_CALLBACK = snapshot_callback
	JavaScriptBridge.eval("""
		(function () {
			const read = window.__NULL_SHIFT_GODOT_READ_CALLBACK;
			delete window.__NULL_SHIFT_GODOT_READ_CALLBACK;
			function freeze(value) {
				if (value && typeof value === 'object') {
					Object.values(value).forEach(freeze);
					Object.freeze(value);
				}
				return value;
			}
			Object.defineProperty(window, '__NULL_SHIFT_GODOT_TEST__', {
				configurable: true,
				writable: false,
				value: Object.freeze({
					version: 1,
					instanceId: '%INSTANCE%',
					state: function () {
						const reply = {};
						read(reply);
						return reply.json ? freeze(JSON.parse(reply.json)) : null;
					}
				})
			});
		})();
	""".replace("%INSTANCE%", instance_id))

func _exit_tree() -> void:
	if snapshot_callback != null and OS.has_feature("web"):
		JavaScriptBridge.eval("if (window.__NULL_SHIFT_GODOT_TEST__ && window.__NULL_SHIFT_GODOT_TEST__.instanceId === '%s') delete window.__NULL_SHIFT_GODOT_TEST__;" % instance_id)
	snapshot_callback = null

func _read_snapshot(arguments: Array) -> void:
	if arguments.size() != 1 or not is_instance_valid(game_root):
		return
	arguments[0].json = JSON.stringify(snapshot())

func _vector3(value: Vector3) -> Dictionary:
	return {"x": value.x, "y": value.y, "z": value.z}

func _rect(value: Rect2) -> Dictionary:
	return {"x": value.position.x, "y": value.position.y, "width": value.size.x, "height": value.size.y}

func _screen_point(node: Node3D) -> Dictionary:
	var camera: Camera3D = game_root.get("camera") as Camera3D
	var position: Vector3 = node.global_position + Vector3.UP * 0.35
	var point: Vector2 = camera.unproject_position(position)
	return {"x": point.x, "y": point.y, "behind": camera.is_position_behind(position)}

func _controls() -> Array[Dictionary]:
	var controls: Array[Dictionary] = []
	var hud: Control = game_root.get("hud_root") as Control
	var viewport_rect: Rect2 = game_root.get_viewport().get_visible_rect()
	for node in hud.find_children("*", "Button", true, false):
		var button := node as Button
		var clip: Rect2 = viewport_rect
		var ancestor: Node = button.get_parent()
		while ancestor != null and ancestor != game_root:
			if ancestor is Control and (ancestor as Control).clip_contents:
				clip = clip.intersection((ancestor as Control).get_global_rect())
			ancestor = ancestor.get_parent()
		controls.append({
			"id": str(button.get_meta("browser_action", button.name)),
			"label": button.text if not button.text.is_empty() else button.tooltip_text,
			"visible": button.is_visible_in_tree(),
			"enabled": not button.disabled,
			"focusable": button.focus_mode != Control.FOCUS_NONE,
			"focused": button.has_focus(),
			"rect": _rect(button.get_global_rect()),
			"clip": _rect(clip)
		})
	return controls

func snapshot() -> Dictionary:
	var player: CharacterBody3D = game_root.get("player") as CharacterBody3D
	var viewport_size: Vector2 = game_root.get_viewport().get_visible_rect().size
	var guard_states: Array[Dictionary] = []
	for entry: Dictionary in game_root.get("guards"):
		var body: Node3D = entry.get("node") as Node3D
		if is_instance_valid(body):
			guard_states.append({
				"id": str(body.get_instance_id()), "role": str(entry.get("role", "")),
				"hp": int(entry.get("hp", 0)), "stun": float(entry.get("stun", 0.0)),
				"position": _vector3(body.global_position), "screen": _screen_point(body),
				"distance": player.global_position.distance_to(body.global_position),
				"clearPath": bool(game_root.call("_has_clear_path_to_aim_target", body))
			})
	var device_states: Array[Dictionary] = []
	for entry: Dictionary in game_root.get("devices"):
		var body: Node3D = entry.get("node") as Node3D
		if is_instance_valid(body):
			device_states.append({"kind": str(entry.get("kind", "")), "hp": int(entry.get("hp", 0)),
				"destroyed": bool(entry.get("destroyed", false)), "position": _vector3(body.global_position), "screen": _screen_point(body)})
	var panels: Dictionary = {}
	for property in ["briefing_panel", "pause_panel", "loadout_panel", "keypad_panel", "result_panel"]:
		var panel: Control = game_root.get(property) as Control
		panels[property] = {"visible": panel.is_visible_in_tree(), "rect": _rect(panel.get_global_rect())}
	return {
		"schemaVersion": 1, "instanceId": instance_id,
		"engineVersion": str(Engine.get_version_info().get("string", "")),
		"platform": OS.get_name(), "renderer": str(ProjectSettings.get_setting("rendering/renderer/rendering_method")),
		"processFrames": Engine.get_process_frames(), "physicsFrames": Engine.get_physics_frames(),
		"drawCalls": int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		"renderedObjects": int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)),
		"viewport": {"width": viewport_size.x, "height": viewport_size.y},
		"touchAvailable": DisplayServer.is_touchscreen_available(), "mobileControlsVisible": bool(game_root.get("mobile_controls_visible")),
		"player": {"position": _vector3(player.global_position), "velocity": _vector3(player.velocity),
			"health": float(game_root.get("player_health")), "maxHealth": float(game_root.get("player_max_health"))},
		"briefing": bool(game_root.get("briefing_visible")), "paused": bool(game_root.get("paused_game")),
		"finished": bool(game_root.get("mission_finished")), "elapsed": float(game_root.get("elapsed")),
		"phaseClock": float(game_root.get("phase_clock")), "nullShift": float(game_root.get("null_shift_timer")),
		"instability": float(game_root.get("instability")), "fireCooldown": float(game_root.get("fire_cooldown")),
		"pulseCooldown": float(game_root.get("pulse_cooldown")), "dashCooldown": float(game_root.get("dash_cooldown")),
		"dashTimer": float(game_root.get("dash_timer")), "muzzleFlash": float(game_root.get("muzzle_flash_timer")),
		"eliminations": int(game_root.get("eliminations")), "runCredits": int(game_root.get("run_credits")),
		"terminalUnlocked": bool(game_root.get("terminal_unlocked")), "coreSecured": bool(game_root.get("core_secured")),
		"objective": str(game_root.get("objective_text")), "guards": guard_states, "devices": device_states,
		"controls": _controls(), "panels": panels
	}
