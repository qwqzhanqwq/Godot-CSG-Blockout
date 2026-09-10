@tool
class_name CSGStairs3D extends CSGPolygon3D

const REGEN_THROTTLE_MS: int = 50
const MAX_STEP_COUNT: int = 100
const MIN_DIMENSION: float = 0.01
const ERGO_STEP_HEIGHT_MIN: float = 0.15
const ERGO_STEP_HEIGHT_MAX: float = 0.20
const ERGO_STEP_DEPTH_MIN: float = 0.25
const ERGO_STEP_DEPTH_MAX: float = 0.30
const ERGO_STEP_HEIGHT_TARGET: float = 0.175
const ERGO_STEP_DEPTH_TARGET: float = 0.275

var _dirty: bool = false
var _last_regen_ms: int = 0
var _regen_in_progress: bool = false

@export_group("Stairs Options")

var _step_count: int = 8
@export_range(1, MAX_STEP_COUNT) var step_count: int = 8:
	get:
		return _step_count
	set(value):
		var clamped: int = clampi(value, 1, MAX_STEP_COUNT)
		if clamped != value:
			push_warning("CSGStairs3D: step_count %d clamped to %d." % [value, clamped])
		if clamped == _step_count:
			return
		_step_count = clamped
		_mark_dirty()

var _total_height: float = 2.0
@export var total_height: float = 2.0:
	get:
		return _total_height
	set(value):
		var clamped: float = maxf(value, MIN_DIMENSION)
		if clamped != value:
			push_warning("CSGStairs3D: total_height must be > 0.0; clamped to %.3f." % clamped)
		if is_equal_approx(clamped, _total_height):
			return
		_total_height = clamped
		_mark_dirty()

var _total_depth: float = 3.0
@export var total_depth: float = 3.0:
	get:
		return _total_depth
	set(value):
		var clamped: float = maxf(value, MIN_DIMENSION)
		if clamped != value:
			push_warning("CSGStairs3D: total_depth must be > 0.0; clamped to %.3f." % clamped)
		if is_equal_approx(clamped, _total_depth):
			return
		_total_depth = clamped
		_mark_dirty()

var _width: float = 1.5
@export var width: float = 1.5:
	get:
		return _width
	set(value):
		var clamped: float = maxf(value, MIN_DIMENSION)
		if clamped != value:
			push_warning("CSGStairs3D: width must be > 0.0; clamped to %.3f." % clamped)
		if is_equal_approx(clamped, _width):
			return
		_width = clamped
		_mark_dirty()

var _is_ramp: bool = false
@export var is_ramp: bool = false:
	get:
		return _is_ramp
	set(value):
		if value == _is_ramp:
			return
		_is_ramp = value
		_mark_dirty()

@export_group("Diagnostics")

var _enable_ergonomic_warning: bool = true
@export var enable_ergonomic_warning: bool = true:
	get:
		return _enable_ergonomic_warning
	set(value):
		if value == _enable_ergonomic_warning:
			return
		_enable_ergonomic_warning = value
		update_configuration_warnings()

var step_height: float = 0.0
var step_depth: float = 0.0
var ergonomic_status: String = ""

func _ready() -> void:
	_mark_dirty()

func _process(_delta: float) -> void:
	if not Engine.is_editor_hint():
		return
	if not _dirty or _regen_in_progress:
		return
	var now: int = Time.get_ticks_msec()
	if now - _last_regen_ms < REGEN_THROTTLE_MS:
		return
	_last_regen_ms = now
	_dirty = false
	_rebuild_geometry()

func _mark_dirty() -> void:
	_dirty = true

func _rebuild_geometry() -> void:
	if _regen_in_progress:
		return
	_regen_in_progress = true
	mode = MODE_DEPTH
	depth = _width
	polygon = _build_profile()
	step_height = _total_height / float(maxi(1, _step_count))
	step_depth = _total_depth / float(maxi(1, _step_count))
	ergonomic_status = _build_ergonomic_status()
	update_configuration_warnings()
	_regen_in_progress = false

func _build_profile() -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	if _is_ramp:
		points.append(Vector2(0.0, 0.0))
		points.append(Vector2(_total_depth, _total_height))
		points.append(Vector2(_total_depth, 0.0))
		return points
	var count: int = maxi(1, _step_count)
	var rise: float = _total_height / float(count)
	var run: float = _total_depth / float(count)
	points.append(Vector2(0.0, 0.0))
	for i: int in range(count):
		points.append(Vector2(run * float(i), rise * float(i + 1)))
		points.append(Vector2(run * float(i + 1), rise * float(i + 1)))
	points.append(Vector2(_total_depth, 0.0))
	return points

func _build_ergonomic_status() -> String:
	if _is_ramp:
		return "Ramp mode (ergonomic check N/A)"
	var height_ok: bool = step_height >= ERGO_STEP_HEIGHT_MIN and step_height <= ERGO_STEP_HEIGHT_MAX
	var depth_ok: bool = step_depth >= ERGO_STEP_DEPTH_MIN and step_depth <= ERGO_STEP_DEPTH_MAX
	if height_ok and depth_ok:
		return "OK"
	if not height_ok and not depth_ok:
		return "Step height and tread depth out of ergonomic range"
	if not height_ok:
		return "Step height out of range (0.15-0.20 m)"
	return "Tread depth out of range (0.25-0.30 m)"

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = PackedStringArray()
	if not _enable_ergonomic_warning or _is_ramp:
		return warnings
	var current_step_height: float = _total_height / float(maxi(1, _step_count))
	var current_step_depth: float = _total_depth / float(maxi(1, _step_count))
	if current_step_height < ERGO_STEP_HEIGHT_MIN or current_step_height > ERGO_STEP_HEIGHT_MAX:
		var suggested_by_height: int = maxi(1, roundi(_total_height / ERGO_STEP_HEIGHT_TARGET))
		warnings.append(
			"Step height %.2f m is outside the ergonomic range 0.15-0.20 m. For total_height %.2f m, try step_count = %d."
			% [current_step_height, _total_height, suggested_by_height]
		)
	if current_step_depth < ERGO_STEP_DEPTH_MIN or current_step_depth > ERGO_STEP_DEPTH_MAX:
		var suggested_by_depth: int = maxi(1, roundi(_total_depth / ERGO_STEP_DEPTH_TARGET))
		warnings.append(
			"Tread depth %.2f m is outside the ergonomic range 0.25-0.30 m. For total_depth %.2f m, try step_count = %d."
			% [current_step_depth, _total_depth, suggested_by_depth]
		)
	return warnings

func _validate_property(property: Dictionary) -> void:
	var prop_name: StringName = property["name"]
	if prop_name == &"polygon" or prop_name == &"mode" or prop_name == &"depth" or prop_name == &"smooth_faces":
		property["usage"] = PROPERTY_USAGE_STORAGE
		return
	if prop_name.begins_with(&"spin") or prop_name.begins_with(&"path"):
		property["usage"] = PROPERTY_USAGE_NONE

func _get_property_list() -> Array[Dictionary]:
	var props: Array[Dictionary] = [
		{
			"name": "step_height",
			"type": TYPE_FLOAT,
			"hint": PROPERTY_HINT_NONE,
			"hint_string": "m",
			"usage": PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_READ_ONLY
		},
		{
			"name": "step_depth",
			"type": TYPE_FLOAT,
			"hint": PROPERTY_HINT_NONE,
			"hint_string": "m",
			"usage": PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_READ_ONLY
		},
		{
			"name": "ergonomic_status",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_NONE,
			"hint_string": "",
			"usage": PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_READ_ONLY
		}
	]
	return props
