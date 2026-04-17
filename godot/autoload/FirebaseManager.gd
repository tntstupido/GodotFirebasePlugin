extends Node

signal firebase_initialized(success: bool, message: String)
signal remote_config_updated(success: bool, message: String)
signal messaging_token_received(token: String)
signal firebase_error(code: int, message: String)

const SINGLETON_CANDIDATES := ["GodotFirebase", "FirebasePlugin", "firebaseplugin", "Firebase"]

var _plugin: Object = null

func _ready() -> void:
	for name in SINGLETON_CANDIDATES:
		if Engine.has_singleton(name):
			_plugin = Engine.get_singleton(name)
			print("FirebaseManager: using singleton '%s'." % name)
			break

	if _plugin == null:
		push_warning("FirebaseManager: Firebase plugin singleton not found.")
		return

	_try_connect("firebase_initialized", _on_firebase_initialized)
	_try_connect("remote_config_updated", _on_remote_config_updated)
	_try_connect("messaging_token_received", _on_messaging_token_received)
	_try_connect("firebase_error", _on_firebase_error)

func initialize() -> void:
	if _plugin != null and _plugin.has_method("initialize"):
		_plugin.call("initialize")

func log_event(name: String, params: Dictionary = {}) -> void:
	if _plugin == null:
		return
	if _plugin.has_method("logEvent"):
		_plugin.call("logEvent", name, JSON.stringify(params))

func set_user_property(name: String, value: String) -> void:
	if _plugin != null and _plugin.has_method("setUserProperty"):
		_plugin.call("setUserProperty", name, value)

func set_user_id(user_id: String) -> void:
	if _plugin != null and _plugin.has_method("setUserId"):
		_plugin.call("setUserId", user_id)

func set_crashlytics_enabled(enabled: bool) -> void:
	if _plugin != null and _plugin.has_method("setCrashlyticsEnabled"):
		_plugin.call("setCrashlyticsEnabled", enabled)

func set_custom_key(key: String, value: Variant) -> void:
	if _plugin != null and _plugin.has_method("setCustomKey"):
		_plugin.call("setCustomKey", key, str(value))

func record_error(message: String) -> void:
	if _plugin != null and _plugin.has_method("recordError"):
		_plugin.call("recordError", message)

func remote_config_fetch_and_activate() -> void:
	if _plugin != null and _plugin.has_method("remoteConfigFetchAndActivate"):
		_plugin.call("remoteConfigFetchAndActivate")

func remote_config_get_string(key: String, fallback: String = "") -> String:
	if _plugin != null and _plugin.has_method("remoteConfigGetString"):
		return str(_plugin.call("remoteConfigGetString", key, fallback))
	return fallback

func remote_config_get_bool(key: String, fallback: bool = false) -> bool:
	if _plugin != null and _plugin.has_method("remoteConfigGetBool"):
		return bool(_plugin.call("remoteConfigGetBool", key, fallback))
	return fallback

func remote_config_get_int(key: String, fallback: int = 0) -> int:
	if _plugin != null and _plugin.has_method("remoteConfigGetInt"):
		return int(_plugin.call("remoteConfigGetInt", key, fallback))
	return fallback

func messaging_get_token() -> void:
	if _plugin != null and _plugin.has_method("messagingGetToken"):
		_plugin.call("messagingGetToken")

func messaging_subscribe(topic: String) -> void:
	if _plugin != null and _plugin.has_method("messagingSubscribe"):
		_plugin.call("messagingSubscribe", topic)

func messaging_unsubscribe(topic: String) -> void:
	if _plugin != null and _plugin.has_method("messagingUnsubscribe"):
		_plugin.call("messagingUnsubscribe", topic)

func _try_connect(signal_name: String, callable_fn: Callable) -> void:
	if _plugin.has_signal(signal_name) and not _plugin.is_connected(signal_name, callable_fn):
		_plugin.connect(signal_name, callable_fn)

func _on_firebase_initialized(success: bool, message: String) -> void:
	emit_signal("firebase_initialized", success, message)

func _on_remote_config_updated(success: bool, message: String) -> void:
	emit_signal("remote_config_updated", success, message)

func _on_messaging_token_received(token: String) -> void:
	emit_signal("messaging_token_received", token)

func _on_firebase_error(code: int, message: String) -> void:
	emit_signal("firebase_error", code, message)
