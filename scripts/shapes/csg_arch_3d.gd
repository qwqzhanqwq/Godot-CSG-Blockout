@tool
class_name CSGArch3D extends CSGPolygon3D
## A wall piece with an arched opening through it: gateways, arcades, bridges. The
## origin is the bottom corner; the width runs along +X, the height up and the
## thickness toward -Z, and the opening is centered in the width. The top of the
## opening is a half circle, or a flatter elliptical arc when the opening is lower
## than half its width. Underneath it is a plain CSGPolygon3D, so it keeps its shape
## when the plugin is disabled or removed.
##
## The `blockout_*` methods are the shape protocol the plugin's tools use; see
## ARCHITECTURE.md.

const MIN_SIZE: float = 0.01
## Thinnest jamb and head left around the opening.
const MIN_BORDER: float = 0.05
const MAX_SEGMENTS: int = 64
## Face ids of the opening's handles (the box faces use 0-5).
const FACE_OPENING_TOP: int = 10
const FACE_OPENING_SIDE: int = 11

var _size: Vector3 = Vector3(3.0, 3.0, 0.5)
## Width (+X), height and thickness (toward -Z), in meters.
@export var size: Vector3 = Vector3(3.0, 3.0, 0.5):
	get:
		return _size
	set(value):
		var clamped: Vector3 = value.max(Vector3.ONE * MIN_SIZE)
		if clamped.is_equal_approx(_size):
			return
		_size = clamped
		_rebuild()

var _opening_width: float = 1.6
## Width of the opening; kept narrower than the arch.
@export var opening_width: float = 1.6:
	get:
		return _opening_width
	set(value):
		var clamped: float = maxf(value, MIN_SIZE)
		if is_equal_approx(clamped, _opening_width):
			return
		_opening_width = clamped
		_rebuild()

var _opening_height: float = 2.4
## Height of the opening at the top of its arc; kept lower than the arch.
@export var opening_height: float = 2.4:
	get:
		return _opening_height
	set(value):
		var clamped: float = maxf(value, MIN_SIZE)
		if is_equal_approx(clamped, _opening_height):
			return
		_opening_height = clamped
		_rebuild()

var _arc_segments: int = 12
@export_range(2, MAX_SEGMENTS) var arc_segments: int = 12:
	get:
		return _arc_segments
	set(value):
		var clamped: int = clampi(value, 2, MAX_SEGMENTS)
		if clamped == _arc_segments:
			return
		_arc_segments = clamped
		_rebuild()

func _init() -> void:
	_rebuild()

## Opening size actually built: {"width", "height", "spring" (where the arc starts)}.
func opening() -> Dictionary:
	var w: float = clampf(_opening_width, MIN_SIZE, maxf(_size.x - MIN_BORDER * 2.0, MIN_SIZE))
	var h: float = clampf(_opening_height, MIN_SIZE, maxf(_size.y - MIN_BORDER, MIN_SIZE))
	return {"width": w, "height": h, "spring": maxf(h - w * 0.5, 0.0)}

## Points of the opening's arc from the right jamb to the left one.
func _arc_points() -> PackedVector2Array:
	var o: Dictionary = opening()
	var half: float = float(o["width"]) * 0.5
	var spring: float = float(o["spring"])
	var rise: float = float(o["height"]) - spring
	var cx: float = _size.x * 0.5
	var pts: PackedVector2Array = PackedVector2Array()
	for i: int in _arc_segments + 1:
		var a: float = PI * float(i) / float(_arc_segments)
		pts.append(Vector2(cx + half * cos(a), spring + rise * sin(a)))
	return pts

func _rebuild() -> void:
	mode = MODE_DEPTH
	depth = _size.z
	var half: float = float(opening()["width"]) * 0.5
	var cx: float = _size.x * 0.5
	var pts: PackedVector2Array = PackedVector2Array([Vector2.ZERO, Vector2(0.0, _size.y), Vector2(_size.x, _size.y), Vector2(_size.x, 0.0), Vector2(cx + half, 0.0)])
	for p: Vector2 in _arc_points():
		_append_distinct(pts, p)
	_append_distinct(pts, Vector2(cx - half, 0.0))
	polygon = pts
	update_configuration_warnings()

static func _append_distinct(pts: PackedVector2Array, p: Vector2) -> void:
	if pts.is_empty() or pts[pts.size() - 1].distance_to(p) > 0.0001:
		pts.append(p)

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = PackedStringArray()
	var o: Dictionary = opening()
	if not is_equal_approx(float(o["width"]), _opening_width) or not is_equal_approx(float(o["height"]), _opening_height):
		warnings.append("The opening is larger than the arch; it is built %.2f m wide and %.2f m high." % [float(o["width"]), float(o["height"])])
	return warnings

## Keeps Godot's polygon point editor away: the profile is built from the properties
## above, so points moved there would be overwritten.
@warning_ignore("native_method_override")
func _is_editable_3d_polygon() -> bool:
	return false

func _validate_property(property: Dictionary) -> void:
	var prop_name: StringName = property["name"]
	if prop_name == &"polygon" or prop_name == &"mode" or prop_name == &"depth" or prop_name == &"smooth_faces":
		property["usage"] = PROPERTY_USAGE_STORAGE
	elif prop_name.begins_with(&"spin") or prop_name.begins_with(&"path"):
		property["usage"] = PROPERTY_USAGE_NONE

# --- shape protocol -------------------------------------------------------------

func blockout_aabb() -> AABB:
	return AABB(Vector3(0.0, 0.0, -_size.z), _size)

## Box faces use CSGBox3D's ids (axis * 2 + side); the opening has a handle under
## the top of its arc (height) and one on its right jamb (width, kept centered).
func blockout_faces() -> Array[Dictionary]:
	var s: Vector3 = _size
	var o: Dictionary = opening()
	var mid_z: float = -s.z * 0.5
	var cx: float = s.x * 0.5
	return [
		{"id": 3, "normal": Vector3.UP, "center": Vector3(cx, s.y, mid_z)},
		{"id": 1, "normal": Vector3.RIGHT, "center": Vector3(s.x, s.y * 0.5, mid_z)},
		{"id": 0, "normal": Vector3.LEFT, "center": Vector3(0.0, s.y * 0.5, mid_z)},
		{"id": 5, "normal": Vector3.BACK, "center": Vector3(cx, (s.y + float(o["height"])) * 0.5, 0.0)},
		{"id": 4, "normal": Vector3.FORWARD, "center": Vector3(cx, (s.y + float(o["height"])) * 0.5, -s.z)},
		{"id": FACE_OPENING_TOP, "normal": Vector3.DOWN, "center": Vector3(cx, float(o["height"]), mid_z)},
		{"id": FACE_OPENING_SIDE, "normal": Vector3.LEFT, "center": Vector3(cx + float(o["width"]) * 0.5, float(o["spring"]) * 0.5, mid_z)},
	]

func blockout_resize_props() -> Array[StringName]:
	return [&"size", &"opening_width", &"opening_height"]

## Moves face `id` by `delta` (local meters along its normal) from the `start`
## property values. Returns the delta actually applied and how far the origin moves.
func blockout_push(id: int, delta: float, start: Dictionary) -> Dictionary:
	if id == FACE_OPENING_TOP:
		# The handle points down into the opening: pushing it out lowers the opening.
		var h0: float = start[&"opening_height"]
		var h: float = clampf(h0 - delta, MIN_SIZE, maxf(_size.y - MIN_BORDER, MIN_SIZE))
		opening_height = h
		return {"applied": h0 - h, "offset": Vector3.ZERO}
	if id == FACE_OPENING_SIDE:
		# The right jamb's face points into the opening; both jambs move, so the
		# opening narrows by twice the push and stays centered.
		var w0: float = start[&"opening_width"]
		var w: float = clampf(w0 - delta * 2.0, MIN_SIZE, maxf(_size.x - MIN_BORDER * 2.0, MIN_SIZE))
		opening_width = w
		return {"applied": (w0 - w) * 0.5, "offset": Vector3.ZERO}
	var s: Vector3 = start[&"size"]
	var axis: int = id >> 1
	var grown: float = maxf(s[axis] + delta, MIN_SIZE) - s[axis]
	s[axis] += grown
	size = s
	var offset: Vector3 = Vector3.ZERO
	if id == 0:
		offset.x = -grown
	elif id == 5:
		offset.z = grown
	return {"applied": grown, "offset": offset}

func blockout_face_outline(id: int) -> PackedVector3Array:
	var out: PackedVector3Array = PackedVector3Array()
	if id == 4 or id == 5:
		var z: float = 0.0 if id == 5 else -_size.z
		for v: Vector2 in polygon:
			out.append(Vector3(v.x, v.y, z))
		return out
	if id == FACE_OPENING_TOP:
		var arc: PackedVector2Array = _arc_points()
		for v: Vector2 in arc:
			out.append(Vector3(v.x, v.y, 0.0))
		for i: int in range(arc.size() - 1, -1, -1):
			out.append(Vector3(arc[i].x, arc[i].y, -_size.z))
		return out
	if id == FACE_OPENING_SIDE:
		var o: Dictionary = opening()
		var x: float = _size.x * 0.5 + float(o["width"]) * 0.5
		var top: float = maxf(float(o["spring"]), 0.05)
		return PackedVector3Array([Vector3(x, 0, 0), Vector3(x, top, 0), Vector3(x, top, -_size.z), Vector3(x, 0, -_size.z)])
	return PackedVector3Array()

func blockout_editable_axes() -> PackedInt32Array:
	return PackedInt32Array([0, 1, 2])

## Properties to set for a typed size along local `axis`.
func blockout_size_props(axis: int, value: float) -> Dictionary:
	var s: Vector3 = _size
	s[axis] = value
	return {&"size": s}

## Convex pieces: the two jambs, then one piece above each segment of the arc.
func blockout_collision_pieces() -> Array[PackedVector3Array]:
	var pieces: Array[PackedVector3Array] = []
	var o: Dictionary = opening()
	var half: float = float(o["width"]) * 0.5
	var cx: float = _size.x * 0.5
	for x_range: Vector2 in [Vector2(0.0, cx - half), Vector2(cx + half, _size.x)]:
		pieces.append(_prism([Vector2(x_range.x, 0.0), Vector2(x_range.x, _size.y), Vector2(x_range.y, _size.y), Vector2(x_range.y, 0.0)]))
	var arc: PackedVector2Array = _arc_points()
	for i: int in arc.size() - 1:
		var a: Vector2 = arc[i]
		var b: Vector2 = arc[i + 1]
		pieces.append(_prism([a, b, Vector2(b.x, _size.y), Vector2(a.x, _size.y)]))
	return pieces

func _prism(profile: Array) -> PackedVector3Array:
	var pts: PackedVector3Array = PackedVector3Array()
	for v: Vector2 in profile:
		pts.append(Vector3(v.x, v.y, 0.0))
		pts.append(Vector3(v.x, v.y, -_size.z))
	return pts
