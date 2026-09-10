@tool
class_name CSGRuler3D extends Node3D

const GLOBAL_METRICS_PREFIX: String = "addons/csg_blockout/player_metrics/"
const KEY_CHARACTER_HEIGHT: StringName = &"character_height"
const KEY_SINGLE_JUMP_HEIGHT: StringName = &"single_jump_height"
const KEY_SPRINT_JUMP_DISTANCE: StringName = &"sprint_jump_distance"
const MIN_METRIC: float = 0.01

var _target_point: Vector3 = Vector3(0.0, 0.0, -3.0)
@export var target_point: Vector3 = Vector3(0.0, 0.0, -3.0):
	get:
		return _target_point
	set(value):
		if value == _target_point:
			return
		_target_point = value
		_refresh()

@export_group("Player Metrics Override")

var _use_global_metrics: bool = true
@export var use_global_metrics: bool = true:
	get:
		return _use_global_metrics
	set(value):
		if value == _use_global_metrics:
			return
		_use_global_metrics = value
		_refresh()

var _character_height: float = 1.8
@export var character_height: float = 1.8:
	get:
		return _character_height
	set(value):
		var clamped: float = maxf(value, MIN_METRIC)
		if is_equal_approx(clamped, _character_height):
			return
		_character_height = clamped
		_refresh()

var _single_jump_height: float = 1.5
@export var single_jump_height: float = 1.5:
	get:
		return _single_jump_height
	set(value):
		var clamped: float = maxf(value, MIN_METRIC)
		if is_equal_approx(clamped, _single_jump_height):
			return
		_single_jump_height = clamped
		_refresh()

var _sprint_jump_distance: float = 4.0
@export var sprint_jump_distance: float = 4.0:
	get:
		return _sprint_jump_distance
	set(value):
		var clamped: float = maxf(value, MIN_METRIC)
		if is_equal_approx(clamped, _sprint_jump_distance):
			return
		_sprint_jump_distance = clamped
		_refresh()

var total_distance: float = 0.0
var horizontal_distance: float = 0.0
var vertical_delta: float = 0.0
var is_jump_reachable: bool = false
var reachability_status: String = ""

func _init() -> void:
	_update_diagnostics()

func _enter_tree() -> void:
	if not is_in_group(&"csg_rulers"):
		add_to_group(&"csg_rulers")

func _ready() -> void:
	if not Engine.is_editor_hint():
		queue_free()
		return
	if not is_in_group(&"csg_rulers"):
		add_to_group(&"csg_rulers")
	if not visibility_changed.is_connected(_on_visibility_changed):
		visibility_changed.connect(_on_visibility_changed)
	_connect_config_signals()
	_update_diagnostics()

func _exit_tree() -> void:
	if is_in_group(&"csg_rulers"):
		remove_from_group(&"csg_rulers")
	if visibility_changed.is_connected(_on_visibility_changed):
		visibility_changed.disconnect(_on_visibility_changed)
	_disconnect_config_signals()

func _on_visibility_changed() -> void:
	update_gizmos()

func _connect_config_signals() -> void:
	var cfg: CsgBlockoutConfig = CsgBlockoutConfig.get_config()
	if cfg != null and not cfg.player_metrics_changed.is_connected(_on_player_metrics_changed):
		cfg.player_metrics_changed.connect(_on_player_metrics_changed)

func _disconnect_config_signals() -> void:
	var cfg: CsgBlockoutConfig = CsgBlockoutConfig.get_config()
	if cfg != null and cfg.player_metrics_changed.is_connected(_on_player_metrics_changed):
		cfg.player_metrics_changed.disconnect(_on_player_metrics_changed)

func _on_player_metrics_changed() -> void:
	if _use_global_metrics:
		_refresh()

func _refresh() -> void:
	_update_diagnostics()
	update_gizmos()
	notify_property_list_changed()

func _update_diagnostics() -> void:
	var horizontal: Vector2 = Vector2(_target_point.x, _target_point.z)
	horizontal_distance = horizontal.length()
	vertical_delta = _target_point.y
	total_distance = _target_point.length()
	var jump_height: float = get_effective_single_jump_height()
	var sprint_distance: float = get_effective_sprint_jump_distance()
	is_jump_reachable = vertical_delta <= jump_height and horizontal_distance <= sprint_distance
	reachability_status = get_reachability_text()

func get_reachability_text() -> String:
	return CsgBlockoutI18n.t("REACHABLE" if is_jump_reachable else "UNREACHABLE")

func get_effective_character_height() -> float:
	if _use_global_metrics:
		var cfg: CsgBlockoutConfig = CsgBlockoutConfig.get_config()
		if cfg != null:
			return cfg.get_character_height(_character_height)
		return _get_global_metric(KEY_CHARACTER_HEIGHT, _character_height)
	return _character_height

func get_effective_single_jump_height() -> float:
	if _use_global_metrics:
		var cfg: CsgBlockoutConfig = CsgBlockoutConfig.get_config()
		if cfg != null:
			return cfg.get_single_jump_height(_single_jump_height)
		return _get_global_metric(KEY_SINGLE_JUMP_HEIGHT, _single_jump_height)
	return _single_jump_height

func get_effective_sprint_jump_distance() -> float:
	if _use_global_metrics:
		var cfg: CsgBlockoutConfig = CsgBlockoutConfig.get_config()
		if cfg != null:
			return cfg.get_sprint_jump_distance(_sprint_jump_distance)
		return _get_global_metric(KEY_SPRINT_JUMP_DISTANCE, _sprint_jump_distance)
	return _sprint_jump_distance

func _get_global_metric(key: StringName, fallback: float) -> float:
	var path: String = GLOBAL_METRICS_PREFIX + String(key)
	if not ProjectSettings.has_setting(path):
		var legacy_path: String = "csg_blockout/player_metrics/" + String(key)
		if ProjectSettings.has_setting(legacy_path):
			path = legacy_path
		else:
			return fallback
	var value: Variant = ProjectSettings.get_setting(path)
	if value is float or value is int:
		var f: float = float(value)
		if not is_nan(f) and not is_inf(f):
			return maxf(f, MIN_METRIC)
	return fallback

func _get_property_list() -> Array[Dictionary]:
	var props: Array[Dictionary] = [
		{
			"name": "total_distance",
			"type": TYPE_FLOAT,
			"hint": PROPERTY_HINT_NONE,
			"hint_string": "m",
			"usage": PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_READ_ONLY
		},
		{
			"name": "horizontal_distance",
			"type": TYPE_FLOAT,
			"hint": PROPERTY_HINT_NONE,
			"hint_string": "m",
			"usage": PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_READ_ONLY
		},
		{
			"name": "vertical_delta",
			"type": TYPE_FLOAT,
			"hint": PROPERTY_HINT_NONE,
			"hint_string": "m",
			"usage": PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_READ_ONLY
		},
		{
			"name": "is_jump_reachable",
			"type": TYPE_BOOL,
			"hint": PROPERTY_HINT_NONE,
			"hint_string": "",
			"usage": PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_READ_ONLY
		},
		{
			"name": "reachability_status",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_NONE,
			"hint_string": "",
			"usage": PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_READ_ONLY
		}
	]
	return props
