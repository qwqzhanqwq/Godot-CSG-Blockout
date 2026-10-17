@tool
extends RefCounted
class_name CsgBlockoutConfig

static var _instance: CsgBlockoutConfig
## Install folder of the addon, set by the editor plugin. Kept here (not read from the
## plugin class) so this script also compiles in exported games.
static var plugin_path: String = ""

static func get_config() -> CsgBlockoutConfig:
	if _instance == null:
		_instance = CsgBlockoutConfig.new()
		_instance._ensure_settings_exist()
	return _instance
# ProjectSettings paths
const SETTING_ACTION_KEY: String = "addons/csg_blockout/action_key"
const SETTING_LANGUAGE_OVERRIDE: String = "addons/csg_blockout/language_override"
const SETTING_MATERIAL_PRESET: String = "addons/csg_blockout/material_preset"
const SETTING_CUSTOM_MATERIAL_PATH: String = "addons/csg_blockout/custom_material_path"
const SETTING_CHARACTER_HEIGHT: String = "addons/csg_blockout/player_metrics/character_height"
const SETTING_SINGLE_JUMP_HEIGHT: String = "addons/csg_blockout/player_metrics/single_jump_height"
const SETTING_SPRINT_JUMP_DISTANCE: String = "addons/csg_blockout/player_metrics/sprint_jump_distance"
const SETTING_ROOM_WALL_THICKNESS: String = "addons/csg_blockout/room/wall_thickness"
const SETTING_ROOM_FLOOR_THICKNESS: String = "addons/csg_blockout/room/floor_thickness"
const SETTING_ROOM_OPEN_TOP: String = "addons/csg_blockout/room/open_top"
const SETTING_ROOM_HEIGHT: String = "addons/csg_blockout/room/height"
const SETTING_DOOR_SIZE: String = "addons/csg_blockout/openings/door_size"
const SETTING_WINDOW_SIZE: String = "addons/csg_blockout/openings/window_size"
const SETTING_WINDOW_SILL: String = "addons/csg_blockout/openings/window_sill_height"
const SETTING_OPENING_FRAME: String = "addons/csg_blockout/openings/add_frame"
const SETTING_FRAME_WIDTH: String = "addons/csg_blockout/openings/frame_width"
const DEFAULT_DOOR_SIZE: Vector2 = Vector2(1.0, 2.1)
const DEFAULT_WINDOW_SIZE: Vector2 = Vector2(1.2, 1.2)
const DEFAULT_WINDOW_SILL: float = 0.9
const DEFAULT_OPENING_FRAME: bool = false
const DEFAULT_FRAME_WIDTH: float = 0.1
const SETTING_CAPSULE_RADIUS: String = "addons/csg_blockout/player_metrics/capsule_radius"
const SETTING_CROUCH_HEIGHT: String = "addons/csg_blockout/player_metrics/crouch_height"
const SETTING_MAX_SLOPE: String = "addons/csg_blockout/player_metrics/max_slope_angle"
const SETTING_WALK_SPEED: String = "addons/csg_blockout/player_metrics/walk_speed"
const SETTING_MAX_STEP_HEIGHT: String = "addons/csg_blockout/player_metrics/max_step_height"
const DEFAULT_CAPSULE_RADIUS: float = 0.35
const DEFAULT_CROUCH_HEIGHT: float = 1.0
const DEFAULT_MAX_SLOPE: float = 45.0
const DEFAULT_WALK_SPEED: float = 3.5
const DEFAULT_MAX_STEP_HEIGHT: float = 0.3
const SETTING_STRIP_SOURCE_ON_EXPORT: String = "addons/csg_blockout/bake/strip_source_on_export"
const DEFAULT_STRIP_SOURCE_ON_EXPORT: bool = true
const DEFAULT_ROOM_WALL_THICKNESS: float = 0.25
const DEFAULT_ROOM_FLOOR_THICKNESS: float = 0.25
const DEFAULT_ROOM_OPEN_TOP: bool = true
const DEFAULT_ROOM_HEIGHT: float = 3.0

# Default values
const DEFAULT_ACTION_KEY: Key = KEY_SHIFT
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
signal player_metrics_changed()

# Configurable properties

## Key to hold for primary action (e.g., opening pie menu)
var action_key: Key = KEY_SHIFT:
	get: return _get_setting(SETTING_ACTION_KEY, DEFAULT_ACTION_KEY)
	set(value): _set_setting(SETTING_ACTION_KEY, value)

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

	# Retired settings: the palette no longer hides, and new shapes no longer take a
	# hidden "current operation" (operations are changed on the selection instead).
	for retired: String in ["addons/csg_blockout/auto_hide", "addons/csg_blockout/default_operation"]:
		if ProjectSettings.has_setting(retired):
			ProjectSettings.clear(retired)

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

	_register(SETTING_ROOM_WALL_THICKNESS, DEFAULT_ROOM_WALL_THICKNESS, TYPE_FLOAT, PROPERTY_HINT_RANGE, "0.01,5.0,0.01,or_greater")
	_register(SETTING_ROOM_FLOOR_THICKNESS, DEFAULT_ROOM_FLOOR_THICKNESS, TYPE_FLOAT, PROPERTY_HINT_RANGE, "0.01,5.0,0.01,or_greater")
	_register(SETTING_ROOM_OPEN_TOP, DEFAULT_ROOM_OPEN_TOP, TYPE_BOOL)
	_register(SETTING_ROOM_HEIGHT, DEFAULT_ROOM_HEIGHT, TYPE_FLOAT, PROPERTY_HINT_RANGE, "0.1,20.0,0.05,or_greater")
	_register(SETTING_DOOR_SIZE, DEFAULT_DOOR_SIZE, TYPE_VECTOR2)
	_register(SETTING_WINDOW_SIZE, DEFAULT_WINDOW_SIZE, TYPE_VECTOR2)
	_register(SETTING_WINDOW_SILL, DEFAULT_WINDOW_SILL, TYPE_FLOAT, PROPERTY_HINT_RANGE, "0.0,5.0,0.05,or_greater")
	_register(SETTING_OPENING_FRAME, DEFAULT_OPENING_FRAME, TYPE_BOOL)
	_register(SETTING_FRAME_WIDTH, DEFAULT_FRAME_WIDTH, TYPE_FLOAT, PROPERTY_HINT_RANGE, "0.01,1.0,0.01,or_greater")
	_register(SETTING_STRIP_SOURCE_ON_EXPORT, DEFAULT_STRIP_SOURCE_ON_EXPORT, TYPE_BOOL)
	_register(SETTING_CAPSULE_RADIUS, DEFAULT_CAPSULE_RADIUS, TYPE_FLOAT, PROPERTY_HINT_RANGE, "0.05,2.0,0.01,or_greater")
	_register(SETTING_CROUCH_HEIGHT, DEFAULT_CROUCH_HEIGHT, TYPE_FLOAT, PROPERTY_HINT_RANGE, "0.1,5.0,0.05,or_greater")
	_register(SETTING_MAX_SLOPE, DEFAULT_MAX_SLOPE, TYPE_FLOAT, PROPERTY_HINT_RANGE, "1.0,89.0,0.5")
	_register(SETTING_WALK_SPEED, DEFAULT_WALK_SPEED, TYPE_FLOAT, PROPERTY_HINT_RANGE, "0.1,50.0,0.1,or_greater")
	_register(SETTING_MAX_STEP_HEIGHT, DEFAULT_MAX_STEP_HEIGHT, TYPE_FLOAT, PROPERTY_HINT_RANGE, "0.01,2.0,0.01,or_greater")
	for path: String in [SETTING_CAPSULE_RADIUS, SETTING_CROUCH_HEIGHT, SETTING_MAX_SLOPE, SETTING_WALK_SPEED, SETTING_MAX_STEP_HEIGHT]:
		ProjectSettings.set_as_basic(path, true)

	if not ProjectSettings.settings_changed.is_connected(_on_project_settings_changed):
		ProjectSettings.settings_changed.connect(_on_project_settings_changed)

## Registers a project setting with its default and editor hint (no-op if present).
func _register(path: String, default_value: Variant, type: int, hint: int = PROPERTY_HINT_NONE, hint_string: String = "") -> void:
	if not ProjectSettings.has_setting(path):
		ProjectSettings.set_setting(path, default_value)
	ProjectSettings.set_initial_value(path, default_value)
	ProjectSettings.add_property_info({"name": path, "type": type, "hint": hint, "hint_string": hint_string})

## Positive float setting with NaN/Inf protection.
func get_positive_float(path: String, default_value: float) -> float:
	var v: Variant = _get_setting(path, default_value)
	if v is float or v is int:
		var f: float = float(v)
		if not is_nan(f) and not is_inf(f) and f > 0.0:
			return f
	return default_value

func get_room_wall_thickness() -> float:
	return get_positive_float(SETTING_ROOM_WALL_THICKNESS, DEFAULT_ROOM_WALL_THICKNESS)

func get_room_floor_thickness() -> float:
	return get_positive_float(SETTING_ROOM_FLOOR_THICKNESS, DEFAULT_ROOM_FLOOR_THICKNESS)

func get_room_open_top() -> bool:
	return bool(_get_setting(SETTING_ROOM_OPEN_TOP, DEFAULT_ROOM_OPEN_TOP))

## Height of rooms drawn with the Room tool (adjust afterwards with the face arrows).
func get_room_height() -> float:
	return get_positive_float(SETTING_ROOM_HEIGHT, DEFAULT_ROOM_HEIGHT)

func _get_size(path: String, default_value: Vector2) -> Vector2:
	var v: Variant = _get_setting(path, default_value)
	if v is Vector2 and (v as Vector2).x > 0.0 and (v as Vector2).y > 0.0:
		return v
	return default_value

func get_door_size() -> Vector2:
	return _get_size(SETTING_DOOR_SIZE, DEFAULT_DOOR_SIZE)

func get_window_size() -> Vector2:
	return _get_size(SETTING_WINDOW_SIZE, DEFAULT_WINDOW_SIZE)

func get_window_sill_height() -> float:
	var v: Variant = _get_setting(SETTING_WINDOW_SILL, DEFAULT_WINDOW_SILL)
	return maxf(float(v), 0.0) if (v is float or v is int) else DEFAULT_WINDOW_SILL

func get_opening_frame() -> bool:
	return bool(_get_setting(SETTING_OPENING_FRAME, DEFAULT_OPENING_FRAME))

func set_opening_frame(value: bool) -> void:
	_set_setting(SETTING_OPENING_FRAME, value)

func get_capsule_radius() -> float:
	return get_positive_float(SETTING_CAPSULE_RADIUS, DEFAULT_CAPSULE_RADIUS)

func get_crouch_height() -> float:
	return get_positive_float(SETTING_CROUCH_HEIGHT, DEFAULT_CROUCH_HEIGHT)

func get_max_slope_angle() -> float:
	return clampf(get_positive_float(SETTING_MAX_SLOPE, DEFAULT_MAX_SLOPE), 1.0, 89.0)

func get_walk_speed() -> float:
	return get_positive_float(SETTING_WALK_SPEED, DEFAULT_WALK_SPEED)

## Highest step the test character walks up without jumping.
func get_max_step_height() -> float:
	return get_positive_float(SETTING_MAX_STEP_HEIGHT, DEFAULT_MAX_STEP_HEIGHT)

## Every player metric in one dictionary (shared by rulers, the player reference,
## the validator and the Play From Here pawn).
func get_player_metrics() -> Dictionary:
	return {
		"character_height": get_character_height(),
		"capsule_radius": get_capsule_radius(),
		"crouch_height": get_crouch_height(),
		"single_jump_height": get_single_jump_height(),
		"sprint_jump_distance": get_sprint_jump_distance(),
		"max_slope_angle": get_max_slope_angle(),
		"walk_speed": get_walk_speed(),
		"max_step_height": get_max_step_height(),
	}

func get_strip_source_on_export() -> bool:
	return bool(_get_setting(SETTING_STRIP_SOURCE_ON_EXPORT, DEFAULT_STRIP_SOURCE_ON_EXPORT))

func get_frame_width() -> float:
	return get_positive_float(SETTING_FRAME_WIDTH, DEFAULT_FRAME_WIDTH)

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
	if not plugin_path.is_empty():
		paths.push_front(plugin_path.path_join("res/materials").path_join(file_name))
		
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

