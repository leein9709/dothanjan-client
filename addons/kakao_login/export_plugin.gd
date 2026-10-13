@tool
extends EditorPlugin

var exporter: EditorExportPlugin

func _enter_tree() -> void:
	exporter = KakaoAndroidExport.new()
	add_export_plugin(exporter)

func _exit_tree() -> void:
	remove_export_plugin(exporter)

class KakaoAndroidExport extends EditorExportPlugin:
	func _get_name() -> String:
		return "KakaoLogin"

	func _supports_platform(platform: EditorExportPlatform) -> bool:
		return platform is EditorExportPlatformAndroid

	func _get_android_libraries(_platform: EditorExportPlatform, _debug: bool) -> PackedStringArray:
		return PackedStringArray(["res://addons/kakao_login/bin/kakao-login-release.aar"])

	func _get_android_dependencies(_platform: EditorExportPlatform, _debug: bool) -> PackedStringArray:
		return PackedStringArray(["com.kakao.sdk:v2-user:2.25.1", "com.navercorp.nid:oauth:5.12.0"])

	func _get_android_dependencies_maven_repos(_platform: EditorExportPlatform, _debug: bool) -> PackedStringArray:
		return PackedStringArray(["https://devrepo.kakao.com/nexus/content/groups/public/"])

	func _get_android_manifest_element_contents(_platform: EditorExportPlatform, _debug: bool) -> String:
		return '<queries><package android:name="com.kakao.talk" /><package android:name="com.nhn.android.search" /></queries>'

	func _get_android_manifest_application_element_contents(_platform: EditorExportPlatform, _debug: bool) -> String:
		var config := ConfigFile.new()
		if config.load("res://config/kakao.local.cfg") != OK:
			push_error("Missing local Kakao native configuration")
			return ""
		var key: String = str(config.get_value("kakao", "native_app_key", ""))
		if not key.is_valid_hex_number(false):
			push_error("Invalid Kakao native configuration")
			return ""
		return '<activity android:name="com.kakao.sdk.auth.AuthCodeHandlerActivity" android:exported="true"><intent-filter><action android:name="android.intent.action.VIEW" /><category android:name="android.intent.category.DEFAULT" /><category android:name="android.intent.category.BROWSABLE" /><data android:host="oauth" android:scheme="kakao%s" /></intent-filter></activity>' % key
