@tool
class_name CSGSpiralStairs3D extends CSGMesh3D
## Stairs winding around a vertical axis through the origin. The first step starts
## on the +X axis and the stairs climb `height` while turning `angle` degrees,
## counterclockwise seen from above unless `clockwise` is on. More than 360 degrees
## makes a tower stair; the steps are then floating slabs so the turns don't touch.
## Underneath it is a plain CSGMesh3D whose mesh is saved with the scene, so it keeps
## its shape when the plugin is disabled or removed.
##
## The `blockout_*` methods are the shape protocol the plugin's tools use; see
## ARCHITECTURE.md.

const MIN_SIZE: float = 0.01
const MIN_INNER_RADIUS: float = 0.05
const MAX_STEP_COUNT: int = 200
## Steps wider than this are split into flat segments along the curve.
const MAX_SEGMENT_DEGREES: float = 10.0
## Every turn needs at least this many steps, or the slabs of one turn would reach
## the next.
const MIN_STEPS_PER_TURN: int = 3
const FACE_OUTER: int = 6
const FACE_INNER: int = 7
const FACE_END: int = 8

@export_group("Spiral Stairs Options")

var _height: float = 3.0
@export var height: float = 3.0:
	get:
		return _height
	set(value):
		var clamped: float = maxf(value, MIN_SIZE)
		if is_equal_approx(clamped, _height):
			return
		_height = clamped
		_rebuild()

var _outer_radius: float = 1.5
@export var outer_radius: float = 1.5:
	get:
		return _outer_radius
	set(value):
		var clamped: float = maxf(value, MIN_INNER_RADIUS + MIN_SIZE)
		if is_equal_approx(clamped, _outer_radius):
			return
		_outer_radius = clamped
		_rebuild()

var _inner_radius: float = 0.25
## Radius of the open well in the middle (put a cylinder there for a center post).
@export var inner_radius: float = 0.25:
	get:
		return _inner_radius
	set(value):
		var clamped: float = maxf(value, MIN_INNER_RADIUS)
		if is_equal_approx(clamped, _inner_radius):
			return
		_inner_radius = clamped
		_rebuild()

var _angle: float = 360.0
## How far the stairs turn from bottom to top, in degrees.
@export_range(30.0, 1440.0, 0.1, "degrees") var angle: float = 360.0:
	get:
		return _angle
	set(value):
		var clamped: float = clampf(value, 30.0, 1440.0)
		if is_equal_approx(clamped, _angle):
			return
		_angle = clamped
		_rebuild()

var _step_count: int = 16
@export_range(2, MAX_STEP_COUNT) var step_count: int = 16:
	get:
		return _step_count
	set(value):
		var clamped: int = clampi(value, 2, MAX_STEP_COUNT)
		if clamped == _step_count:
			return
		_step_count = clamped
		_rebuild()

var _step_thickness: float = 0.25
## Thickness of each floating step. Kept thicker than one step's rise (so the steps
## join) and, for more than one turn, thin enough to leave the turn above free.
@export var step_thickness: float = 0.25:
	get:
		return _step_thickness
	set(value):
		var clamped: float = maxf(value, MIN_SIZE)
		if is_equal_approx(clamped, _step_thickness):
			return
		_step_thickness = clamped
		_rebuild()

var _fill_to_floor: bool = false
## Solid steps down to the floor instead of floating ones (up to one turn).
@export var fill_to_floor: bool = false:
	get:
		return _fill_to_floor
	set(value):
		if value == _fill_to_floor:
			return
		_fill_to_floor = value
		_rebuild()

var _clockwise: bool = false
## Climb clockwise seen from above.
@export var clockwise: bool = false:
	get:
		return _clockwise
	set(value):
		if value == _clockwise:
			return
		_clockwise = value
		_rebuild()

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

## Built layout, see _layout().
var _l: Dictionary = {}

func _init() -> void:
	_rebuild()

# --- layout ---------------------------------------------------------------------

## {"n": steps, "m": segments per step, "sweep": radians, "rise", "thickness",
##  "fill", "connected" (a filled full turn closes on itself), "tops", "bots"}
func _layout() -> Dictionary:
	var n: int = maxi(_step_count, ceili(_angle / 360.0 * float(MIN_STEPS_PER_TURN)))
	var sweep: float = deg_to_rad(_angle)
	var rise: float = _height / float(n)
	var fill: bool = _fill_to_floor and _angle <= 360.0 + 0.001
	var thickness: float = _step_thickness
	if _angle >= 360.0 - 0.001 and not fill:
		# Height gained per full turn, minus one step: what the turn above leaves.
		var turn_rise: float = rise * TAU / (sweep / float(n))
		thickness = minf(thickness, turn_rise - rise - 0.01)
	thickness = maxf(thickness, rise + 0.01)
	var tops: PackedFloat64Array = PackedFloat64Array()
	var bots: PackedFloat64Array = PackedFloat64Array()
	for i: int in n:
		var top: float = rise * float(i + 1)
		tops.append(top)
		# Floating steps near the bottom stop at the floor.
		bots.append(0.0 if fill else maxf(top - thickness, 0.0))
	return {
		"n": n,
		"m": maxi(1, ceili(rad_to_deg(sweep / float(n)) / MAX_SEGMENT_DEGREES)),
		"sweep": sweep,
		"rise": rise,
		"thickness": thickness,
		"fill": fill,
		"connected": fill and is_equal_approx(_angle, 360.0),
		"tops": tops,
		"bots": bots,
	}

## Angle of step boundary `k` (0..n), radians. A closed full turn ends where it starts.
func _boundary(k: int) -> float:
	if k == int(_l["n"]) and bool(_l["connected"]):
		return 0.0
	return float(_l["sweep"]) * float(k) / float(_l["n"])

## Angle of segment `j` (0..m) inside step `i`.
func _sub_angle(i: int, j: int) -> float:
	var m: int = _l["m"]
	if j == 0:
		return _boundary(i)
	if j == m:
		return _boundary(i + 1)
	return float(_l["sweep"]) * (float(i) + float(j) / float(m)) / float(_l["n"])

## Local point at `theta` (radians along the climb), distance `r` from the axis.
func _at(theta: float, r: float, y: float) -> Vector3:
	var z: float = r * sin(theta)
	return Vector3(r * cos(theta), y, z if _clockwise else -z)

func _radial(theta: float) -> Vector3:
	return _at(theta, 1.0, 0.0)

## Direction the climb turns toward at `theta`.
func _tangent(theta: float) -> Vector3:
	var z: float = cos(theta)
	return Vector3(-sin(theta), 0.0, z if _clockwise else -z)

func _interval(i: int) -> Vector2:
	return Vector2((_l["bots"] as PackedFloat64Array)[i], (_l["tops"] as PackedFloat64Array)[i])

## Steps meeting at boundary `k`: [previous or -1, next or -1].
func _neighbors(k: int) -> PackedInt32Array:
	var n: int = _l["n"]
	var connected: bool = _l["connected"]
	var prev: int = k - 1 if k > 0 else (n - 1 if connected else -1)
	var next: int = k if k < n else (0 if connected else -1)
	return PackedInt32Array([prev, next])

## Heights where faces meet on the vertical lines at boundary `k`.
func _splits(k: int) -> PackedFloat64Array:
	var ys: Array[float] = []
	for s: int in _neighbors(k):
		if s >= 0:
			var iv: Vector2 = _interval(s)
			for y: float in [iv.x, iv.y]:
				if not ys.has(y):
					ys.append(y)
	ys.sort()
	return PackedFloat64Array(ys)

# --- mesh -----------------------------------------------------------------------

var _verts: PackedVector3Array
var _indices: PackedInt32Array
var _lookup: Dictionary

func _rebuild() -> void:
	_l = _layout()
	_verts = PackedVector3Array()
	_indices = PackedInt32Array()
	_lookup = {}
	var n: int = _l["n"]
	var m: int = _l["m"]
	var ri: float = _inner_radius
	var ro: float = maxf(_outer_radius, ri + MIN_SIZE)
	for i: int in n:
		var iv: Vector2 = _interval(i)
		for j: int in m:
			var a: float = _sub_angle(i, j)
			var b: float = _sub_angle(i, j + 1)
			_quad(_at(a, ri, iv.y), _at(a, ro, iv.y), _at(b, ro, iv.y), _at(b, ri, iv.y), Vector3.UP)
			_quad(_at(a, ri, iv.x), _at(a, ro, iv.x), _at(b, ro, iv.x), _at(b, ri, iv.x), Vector3.DOWN)
			var left: PackedFloat64Array = _clip(_splits(i), iv) if j == 0 else PackedFloat64Array([iv.x, iv.y])
			var right: PackedFloat64Array = _clip(_splits(i + 1), iv) if j == m - 1 else PackedFloat64Array([iv.x, iv.y])
			# From the unwrapped angle: a closed turn's last segment ends at 0, not TAU.
			var mid: Vector3 = _radial(float(_l["sweep"]) * (float(i) + (float(j) + 0.5) / float(m)) / float(n))
			_zip(a, b, ro, left, right, mid)
			_zip(a, b, ri, left, right, -mid)
	# Risers, undersides and the two ends: the parts of each boundary plane that only
	# one of its two steps covers.
	var last: int = n - 1 if bool(_l["connected"]) else n
	for k: int in last + 1:
		var theta: float = _boundary(k)
		var pair: PackedInt32Array = _neighbors(k)
		var prev: Vector2 = _interval(pair[0]) if pair[0] >= 0 else Vector2(INF, -INF)
		var next: Vector2 = _interval(pair[1]) if pair[1] >= 0 else Vector2(INF, -INF)
		for part: Vector2 in _minus(prev, next):
			_quad(_at(theta, ri, part.x), _at(theta, ro, part.x), _at(theta, ro, part.y), _at(theta, ri, part.y), _tangent(theta))
		for part: Vector2 in _minus(next, prev):
			_quad(_at(theta, ri, part.x), _at(theta, ro, part.x), _at(theta, ro, part.y), _at(theta, ri, part.y), -_tangent(theta))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _verts
	arrays[Mesh.ARRAY_INDEX] = _indices
	# A new mesh every time: duplicated stairs share the old one until they change.
	var built: ArrayMesh = ArrayMesh.new()
	built.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh = built
	_verts = PackedVector3Array()
	_indices = PackedInt32Array()
	_lookup = {}
	update_configuration_warnings()

static func _clip(ys: PackedFloat64Array, iv: Vector2) -> PackedFloat64Array:
	var out: PackedFloat64Array = PackedFloat64Array()
	for y: float in ys:
		if y >= iv.x and y <= iv.y:
			out.append(y)
	return out

## Parts of interval `a` not covered by `b` (empty intervals are x > y).
static func _minus(a: Vector2, b: Vector2) -> Array[Vector2]:
	var out: Array[Vector2] = []
	if a.x >= a.y:
		return out
	if b.x >= b.y or b.y <= a.x or b.x >= a.y:
		out.append(a)
		return out
	if b.x > a.x:
		out.append(Vector2(a.x, b.x))
	if b.y < a.y:
		out.append(Vector2(b.y, a.y))
	return out

func _index(p: Vector3) -> int:
	var found: Variant = _lookup.get(p)
	if found != null:
		return found
	_lookup[p] = _verts.size()
	_verts.append(p)
	return _verts.size() - 1

## Triangle facing `outward` (Godot's front faces are clockwise seen from outside).
func _tri(a: Vector3, b: Vector3, c: Vector3, outward: Vector3) -> void:
	if (b - a).cross(c - a).dot(outward) > 0.0:
		var tmp: Vector3 = b
		b = c
		c = tmp
	_indices.append_array([_index(a), _index(b), _index(c)])

func _quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, outward: Vector3) -> void:
	_tri(a, b, c, outward)
	_tri(a, c, d, outward)

## Wall strip between two vertical lines (at angles `a` and `b`, radius `r`) whose
## edges are split at the heights in `left` and `right` (both from bottom to top).
func _zip(a: float, b: float, r: float, left: PackedFloat64Array, right: PackedFloat64Array, outward: Vector3) -> void:
	var i: int = 0
	var j: int = 0
	while i < left.size() - 1 or j < right.size() - 1:
		var step_left: bool = j >= right.size() - 1 or (i < left.size() - 1 and left[i + 1] <= right[j + 1])
		if step_left:
			_tri(_at(a, r, left[i]), _at(b, r, right[j]), _at(a, r, left[i + 1]), outward)
			i += 1
		else:
			_tri(_at(a, r, left[i]), _at(b, r, right[j]), _at(b, r, right[j + 1]), outward)
			j += 1

# --- diagnostics ----------------------------------------------------------------

## Rise of one step, in meters.
func step_height() -> float:
	return float(_l["rise"])

## Clear height between a step and the underside of the turn above it, or INF when
## the stairs don't pass over themselves.
func headroom() -> float:
	if _angle <= 360.0 or bool(_l["fill"]):
		return INF
	return float(_l["rise"]) * TAU / (float(_l["sweep"]) / float(_l["n"])) - float(_l["thickness"])

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = PackedStringArray()
	if _l.is_empty():
		return warnings
	if _fill_to_floor and not bool(_l["fill"]):
		warnings.append("Fill to floor works up to one turn (360 degrees); these stairs are built with floating steps.")
	if not _enable_ergonomic_warning:
		return warnings
	var rise: float = step_height()
	if rise < CSGStairs3D.ERGO_STEP_HEIGHT_MIN or rise > CSGStairs3D.ERGO_STEP_HEIGHT_MAX:
		warnings.append("Step height %.2f m is outside the ergonomic range 0.15-0.20 m. For height %.2f m, try step_count = %d."
			% [rise, _height, maxi(2, roundi(_height / CSGStairs3D.ERGO_STEP_HEIGHT_TARGET))])
	var max_step: float = CSGStairs3D.max_step_height()
	if rise > max_step + 0.0001:
		warnings.append("Each step is %.2f m high, more than the test character walks up (max_step_height %.2f m): in Play From Here it has to jump them." % [rise, max_step])
	var character: float = float(ProjectSettings.get_setting(CsgBlockoutConfig.SETTING_CHARACTER_HEIGHT, CsgBlockoutConfig.DEFAULT_CHARACTER_HEIGHT))
	var clear: float = headroom()
	if clear < character:
		warnings.append("Headroom under the turn above is %.2f m, lower than the character height (%.2f m). Add height or turn less per meter." % [clear, character])
	return warnings

func _get_property_list() -> Array[Dictionary]:
	return [
		{"name": "step_height_m", "type": TYPE_FLOAT, "hint": PROPERTY_HINT_NONE, "hint_string": "m", "usage": PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_READ_ONLY},
		{"name": "headroom_m", "type": TYPE_FLOAT, "hint": PROPERTY_HINT_NONE, "hint_string": "m", "usage": PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_READ_ONLY},
	]

func _get(property: StringName) -> Variant:
	if property == &"step_height_m":
		return step_height()
	if property == &"headroom_m":
		var clear: float = headroom()
		return clear if is_finite(clear) else 0.0
	return null

func _validate_property(property: Dictionary) -> void:
	if property["name"] == &"mesh":
		property["usage"] = PROPERTY_USAGE_STORAGE

# --- shape protocol -------------------------------------------------------------

func blockout_aabb() -> AABB:
	return mesh.get_aabb() if mesh != null else AABB()

func blockout_faces() -> Array[Dictionary]:
	var n: int = _l["n"]
	var mid_step: int = n >> 1
	var r_mid: float = (_inner_radius + _outer_radius) * 0.5
	var top_theta: float = (_sub_angle(n - 1, 0) + float(_l["sweep"])) * 0.5
	var wall_theta: float = float(_l["sweep"]) * (float(mid_step) + 0.5) / float(n)
	var wall: Vector2 = _interval(mid_step)
	var last: Vector2 = _interval(n - 1)
	return [
		{"id": 3, "normal": Vector3.UP, "center": _at(top_theta, r_mid, _height)},
		{"id": FACE_OUTER, "normal": _radial(wall_theta), "center": _at(wall_theta, _outer_radius, (wall.x + wall.y) * 0.5)},
		{"id": FACE_INNER, "normal": -_radial(wall_theta), "center": _at(wall_theta, _inner_radius, (wall.x + wall.y) * 0.5)},
		{"id": FACE_END, "normal": _tangent(float(_l["sweep"])), "center": _at(float(_l["sweep"]), r_mid, (last.x + last.y) * 0.5)},
	]

func blockout_resize_props() -> Array[StringName]:
	return [&"height", &"outer_radius", &"inner_radius", &"angle"]

## Moves face `id` by `delta` (local meters along its normal) from the `start`
## property values. Returns the delta actually applied and how far the origin moves.
func blockout_push(id: int, delta: float, start: Dictionary) -> Dictionary:
	match id:
		3:
			var h0: float = start[&"height"]
			height = h0 + delta
			return {"applied": _height - h0, "offset": Vector3.ZERO}
		FACE_OUTER:
			var o0: float = start[&"outer_radius"]
			outer_radius = maxf(o0 + delta, float(start[&"inner_radius"]) + 0.1)
			return {"applied": _outer_radius - o0, "offset": Vector3.ZERO}
		FACE_INNER:
			var i0: float = start[&"inner_radius"]
			inner_radius = clampf(i0 - delta, MIN_INNER_RADIUS, float(start[&"outer_radius"]) - 0.1)
			return {"applied": i0 - _inner_radius, "offset": Vector3.ZERO}
		FACE_END:
			var a0: float = start[&"angle"]
			var r_mid: float = (float(start[&"inner_radius"]) + float(start[&"outer_radius"])) * 0.5
			angle = a0 + rad_to_deg(delta / r_mid)
			return {"applied": deg_to_rad(_angle - a0) * r_mid, "offset": Vector3.ZERO}
	return {"applied": 0.0, "offset": Vector3.ZERO}

func blockout_face_outline(id: int) -> PackedVector3Array:
	var n: int = _l["n"]
	var m: int = _l["m"]
	var out: PackedVector3Array = PackedVector3Array()
	if id == FACE_END:
		var theta: float = float(_l["sweep"])
		var last: Vector2 = _interval(n - 1)
		return PackedVector3Array([_at(theta, _inner_radius, last.x), _at(theta, _outer_radius, last.x), _at(theta, _outer_radius, last.y), _at(theta, _inner_radius, last.y)])
	var step: int = n - 1 if id == 3 else n >> 1
	var iv: Vector2 = _interval(step)
	for j: int in m + 1:
		out.append(_at(_sub_angle(step, j), _outer_radius if id != FACE_INNER else _inner_radius, iv.y if id == 3 else iv.x))
	for j: int in range(m, -1, -1):
		out.append(_at(_sub_angle(step, j), _inner_radius if id != FACE_OUTER else _outer_radius, iv.y))
	return out

func blockout_editable_axes() -> PackedInt32Array:
	return PackedInt32Array([1])

## Properties to set for a typed size along local `axis` (only the height).
func blockout_size_props(axis: int, value: float) -> Dictionary:
	return {&"height": value} if axis == 1 else {}

## One convex block per step.
func blockout_collision_pieces() -> Array[PackedVector3Array]:
	var pieces: Array[PackedVector3Array] = []
	for i: int in int(_l["n"]):
		var iv: Vector2 = _interval(i)
		var pts: PackedVector3Array = PackedVector3Array()
		for j: int in int(_l["m"]) + 1:
			var a: float = _sub_angle(i, j)
			for r: float in [_inner_radius, _outer_radius]:
				pts.append(_at(a, r, iv.x))
				pts.append(_at(a, r, iv.y))
		pieces.append(pts)
	return pieces

## Approximate signed distance from a local point to the nearest step.
func blockout_distance(p: Vector3) -> float:
	var q: Vector3 = Vector3(p.x, p.y, -p.z) if _clockwise else p
	var best: float = INF
	var n: int = _l["n"]
	var step: float = float(_l["sweep"]) / float(n)
	for i: int in n:
		var iv: Vector2 = _interval(i)
		best = minf(best, CsgBlockoutShapeInfo.sector_distance(q, _inner_radius, _outer_radius, iv.x, iv.y, step * float(i), step * float(i + 1)))
	return best
