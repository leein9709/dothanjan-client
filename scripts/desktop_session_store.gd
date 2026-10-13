extends RefCounted

const WINDOWS_HELPER: String = "res://scripts/windows_session_store.ps1"
const KEYCHAIN_SERVICE: String = "org.dothanjan.desktop.session.v1"
var storage_path: String = "user://session.dpapi"

func load_credentials() -> String:
	if OS.get_name() == "Windows":
		var result: Dictionary = _windows("load")
		return str(result.get("payload", "")) if result.get("ok", false) else "!storage_error"
	if OS.get_name() == "macOS":
		var result: Dictionary = _run("/usr/bin/security", PackedStringArray(["find-generic-password", "-s", KEYCHAIN_SERVICE, "-a", "credential_bundle", "-w"]))
		if result.code == 44: return ""
		if result.code != 0: return "!storage_error"
		var payload: String = Marshalls.base64_to_utf8(str(result.output).strip_edges())
		return payload if JSON.parse_string(payload) is Dictionary else "!storage_error"
	return "!storage_error"

func save_credentials(payload: String) -> bool:
	if payload.to_utf8_buffer().size() > 8192: return false
	if OS.get_name() == "Windows": return bool(_windows("save", payload).get("ok", false))
	if OS.get_name() == "macOS":
		# Interactive stdin keeps the token out of process command-line arguments.
		var encoded: String = Marshalls.utf8_to_base64(payload)
		# The shell reads one base64 line, then its builtin printf closes the security tool's stdin.
		# There is no token interpolation into shell code or process argv.
		var command: String = "IFS= read -r payload; printf 'add-generic-password -U -s %s -a credential_bundle -w %%s\\n' \"$payload\" | /usr/bin/security -i -q -p ''" % KEYCHAIN_SERVICE
		var result: Dictionary = _run("/bin/sh", PackedStringArray(["-c", command]), encoded + "\n")
		if result.code != 0 or not str(result.stderr).strip_edges().is_empty(): return false
		# The interactive tool's final exit code does not guarantee each command succeeded.
		return load_credentials() == payload
	return false

func clear_credentials() -> bool:
	if OS.get_name() == "Windows": return bool(_windows("clear").get("ok", false))
	if OS.get_name() == "macOS":
		var result: Dictionary = _run("/usr/bin/security", PackedStringArray(["delete-generic-password", "-s", KEYCHAIN_SERVICE, "-a", "credential_bundle"]))
		return result.code in [0, 44]
	return false

func _windows(action: String, payload: String = "") -> Dictionary:
	var source: String = FileAccess.get_file_as_string(WINDOWS_HELPER)
	if source.is_empty(): return {"ok": false}
	var utf16 := PackedByteArray()
	for index: int in source.length():
		var character: int = source.unicode_at(index)
		utf16.append(character & 255)
		utf16.append((character >> 8) & 255)
	var executable: String = OS.get_environment("SystemRoot").path_join("System32/WindowsPowerShell/v1.0/powershell.exe")
	var args := PackedStringArray(["-NoProfile", "-NonInteractive", "-WindowStyle", "Hidden", "-EncodedCommand", Marshalls.raw_to_base64(utf16)])
	var request: String = JSON.stringify({"action": action, "path": ProjectSettings.globalize_path(storage_path), "payload": payload}) + "\n"
	var result: Dictionary = _run(executable, args, request)
	if result.code != 0: return {"ok": false}
	var data: Variant = JSON.parse_string(str(result.output).strip_edges())
	return data if data is Dictionary else {"ok": false}

func _run(executable: String, args: PackedStringArray, input: String = "") -> Dictionary:
	var process: Dictionary = OS.execute_with_pipe(executable, args, false)
	if process.is_empty(): return {"code": -1, "output": "", "stderr": ""}
	var pipe: FileAccess = process.stdio
	var errors: FileAccess = process.stderr
	if not input.is_empty():
		pipe.store_buffer(input.to_utf8_buffer())
		pipe.flush()
	var output := PackedByteArray()
	var stderr := PackedByteArray()
	var deadline: int = Time.get_ticks_msec() + 8000
	while OS.is_process_running(process.pid) and Time.get_ticks_msec() < deadline:
		output.append_array(pipe.get_buffer(4096))
		stderr.append_array(errors.get_buffer(4096))
		if output.size() > 32768 or stderr.size() > 8192: break
		OS.delay_msec(5)
	if OS.is_process_running(process.pid):
		OS.kill(process.pid)
		pipe.close()
		errors.close()
		return {"code": -1, "output": "", "stderr": ""}
	output.append_array(pipe.get_buffer(16384))
	stderr.append_array(errors.get_buffer(8192))
	var code: int = OS.get_process_exit_code(process.pid)
	pipe.close()
	errors.close()
	return {"code": code, "output": output.get_string_from_utf8(), "stderr": stderr.get_string_from_utf8()}
