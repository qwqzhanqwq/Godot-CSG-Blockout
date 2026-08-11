@tool
extends RefCounted
class_name CsgBlockoutConfig

static var _instance: CsgBlockoutConfig

static func get_config() -> CsgBlockoutConfig:
	if _instance == null:
		_instance = CsgBlockoutConfig.new()
		_instance._ensure_settings_exist()
	return _instance
# ProjectSettings paths
const SETTING_DEFAULT_BEHAVIOR = "addons/csg_blockout/default_behavior"
const SETTING_ACTION_KEY = "addons/csg_blockout/action_key"
const SETTING_SECONDARY_ACTION_KEY = "addons/csg_blockout/secondary_action_key"
const SETTING_AUTO_HIDE = "addons/csg_blockout/auto_hide"
const SETTING_LANGUAGE_OVERRIDE = "addons/csg_blockout/language_override"

# Default values
const DEFAULT_DEFAULT_BEHAVIOR = CSGBehavior.SIBLING
const DEFAULT_ACTION_KEY = KEY_SHIFT
const DEFAULT_SECONDARY_ACTION_KEY = KEY_ALT
const DEFAULT_AUTO_HIDE = true
const DEFAULT_LANGUAGE_OVERRIDE = "zh_CN"

# Configurable properties

## Default behavior when adding new CSG nodes
var default_behavior: CSGBehavior = CSGBehavior.SIBLING:
	get: return _get_setting(SETTING_DEFAULT_BEHAVIOR, DEFAULT_DEFAULT_BEHAVIOR)
	set(value): _set_setting(SETTING_DEFAULT_BEHAVIOR, value)

## Key to hold for primary action (e.g., adding CSG nodes)
var action_key: Key = KEY_SHIFT:
	get: return _get_setting(SETTING_ACTION_KEY, DEFAULT_ACTION_KEY)
	set(value): _set_setting(SETTING_ACTION_KEY, value)

## Key to hold for secondary action (e.g., alternative CSG operations)
var secondary_action_key: Key = KEY_ALT:
	get: return _get_setting(SETTING_SECONDARY_ACTION_KEY, DEFAULT_SECONDARY_ACTION_KEY)
	set(value): _set_setting(SETTING_SECONDARY_ACTION_KEY, value)

## Whether to auto-hide the CSG blockout UI when not in use
var auto_hide: bool = true:
	get: return _get_setting(SETTING_AUTO_HIDE, DEFAULT_AUTO_HIDE)
	set(value): _set_setting(SETTING_AUTO_HIDE, value)

## Language override (en, zh_CN)
var language_override: String = "zh_CN":
	get: return _get_setting(SETTING_LANGUAGE_OVERRIDE, DEFAULT_LANGUAGE_OVERRIDE)
	set(value): _set_setting(SETTING_LANGUAGE_OVERRIDE, value)

signal config_saved()

enum CSGBehavior { SIBLING, CHILD }



func _ensure_settings_exist() -> void:
	"""Register settings in ProjectSettings if they don't exist."""
	if not ProjectSettings.has_setting(SETTING_DEFAULT_BEHAVIOR):
		ProjectSettings.set_setting(SETTING_DEFAULT_BEHAVIOR, DEFAULT_DEFAULT_BEHAVIOR)
		ProjectSettings.set_initial_value(SETTING_DEFAULT_BEHAVIOR, DEFAULT_DEFAULT_BEHAVIOR)
		ProjectSettings.add_property_info({
			"name": SETTING_DEFAULT_BEHAVIOR,
			"type": TYPE_INT,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Sibling,Child"
		})
	
	if not ProjectSettings.has_setting(SETTING_ACTION_KEY):
		ProjectSettings.set_setting(SETTING_ACTION_KEY, DEFAULT_ACTION_KEY)
		ProjectSettings.set_initial_value(SETTING_ACTION_KEY, DEFAULT_ACTION_KEY)
		ProjectSettings.add_property_info({
			"name": SETTING_ACTION_KEY,
			"type": TYPE_INT,
			"hint": PROPERTY_HINT_NONE
		})
	
	if not ProjectSettings.has_setting(SETTING_SECONDARY_ACTION_KEY):
		ProjectSettings.set_setting(SETTING_SECONDARY_ACTION_KEY, DEFAULT_SECONDARY_ACTION_KEY)
		ProjectSettings.set_initial_value(SETTING_SECONDARY_ACTION_KEY, DEFAULT_SECONDARY_ACTION_KEY)
		ProjectSettings.add_property_info({
			"name": SETTING_SECONDARY_ACTION_KEY,
			"type": TYPE_INT,
			"hint": PROPERTY_HINT_NONE
		})
	
	if not ProjectSettings.has_setting(SETTING_AUTO_HIDE):
		ProjectSettings.set_setting(SETTING_AUTO_HIDE, DEFAULT_AUTO_HIDE)
		ProjectSettings.set_initial_value(SETTING_AUTO_HIDE, DEFAULT_AUTO_HIDE)
		ProjectSettings.add_property_info({
			"name": SETTING_AUTO_HIDE,
			"type": TYPE_BOOL
		})
		
	if not ProjectSettings.has_setting(SETTING_LANGUAGE_OVERRIDE):
		ProjectSettings.set_setting(SETTING_LANGUAGE_OVERRIDE, DEFAULT_LANGUAGE_OVERRIDE)
		ProjectSettings.set_initial_value(SETTING_LANGUAGE_OVERRIDE, DEFAULT_LANGUAGE_OVERRIDE)
		ProjectSettings.add_property_info({
			"name": SETTING_LANGUAGE_OVERRIDE,
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "en,zh_CN"
		})

func _get_setting(path: String, default_value: Variant) -> Variant:
	"""Get a setting from ProjectSettings."""
	return ProjectSettings.get_setting(path, default_value)

func _set_setting(path: String, value: Variant) -> void:
	"""Set a setting in ProjectSettings."""
	ProjectSettings.set_setting(path, value)

func save_config() -> void:
	"""Save settings to project.godot file."""
	var err = ProjectSettings.save()
	if err == OK:
		print("CsgBlockout: Saved Config to ProjectSettings")
		config_saved.emit()
	else:
		push_error("CsgBlockout: Failed to save config - error code %d" % err)
