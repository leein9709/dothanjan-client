extends Node

signal sign_in_unavailable(provider_name: String)

const PROVIDER_NAMES: Dictionary = {"kakao": "카카오", "naver": "네이버", "apple": "Apple"}

func apple_available() -> bool:
	return OS.get_name() in ["iOS", "macOS"] or (OS.is_debug_build() and "--preview-apple" in OS.get_cmdline_user_args())

func request_sign_in(provider: String) -> void:
	if not PROVIDER_NAMES.has(provider):
		return
	if provider == "apple" and not apple_available():
		return
	# Connect native/browser OAuth and backend validation here after registration.
	# Never issue a fake session or collect a password in this placeholder screen.
	sign_in_unavailable.emit(str(PROVIDER_NAMES[provider]))
