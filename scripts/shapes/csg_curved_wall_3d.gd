@tool
class_name CSGCurvedWall3D extends CSGPolygon3D
## A wall bent around a vertical axis through the origin: round rooms, towers,
## curved corridors. `radius` is the inner face; the wall is `thickness` thick
## outward from it. It starts on the +X axis and sweeps `angle` degrees
## counterclockwise seen from above (toward -Z); 360 makes a closed ring.
## Underneath it is a plain CSGPolygon3D in spin mode, so it keeps its shape when
## the plugin is disabled or removed.
##
## The `blockout_*` methods are the shape protocol the plugin's tools use; see
## ARCHITECTURE.md.

const MIN_SIZE: float = 0.01
const MAX_SIDES: int = 128
const FACE_OUTER: int = 6
const FACE_INNER: int = 7
const FACE_END: int = 8

var _radius: float = 3.0
## Radius of the inner face, in meters.
@export var radius: float = 3.0:
	get:
		return _radius
	set(value):
		var clamped: float = maxf(value, MIN_SIZE)
		if is_equal_approx(clamped, _radius):
			return
		_radius = clamped
		_rebuild()

var _thickness: float = 0.25
@export var thickness: float = 0.25:
	get:
		return _thickness
	set(value):
		var clamped: float = maxf(value, MIN_SIZE)
		if is_equal_approx(clamped, _thickness):
			return
		_thickness = clamped
		_rebuild()

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

var _angle: float = 90.0
## How far the wall sweeps around, in degrees (360 closes the ring).
@export_range(1.0, 360.0, 0.1, "degrees") var angle: float = 90.0:
	get:
		return _angle
	set(value):
		var clamped: float = clampf(value, 1.0, 360.0)
		if is_equal_approx(clamped, _angle):
			return
		_angle = clamped
		_rebuild()

var _sides: int = 12
## Flat segments along the curve.
@export_range(3, MAX_SIDES) var sides: int = 12:
	get:
		return _sides
	set(value):
		var clamped: int = clampi(value, 3, MAX_SIDES)
		if clamped == _sides:
			return
		_sides = clamped
		_rebuild()

func _init() -> void:
	_rebuild()

func _rebuild() -> void:
	mode = MODE_SPIN
	spin_degrees = _angle
	spin_sides = _sides
	var r1: float = _radius + _thickness
	polygon = PackedVector2Array([Vector2(_radius, 0.0), Vector2(_radius, _height), Vector2(r1, _height), Vector2(r1, 0.0)])

## Local point at `theta` (radians from +X toward -Z), distance `r` from the axis.
static func at(theta: float, r: float, y: float) -> Vector3:
	return Vector3(r * cos(theta), y, -r * sin(theta))

## Angle of segment boundary `k` (0..sides), radians.
func _segment_angle(k: int) -> float:
	return deg_to_rad(_angle) * float(k) / float(_sides)

## Keeps Godot's polygon point editor away: the profile is built from the properties
## above, so points moved there would be overwritten.
@warning_ignore("native_method_override")
func _is_editable_3d_polygon() -> bool:
	return false

func _validate_property(property: Dictionary) -> void:
	var prop_name: StringName = property["name"]
	if prop_name == &"polygon" or prop_name == &"mode" or prop_name.begins_with(&"spin") or prop_name == &"smooth_faces":
		property["usage"] = PROPERTY_USAGE_STORAGE
	elif prop_name == &"depth" or prop_name.begins_with(&"path"):
		property["usage"] = PROPERTY_USAGE_NONE

# --- shape protocol -------------------------------------------------------------

## Bounds of the segment corners (the faces are flat, so nothing sticks out further).
func blockout_aabb() -> AABB:
	var box: AABB = AABB(at(0.0, _radius, 0.0), Vector3.ZERO)
	for k: int in _sides + 1:
		var a: float = _segment_angle(k)
		box = box.expand(at(a, _radius, 0.0)).expand(at(a, _radius + _thickness, _height))
	return box

func blockout_faces() -> Array[Dictionary]:
	var mid: float = deg_to_rad(_angle) * 0.5
	var end: float = deg_to_rad(_angle)
	var r_mid: float = _radius + _thickness * 0.5
	var radial: Vector3 = at(mid, 1.0, 0.0)
	var faces: Array[Dictionary] = [
		{"id": 3, "normal": Vector3.UP, "center": at(mid, r_mid, _height)},
		{"id": 2, "normal": Vector3.DOWN, "center": at(mid, r_mid, 0.0)},
		{"id": FACE_OUTER, "normal": radial, "center": at(mid, _radius + _thickness, _height * 0.5)},
		{"id": FACE_INNER, "normal": -radial, "center": at(mid, _radius, _height * 0.5)},
	]
	if _angle < 360.0:
		faces.append({"id": FACE_END, "normal": Vector3(-sin(end), 0.0, -cos(end)), "center": at(end, r_mid, _height * 0.5)})
	return faces

func blockout_resize_props() -> Array[StringName]:
	return [&"radius", &"thickness", &"height", &"angle"]

## Moves face `id` by `delta` (local meters along its normal) from the `start`
## property values. Returns the delta actually applied and how far the origin moves.
func blockout_push(id: int, delta: float, start: Dictionary) -> Dictionary:
	match id:
		3, 2:
			var h0: float = start[&"height"]
			height = maxf(h0 + delta, MIN_SIZE)
			var grown: float = _height - h0
			return {"applied": grown, "offset": Vector3(0.0, -grown if id == 2 else 0.0, 0.0)}
		FACE_OUTER:
			var t0: float = start[&"thickness"]
			thickness = maxf(t0 + delta, MIN_SIZE)
			return {"applied": _thickness - t0, "offset": Vector3.ZERO}
		FACE_INNER:
			# The inner face moves toward the axis; the outer face stays.
			var r0: float = start[&"radius"]
			var t0: float = start[&"thickness"]
			var new_r: float = clampf(r0 - delta, MIN_SIZE, r0 + t0 - MIN_SIZE)
			radius = new_r
			thickness = t0 + r0 - new_r
			return {"applied": r0 - new_r, "offset": Vector3.ZERO}
		FACE_END:
			var a0: float = start[&"angle"]
			var r_mid: float = float(start[&"radius"]) + float(start[&"thickness"]) * 0.5
			angle = a0 + rad_to_deg(delta / maxf(r_mid, MIN_SIZE))
			return {"applied": deg_to_rad(_angle - a0) * r_mid, "offset": Vector3.ZERO}
	return {"applied": 0.0, "offset": Vector3.ZERO}

func blockout_face_outline(id: int) -> PackedVector3Array:
	var out: PackedVector3Array = PackedVector3Array()
	var r1: float = _radius + _thickness
	if id == FACE_END:
		var a: float = deg_to_rad(_angle)
		return PackedVector3Array([at(a, _radius, 0.0), at(a, _radius, _height), at(a, r1, _height), at(a, r1, 0.0)])
	# Two arcs: along the top or bottom (radii) or along a face (heights).
	var flat: bool = id == 2 or id == 3
	var y: float = _height if id == 3 else 0.0
	var r: float = r1 if id == FACE_OUTER else _radius
	for k: int in _sides + 1:
		out.append(at(_segment_angle(k), r1 if flat else r, y if flat else 0.0))
	for k: int in range(_sides, -1, -1):
		out.append(at(_segment_angle(k), _radius if flat else r, y if flat else _height))
	return out

func blockout_editable_axes() -> PackedInt32Array:
	return PackedInt32Array([1])

## Properties to set for a typed size along local `axis` (only the height).
func blockout_size_props(axis: int, value: float) -> Dictionary:
	return {&"height": value} if axis == 1 else {}

## One convex block per flat segment.
func blockout_collision_pieces() -> Array[PackedVector3Array]:
	var pieces: Array[PackedVector3Array] = []
	var r1: float = _radius + _thickness
	for k: int in _sides:
		var pts: PackedVector3Array = PackedVector3Array()
		for a: float in [_segment_angle(k), _segment_angle(k + 1)]:
			for r: float in [_radius, r1]:
				pts.append(at(a, r, 0.0))
				pts.append(at(a, r, _height))
		pieces.append(pts)
	return pieces

## Approximate signed distance from a local point to the wall.
func blockout_distance(p: Vector3) -> float:
	return CsgBlockoutShapeInfo.sector_distance(p, _radius, _radius + _thickness, 0.0, _height, 0.0, deg_to_rad(_angle))
