extends RefCounted
class_name A7GamepadDirector
## W74 native controller InputEvent mapping to ORIGINAL real game callbacks.
## Tested by actual Godot InputEventJoypadButton/Motion. No physical gamepad
## has been connected to CI, so hardware support is not claimed as verified.

const RIGHT_SHOULDER_ACTION := JOY_BUTTON_RIGHT_SHOULDER
const ACTIONS: Array[String] = ["PUMP","VENT","SEAL","SCAN","POWER"]
var action_index: int = 0
var actual_button_events: int = 0
var actual_axis_events: int = 0
var original_actions_via_controller: int = 0
var world_interactions_via_controller: int = 0
var save_requests_via_controller: int = 0
var restore_requests_via_controller: int = 0
var last_command: String = ""
var any_controller_event_observed: bool = false

func selected_action() -> String:
    return ACTIONS[action_index]

func route_motion(event: InputEventJoypadMotion,
        screen: A7CascadeScreen) -> bool:
    if screen == null or screen.stage_3d == null or (
            screen.stage_3d.first_person == null):
        return false
    var player: A7FirstPersonOperator = screen.stage_3d.first_person
    if not player.set_controller_axis(event.axis,event.axis_value):
        return false
    any_controller_event_observed = true
    actual_axis_events += 1
    last_command = "analog_motion"
    return true

func route_button(button: int, screen: A7CascadeScreen) -> bool:
    if screen == null or screen.stage_3d == null:
        return false
    if button not in [
        JOY_BUTTON_A,JOY_BUTTON_B,JOY_BUTTON_X,JOY_BUTTON_Y,
        JOY_BUTTON_START,JOY_BUTTON_BACK,
        JOY_BUTTON_DPAD_LEFT,JOY_BUTTON_DPAD_RIGHT,
        JOY_BUTTON_RIGHT_SHOULDER,JOY_BUTTON_LEFT_SHOULDER]:
        return false
    any_controller_event_observed = true
    actual_button_events += 1
    match button:
        JOY_BUTTON_A:
            var world: A7WorldInteraction = screen.stage_3d.world_interaction
            var mission: A7SpatialMission = screen.stage_3d.spatial_mission
            if mission != null and mission.extended_mode and (
                    world != null and screen.stage_3d.first_person.piloting):
                screen._world_use()
                world_interactions_via_controller += 1
                last_command = "physical_world_A"
            else:
                screen._pilot_inspect()
                last_command = "physical_inspection_A"
        JOY_BUTTON_X:
            screen._pilot_inspect()
            last_command = "physical_inspection_X"
        JOY_BUTTON_Y:
            screen._toggle_pilot()
            last_command = "toggle_first_person"
        JOY_BUTTON_B:
            if screen.stage_3d.first_person.piloting:
                screen._toggle_pilot()
            last_command = "back_to_camera"
        JOY_BUTTON_START:
            screen._start_extended_mission()
            last_command = "start_true_field_mission"
        JOY_BUTTON_BACK:
            screen._load_checkpoint()
            restore_requests_via_controller += 1
            last_command = "explicit_local_load"
        JOY_BUTTON_LEFT_SHOULDER:
            screen._save_checkpoint()
            save_requests_via_controller += 1
            last_command = "explicit_local_save"
        JOY_BUTTON_DPAD_LEFT:
            action_index = posmod(action_index-1,ACTIONS.size())
            screen._preview_action(selected_action())
            last_command = "select_previous_real_action"
        JOY_BUTTON_DPAD_RIGHT:
            action_index = posmod(action_index+1,ACTIONS.size())
            screen._preview_action(selected_action())
            last_command = "select_next_real_action"
        JOY_BUTTON_RIGHT_SHOULDER:
            var before: int = (screen.model.snapshot()["history"] as Array).size()
            screen._on_action(selected_action())
            if (screen.model.snapshot()["history"] as Array).size() > before:
                original_actions_via_controller += 1
            last_command = "submit_original_A7_action"
    return true

func explain(locale: String) -> String:
    var heading: String = ("ГЕЙМПАД: " if locale == "ru" else "CONTROLLER: ")
    var target: String = selected_action()
    return (heading+
        ("D-PAD ВЫБОР  /  RB: %s  /  A: УЗЕЛ  /  X: ОСМОТР" % target
            if locale == "ru" else
            "D-PAD SELECT  /  RB: %s  /  A: DEVICE  /  X: INSPECT" % target))

func qa_readout() -> Dictionary:
    return {
        "schema":"LAST_FRONTIER_W74_ORIGINAL_GAMEPAD_EVENT_ROUTE_V1",
        "native_Joypad_button_events":actual_button_events,
        "native_Joypad_motion_events":actual_axis_events,
        "gamepad_original_A7_action_commits":original_actions_via_controller,
        "world_button_activations":world_interactions_via_controller,
        "controller_explicit_save_calls":save_requests_via_controller,
        "controller_explicit_load_calls":restore_requests_via_controller,
        "selected_original_action":selected_action(),
        "last_command":last_command,
        "observed_gamepad_event":any_controller_event_observed,
        "physical_Xbox_PS_controller_tested":false,
        "hardware_controller_certified":false,
    }
