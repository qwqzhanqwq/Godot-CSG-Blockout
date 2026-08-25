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
const SETTING_ACTION_KEY = "addons/csg_blockout/action_key"
const SETTING_AUTO_HIDE = "addons/csg_blockout/auto_hide"
const SETTING_LANGUAGE_OVERRIDE = "addons/csg_blockout/language_override"
const SETTING_MATERIAL_PRESET = "addons/csg_blockout/material_preset"

# Default values
const DEFAULT_ACTION_KEY = KEY_SHIFT
const DEFAULT_AUTO_HIDE = true
const DEFAULT_LANGUAGE_OVERRIDE = "zh_CN"
const DEFAULT_MATERIAL_PRESET = MaterialPreset.GRID_LIGHT

enum MaterialPreset {
	NONE = 0,
	GRID_LIGHT = 1,
	GRID_DARK = 2,
	GRID_ORANGE = 3,
	CUSTOM = 4
}

signal config_saved()
signal material_preset_changed(preset: MaterialPreset)
signal custom_material_changed(mat: Material)

# Configurable properties

## Key to hold for primary action (e.g., opening pie menu)
var action_key: Key = KEY_SHIFT:
	get: return _get_setting(SETTING_ACTION_KEY, DEFAULT_ACTION_KEY)
	set(value): _set_setting(SETTING_ACTION_KEY, value)

## Whether to auto-hide the CSG blockout UI when not in use
var auto_hide: bool = true:
	get: return _get_setting(SETTING_AUTO_HIDE, DEFAULT_AUTO_HIDE)
	set(value): _set_setting(SETTING_AUTO_HIDE, value)

## Language override (en, zh_CN)
var language_override: String = "zh_CN":
	get: return _get_setting(SETTING_LANGUAGE_OVERRIDE, DEFAULT_LANGUAGE_OVERRIDE)
	set(value): _set_setting(SETTING_LANGUAGE_OVERRIDE, value)

## Material Preset (None, Light Grid, Dark Grid, Orange Grid, Custom)
var material_preset: MaterialPreset = MaterialPreset.GRID_LIGHT:
	get: return _get_setting(SETTING_MATERIAL_PRESET, DEFAULT_MATERIAL_PRESET) as MaterialPreset
	set(value):
		_set_setting(SETTING_MATERIAL_PRESET, value)
		material_preset_changed.emit(value)

var custom_material: Material = null:
	set(value):
		custom_material = value
		custom_material_changed.emit(value)

func _ensure_settings_exist() -> void:
	"""Register settings in ProjectSettings if they don't exist."""
	if not ProjectSettings.has_setting(SETTING_ACTION_KEY):
		ProjectSettings.set_setting(SETTING_ACTION_KEY, DEFAULT_ACTION_KEY)
		ProjectSettings.set_initial_value(SETTING_ACTION_KEY, DEFAULT_ACTION_KEY)
		ProjectSettings.add_property_info({
			"name": SETTING_ACTION_KEY,
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

	if not ProjectSettings.has_setting(SETTING_MATERIAL_PRESET):
		ProjectSettings.set_setting(SETTING_MATERIAL_PRESET, DEFAULT_MATERIAL_PRESET)
		ProjectSettings.set_initial_value(SETTING_MATERIAL_PRESET, DEFAULT_MATERIAL_PRESET)
		ProjectSettings.add_property_info({
			"name": SETTING_MATERIAL_PRESET,
			"type": TYPE_INT,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "None,Light Grid,Dark Grid,Orange Grid,Custom"
		})

func get_preset_material(preset: MaterialPreset) -> Material:
	var file_name := ""
	match preset:
		MaterialPreset.GRID_LIGHT:
			file_name = "mat_grid_light.tres"
		MaterialPreset.GRID_DARK:
			file_name = "mat_grid_dark.tres"
		MaterialPreset.GRID_ORANGE:
			file_name = "mat_grid_orange.tres"
		_:
			return null
			
	var paths := [
		"res://addons/csg_blockout/res/materials/" + file_name,
		"res://res/materials/" + file_name
	]
	if not CsgBlockout.csg_plugin_path.is_empty():
		paths.push_front(CsgBlockout.csg_plugin_path.path_join("res/materials").path_join(file_name))
		
	for p in paths:
		if ResourceLoader.exists(p):
			return ResourceLoader.load(p) as Material
	return null

func get_active_material() -> Material:
	match material_preset:
		MaterialPreset.NONE:
			return null
		MaterialPreset.GRID_LIGHT, MaterialPreset.GRID_DARK, MaterialPreset.GRID_ORANGE:
			return get_preset_material(material_preset)
		MaterialPreset.CUSTOM:
			return custom_material
		_:
			return null

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

