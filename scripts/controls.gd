extends RefCounted

static func install() -> void:
	var bindings := {"move_left": KEY_A, "move_right": KEY_D, "jump": KEY_SPACE,
		"light": KEY_J, "heavy": KEY_K, "parry": KEY_L, "dodge": KEY_SHIFT,
		"stance": KEY_Q, "retry": KEY_R, "pause": KEY_ESCAPE, "confirm": KEY_ENTER,
		"skip": KEY_TAB}
	for action in bindings:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		var event := InputEventKey.new()
		event.physical_keycode = bindings[action]
		InputMap.action_add_event(action, event)
