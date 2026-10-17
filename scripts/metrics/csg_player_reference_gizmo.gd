@tool
class_name CSGPlayerReferenceGizmoPlugin extends EditorNode3DGizmoPlugin
## Draws CSGPlayerReference3D: capsule (cyan), crouch height (blue), eye height,
## jump-onto height ring and sprint-jump arc (green), max walkable slope and the
## highest step walked up without jumping (orange).

const SEGMENTS: int = 32
const ARC_STEPS: int = 24
const SLOPE_LENGTH: float = 2.0
const EYE_OFFSET: float = 0.12

func _init() -> void:
	create_material(&"capsule", Color(0.3, 0.85, 1.0))
	create_material(&"crouch", Color(0.35, 0.55, 1.0))
	create_material(&"jump", Color(0.4, 0.95, 0.45))
	create_material(&"slope", Color(1.0, 0.7, 0.25))

func _has_gizmo(for_node_3d: Node3D) -> bool:
	return for_node_3d is CSGPlayerReference3D

func _get_gizmo_name() -> String:
	return "CSGPlayerReference"

func _redraw(gizmo: EditorNode3DGizmo) -> void:
	gizmo.clear()
	var node: CSGPlayerReference3D = gizmo.get_node_3d() as CSGPlayerReference3D
	if node == null or not node.is_visible_in_tree():
		return
	var m: Dictionary = node.metrics()
	var h: float = m["character_height"]
	var r: float = minf(m["capsule_radius"], h * 0.5)
	var capsule: PackedVector3Array = PackedVector3Array()
	_ring(capsule, r, r)
	_ring(capsule, h - r, r)
	for i: int in 4:
		var a: float = TAU * float(i) / 4.0
		var off: Vector3 = Vector3(cos(a), 0, sin(a)) * r
		capsule.append(off + Vector3(0, r, 0))
		capsule.append(off + Vector3(0, h - r, 0))
	for plane: int in 2:
		_half_circle(capsule, Vector3(0, r, 0), r, plane, PI, TAU)
		_half_circle(capsule, Vector3(0, h - r, 0), r, plane, 0.0, PI)
	# Eye height: short forward tick.
	var eye: float = maxf(h - EYE_OFFSET, r)
	capsule.append(Vector3(0, eye, 0))
	capsule.append(Vector3(0, eye, -r - 0.25))
	gizmo.add_lines(capsule, get_material(&"capsule", gizmo))
	gizmo.add_collision_segments(capsule)

	var crouch: PackedVector3Array = PackedVector3Array()
	_ring(crouch, minf(m["crouch_height"], h), r * 1.15)
	gizmo.add_lines(crouch, get_material(&"crouch", gizmo))

	var jump: PackedVector3Array = PackedVector3Array()
	var jh: float = m["single_jump_height"]
	_ring(jump, jh, r + 0.25)
	if node.show_jump_arc:
		var dist: float = m["sprint_jump_distance"]
		var prev: Vector3 = Vector3.ZERO
		for i: int in range(1, ARC_STEPS + 1):
			var t: float = float(i) / float(ARC_STEPS)
			var p: Vector3 = Vector3(0, 4.0 * jh * t * (1.0 - t), -dist * t)
			jump.append(prev)
			jump.append(p)
			prev = p
		# Landing marker.
		jump.append(Vector3(-0.3, 0, -dist))
		jump.append(Vector3(0.3, 0, -dist))
	gizmo.add_lines(jump, get_material(&"jump", gizmo))

	if node.show_slope:
		var slope: PackedVector3Array = PackedVector3Array()
		var rise: float = tan(deg_to_rad(m["max_slope_angle"])) * SLOPE_LENGTH
		var x: float = r + 0.4
		var a0: Vector3 = Vector3(x, 0, 0)
		var a1: Vector3 = Vector3(x, 0, -SLOPE_LENGTH)
		var a2: Vector3 = Vector3(x, rise, -SLOPE_LENGTH)
		slope.append_array(PackedVector3Array([a0, a1, a1, a2, a2, a0]))
		# The highest step, on the other side: floor, riser, tread.
		var step: float = m.get("max_step_height", 0.3)
		var s0: Vector3 = Vector3(-x, 0, 0)
		var s1: Vector3 = Vector3(-x, 0, -0.4)
		var s2: Vector3 = Vector3(-x, step, -0.4)
		var s3: Vector3 = Vector3(-x, step, -0.8)
		slope.append_array(PackedVector3Array([s0, s1, s1, s2, s2, s3]))
		gizmo.add_lines(slope, get_material(&"slope", gizmo))

static func _ring(out: PackedVector3Array, y: float, radius: float) -> void:
	for i: int in SEGMENTS:
		var a0: float = TAU * float(i) / float(SEGMENTS)
		var a1: float = TAU * float(i + 1) / float(SEGMENTS)
		out.append(Vector3(cos(a0) * radius, y, sin(a0) * radius))
		out.append(Vector3(cos(a1) * radius, y, sin(a1) * radius))

## Half circle in the XY (plane 0) or ZY (plane 1) plane, angles from a0 to a1.
static func _half_circle(out: PackedVector3Array, center: Vector3, radius: float, plane: int, a0: float, a1: float) -> void:
	var steps: int = SEGMENTS / 2
	for i: int in steps:
		var t0: float = lerpf(a0, a1, float(i) / float(steps))
		var t1: float = lerpf(a0, a1, float(i + 1) / float(steps))
		var p0: Vector3 = Vector3(cos(t0) * radius, sin(t0) * radius, 0) if plane == 0 else Vector3(0, sin(t0) * radius, cos(t0) * radius)
		var p1: Vector3 = Vector3(cos(t1) * radius, sin(t1) * radius, 0) if plane == 0 else Vector3(0, sin(t1) * radius, cos(t1) * radius)
		out.append(center + p0)
		out.append(center + p1)
