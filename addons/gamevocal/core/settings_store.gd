@tool
class_name GameVocalSettingsStore
extends RefCounted

# Securely stores user API keys in EditorSettings (not in project files).

const SETTING_API_KEY = "gamevocal/credentials/api_key"

static func get_api_key() -> String:
	if not Engine.is_editor_hint():
		return ""
	var settings = EditorInterface.get_editor_settings()
	if settings.has_setting(SETTING_API_KEY):
		return settings.get_setting(SETTING_API_KEY)
	return ""

static func set_api_key(key: String):
	if not Engine.is_editor_hint():
		return
	var settings = EditorInterface.get_editor_settings()
	settings.set_setting(SETTING_API_KEY, key)

static func clear_credentials():
	if not Engine.is_editor_hint():
		return
	var settings = EditorInterface.get_editor_settings()
	settings.erase(SETTING_API_KEY)
