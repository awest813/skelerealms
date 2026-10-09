extends RefCounted
## Defaults are registered only when absent, allowing project-level remapping.

static func install() -> void:
	var keys := {
		"flight_forward": KEY_W, "flight_reverse": KEY_S,
		"flight_left": KEY_A, "flight_right": KEY_D,
		"flight_up": KEY_SPACE, "flight_down": KEY_CTRL,
		"flight_roll_left": KEY_Q, "flight_roll_right": KEY_E,
		"flight_pitch_up": KEY_UP, "flight_pitch_down": KEY_DOWN,
		"flight_yaw_left": KEY_LEFT, "flight_yaw_right": KEY_RIGHT,
		"flight_brake": KEY_SHIFT, "flight_assist": KEY_F,
		"flight_reset": KEY_R, "flight_pause": KEY_ESCAPE,
		"flight_jump": KEY_J, "flight_dock": KEY_X, "flight_map": KEY_M, "flight_land": KEY_L,
	}
	for action: String in keys:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		var event := InputEventKey.new()
		event.physical_keycode = keys[action]
		InputMap.action_add_event(action, event)
	# Mouse buttons use a separate table: left mouse fires the laser.
	var mouse_buttons := {
		"flight_fire": MOUSE_BUTTON_LEFT,
	}
	for action: String in mouse_buttons:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		var event := InputEventMouseButton.new()
		event.button_index = mouse_buttons[action]
		InputMap.action_add_event(action, event)
