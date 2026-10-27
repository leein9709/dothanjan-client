extends Node

signal sign_in_unavailable(provider_name: String)
signal busy_changed(is_busy: bool)
signal login_finished(success: bool, error_code: String)
signal logged_out
signal last_login_provider_changed(provider: String)
signal session_changed(authenticated: bool)
signal startup_check_changed(checking: bool)

const PROVIDER_NAMES: Dictionary = {"kakao": "카카오", "naver": "네이버", "apple": "Apple"}
const LOGIN_SCENE: String = "res://scenes/login.tscn"
const AUTH_PROTOCOL_VERSION: int = 2
const DESKTOP_SESSION_STORE: Script = preload("res://scripts/desktop_session_store.gd")
var busy: bool = false
var startup_check_pending: bool = true
var player_id: String = ""
var current_provider: String = "kakao"
# Game accessToken is memory-only on every platform.
var _accessToken: String = ""
var _access_deadline: int = 0
var _mobile: bool = false
var _credentials: Dictionary = {}
var _secure_store: Object
var _native: Object
var _naver_native: Object
var _generation: int = 0
var _operation: String = ""
var _naver_retried: bool = false
var _retry_at: int = 0
var _retry_count: int = 0
var _initial_restore: bool = true
var _resume_refresh_pending: bool = false
# Non-secret display history is separate from credentials and survives logout.
var _history_path: String = "user://login_history.cfg"
var _last_login_provider: String = ""
var _history_saved: bool = false
var _published_authenticated: bool = false

func _ready() -> void:
	_load_login_history()
	# Isolated integration fixtures must never read or rotate real account credentials.
	if OS.is_debug_build() and "--auth-fixture" in OS.get_cmdline_user_args():
		startup_check_pending = false
		return
	_mobile = OS.get_name() in ["Android", "iOS"]
	if _mobile and Engine.has_singleton("SessionStore"):
		_secure_store = Engine.get_singleton("SessionStore")
	elif OS.get_name() in ["Windows", "macOS"]:
		_secure_store = DESKTOP_SESSION_STORE.new()
	if _mobile and Engine.has_singleton("KakaoLogin"):
		_native = Engine.get_singleton("KakaoLogin")
		_native.connect("login_success", _on_native_login_success)
		_native.connect("login_failure", _on_native_login_failure)
		var config := ConfigFile.new()
		if config.load("res://config/kakao.local.cfg") == OK:
			var key: String = str(config.get_value("kakao", "native_app_key", ""))
			if not key.is_empty(): _native.configure(key)
	if _mobile and Engine.has_singleton("NaverLogin"):
		_naver_native = Engine.get_singleton("NaverLogin")
		_naver_native.connect("login_success", _on_naver_native_success)
		_naver_native.connect("login_failure", _on_naver_native_failure)
		var naver_config := ConfigFile.new()
		if naver_config.load("res://config/naver.local.cfg") == OK:
			var client_id: String = str(naver_config.get_value("naver", "client_id", ""))
			var client_secret: String = str(naver_config.get_value("naver", "client_secret", ""))
			var app_name: String = str(naver_config.get_value("naver", "app_name", "도트한잔"))
			if not client_id.is_empty() and not client_secret.is_empty():
				if OS.get_name() == "iOS":
					_naver_native.configure(client_id, client_secret, app_name, str(naver_config.get_value("naver", "url_scheme", "dothanjan-naver")))
				else:
					_naver_native.configure(client_id, client_secret, app_name)
	var timer := Timer.new()
	timer.wait_time = 30.0
	timer.timeout.connect(_session_tick)
	add_child(timer)
	timer.start()
	_restore_session.call_deferred()

func apple_available() -> bool:
	return OS.get_name() in ["iOS", "macOS"] or (OS.is_debug_build() and "--preview-apple" in OS.get_cmdline_user_args())

func has_valid_session() -> bool:
	return not _accessToken.is_empty() and _access_deadline > Time.get_ticks_msec()

func fetch_player_profile() -> Dictionary:
	if not has_valid_session(): return {"error": "session_expired"}
	var generation: int = _generation
	var account: String = player_id
	var response: Dictionary = await _request("/v1/auth/me", {}, PackedStringArray(["Authorization: Bearer " + _accessToken]), HTTPClient.METHOD_GET)
	# A delayed response must never open another account's setup screen.
	if generation != _generation or account != player_id or not has_valid_session():
		return {"error": "session_changed"}
	if response.status == 401:
		_clear_memory()
		_refresh_session()
		return {"error": "session_expired"}
	var profile: Variant = response.data.get("player")
	if response.status != 200 or not profile is Dictionary or str(profile.get("id", "")) != account:
		return {"error": "server_unavailable"}
	return {"player": profile}

func _publish_session_state() -> void:
	var authenticated: bool = has_valid_session()
	if authenticated == _published_authenticated: return
	_published_authenticated = authenticated
	session_changed.emit(authenticated)

func check_cafe_name(value: String) -> Dictionary:
	if not has_valid_session(): return {"error": "session_expired"}
	var generation: int = _generation
	var account: String = player_id
	var response: Dictionary = await _request("/v1/auth/cafe-name/check", {"cafe_name": value}, PackedStringArray(["Authorization: Bearer " + _accessToken]))
	if generation != _generation or account != player_id or not has_valid_session():
		return {"error": "session_changed"}
	if response.status == 401:
		_clear_memory()
		_refresh_session()
		return {"error": "session_expired"}
	var data: Dictionary = response.data
	if response.status == 200 and data.get("available") is bool and data.get("cafe_name") is String:
		return {"available": data.available, "cafe_name": data.cafe_name}
	if response.status == 400:
		return {"error": "invalid_cafe_name", "reason": str(data.get("reason", ""))}
	if response.status == 429: return {"error": "too_many_attempts"}
	if response.status == 404: return {"error": "server_update_required"}
	return {"error": "server_unavailable"}

func setup_cafe(owner: String, cafe_name: String) -> Dictionary:
	if not has_valid_session(): return {"error": "session_expired"}
	var generation: int = _generation
	var account: String = player_id
	var response: Dictionary = await _request("/v1/auth/cafe/setup", {"owner_character_id": owner, "cafe_name": cafe_name}, PackedStringArray(["Authorization: Bearer " + _accessToken]))
	if generation != _generation or account != player_id or not has_valid_session(): return {"error": "session_changed"}
	if response.status == 401:
		_clear_memory()
		_refresh_session()
		return {"error": "session_expired"}
	var profile: Variant = response.data.get("player")
	if response.status == 200 and profile is Dictionary and str(profile.get("id", "")) == account and str(profile.get("owner_character_id", "")) == owner and str(profile.get("cafe_name", "")) == cafe_name:
		return {"player": profile}
	return {"error": str(response.data.get("error", "server_unavailable"))}

func get_last_login_provider() -> String:
	return _last_login_provider

func _load_login_history() -> void:
	var config := ConfigFile.new()
	var provider: String = ""
	if config.load(_history_path) == OK:
		var stored: Variant = config.get_value("login", "last_provider", "")
		if stored is String and PROVIDER_NAMES.has(stored): provider = stored
	_history_saved = not provider.is_empty()
	if provider == _last_login_provider: return
	_last_login_provider = provider
	last_login_provider_changed.emit(provider)

func _remember_last_login(provider: String) -> void:
	if not PROVIDER_NAMES.has(provider) or (provider == _last_login_provider and _history_saved): return
	var config := ConfigFile.new()
	config.set_value("login", "last_provider", provider)
	_history_saved = config.save(_history_path) == OK
	if not _history_saved:
		# Display metadata must never turn a verified login into a failed login.
		push_warning("Could not save last login provider history")
	if provider == _last_login_provider: return
	_last_login_provider = provider
	last_login_provider_changed.emit(provider)

func request_sign_in(provider: String) -> void:
	if busy or not PROVIDER_NAMES.has(provider): return
	if provider == "apple" and not apple_available(): return
	if provider == "apple":
		sign_in_unavailable.emit(str(PROVIDER_NAMES[provider]))
		return
	if _credentials.get("logout_pending", false):
		_login_after_pending_logout(provider)
		return
	_set_busy(true)
	_operation = "signin"
	_generation += 1
	current_provider = provider
	_initial_restore = false
	_naver_retried = false
	_clear_memory()
	var generation: int = _generation
	var compatibility: String = await _check_auth_protocol(provider)
	if not busy or generation != _generation: return
	if not compatibility.is_empty():
		_finish(false, compatibility)
		return
	if _mobile:
		var native: Object = _native if provider == "kakao" else _naver_native
		if native == null:
			_finish(false, "sdk_unavailable")
		else:
			native.login(_generation)
			_native_timeout(_generation)
	else:
		_web_login(provider, _generation)

func _native_timeout(generation: int) -> void:
	await get_tree().create_timer(180.0).timeout
	if busy and _operation == "signin" and generation == _generation: _finish(false, "login_expired")

func _web_login(provider: String, generation: int) -> void:
	var base: String = "/v1/auth/%s" % provider
	var started: Dictionary = await _request(base + "/start", {})
	if not busy or generation != _generation: return
	if started.status != 200:
		_finish(false, str(started.data.get("error", "server_unavailable")))
		return
	var data: Dictionary = started.data
	var url := str(data.get("authorization_url", ""))
	var expected_url: String = "https://kauth.kakao.com/oauth/authorize?" if provider == "kakao" else "https://nid.naver.com/oauth2.0/authorize?"
	if not url.begins_with(expected_url):
		_finish(false, "login_failed")
		return
	if OS.shell_open(url) != OK:
		_finish(false, "browser_unavailable")
		return
	var deadline: int = Time.get_ticks_msec() + 600000
	var retries: int = 0
	while busy and generation == _generation and Time.get_ticks_msec() < deadline:
		await get_tree().create_timer(1.5).timeout
		if not busy or generation != _generation: return
		var response: Dictionary = await _request(base + "/result", {"request_id": data.get("request_id", ""), "proof": data.get("proof", "")})
		if not busy or generation != _generation: return
		if response.status == 202: continue
		if response.status == 0 or response.status >= 500 or response.status == 429:
			retries += 1
			if retries < 3: continue
		else: retries = 0
		_accept_response(response)
		return
	if busy and generation == _generation: _finish(false, "login_expired")

func _on_native_login_success(providerAccessToken: String, generation: int) -> void:
	if not busy or _operation != "signin" or current_provider != "kakao" or generation != _generation: return
	var response: Dictionary = await _request("/v1/auth/kakao/native", {"providerAccessToken": providerAccessToken})
	if not busy or generation != _generation: return
	_accept_response(response)

func _on_native_login_failure(code: String, generation: int) -> void:
	if busy and _operation == "signin" and current_provider == "kakao" and generation == _generation: _finish(false, code)

func _on_naver_native_success(providerAccessToken: String, providerRefreshToken: String, generation: int) -> void:
	if not busy or _operation != "signin" or current_provider != "naver" or generation != _generation: return
	var response: Dictionary = await _request("/v1/auth/naver/native", {"providerAccessToken": providerAccessToken, "providerRefreshToken": providerRefreshToken})
	if not busy or generation != _generation: return
	if response.status == 401 and str(response.data.get("error", "")) == "invalid_token" and not _naver_retried and _naver_native != null:
		_naver_retried = true
		_naver_native.reauthenticate(generation)
		return
	_accept_response(response)

func _on_naver_native_failure(code: String, generation: int) -> void:
	if busy and _operation == "signin" and current_provider == "naver" and generation == _generation: _finish(false, code)

func _valid_token(value: Variant) -> bool:
	if not value is String: return false
	var pattern := RegEx.new()
	pattern.compile("^[A-Za-z0-9_-]{43}$")
	return pattern.search(value) != null

func _valid_request_id(value: Variant) -> bool:
	if not value is String: return false
	var pattern := RegEx.new()
	pattern.compile("^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$")
	return pattern.search(value) != null

func _accept_response(response: Dictionary, renewing: bool = false) -> void:
	var data: Dictionary = response.data
	if response.status == 200 and data.has("token") and not data.has("accessToken"):
		_finish(false, "server_update_required")
		return
	var valid: bool = response.status == 200 and data.get("status", "") == "success" and _valid_token(data.get("accessToken", "")) and data.get("player", {}) is Dictionary
	if valid: valid = not str(data.player.get("id", "")).is_empty()
	if valid:
		valid = _valid_token(data.get("refreshToken", "")) and data.get("provider", "") == current_provider
	if not valid:
		if renewing: _refresh_failed(response)
		else: _finish(false, str(data.get("error", "login_failed" if response.status == 200 else "server_unavailable")))
		return
	var next_credentials: Dictionary = {"v": 1, "provider": current_provider, "refreshToken": data.refreshToken, "api_base_url": AppConfig.api_base_url}
	if not _save_credentials(next_credentials):
		_retry_at = Time.get_ticks_msec() + 5000
		if renewing:
			_set_busy(false)
			if _initial_restore: login_finished.emit(false, "session_storage_failed")
			_initial_restore = false
		else: _finish(false, "session_storage_failed")
		return
	_accessToken = str(data.accessToken)
	player_id = str(data.player.id)
	var elapsed_seconds: int = int(ceil(float(response.get("elapsed_msec", 0)) / 1000.0))
	var seconds: int = maxi(0, int(data.get("expires_in", 0)) - elapsed_seconds)
	_access_deadline = Time.get_ticks_msec() + seconds * 1000
	if seconds <= 0:
		_clear_memory()
		if not _credentials.is_empty():
			# A response delivered after a long suspension can contain an already expired accessToken.
			_initial_restore = true
			_set_busy(false)
			_refresh_session.call_deferred()
		else: _finish(false, "session_expired")
		return
	_retry_count = 0
	_retry_at = 0
	_remember_last_login(current_provider)
	_publish_session_state()
	var announce: bool = not renewing or _initial_restore
	_initial_restore = false
	_set_busy(false)
	if announce: login_finished.emit(true, "")

func _save_credentials(payload: Dictionary) -> bool:
	if _secure_store == null: return false
	if not _secure_store.save_credentials(JSON.stringify(payload)): return false
	_credentials = payload
	return true

func _restore_session() -> void:
	startup_check_pending = true
	startup_check_changed.emit(true)
	# Allow the login scene to attach its modal signal handlers first.
	await get_tree().process_frame
	await _restore_saved_session()
	startup_check_pending = false
	startup_check_changed.emit(false)

func _restore_saved_session() -> void:
	if busy or _secure_store == null:
		_initial_restore = false
		return
	var stored: String = _secure_store.load_credentials()
	if stored.is_empty():
		_initial_restore = false
		return
	if stored == "!storage_error":
		_initial_restore = false
		login_finished.emit(false, "session_storage_failed")
		return
	var payload: Variant = JSON.parse_string(stored)
	if not payload is Dictionary:
		_secure_store.clear_credentials()
		_initial_restore = false
		return
	var valid: bool = payload.get("v", 0) == 1 and payload.get("provider", "") in ["kakao", "naver"] and _valid_token(payload.get("refreshToken", ""))
	valid = valid and payload.get("api_base_url", "") == AppConfig.api_base_url
	if payload.has("refresh_request_id"): valid = valid and _valid_request_id(payload.refresh_request_id)
	if not valid:
		_secure_store.clear_credentials()
		_initial_restore = false
		return
	_credentials = payload
	current_provider = str(payload.provider)
	if _credentials.get("logout_pending", false):
		_initial_restore = false
		_try_pending_logout()
	else: await _refresh_session()

func _new_request_id() -> String:
	var bytes: PackedByteArray = Crypto.new().generate_random_bytes(16)
	bytes[6] = (bytes[6] & 15) | 64
	bytes[8] = (bytes[8] & 63) | 128
	var hex: String = bytes.hex_encode()
	return "%s-%s-%s-%s-%s" % [hex.substr(0, 8), hex.substr(8, 4), hex.substr(12, 4), hex.substr(16, 4), hex.substr(20, 12)]

func _refresh_session() -> void:
	if busy or _credentials.is_empty() or _credentials.get("logout_pending", false): return
	_set_busy(true)
	_operation = "refresh"
	_generation += 1
	var generation: int = _generation
	current_provider = str(_credentials.provider)
	var compatibility: String = await _check_auth_protocol(current_provider)
	if not busy or generation != _generation: return
	if not compatibility.is_empty():
		_refresh_failed({"status": 0, "data": {"error": compatibility}})
		return
	var request_id: String = str(_credentials.get("refresh_request_id", ""))
	if request_id.is_empty():
		request_id = _new_request_id()
		var pending: Dictionary = _credentials.duplicate()
		pending["refresh_request_id"] = request_id
		# Persist the operation before sending: a lost response retries the exact same rotation.
		if not _save_credentials(pending):
			_set_busy(false)
			_retry_at = Time.get_ticks_msec() + 5000
			if _initial_restore: login_finished.emit(false, "session_storage_failed")
			_initial_restore = false
			return
	var response: Dictionary = await _request("/v1/auth/session/refresh", {"refreshToken": _credentials.refreshToken, "request_id": request_id})
	if not busy or generation != _generation: return
	_accept_response(response, true)

func _refresh_failed(response: Dictionary) -> void:
	_set_busy(false)
	if response.status == 401:
		_clear_memory()
		_credentials = {}
		var cleared: bool = _secure_store != null and _secure_store.clear_credentials()
		login_finished.emit(false, str(response.data.get("error", "session_expired")) if cleared else "session_storage_failed")
	else:
		# Outages preserve the credential and operation UUID; they do not sign the player out.
		_retry_count += 1
		_retry_at = Time.get_ticks_msec() + int(minf(60.0, 10.0 * pow(2.0, mini(_retry_count - 1, 3)))) * 1000
		if _initial_restore: login_finished.emit(false, str(response.data.get("error", "server_unavailable")))
	_initial_restore = false
	_publish_session_state()

func _session_tick() -> void:
	_publish_session_state()
	if busy: return
	var now: int = Time.get_ticks_msec()
	if not _credentials.is_empty() and now >= _retry_at:
		if _credentials.get("logout_pending", false): _try_pending_logout()
		elif _accessToken.is_empty() or _access_deadline <= now + 60000: _refresh_session()
	elif _credentials.is_empty() and not _accessToken.is_empty() and _access_deadline <= now:
		_clear_memory()
		login_finished.emit(false, "session_expired")

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_RESUMED: _publish_session_state()
	if what == NOTIFICATION_APPLICATION_RESUMED and not _credentials.is_empty():
		if busy:
			if _operation == "refresh": _resume_refresh_pending = true
			return
		if _credentials.get("logout_pending", false): _try_pending_logout()
		else: _refresh_session()

func logout() -> bool:
	if busy: return false
	_generation += 1
	var accessToken: String = _accessToken
	if not _credentials.is_empty():
		var pending: Dictionary = _credentials.duplicate()
		pending["logout_pending"] = true
		# Do not report a completed logout until relaunch can no longer restore this credential.
		if not _save_credentials(pending):
			login_finished.emit(false, "session_storage_failed")
			return false
		_clear_memory()
		_set_busy(true)
		_operation = "logout"
		_complete_local_logout()
		await _flush_pending_logout()
		_set_busy(false)
	else:
		_clear_memory()
		if not accessToken.is_empty():
			_set_busy(true)
			_operation = "logout"
		_complete_local_logout()
		if not accessToken.is_empty():
			await _request("/v1/auth/logout", {}, PackedStringArray(["Authorization: Bearer " + accessToken]))
			_set_busy(false)
	return true

func _complete_local_logout() -> void:
	logged_out.emit()
	# The autoload survives scene changes; server revocation can finish on the login page.
	_show_login_page.call_deferred()

func _show_login_page() -> void:
	var tree: SceneTree = get_tree()
	if tree.current_scene != null and tree.current_scene.scene_file_path == LOGIN_SCENE: return
	if tree.change_scene_to_file(LOGIN_SCENE) != OK:
		push_error("Could not open the login scene after logout")

func _flush_pending_logout() -> String:
	var response: Dictionary = await _request("/v1/auth/logout", {"refreshToken": _credentials.refreshToken})
	if response.status != 204:
		_retry_at = Time.get_ticks_msec() + 60000
		return "server_unavailable"
	if _secure_store == null or not _secure_store.clear_credentials():
		_retry_at = Time.get_ticks_msec() + 5000
		return "session_storage_failed"
	_credentials = {}
	_retry_at = 0
	return ""

func _try_pending_logout() -> void:
	if busy: return
	_set_busy(true)
	_operation = "logout"
	await _flush_pending_logout()
	_set_busy(false)

func _login_after_pending_logout(provider: String) -> void:
	_set_busy(true)
	_operation = "logout"
	var error: String = await _flush_pending_logout()
	_set_busy(false)
	if not error.is_empty(): login_finished.emit(false, error)
	else: request_sign_in(provider)

func _clear_memory() -> void:
	_accessToken = ""
	_access_deadline = 0
	player_id = ""
	_publish_session_state()

func _finish(success: bool, code: String) -> void:
	_set_busy(false)
	login_finished.emit(success, code)

func _set_busy(value: bool) -> void:
	busy = value
	if not value:
		_operation = ""
		if _resume_refresh_pending:
			_resume_refresh_pending = false
			_refresh_session.call_deferred()
	busy_changed.emit(value)

func _check_auth_protocol(provider: String) -> String:
	var response: Dictionary = await _request("/v1/auth/providers", {}, PackedStringArray(), HTTPClient.METHOD_GET)
	if response.status != 200: return "server_unavailable"
	if response.data.get("protocol_version", 0) != AUTH_PROTOCOL_VERSION: return "server_update_required"
	var providers: Variant = response.data.get("providers", [])
	if providers is Array:
		for item: Variant in providers:
			if item is Dictionary and item.get("id", "") == provider:
				return "" if item.get("enabled", false) else "provider_not_configured"
	return "provider_not_configured"

func _request(path: String, payload: Dictionary, extra_headers: PackedStringArray = PackedStringArray(), method: HTTPClient.Method = HTTPClient.METHOD_POST) -> Dictionary:
	if AppConfig.api_base_url.is_empty(): return {"status": 0, "data": {"error": "server_unavailable"}}
	var request := HTTPRequest.new()
	request.timeout = 35.0
	add_child(request)
	var headers := PackedStringArray(["Content-Type: application/json"])
	headers.append_array(extra_headers)
	var started_at: int = Time.get_ticks_msec()
	var started_unix_msec: int = int(Time.get_unix_time_from_system() * 1000.0)
	var error: Error = request.request(AppConfig.api_base_url + path, headers, method, "" if method == HTTPClient.METHOD_GET else JSON.stringify(payload))
	if error != OK:
		request.queue_free()
		return {"status": 0, "data": {"error": "server_unavailable"}}
	var result: Array = await request.request_completed
	request.queue_free()
	if result[0] != HTTPRequest.RESULT_SUCCESS: return {"status": 0, "data": {"error": "server_unavailable"}}
	var data: Variant = null
	# Logout deliberately returns 204 with no JSON body.
	if not result[3].is_empty(): data = JSON.parse_string(result[3].get_string_from_utf8())
	# Wall-clock elapsed time also covers device sleep when the monotonic clock pauses.
	var elapsed: int = maxi(Time.get_ticks_msec() - started_at, int(Time.get_unix_time_from_system() * 1000.0) - started_unix_msec)
	return {"status": int(result[1]), "data": data if data is Dictionary else {}, "elapsed_msec": elapsed}
