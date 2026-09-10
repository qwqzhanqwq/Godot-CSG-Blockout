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
const SETTING_ACTION_KEY: String = "addons/csg_blockout/action_key"
const SETTING_AUTO_HIDE: String = "addons/csg_blockout/auto_hide"
const SETTING_LANGUAGE_OVERRIDE: String = "addons/csg_blockout/language_override"
const SETTING_MATERIAL_PRESET: String = "addons/csg_blockout/material_preset"
const SETTING_DEFAULT_OPERATION: String = "addons/csg_blockout/default_operation"
const SETTING_CUSTOM_MATERIAL_PATH: String = "addons/csg_blockout/custom_material_path"
const SETTING_CHARACTER_HEIGHT: String = "addons/csg_blockout/player_metrics/character_height"
const SETTING_SINGLE_JUMP_HEIGHT: String = "addons/csg_blockout/player_metrics/single_jump_height"
const SETTING_SPRINT_JUMP_DISTANCE: String = "addons/csg_blockout/player_metrics/sprint_jump_distance"

# Default values
const DEFAULT_ACTION_KEY: Key = KEY_SHIFT
const DEFAULT_AUTO_HIDE: bool = true
const DEFAULT_LANGUAGE_OVERRIDE: String = "auto"
const DEFAULT_MATERIAL_PRESET: MaterialPreset = MaterialPreset.GRID_LIGHT
const DEFAULT_CHARACTER_HEIGHT: float = 1.8
const DEFAULT_SINGLE_JUMP_HEIGHT: float = 1.5
const DEFAULT_SPRINT_JUMP_DISTANCE: float = 4.0
const MIN_METRIC: float = 0.01

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
signal default_operation_changed(op: CSGShape3D.Operation)
signal player_metrics_changed()

# Configurable properties

## Key to hold for primary action (e.g., opening pie menu)
var action_key: Key = KEY_SHIFT:
	get: return _get_setting(SETTING_ACTION_KEY, DEFAULT_ACTION_KEY)
	set(value): _set_setting(SETTING_ACTION_KEY, value)

## Whether to auto-hide the CSG blockout UI when not in use
var auto_hide: bool = true:
	get: return _get_setting(SETTING_AUTO_HIDE, DEFAULT_AUTO_HIDE)
	set(value): _set_setting(SETTING_AUTO_HIDE, value)

## Language override (auto, en, zh_CN, ja, ko, es, pt, ru)
var language_override: String = "auto":
	get: return _get_setting(SETTING_LANGUAGE_OVERRIDE, DEFAULT_LANGUAGE_OVERRIDE)
	set(value): _set_setting(SETTING_LANGUAGE_OVERRIDE, value)

## Material Preset (None, Light Grid, Dark Grid, Orange Grid, Custom)
var material_preset: MaterialPreset = MaterialPreset.GRID_LIGHT:
	get: return _get_setting(SETTING_MATERIAL_PRESET, DEFAULT_MATERIAL_PRESET) as MaterialPreset
	set(value):
		_set_setting(SETTING_MATERIAL_PRESET, value)
		material_preset_changed.emit(value)

## Default CSG boolean operation applied to newly created nodes (shared by pie menu & sidebar)
var default_operation: CSGShape3D.Operation = CSGShape3D.OPERATION_UNION:
	get: return _get_setting(SETTING_DEFAULT_OPERATION, CSGShape3D.OPERATION_UNION) as CSGShape3D.Operation
	set(value):
		_set_setting(SETTING_DEFAULT_OPERATION, value)
		default_operation_changed.emit(value)

var custom_material: Material = null:
	get:
		if custom_material == null:
			var path: String = _get_setting(SETTING_CUSTOM_MATERIAL_PATH, "")
			if not path.is_empty() and ResourceLoader.exists(path):
				custom_material = ResourceLoader.load(path) as Material
		return custom_material
	set(value):
		custom_material = value
		_set_setting(SETTING_CUSTOM_MATERIAL_PATH, value.resource_path if value != null else "")
		custom_material_changed.emit(value)

## Player character standing height in meters
var character_height: float = DEFAULT_CHARACTER_HEIGHT:
	get: return get_character_height()
	set(value): set_character_height(value)

## Player single jump vertical reach in meters
var single_jump_height: float = DEFAULT_SINGLE_JUMP_HEIGHT:
	get: return get_single_jump_height()
	set(value): set_single_jump_height(value)

## Player sprint jump horizontal reach in meters
var sprint_jump_distance: float = DEFAULT_SPRINT_JUMP_DISTANCE:
	get: return get_sprint_jump_distance()
	set(value): set_sprint_jump_distance(value)

func _ensure_settings_exist() -> void:
	"""Register settings in ProjectSettings if they don't exist."""
	if not ProjectSettings.has_setting(SETTING_ACTION_KEY):
		ProjectSettings.set_setting(SETTING_ACTION_KEY, DEFAULT_ACTION_KEY)
		ProjectSettings.set_initial_value(SETTING_ACTION_KEY, DEFAULT_ACTION_KEY)
		ProjectSettings.add_property_info({
			"name": SETTING_ACTION_KEY,
			"type": TYPE_INT,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Shift:%d,Ctrl:%d,Alt:%d,Meta:%d" % [KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_META]
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
			"hint_string": "auto,en,zh_CN,ja,ko,es,pt,ru"
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

	if not ProjectSettings.has_setting(SETTING_DEFAULT_OPERATION):
		ProjectSettings.set_setting(SETTING_DEFAULT_OPERATION, CSGShape3D.OPERATION_UNION)
		ProjectSettings.set_initial_value(SETTING_DEFAULT_OPERATION, CSGShape3D.OPERATION_UNION)
		ProjectSettings.add_property_info({
			"name": SETTING_DEFAULT_OPERATION,
			"type": TYPE_INT,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Union:0,Intersection:1,Subtraction:2"
		})

	if not ProjectSettings.has_setting(SETTING_CHARACTER_HEIGHT):
		var default_ch: float = DEFAULT_CHARACTER_HEIGHT
		if ProjectSettings.has_setting("csg_blockout/player_metrics/character_height"):
			var legacy_val: Variant = ProjectSettings.get_setting("csg_blockout/player_metrics/character_height")
			if legacy_val is float or legacy_val is int:
				default_ch = float(legacy_val)
		ProjectSettings.set_setting(SETTING_CHARACTER_HEIGHT, default_ch)
	ProjectSettings.set_initial_value(SETTING_CHARACTER_HEIGHT, DEFAULT_CHARACTER_HEIGHT)
	ProjectSettings.set_as_basic(SETTING_CHARACTER_HEIGHT, true)
	ProjectSettings.add_property_info({
		"name": SETTING_CHARACTER_HEIGHT,
		"type": TYPE_FLOAT,
		"hint": PROPERTY_HINT_RANGE,
		"hint_string": "0.1,10.0,0.05,or_greater"
	})

	if not ProjectSettings.has_setting(SETTING_SINGLE_JUMP_HEIGHT):
		var default_jh: float = DEFAULT_SINGLE_JUMP_HEIGHT
		if ProjectSettings.has_setting("csg_blockout/player_metrics/single_jump_height"):
			var legacy_val: Variant = ProjectSettings.get_setting("csg_blockout/player_metrics/single_jump_height")
			if legacy_val is float or legacy_val is int:
				default_jh = float(legacy_val)
		ProjectSettings.set_setting(SETTING_SINGLE_JUMP_HEIGHT, default_jh)
	ProjectSettings.set_initial_value(SETTING_SINGLE_JUMP_HEIGHT, DEFAULT_SINGLE_JUMP_HEIGHT)
	ProjectSettings.set_as_basic(SETTING_SINGLE_JUMP_HEIGHT, true)
	ProjectSettings.add_property_info({
		"name": SETTING_SINGLE_JUMP_HEIGHT,
		"type": TYPE_FLOAT,
		"hint": PROPERTY_HINT_RANGE,
		"hint_string": "0.1,10.0,0.05,or_greater"
	})

	if not ProjectSettings.has_setting(SETTING_SPRINT_JUMP_DISTANCE):
		var default_jd: float = DEFAULT_SPRINT_JUMP_DISTANCE
		if ProjectSettings.has_setting("csg_blockout/player_metrics/sprint_jump_distance"):
			var legacy_val: Variant = ProjectSettings.get_setting("csg_blockout/player_metrics/sprint_jump_distance")
			if legacy_val is float or legacy_val is int:
				default_jd = float(legacy_val)
		ProjectSettings.set_setting(SETTING_SPRINT_JUMP_DISTANCE, default_jd)
	ProjectSettings.set_initial_value(SETTING_SPRINT_JUMP_DISTANCE, DEFAULT_SPRINT_JUMP_DISTANCE)
	ProjectSettings.set_as_basic(SETTING_SPRINT_JUMP_DISTANCE, true)
	ProjectSettings.add_property_info({
		"name": SETTING_SPRINT_JUMP_DISTANCE,
		"type": TYPE_FLOAT,
		"hint": PROPERTY_HINT_RANGE,
		"hint_string": "0.1,20.0,0.05,or_greater"
	})

	if not ProjectSettings.settings_changed.is_connected(_on_project_settings_changed):
		ProjectSettings.settings_changed.connect(_on_project_settings_changed)

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

func get_character_height(fallback: float = DEFAULT_CHARACTER_HEIGHT) -> float:
	var safe_fallback: float = fallback if (fallback > 0.0 and not is_nan(fallback) and not is_inf(fallback)) else DEFAULT_CHARACTER_HEIGHT
	var val: Variant = _get_setting(SETTING_CHARACTER_HEIGHT, null)
	if val == null:
		val = _get_setting("csg_blockout/player_metrics/character_height", safe_fallback)
	if val is float or val is int:
		var f: float = float(val)
		if not is_nan(f) and not is_inf(f):
			return maxf(f, MIN_METRIC)
	return safe_fallback

func set_character_height(value: float) -> void:
	var valid_value: float = value if (not is_nan(value) and not is_inf(value)) else DEFAULT_CHARACTER_HEIGHT
	var clamped: float = maxf(valid_value, MIN_METRIC)
	_set_setting(SETTING_CHARACTER_HEIGHT, clamped)
	player_metrics_changed.emit()

func get_single_jump_height(fallback: float = DEFAULT_SINGLE_JUMP_HEIGHT) -> float:
	var safe_fallback: float = fallback if (fallback > 0.0 and not is_nan(fallback) and not is_inf(fallback)) else DEFAULT_SINGLE_JUMP_HEIGHT
	var val: Variant = _get_setting(SETTING_SINGLE_JUMP_HEIGHT, null)
	if val == null:
		val = _get_setting("csg_blockout/player_metrics/single_jump_height", safe_fallback)
	if val is float or val is int:
		var f: float = float(val)
		if not is_nan(f) and not is_inf(f):
			return maxf(f, MIN_METRIC)
	return safe_fallback

func set_single_jump_height(value: float) -> void:
	var valid_value: float = value if (not is_nan(value) and not is_inf(value)) else DEFAULT_SINGLE_JUMP_HEIGHT
	var clamped: float = maxf(valid_value, MIN_METRIC)
	_set_setting(SETTING_SINGLE_JUMP_HEIGHT, clamped)
	player_metrics_changed.emit()

func get_sprint_jump_distance(fallback: float = DEFAULT_SPRINT_JUMP_DISTANCE) -> float:
	var safe_fallback: float = fallback if (fallback > 0.0 and not is_nan(fallback) and not is_inf(fallback)) else DEFAULT_SPRINT_JUMP_DISTANCE
	var val: Variant = _get_setting(SETTING_SPRINT_JUMP_DISTANCE, null)
	if val == null:
		val = _get_setting("csg_blockout/player_metrics/sprint_jump_distance", safe_fallback)
	if val is float or val is int:
		var f: float = float(val)
		if not is_nan(f) and not is_inf(f):
			return maxf(f, MIN_METRIC)
	return safe_fallback

func set_sprint_jump_distance(value: float) -> void:
	var valid_value: float = value if (not is_nan(value) and not is_inf(value)) else DEFAULT_SPRINT_JUMP_DISTANCE
	var clamped: float = maxf(valid_value, MIN_METRIC)
	_set_setting(SETTING_SPRINT_JUMP_DISTANCE, clamped)
	player_metrics_changed.emit()

func _on_project_settings_changed() -> void:
	player_metrics_changed.emit()

func _get_setting(path: String, default_value: Variant) -> Variant:
	"""Get a setting from ProjectSettings."""
	return ProjectSettings.get_setting(path, default_value)

func _set_setting(path: String, value: Variant) -> void:
	"""Set a setting in ProjectSettings."""
	ProjectSettings.set_setting(path, value)

func save_config() -> void:
	"""Save settings to project.godot file."""
	var err: Error = ProjectSettings.save()
	if err == OK:
		print("CsgBlockout: Saved Config to ProjectSettings")
		config_saved.emit()
	else:
		push_error("CsgBlockout: Failed to save config - error code %d" % err)

