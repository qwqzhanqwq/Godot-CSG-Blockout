@tool
class_name CSGWedge3D extends CSGPolygon3D
## A box with one sloped face, for ramps, roof halves and angled walls. The slope
## rises from the origin toward +X (like CSGStairs3D in ramp mode) and the width
## extrudes toward -Z. Underneath it is a plain CSGPolygon3D, so it keeps its shape
## when the plugin is disabled or removed.
##
## The `blockout_*` methods are the shape protocol the plugin's tools use (face
## arrows, typed sizes, bounds, collision); see ARCHITECTURE.md.

const MIN_SIZE: float = 0.01

var _size: Vector3 = Vector3(2.0, 1.0, 2.0)
## Length along +X (the slope's run), height, and width (toward -Z), in meters.
@export var size: Vector3 = Vector3(2.0, 1.0, 2.0):
	get:
		return _size
	set(value):
		var clamped: Vector3 = value.max(Vector3.ONE * MIN_SIZE)
		if clamped.is_equal_approx(_size):
			return
		_size = clamped
		_rebuild()

func _init() -> void:
	_rebuild()

func _rebuild() -> void:
	mode = MODE_DEPTH
	depth = _size.z
	polygon = PackedVector2Array([Vector2.ZERO, Vector2(_size.x, _size.y), Vector2(_size.x, 0.0)])

## Slope angle in degrees.
func slope_degrees() -> float:
	return rad_to_deg(atan2(_size.y, _size.x))

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

## Face ids follow CSGBox3D's handles: axis * 2 + (0 for -, 1 for +). The top
## handle sits on the high edge and changes the height.
func blockout_faces() -> Array[Dictionary]:
	var s: Vector3 = _size
	var mid_z: float = -s.z * 0.5
	return [
		{"id": 3, "normal": Vector3.UP, "center": Vector3(s.x, s.y, mid_z)},
		{"id": 1, "normal": Vector3.RIGHT, "center": Vector3(s.x, s.y * 0.5, mid_z)},
		{"id": 0, "normal": Vector3.LEFT, "center": Vector3(0.0, 0.0, mid_z)},
		{"id": 5, "normal": Vector3.BACK, "center": Vector3(s.x * 0.67, s.y * 0.33, 0.0)},
		{"id": 4, "normal": Vector3.FORWARD, "center": Vector3(s.x * 0.67, s.y * 0.33, -s.z)},
	]

func blockout_resize_props() -> Array[StringName]:
	return [&"size"]

## Moves face `id` by `delta` (local meters along its normal) from the `start`
## property values. Returns the delta actually applied and how far the origin moves.
func blockout_push(id: int, delta: float, start: Dictionary) -> Dictionary:
	var s: Vector3 = start[&"size"]
	var axis: int = id >> 1
	var grown: float = maxf(s[axis] + delta, MIN_SIZE) - s[axis]
	s[axis] += grown
	size = s
	var offset: Vector3 = Vector3.ZERO
	# The -X tip and the +Z side sit at the origin: growing them moves it.
	if id == 0:
		offset.x = -grown
	elif id == 5:
		offset.z = grown
	return {"applied": grown, "offset": offset}

func blockout_face_outline(id: int) -> PackedVector3Array:
	var s: Vector3 = _size
	match id:
		1:
			return PackedVector3Array([Vector3(s.x, 0, 0), Vector3(s.x, s.y, 0), Vector3(s.x, s.y, -s.z), Vector3(s.x, 0, -s.z)])
		4, 5:
			var z: float = 0.0 if id == 5 else -s.z
			return PackedVector3Array([Vector3(0, 0, z), Vector3(s.x, s.y, z), Vector3(s.x, 0, z)])
	return PackedVector3Array([Vector3.ZERO, Vector3(s.x, s.y, 0), Vector3(s.x, s.y, -s.z), Vector3(0, 0, -s.z)])

func blockout_editable_axes() -> PackedInt32Array:
	return PackedInt32Array([0, 1, 2])

## Properties to set for a typed size along local `axis`.
func blockout_size_props(axis: int, value: float) -> Dictionary:
	var s: Vector3 = _size
	s[axis] = value
	return {&"size": s}

func blockout_collision_pieces() -> Array[PackedVector3Array]:
	var pts: PackedVector3Array = PackedVector3Array()
	for v: Vector2 in polygon:
		pts.append(Vector3(v.x, v.y, 0.0))
		pts.append(Vector3(v.x, v.y, -_size.z))
	return [pts]
