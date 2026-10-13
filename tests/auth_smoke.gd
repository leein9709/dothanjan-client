extends SceneTree

var failures: int = 0

class FakeStore extends RefCounted:
	var saved: String = ""
	var reject_writes: bool = false
	var writes: int = 0
	func load_credentials() -> String: return saved
	func save_credentials(payload: String) -> bool:
		if reject_writes: return false
		writes += 1
		saved = payload
		return true
	func clear_credentials() -> bool:
		if reject_writes: return false
		saved = ""
		return true

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1

func _run() -> void:
	await process_frame
	var login: Control = load("res://scenes/login.tscn").instantiate()
	root.add_child(login)
	current_scene = login
	await process_frame
	var auth: Node = root.get_node("SocialAuth")
	auth._secure_store = FakeStore.new()
	var entry_requests: Array = []
	login.entry_requested.connect(func() -> void: entry_requests.append(true))
	check(login.login_panel.visible and not login.entry_button.visible, "Signed-out startup must retain the login panel")
	check(not login.logout_button.visible, "Signed-out startup must hide logout")
	auth.login_finished.emit(false, "session_storage_failed")
	check(not login.dialog.visible, "Startup restoration failure must never open a modal")
	login.entry_button.pressed.emit()
	check(entry_requests.is_empty(), "Unverified sessions must not enter the gate")
	var history_path: String = "user://auth_smoke_login_history_%s.cfg" % Time.get_ticks_usec()
	auth._history_path = history_path
	auth._load_login_history()
	check(auth.get_last_login_provider().is_empty() and not login.last_login_hint.visible, "No history must hide the entire last login row")
	var icons: Dictionary = {"kakao": login.KAKAO_ICON, "naver": login.NAVER_ICON, "apple": login.APPLE_ICON}
	for provider: String in ["kakao", "naver", "apple", "unknown"]:
		var fixture := ConfigFile.new()
		fixture.set_value("login", "last_provider", provider)
		fixture.save(history_path)
		auth._load_login_history()
		if provider == "unknown":
			check(not login.last_login_hint.visible, "Unknown stored providers must hide the row")
		else:
			check(login.last_login_hint.visible and login.last_login_icon.texture == icons[provider], "History must display the corresponding provider logo")
			check(login.last_login_hint.accessibility_name.contains(auth.PROVIDER_NAMES[provider]), "Logo history must also name the provider accessibly")
	for attempt: int in range(2):
		auth._set_busy(true)
		auth._operation = "signin"
		auth._clear_memory()
		check(login.find_child("KakaoLogin", true, false).disabled, "Duplicate sign-in must be disabled")
		auth._on_native_login_success("fixture-client", auth._generation)
		var result: Array = await auth.login_finished
		await process_frame
		check(result[0], "Verified SDK token must finish sign-in")
		check(not auth.player_id.is_empty(), "Server must supply a player identity")
		check(auth.get_last_login_provider() == "kakao" and not login.last_login_hint.is_visible_in_tree(), "Successful login must keep provider history inside the hidden panel")
		check(not login.dialog.visible, "Successful sign-in must not display a modal")
		check(not login.login_panel.visible and login.entry_button.visible, "Successful sign-in must reveal the common entry gate")
		check(login.logout_button.visible, "The authenticated entry gate must offer logout")
		check(login.entry_prompt.text == "터치해서 들어가요.", "Entry prompt wording must match")
		check(login.entry_prompt.get_theme_font_size("font_size") == 29, "Entry prompt must match the subtitle's font size")
		check(login.entry_prompt.get_theme_color("font_shadow_color") == login.motto.get_theme_color("font_shadow_color"), "Entry and motto must share the same shadow")
		for offset: String in ["shadow_offset_x", "shadow_offset_y"]:
			check(login.entry_prompt.get_theme_constant(offset) == login.motto.get_theme_constant(offset), "Entry and motto must share shadow offsets")
		auth._set_busy(true)
		login.entry_button.pressed.emit()
		check(entry_requests.is_empty(), "An authentication operation must block entry input")
		auth._set_busy(false)
		check(root.get_children().has(login), "Sign-in must remain on the login scene")
		login.dialog.hide()
	var ready_login: Control = load("res://scenes/login.tscn").instantiate()
	root.add_child(ready_login)
	check(not ready_login.login_panel.visible and ready_login.entry_button.visible and not ready_login.dialog.visible, "A scene opened with a verified session must start at the entry gate")
	ready_login.queue_free()
	auth._set_busy(true)
	auth._operation = "signin"
	auth._clear_memory()
	login._manual_login_pending = true
	auth._on_native_login_success("invalid", auth._generation)
	var failed: Array = await auth.login_finished
	await process_frame
	check(not failed[0] and login.dialog.visible, "Invalid token must show failure modal")
	check(login.login_panel.visible and not login.entry_button.visible, "Failed sign-in must retain the original login UI")
	check(auth.get_last_login_provider() == "kakao", "Failed login must not overwrite the last successful provider")
	check(not login.find_child("KakaoLogin", true, false).disabled, "Retry must become available")
	login.dialog.hide()
	auth.current_provider = "naver"
	auth._generation += 1
	auth._set_busy(true)
	auth._operation = "signin"
	auth._on_naver_native_success("fixture-client", "fixture-refresh", auth._generation)
	var naver_result: Array = await auth.login_finished
	await process_frame
	check(naver_result[0] and not login.dialog.visible and login.entry_button.visible and not login.login_panel.visible, "Naver must use the same entry gate without a success modal")
	check(auth.get_last_login_provider() == "naver" and login.last_login_icon.texture == login.NAVER_ICON, "Successful Naver login must replace the previous provider")
	check(root.get_children().has(login), "Naver login must remain on the login scene")
	login.dialog.hide()
	auth._set_busy(true)
	auth._operation = "signin"
	auth._on_naver_native_success("fixture-client", "fixture-refresh", auth._generation - 1)
	await process_frame
	check(auth.busy, "Late SDK callbacks must not complete a new sign-in attempt")
	login._manual_login_pending = true
	auth._on_naver_native_failure("cancelled", auth._generation)
	check(not auth.busy and login.dialog.visible, "Naver cancellation must release the buttons and show a modal")
	check(auth.get_last_login_provider() == "naver", "Cancellation must preserve last login history")
	var restored_history: Node = load("res://scripts/social_auth.gd").new()
	restored_history._history_path = history_path
	root.add_child(restored_history)
	check(restored_history.get_last_login_provider() == "naver", "A new app instance must load display history without restoring a PC session")
	check(not restored_history.has_valid_session(), "Provider history must never act as an authentication credential")
	restored_history.queue_free()

	var mobile_auth: Node = load("res://scripts/social_auth.gd").new()
	mobile_auth._history_path = history_path + ".mobile"
	root.add_child(mobile_auth)
	var store := FakeStore.new()
	var mobile_session_states: Array = []
	mobile_auth.session_changed.connect(func(authenticated: bool) -> void: mobile_session_states.append(authenticated))
	mobile_auth._mobile = true
	mobile_auth._secure_store = store
	mobile_auth.current_provider = "kakao"
	var fresh: Dictionary = await mobile_auth._request("/v1/auth/kakao/native", {"providerAccessToken": "fixture-client"})
	mobile_auth._set_busy(true)
	mobile_auth._accept_response(fresh)
	check(mobile_auth.has_valid_session(), "Mobile sign-in must accept a short accessToken")
	var credential: Dictionary = JSON.parse_string(store.saved)
	check(credential.refreshToken == fresh.data.refreshToken, "Only game refreshToken must persist")
	check(not credential.has("accessToken") and not store.saved.contains(fresh.data.accessToken), "accessToken must stay in memory")
	mobile_auth._clear_memory()
	mobile_auth._credentials = {}
	mobile_auth._initial_restore = true
	mobile_auth._restore_session()
	var restored: Array = await mobile_auth.login_finished
	check(restored[0] and mobile_auth.has_valid_session(), "App restart must restore login without a provider SDK prompt")
	check(mobile_session_states == [true, false, true], "Sign-in and auto restore must publish the same authenticated state for the entry gate")
	check(JSON.parse_string(store.saved).refreshToken != credential.refreshToken, "Restore must persist the rotated refreshToken")
	check(not JSON.parse_string(store.saved).has("refresh_request_id"), "A successful rotation must clear the pending operation")
	var persisted: String = store.saved
	mobile_auth._set_busy(true)
	mobile_auth._refresh_failed({"status": 0, "data": {"error": "server_unavailable"}})
	check(store.saved == persisted and not mobile_auth._credentials.is_empty(), "Network failure must retain credentials")
	store.reject_writes = true
	var rejected_logout: bool = await mobile_auth.logout()
	check(not rejected_logout, "Failed logout persistence must not claim completion")
	check(mobile_auth.has_valid_session(), "An unsuccessful logout must preserve current sign-in")
	store.reject_writes = false
	var completed_logout: bool = await mobile_auth.logout()
	check(completed_logout, "Mobile logout must revoke the family and clear secure storage")
	check(store.saved.is_empty() and not mobile_auth.has_valid_session(), "Logout must prevent future restore")
	check(mobile_auth.get_last_login_provider() == "kakao", "Mobile logout must preserve the last successful provider")
	var desktop_auth: Node = load("res://scripts/social_auth.gd").new()
	desktop_auth._history_path = history_path + ".desktop"
	root.add_child(desktop_auth)
	desktop_auth._mobile = false
	desktop_auth._secure_store = store
	var previous_writes: int = store.writes
	desktop_auth._set_busy(true)
	desktop_auth._accept_response(fresh)
	check(desktop_auth.has_valid_session() and store.writes == previous_writes + 1, "PC must persist refreshToken in its safe store")
	desktop_auth._clear_memory()
	desktop_auth._credentials = {}
	desktop_auth._initial_restore = true
	desktop_auth._restore_session()
	var pc_restored: Array = await desktop_auth.login_finished
	check(pc_restored[0] and desktop_auth.has_valid_session(), "PC restart must automatically renew without browser login")
	check(not JSON.parse_string(store.saved).has("accessToken"), "PC accessToken must remain memory-only")
	mobile_auth.queue_free()
	desktop_auth.queue_free()
	# The current account has no saved owner/name; entry must open the review-only book.
	login.entry_button.pressed.emit()
	for frame: int in range(600):
		await process_frame
		if current_scene != null and current_scene.scene_file_path == "res://scenes/owner_setup.tscn": break
	check(current_scene != null and current_scene.scene_file_path == "res://scenes/owner_setup.tscn", "A verified account without owner/name must enter the owner book")
	if current_scene != null and current_scene.scene_file_path == "res://scenes/owner_setup.tscn":
		var book: Control = current_scene
		check(book.OWNERS.size() == 9 and book.cards.size() == 9, "The book must offer exactly the approved nine owners")
		book._select_owner(3)
		book.name_input.text = "저장하지 않는 찻집"
		book.start_button.pressed.emit()
		check(current_scene == book and book.selected_owner_id == "cat-black", "Start must not save or navigate")
		book.back_button.pressed.emit()
		await process_frame
		await process_frame
		login = current_scene
		check(login != null and login.scene_file_path == auth.LOGIN_SCENE and login.entry_button.visible, "Back must return to the authenticated entry gate")
		check(auth.has_valid_session(), "Back must preserve the authenticated session")

	# A disposable scene verifies logout returning from a future game screen.
	root.remove_child(login)
	login.queue_free()
	var game_fixture := Control.new()
	root.add_child(game_fixture)
	current_scene = game_fixture
	var logout_completed: bool = await auth.logout()
	await process_frame
	await process_frame
	check(logout_completed and not auth.has_valid_session(), "Manual logout must end the current session")
	check(current_scene != null and current_scene.scene_file_path == "res://scenes/login.tscn", "Manual logout must return to the login page")
	if current_scene != null and current_scene.scene_file_path == "res://scenes/login.tscn":
		check(current_scene.last_login_hint.visible and current_scene.last_login_icon.texture == icons.naver, "Returned login page must retain the last provider logo")
		check(current_scene.login_panel.visible and not current_scene.entry_button.visible, "Manual logout must restore the original login UI")
	for fixture_path: String in [history_path, history_path + ".mobile", history_path + ".desktop"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(fixture_path))
	print("CLIENT_AUTH_SMOKE_FAILURES=", failures)
	quit(0 if failures == 0 else 1)
