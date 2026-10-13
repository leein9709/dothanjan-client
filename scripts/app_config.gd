extends Node

var api_base_url: String = ""

func _ready() -> void:
	var config := ConfigFile.new()
	var environment: String = "development" if OS.is_debug_build() else "production"
	if config.load("res://config/%s.cfg" % environment) == OK:
		api_base_url = str(config.get_value("api", "base_url", "")).trim_suffix("/")
	if OS.is_debug_build():
		var local := ConfigFile.new()
		if local.load("res://config/local.cfg") == OK:
			api_base_url = str(local.get_value("api", "base_url", api_base_url)).trim_suffix("/")
		var override_url: String = OS.get_environment("DOTHANJAN_API_URL")
		if not override_url.is_empty():
			api_base_url = override_url.trim_suffix("/")
	if not OS.is_debug_build() and not api_base_url.is_empty() and not api_base_url.begins_with("https://"):
		push_error("Release API endpoint must use HTTPS")
		api_base_url = ""
	_register_movement_actions()

func _register_movement_actions() -> void:
	var mapping: Dictionary = {
		"move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT],
		"move_up": [KEY_W, KEY_UP], "move_down": [KEY_S, KEY_DOWN]
	}
	for action: String in mapping:
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.2)
		for key: int in mapping[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			if not InputMap.action_has_event(action, event):
				InputMap.action_add_event(action, event)
