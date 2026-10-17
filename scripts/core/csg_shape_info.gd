@tool
class_name CsgBlockoutShapeInfo
extends RefCounted
## Geometry facts about CSG primitives that the engine doesn't expose directly:
## local bounds, pushable faces, preview meshes and surface distance.
## The plugin's own shapes (wedge, arch, curved wall, spiral stairs) answer these
## through their `blockout_*` methods (the shape protocol, see ARCHITECTURE.md).

const MIN_SIZE: float = 0.01

static func is_primitive(n: Node) -> bool:
	return n is CSGShape3D and not (n is CSGCombiner3D)

## True for nodes that implement the shape protocol.
static func has_protocol(n: Object) -> bool:
	return n != null and n.has_method(&"blockout_faces")

## Local-space bounds of a CSG node (combiners merge their non-subtracting children).
static func local_aabb(n: Node3D) -> AABB:
	if has_protocol(n):
		return n.call(&"blockout_aabb")
	if n is CSGBox3D:
		var s: Vector3 = (n as CSGBox3D).size
		return AABB(-s * 0.5, s)
	if n is CSGCylinder3D:
		var c: CSGCylinder3D = n as CSGCylinder3D
		return AABB(Vector3(-c.radius, -c.height * 0.5, -c.radius), Vector3(c.radius * 2.0, c.height, c.radius * 2.0))
	if n is CSGSphere3D:
		var r: float = (n as CSGSphere3D).radius
		return AABB(Vector3(-r, -r, -r), Vector3(r, r, r) * 2.0)
	if n is CSGTorus3D:
		var t: CSGTorus3D = n as CSGTorus3D
		var ring: float = absf(t.outer_radius - t.inner_radius) * 0.5
		var outer: float = maxf(t.outer_radius, t.inner_radius)
		return AABB(Vector3(-outer, -ring, -outer), Vector3(outer * 2.0, ring * 2.0, outer * 2.0))
	if n is CSGPolygon3D and (n as CSGPolygon3D).mode == CSGPolygon3D.MODE_DEPTH:
		var p: CSGPolygon3D = n as CSGPolygon3D
		if p.polygon.is_empty():
			return AABB()
		var lo: Vector2 = p.polygon[0]
		var hi: Vector2 = p.polygon[0]
		for v: Vector2 in p.polygon:
			lo = lo.min(v)
			hi = hi.max(v)
		# Depth mode extrudes along -Z.
		return AABB(Vector3(lo.x, lo.y, -p.depth), Vector3(hi.x - lo.x, hi.y - lo.y, p.depth))
	if n is CSGMesh3D and (n as CSGMesh3D).mesh != null:
		return (n as CSGMesh3D).mesh.get_aabb()
	if n is CSGCombiner3D or (n is CSGShape3D and n.get_child_count() > 0):
		var merged: AABB = AABB()
		var has_any: bool = false
		for child: Node in n.get_children():
			if not (child is CSGShape3D) or not (child as Node3D).visible:
				continue
			if (child as CSGShape3D).operation == CSGShape3D.OPERATION_SUBTRACTION:
				continue
			var child_box: AABB = transform_aabb((child as Node3D).transform, local_aabb(child as Node3D))
			merged = child_box if not has_any else merged.merge(child_box)
			has_any = true
		if has_any:
			return merged
	if n is VisualInstance3D:
		var box: AABB = (n as VisualInstance3D).get_aabb()
		if box.size != Vector3.ZERO:
			return box
	return AABB(Vector3(-0.5, -0.5, -0.5), Vector3.ONE)

static func transform_aabb(xform: Transform3D, box: AABB) -> AABB:
	var out: AABB = AABB(xform * box.position, Vector3.ZERO)
	for i: int in 8:
		out = out.expand(xform * box.get_endpoint(i))
	return out

## World-space box as a transform that maps the unit cube (-0.5..0.5) onto it.
static func world_box_xform(n: Node3D) -> Transform3D:
	var box: AABB = local_aabb(n)
	var local: Transform3D = Transform3D(Basis.from_scale(box.size.max(Vector3.ONE * 0.001)), box.get_center())
	return n.global_transform * local

## Size of the node's local bounds in world units (accounts for node scale).
static func world_size(n: Node3D) -> Vector3:
	var s: Vector3 = local_aabb(n).size
	var b: Basis = n.global_transform.basis
	return Vector3(s.x * b.x.length(), s.y * b.y.length(), s.z * b.z.length())

## Distance from local edge of the shape to its origin along local +Y (how far to lift a
## new shape so it rests on a surface).
static func bottom_offset(n: Node3D) -> float:
	return -local_aabb(n).position.y

# --- faces for push/pull ------------------------------------------------------

## Pushable faces in local space: {id, normal, center, axis, sign, radial}.
static func push_faces(n: Node3D) -> Array[Dictionary]:
	var faces: Array[Dictionary] = []
	if has_protocol(n):
		for f: Dictionary in n.call(&"blockout_faces"):
			var normal: Vector3 = f["normal"]
			var axis: int = normal.abs().max_axis_index()
			faces.append({"id": f["id"], "normal": normal, "center": f["center"], "axis": axis, "sign": int(signf(normal[axis])), "radial": false})
	elif n is CSGBox3D:
		var half: Vector3 = (n as CSGBox3D).size * 0.5
		for axis: int in 3:
			for side: int in [-1, 1]:
				var normal: Vector3 = Vector3.ZERO
				normal[axis] = float(side)
				faces.append({"id": axis * 2 + (0 if side < 0 else 1), "normal": normal, "center": normal * half[axis], "axis": axis, "sign": side, "radial": false})
	elif n is CSGCylinder3D:
		var c: CSGCylinder3D = n as CSGCylinder3D
		faces.append({"id": 3, "normal": Vector3.UP, "center": Vector3(0, c.height * 0.5, 0), "axis": 1, "sign": 1, "radial": false})
		faces.append({"id": 2, "normal": Vector3.DOWN, "center": Vector3(0, -c.height * 0.5, 0), "axis": 1, "sign": -1, "radial": false})
		faces.append({"id": 6, "normal": Vector3.RIGHT, "center": Vector3(c.radius, 0, 0), "axis": 0, "sign": 1, "radial": true})
	elif n is CSGStairs3D:
		var s: CSGStairs3D = n as CSGStairs3D
		faces.append({"id": 3, "normal": Vector3.UP, "center": Vector3(s.total_depth, s.total_height, -s.width * 0.5), "axis": 1, "sign": 1, "radial": false})
		faces.append({"id": 1, "normal": Vector3.RIGHT, "center": Vector3(s.total_depth, s.total_height * 0.5, -s.width * 0.5), "axis": 0, "sign": 1, "radial": false})
		faces.append({"id": 4, "normal": Vector3.BACK, "center": Vector3(s.total_depth * 0.5, s.total_height * 0.5, 0.0), "axis": 2, "sign": 1, "radial": false})
		faces.append({"id": 5, "normal": Vector3.FORWARD, "center": Vector3(s.total_depth * 0.5, s.total_height * 0.5, -s.width), "axis": 2, "sign": -1, "radial": false})
	return faces

## Corners of a box face in local space, for highlighting (counter-clockwise from outside).
static func box_face_corners(half: Vector3, axis: int, side: int) -> PackedVector3Array:
	var u: int = (axis + 1) % 3
	var v: int = (axis + 2) % 3
	var pts: PackedVector3Array = PackedVector3Array()
	for c: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		var p: Vector3 = Vector3.ZERO
		p[axis] = half[axis] * float(side)
		p[u] = half[u] * c.x
		p[v] = half[v] * c.y
		pts.append(p)
	return pts

# --- preview meshes -------------------------------------------------------------

## Mesh that approximates the shape for ghost previews, in the node's local space.
static func preview_mesh(n: Node3D) -> Mesh:
	if n is CSGBox3D:
		var box: BoxMesh = BoxMesh.new()
		box.size = (n as CSGBox3D).size
		return box
	if n is CSGCylinder3D:
		var c: CSGCylinder3D = n as CSGCylinder3D
		var cyl: CylinderMesh = CylinderMesh.new()
		cyl.top_radius = 0.0 if c.cone else c.radius
		cyl.bottom_radius = c.radius
		cyl.height = c.height
		cyl.radial_segments = maxi(c.sides, 3)
		return cyl
	if n is CSGSphere3D:
		var sph: SphereMesh = SphereMesh.new()
		sph.radius = (n as CSGSphere3D).radius
		sph.height = sph.radius * 2.0
		return sph
	if n is CSGTorus3D:
		var t: CSGTorus3D = n as CSGTorus3D
		var tor: TorusMesh = TorusMesh.new()
		tor.inner_radius = minf(t.inner_radius, t.outer_radius)
		tor.outer_radius = maxf(t.inner_radius, t.outer_radius)
		return tor
	if n is CSGMesh3D and (n as CSGMesh3D).mesh != null:
		return (n as CSGMesh3D).mesh
	if _has_profile(n):
		var p: CSGPolygon3D = n as CSGPolygon3D
		if p.mode == CSGPolygon3D.MODE_DEPTH:
			return extrusion_mesh(p.polygon, p.depth)
		return spin_mesh(p.polygon, p.spin_degrees, p.spin_sides)
	var aabb: AABB = local_aabb(n)
	var fallback: BoxMesh = BoxMesh.new()
	fallback.size = aabb.size
	return fallback

## Offset of preview_mesh() relative to the node origin (non-centered shapes).
static func preview_offset(n: Node3D) -> Vector3:
	if n is CSGBox3D or n is CSGCylinder3D or n is CSGSphere3D or n is CSGTorus3D or n is CSGMesh3D or _has_profile(n):
		return Vector3.ZERO
	return local_aabb(n).get_center()

## A CSGPolygon3D whose preview is built from its profile (depth or spin mode).
static func _has_profile(n: Node3D) -> bool:
	return n is CSGPolygon3D and (n as CSGPolygon3D).polygon.size() >= 3 and (n as CSGPolygon3D).mode != CSGPolygon3D.MODE_PATH

## Triangles of a profile (local XY) extruded from z = 0 to z = -depth, like
## CSGPolygon3D in depth mode. Unwound: the ghost material draws both sides.
static func extrusion_mesh(polygon: PackedVector2Array, depth: float) -> ArrayMesh:
	var verts: PackedVector3Array = PackedVector3Array()
	var caps: PackedInt32Array = Geometry2D.triangulate_polygon(polygon)
	for z: float in [0.0, -depth]:
		for i: int in caps:
			verts.append(Vector3(polygon[i].x, polygon[i].y, z))
	for i: int in polygon.size():
		var a: Vector2 = polygon[i]
		var b: Vector2 = polygon[(i + 1) % polygon.size()]
		verts.append_array([Vector3(a.x, a.y, 0.0), Vector3(b.x, b.y, 0.0), Vector3(b.x, b.y, -depth)])
		verts.append_array([Vector3(a.x, a.y, 0.0), Vector3(b.x, b.y, -depth), Vector3(a.x, a.y, -depth)])
	return _triangles_mesh(verts)

## Triangles of a profile (local XY, x >= 0) turned `degrees` around +Y in `sides`
## steps, like CSGPolygon3D in spin mode (from +X toward -Z). Unwound.
static func spin_mesh(polygon: PackedVector2Array, degrees: float, sides: int) -> ArrayMesh:
	var verts: PackedVector3Array = PackedVector3Array()
	var count: int = maxi(sides, 1)
	var turn: Callable = func(v: Vector2, k: int) -> Vector3:
		var a: float = deg_to_rad(degrees) * float(k) / float(count)
		return Vector3(v.x * cos(a), v.y, -v.x * sin(a))
	for k: int in count:
		for i: int in polygon.size():
			var a: Vector2 = polygon[i]
			var b: Vector2 = polygon[(i + 1) % polygon.size()]
			verts.append_array([turn.call(a, k), turn.call(b, k), turn.call(b, k + 1)])
			verts.append_array([turn.call(a, k), turn.call(b, k + 1), turn.call(a, k + 1)])
	if degrees < 360.0:
		var caps: PackedInt32Array = Geometry2D.triangulate_polygon(polygon)
		for k: int in [0, count]:
			for i: int in caps:
				verts.append(turn.call(polygon[i], k))
	return _triangles_mesh(verts)

static func _triangles_mesh(verts: PackedVector3Array) -> ArrayMesh:
	var mesh: ArrayMesh = ArrayMesh.new()
	if verts.is_empty():
		return mesh
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

# --- surface distance -----------------------------------------------------------

## Approximate unsigned distance (world units) from a world point to the shape surface.
static func surface_distance(n: Node3D, world_point: Vector3) -> float:
	var inv: Transform3D = n.global_transform.affine_inverse()
	var p: Vector3 = inv * world_point
	var scale: float = (n.global_transform.basis.x.length() + n.global_transform.basis.y.length() + n.global_transform.basis.z.length()) / 3.0
	var d: float
	if n.has_method(&"blockout_distance"):
		d = n.call(&"blockout_distance", p)
	elif n is CSGBox3D:
		d = _sdf_box(p, (n as CSGBox3D).size * 0.5)
	elif n is CSGCylinder3D:
		var c: CSGCylinder3D = n as CSGCylinder3D
		var q: Vector2 = Vector2(Vector2(p.x, p.z).length() - c.radius, absf(p.y) - c.height * 0.5)
		d = minf(maxf(q.x, q.y), 0.0) + q.max(Vector2.ZERO).length()
	elif n is CSGSphere3D:
		d = p.length() - (n as CSGSphere3D).radius
	elif n is CSGPolygon3D and (n as CSGPolygon3D).mode == CSGPolygon3D.MODE_DEPTH and (n as CSGPolygon3D).polygon.size() >= 3:
		d = _sdf_extrusion(p, (n as CSGPolygon3D).polygon, (n as CSGPolygon3D).depth)
	else:
		var box: AABB = local_aabb(n)
		d = _sdf_box(p - box.get_center(), box.size * 0.5)
	return absf(d) * scale

## Signed distance to a polygon (local XY) extruded from z = 0 to z = -depth, the
## shape of a CSGPolygon3D in depth mode (stairs and ramps, for instance).
static func _sdf_extrusion(p: Vector3, polygon: PackedVector2Array, depth: float) -> float:
	var q: Vector2 = Vector2(p.x, p.y)
	var edge: float = INF
	for i: int in polygon.size():
		var closest: Vector2 = Geometry2D.get_closest_point_to_segment(q, polygon[i], polygon[(i + 1) % polygon.size()])
		edge = minf(edge, closest.distance_to(q))
	var in_profile: float = -edge if Geometry2D.is_point_in_polygon(q, polygon) else edge
	var in_depth: float = maxf(p.z, -depth - p.z)
	return Vector2(maxf(in_profile, 0.0), maxf(in_depth, 0.0)).length() + minf(maxf(in_profile, in_depth), 0.0)

## Approximate signed distance to a ring sector around +Y: radii r0..r1, heights
## y0..y1, angles a0..a1 (radians from +X toward -Z, a1 - a0 up to TAU). Used by the
## curved wall and the spiral stairs.
static func sector_distance(p: Vector3, r0: float, r1: float, y0: float, y1: float, a0: float, a1: float) -> float:
	var r: float = Vector2(p.x, p.z).length()
	var span: float = a1 - a0
	var da: float = -INF
	if span < TAU - 0.0001:
		var rel: float = fposmod(atan2(-p.z, p.x) - a0, TAU)
		if rel > span:
			# Outside the sweep: how far around to the nearest end, as a distance.
			da = r * sin(minf(minf(rel - span, TAU - rel), PI * 0.5))
		else:
			da = -r * sin(minf(minf(rel, span - rel), PI * 0.5))
	var q: Vector3 = Vector3(maxf(r0 - r, r - r1), maxf(y0 - p.y, p.y - y1), da)
	return q.max(Vector3.ZERO).length() + minf(maxf(q.x, maxf(q.y, q.z)), 0.0)

static func _sdf_box(p: Vector3, half: Vector3) -> float:
	var q: Vector3 = p.abs() - half
	return q.max(Vector3.ZERO).length() + minf(maxf(q.x, maxf(q.y, q.z)), 0.0)

## All CSG primitives under (and including) `root`, in tree order.
static func primitives_under(root: Node) -> Array[CSGShape3D]:
	var out: Array[CSGShape3D] = []
	_collect_primitives(root, out)
	return out

static func _collect_primitives(n: Node, out: Array[CSGShape3D]) -> void:
	if is_primitive(n):
		out.append(n as CSGShape3D)
	for child: Node in n.get_children():
		if child is CSGShape3D:
			_collect_primitives(child, out)

## The CSG root (topmost CSGShape3D ancestor) of `n`, or null.
static func csg_root_of(n: Node) -> CSGShape3D:
	var root: CSGShape3D = null
	var cur: Node = n
	while cur != null and cur is CSGShape3D:
		root = cur as CSGShape3D
		cur = cur.get_parent()
	return root
