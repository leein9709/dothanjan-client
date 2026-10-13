extends SceneTree

var failures: int = 0

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, description: String) -> void:
	if not condition:
		push_error(description)
		failures += 1

func _run() -> void:
	await process_frame
	var packed: PackedScene = load("res://scenes/login.tscn")
	var login: Control = packed.instantiate()
	root.add_child(login)
	await process_frame
	var auth: Node = root.get_node("SocialAuth")
	check(login.find_child("KakaoLogin", true, false) != null, "Missing Kakao button")
	check(login.find_child("NaverLogin", true, false) != null, "Missing Naver button")
	check((login.find_child("AppleLogin", true, false) != null) == auth.apple_available(), "Apple visibility mismatch")
	var naver: Button = login.find_child("NaverLogin", true, false)
	naver.grab_focus()
	# Exercise the common preparation modal without starting a real provider login.
	login._on_sign_in_unavailable("네이버")
	await process_frame
	check(login.dialog.visible, "Unconfigured sign-in must display notice")
	check(login.dialog.dialog_text.contains("네이버"), "Provider notice mismatch")
	check(login.dialog.confirm_button.has_focus(), "Modal must own keyboard focus")
	login.dialog.confirm_button.pressed.emit()
	check(not login.dialog.visible, "Modal confirmation must close the notice")
	check(naver.has_focus(), "Closing modal must return focus to the provider")
	for provider: String in ["naver", "apple"]:
		if provider == "apple" and not auth.apple_available():
			continue
		if provider == "naver": login._on_sign_in_unavailable("네이버")
		else: auth.request_sign_in(provider)
		check(login.dialog.visible and login.dialog.dialog_text.contains(auth.PROVIDER_NAMES[provider]), "Reused modal must show the selected provider")
		var cancel := InputEventAction.new()
		cancel.action = "ui_cancel"
		cancel.pressed = true
		Input.parse_input_event(cancel)
		await process_frame
		check(not login.dialog.visible, "Cancel must dismiss the modal")
		cancel = InputEventAction.new()
		cancel.action = "ui_cancel"
		cancel.pressed = false
		Input.parse_input_event(cancel)
	check(InputMap.has_action("move_left"), "Missing common movement bindings")
	check(ProjectSettings.get_setting("display/window/handheld/orientation") == 0, "Landscape must be configured")
	var request := HTTPRequest.new()
	root.add_child(request)
	request.timeout = 5.0
	var config: Node = root.get_node("AppConfig")
	var error: Error = request.request(config.api_base_url + "/health/ready")
	check(error == OK, "HTTP request failed to start")
	if error == OK:
		var response: Array = await request.request_completed
		check(response[0] == HTTPRequest.RESULT_SUCCESS and response[1] == 200, "Real backend readiness request failed")
	print("CLIENT_SMOKE_FAILURES=", failures)
	quit(0 if failures == 0 else 1)
