@tool
extends EditorPlugin

const PLUGIN_NAME := "FirebasePlugin"
const DEBUG_AAR := "res://addons/firebase_plugin/FirebasePlugin-debug.aar"
const RELEASE_AAR := "res://addons/firebase_plugin/FirebasePlugin-release.aar"

const ANDROID_GOOGLE_APP_ID := "firebase/android/google_app_id"
const IOS_GOOGLE_APP_ID := "firebase/ios/google_app_id"
const REMOTE_CONFIG_MIN_FETCH_SECONDS := "firebase/remote_config/min_fetch_interval_seconds"

var export_plugin: FirebaseExportPlugin

func _enter_tree() -> void:
	export_plugin = FirebaseExportPlugin.new()
	add_export_plugin(export_plugin)

func _exit_tree() -> void:
	remove_export_plugin(export_plugin)
	export_plugin = null


class FirebaseExportPlugin extends EditorExportPlugin:
	func _get_name() -> String:
		return PLUGIN_NAME

	func _supports_platform(platform: EditorExportPlatform) -> bool:
		return platform is EditorExportPlatformAndroid or _is_ios_platform(platform)

	func _get_android_libraries(platform: EditorExportPlatform, debug: bool) -> PackedStringArray:
		if debug:
			return PackedStringArray([DEBUG_AAR])
		return PackedStringArray([RELEASE_AAR])

	func _get_android_dependencies(platform: EditorExportPlatform, debug: bool) -> PackedStringArray:
		return PackedStringArray([
			"com.google.firebase:firebase-analytics:22.4.0",
			"com.google.firebase:firebase-crashlytics:19.4.1",
			"com.google.firebase:firebase-config:22.1.2",
			"com.google.firebase:firebase-messaging:24.1.1"
		])

	func _get_android_maven_repos(platform: EditorExportPlatform, debug: bool) -> PackedStringArray:
		return PackedStringArray([
			"https://dl.google.com/dl/android/maven2/"
		])

	func _get_android_manifest_application_element_contents(platform: EditorExportPlatform, debug: bool) -> String:
		return (
			'\t\t<meta-data\n'
			+ '\t\t\tandroid:name="org.godotengine.plugin.v2.FirebasePlugin"\n'
			+ '\t\t\tandroid:value="com.mladenstojanovic.firebaseplugin.FirebasePlugin" />\n'
		)

	func _get_android_permissions(platform: EditorExportPlatform, debug: bool) -> PackedStringArray:
		return PackedStringArray([
			"android.permission.INTERNET",
			"android.permission.ACCESS_NETWORK_STATE"
		])

	func _get_export_options(platform: EditorExportPlatform) -> Array[Dictionary]:
		return [
			{
				"option": {
					"name": ANDROID_GOOGLE_APP_ID,
					"type": TYPE_STRING,
				},
				"default_value": "",
			},
			{
				"option": {
					"name": IOS_GOOGLE_APP_ID,
					"type": TYPE_STRING,
				},
				"default_value": "",
			},
			{
				"option": {
					"name": REMOTE_CONFIG_MIN_FETCH_SECONDS,
					"type": TYPE_INT,
				},
				"default_value": 3600,
			}
		]

	func _is_ios_platform(platform: EditorExportPlatform) -> bool:
		return platform.get_class().contains("iOS")
