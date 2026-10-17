@tool
class_name CsgBlockoutFaceDrag
extends CsgBlockoutTool
## Face push/pull through arrow handles: every face of a selected box, cylinder or
## stairs that faces the camera shows an arrow; drag it to move that face along its
## normal. The opposite face stays put, axis-aligned faces land on grid lines, and the
## drag is one undo step. No modifier key, so Shift stays Godot's multi-select.
## Supported: CSGBox3D (6 faces), CSGCylinder3D (caps -> height, side -> radius),
## CSGStairs3D (top -> height, front -> depth, sides -> width), the plugin's other shapes
## (wedge, arch, curved wall, spiral stairs: their own faces, through the shape protocol
## in CsgBlockoutShapeInfo), and rooms from the Room tool (selected as a whole or by
## their Shell), which resize as rooms: the walls keep their thickness (see
## CsgBlockoutRoom). With a room's Shell selected, Godot's own size handles on its far
## faces resize the room this way too.

## Mouse travel (px) before a press on a handle becomes a drag.
const DRAG_THRESHOLD: float = 3.0
const MIN_EXTENT: float = 0.01
## Handles are drawn for at most this many selected shapes.
const MAX_HANDLE_NODES: int = 4
const HANDLE_RADIUS: float = 6.0
const ARROW_LENGTH: float = 24.0
const PICK_RADIUS: float = 11.0
## Cyan, so it never blends with Godot's orange selection box.
const COLOR: Color = Color(0.3, 0.9, 1.0)

var _hover: Dictionary = {}
var _drag: Dictionary = {}
var _press_pos: Vector2 = Vector2.ZERO

func get_id() -> StringName:
	return &"face_drag"

static func supports(n: Node) -> bool:
	return n is CSGBox3D or n is CSGCylinder3D or n is CSGStairs3D or CsgBlockoutShapeInfo.has_protocol(n)

func input(camera: Camera3D, event: InputEvent) -> int:
	if manager.active != null:
		_hover = {}
		return PASS
	if event is InputEventMouseMotion:
		var mm: InputEventMouseMotion = event as InputEventMouseMotion
		if not _drag.is_empty():
			if not _drag["moved"] and mm.position.distance_to(_press_pos) < DRAG_THRESHOLD:
				return STOP
			_drag["moved"] = true
			_update_drag(camera, mm.position, mm)
			return STOP
		var previous: String = _key(_hover)
		_hover = _pick(camera, mm.position)
		if _key(_hover) != previous:
			manager.refresh()
		return PASS
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.pressed:
			if mb.double_click:
				return PASS
			var handle: Dictionary = _pick(camera, mb.position)
			if handle.is_empty():
				return PASS
			_begin(handle, mb.position)
			return STOP
		if not _drag.is_empty():
			_finish()
			return STOP
	return PASS

# --- handles -------------------------------------------------------------------------

## Handles of the selected shapes' camera-facing faces:
## [{"node", "face", "point" (world anchor), "screen", "dir" (screen arrow direction)}].
## A selected room gets the handles of its Shell. `far_room_faces` adds the faces
## turned away from the camera of a selected room Shell (no arrow: "dir" is zero),
## where Godot draws its own size handles.
func _handles(camera: Camera3D, far_room_faces: bool = false) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if camera == null:
		return out
	var count: int = 0
	var seen: Array[Node] = []
	for n: Node in EditorInterface.get_selection().get_selected_nodes():
		if count >= MAX_HANDLE_NODES:
			break
		var room: CSGCombiner3D = CsgBlockoutRoom.room_of(n)
		var target: Node = CsgBlockoutRoom.shell_of(room) if room != null else n
		if target in seen or not supports(target) or not (target as Node3D).is_visible_in_tree():
			continue
		seen.append(target)
		count += 1
		var node: Node3D = target as Node3D
		var far_faces: bool = far_room_faces and room != null and n == target
		var xf: Transform3D = node.global_transform
		for face: Dictionary in CsgBlockoutShapeInfo.push_faces(node):
			var normal: Vector3 = (xf.basis * (face["normal"] as Vector3)).normalized()
			var anchor: Vector3 = xf * (face["center"] as Vector3)
			if face["radial"]:
				# Cylinder side: put the handle on the side that faces the camera.
				var up: Vector3 = xf.basis.y.normalized()
				var to_cam: Vector3 = camera.global_position - xf.origin
				to_cam -= up * to_cam.dot(up)
				if to_cam.length() < 0.001:
					continue
				normal = to_cam.normalized()
				anchor = xf.origin + normal * ((node as CSGCylinder3D).radius * xf.basis.x.length())
			if camera.is_position_behind(anchor):
				continue
			if normal.dot(camera.global_position - anchor) <= 0.0:
				if far_faces:
					out.append({"node": node, "face": face, "point": anchor, "screen": camera.unproject_position(anchor), "dir": Vector2.ZERO})
				continue
			var screen: Vector2 = camera.unproject_position(anchor)
			var dir: Vector2 = Vector2.ZERO
			if not camera.is_position_behind(anchor + normal * 0.25):
				dir = camera.unproject_position(anchor + normal * 0.25) - screen
			dir = dir.normalized() if dir.length() > 0.5 else Vector2.ZERO
			out.append({"node": node, "face": face, "point": anchor, "screen": screen, "dir": dir})
	return out

## The handle under `pos` (arrow or knob), or {}.
func _pick(camera: Camera3D, pos: Vector2) -> Dictionary:
	var p: Vector2 = manager.ray_pos(pos)
	var scale: float = EditorInterface.get_editor_scale()
	var best: Dictionary = {}
	var best_d: float = PICK_RADIUS * scale
	for h: Dictionary in _handles(camera, true):
		var screen: Vector2 = h["screen"]
		var tip: Vector2 = screen + (h["dir"] as Vector2) * ARROW_LENGTH * scale
		var d: float = Geometry2D.get_closest_point_to_segment(p, screen, tip).distance_to(p)
		if d < best_d:
			best_d = d
			best = h
	return best

## The handle's node still exists and is in the edited scene (not a closed one).
static func _alive(h: Dictionary) -> bool:
	return not h.is_empty() and is_instance_valid(h.get("node")) and (h["node"] as Node).is_inside_tree()

static func _key(h: Dictionary) -> String:
	if not _alive(h):
		return ""
	return "%d:%d" % [(h["node"] as Node).get_instance_id(), int(h["face"]["id"])]

# --- dragging ----------------------------------------------------------------------

func _begin(handle: Dictionary, pos: Vector2) -> void:
	var node: Node3D = handle["node"]
	var face: Dictionary = handle["face"]
	var world_normal: Vector3 = (node.global_transform.basis * (face["normal"] as Vector3)).normalized()
	if face["radial"]:
		var radial: Vector3 = (handle["point"] as Vector3) - node.global_position
		radial = radial - node.global_transform.basis.y.normalized() * radial.dot(node.global_transform.basis.y.normalized())
		world_normal = radial.normalized() if radial.length() > 0.0001 else world_normal
	var props: Dictionary = {}
	for p: StringName in _props_for(node):
		props[p] = node.get(p)
	_press_pos = pos
	_drag = {
		"node": node,
		"face": face,
		"normal": world_normal,
		"start_point": handle["point"],
		"start_props": props,
		"start_xform": node.global_transform,
		"delta": 0.0,
		"moved": false,
	}
	var room: CSGCombiner3D = CsgBlockoutRoom.room_of(node)
	if room != null:
		_drag["room"] = CsgBlockoutRoom.Resize.new(room, face["axis"])
	_hover = handle

static func _props_for(n: Node3D) -> Array[StringName]:
	if n is CSGBox3D:
		return [&"size"]
	if n is CSGCylinder3D:
		return [&"height", &"radius"]
	if n is CSGStairs3D:
		return [&"total_height", &"total_depth", &"width"]
	if CsgBlockoutShapeInfo.has_protocol(n):
		return n.call(&"blockout_resize_props")
	return []

func _update_drag(camera: Camera3D, pos: Vector2, event: InputEvent) -> void:
	var rp: Vector2 = manager.ray_pos(pos)
	var o: Vector3 = camera.project_ray_origin(rp)
	var d: Vector3 = camera.project_ray_normal(rp)
	var n: Vector3 = _drag["normal"]
	var p0: Vector3 = _drag["start_point"]
	var w0: Vector3 = p0 - o
	var b: float = n.dot(d)
	var denom: float = 1.0 - b * b
	if denom < 0.0001:
		return
	var t: float = (b * d.dot(w0) - n.dot(w0)) / denom
	var grid: CsgBlockoutGrid = CsgBlockoutGrid.get_grid()
	var active: bool = grid.is_active(event)
	var delta: float = t
	if active:
		var axis_index: int = n.abs().max_axis_index()
		if absf(n[axis_index]) > 0.9999 and not _drag["face"]["radial"]:
			# World-aligned face: put the face itself on a grid line.
			var face_coord: float = _face_world_coord(axis_index)
			var target: float = snappedf(face_coord + t * signf(n[axis_index]), grid.size)
			delta = (target - face_coord) * signf(n[axis_index])
		else:
			delta = snappedf(t, grid.size)
	_drag["delta"] = _apply(delta)
	manager.refresh()

## World coordinate (along axis) of the dragged face at drag start.
func _face_world_coord(axis_index: int) -> float:
	var node: Node3D = _drag["node"]
	var xf: Transform3D = _drag["start_xform"]
	var face: Dictionary = _drag["face"]
	var center: Vector3 = face["center"]
	# Face centers in push_faces() reflect the current size; rebuild from start values.
	if node is CSGBox3D:
		var s: Vector3 = _drag["start_props"][&"size"]
		center = (face["normal"] as Vector3) * s[face["axis"]] * 0.5
	elif node is CSGCylinder3D:
		center = Vector3(0, float(_drag["start_props"][&"height"]) * 0.5 * float(face["sign"]), 0)
	return (xf * center)[axis_index]

## Applies a world-space push of `delta` meters (clamped so the shape never inverts).
## Returns the delta actually applied.
func _apply(delta: float) -> float:
	var node: Node3D = _drag["node"]
	var face: Dictionary = _drag["face"]
	var start: Dictionary = _drag["start_props"]
	var xf: Transform3D = _drag["start_xform"]
	var axis: int = face["axis"]
	var axis_scale: float = maxf(xf.basis[axis].length(), 0.0001)
	var axis_dir: Vector3 = xf.basis[axis].normalized()
	var applied: float = delta
	if _drag.has("room"):
		var grow: Vector2 = (_drag["room"] as CsgBlockoutRoom.Resize).apply(delta if int(face["sign"]) > 0 else 0.0, delta if int(face["sign"]) < 0 else 0.0)
		applied = grow.x + grow.y
	elif node is CSGBox3D:
		var size: Vector3 = start[&"size"]
		var new_len: float = maxf(size[axis] + delta / axis_scale, MIN_EXTENT)
		applied = (new_len - size[axis]) * axis_scale
		size[axis] = new_len
		(node as CSGBox3D).size = size
		node.global_position = xf.origin + axis_dir * (float(face["sign"]) * applied * 0.5)
	elif node is CSGCylinder3D:
		var c: CSGCylinder3D = node as CSGCylinder3D
		if face["radial"]:
			var new_r: float = maxf(float(start[&"radius"]) + delta / axis_scale, MIN_EXTENT)
			applied = (new_r - float(start[&"radius"])) * axis_scale
			c.radius = new_r
		else:
			var y_scale: float = maxf(xf.basis.y.length(), 0.0001)
			var new_h: float = maxf(float(start[&"height"]) + delta / y_scale, MIN_EXTENT)
			applied = (new_h - float(start[&"height"])) * y_scale
			c.height = new_h
			node.global_position = xf.origin + xf.basis.y.normalized() * (float(face["sign"]) * applied * 0.5)
	elif CsgBlockoutShapeInfo.has_protocol(node):
		# The shape works in local meters along the face normal from its start values.
		var normal_scale: float = maxf((xf.basis * (face["normal"] as Vector3)).length(), 0.0001)
		var result: Dictionary = node.call(&"blockout_push", int(face["id"]), delta / normal_scale, start)
		applied = float(result["applied"]) * normal_scale
		node.global_position = xf.origin + xf.basis * (result["offset"] as Vector3)
	elif node is CSGStairs3D:
		var s: CSGStairs3D = node as CSGStairs3D
		match int(face["id"]):
			3:
				var new_h: float = maxf(float(start[&"total_height"]) + delta / axis_scale, MIN_EXTENT)
				applied = (new_h - float(start[&"total_height"])) * axis_scale
				s.total_height = new_h
			1:
				var new_d: float = maxf(float(start[&"total_depth"]) + delta / axis_scale, MIN_EXTENT)
				applied = (new_d - float(start[&"total_depth"])) * axis_scale
				s.total_depth = new_d
			4, 5:
				var new_w: float = maxf(float(start[&"width"]) + delta / axis_scale, MIN_EXTENT)
				applied = (new_w - float(start[&"width"])) * axis_scale
				s.width = new_w
				if int(face["id"]) == 4:
					# Extrusion runs toward -Z from the origin: growing the +Z side moves the origin.
					node.global_position = xf.origin + axis_dir * applied
	return applied

func _finish() -> void:
	var node: Node3D = _drag["node"]
	if not _drag["moved"]:
		# Clicked a handle without dragging: nothing to do.
		_drag = {}
		manager.refresh()
		return
	if _drag.has("room"):
		(_drag["room"] as CsgBlockoutRoom.Resize).commit(CsgBlockoutI18n.t("PUSH_FACE_ACTION"))
		_drag = {}
		manager.refresh()
		return
	var final_props: Dictionary = {}
	for p: StringName in _drag["start_props"]:
		final_props[p] = node.get(p)
	var final_pos: Vector3 = node.global_position
	# Restore, then record start -> final as a single undo step.
	for p: StringName in _drag["start_props"]:
		node.set(p, _drag["start_props"][p])
	node.global_transform = _drag["start_xform"]
	var action: CsgBlockoutSceneOps.Action = CsgBlockoutSceneOps.Action.new(CsgBlockoutI18n.t("PUSH_FACE_ACTION"))
	for p: StringName in final_props:
		if final_props[p] != _drag["start_props"][p]:
			action.set_property(node, p, final_props[p])
	if not final_pos.is_equal_approx(node.global_position):
		action.set_property(node, &"global_position", final_pos)
	action.commit()
	if node is CSGBox3D:
		CsgBlockoutDrawTool.note_resized(node, (node as CSGBox3D).size)
	_drag = {}
	manager.refresh()

# --- overlay -------------------------------------------------------------------------

func draw_overlay(overlay: Control, camera: Camera3D) -> void:
	if camera == null or manager.active != null:
		return
	var scale: float = EditorInterface.get_editor_scale()
	var current: Dictionary = _drag if not _drag.is_empty() else _hover
	if not current.is_empty() and _alive(current):
		var outline: PackedVector2Array = _face_outline(current["node"], current["face"], camera)
		if outline.size() >= 3:
			var fill: Color = COLOR
			fill.a = 0.3
			if not Geometry2D.triangulate_polygon(outline).is_empty():
				overlay.draw_colored_polygon(outline, fill)
			var closed: PackedVector2Array = outline.duplicate()
			closed.append(outline[0])
			overlay.draw_polyline(closed, COLOR, 2.5 * scale, true)
	if _drag.is_empty():
		var hot: String = _key(_hover)
		for h: Dictionary in _handles(camera):
			_draw_handle(overlay, h, _key(h) == hot, scale)
	elif _drag["moved"]:
		var node: Node3D = _drag["node"]
		var font: Font = overlay.get_theme_font(&"font", &"Label")
		var world: Vector3 = (_drag["start_point"] as Vector3) + (_drag["normal"] as Vector3) * float(_drag["delta"])
		if not camera.is_position_behind(world):
			var size: Vector3 = CsgBlockoutShapeInfo.world_size(node)
			var text: String = "%+.2f m  ·  %s × %s × %s m" % [float(_drag["delta"]), CsgBlockoutDrawTool._fmt(size.x), CsgBlockoutDrawTool._fmt(size.y), CsgBlockoutDrawTool._fmt(size.z)]
			CsgBlockoutToolManager.draw_label(overlay, font, int(round(13 * scale)), camera.unproject_position(world) + Vector2(14, -14) * scale, text, true)

## Knob on the face with an arrow pointing out of it.
func _draw_handle(overlay: Control, h: Dictionary, hot: bool, s: float) -> void:
	var screen: Vector2 = h["screen"]
	var dir: Vector2 = h["dir"]
	var color: Color = COLOR if hot else COLOR.darkened(0.2)
	if dir != Vector2.ZERO:
		var tip: Vector2 = screen + dir * ARROW_LENGTH * s * (1.15 if hot else 1.0)
		var side: Vector2 = Vector2(-dir.y, dir.x)
		overlay.draw_line(screen, tip, Color(0, 0, 0, 0.5), 5.0 * s, true)
		overlay.draw_line(screen, tip, color, 2.5 * s, true)
		var head: PackedVector2Array = PackedVector2Array([tip + dir * 8.0 * s, tip + side * 5.5 * s, tip - side * 5.5 * s])
		overlay.draw_colored_polygon(head, color)
	var r: float = HANDLE_RADIUS * s * (1.3 if hot else 1.0)
	overlay.draw_circle(screen, r + 1.5 * s, Color(0, 0, 0, 0.55))
	overlay.draw_circle(screen, r, color)
	overlay.draw_circle(screen, r * 0.4, Color(1, 1, 1, 0.95))

## Screen-space outline of a face (empty if any corner is behind the camera).
func _face_outline(node: Node3D, face: Dictionary, camera: Camera3D) -> PackedVector2Array:
	var pts3: PackedVector3Array = PackedVector3Array()
	var xf: Transform3D = node.global_transform
	if node is CSGCylinder3D:
		var c: CSGCylinder3D = node as CSGCylinder3D
		if face["radial"]:
			var to_cam: Vector3 = xf.affine_inverse() * camera.global_position
			var side: Vector3 = Vector3(-to_cam.z, 0, to_cam.x).normalized() * c.radius
			for y: float in [c.height * 0.5, -c.height * 0.5]:
				pts3.append(Vector3(-side.x, y, -side.z))
				pts3.append(Vector3(side.x, y, side.z))
			pts3 = PackedVector3Array([pts3[0], pts3[1], pts3[3], pts3[2]])
		else:
			var y: float = c.height * 0.5 * float(face["sign"])
			for i: int in 24:
				var a: float = TAU * float(i) / 24.0
				pts3.append(Vector3(cos(a) * c.radius, y, sin(a) * c.radius))
	elif CsgBlockoutShapeInfo.has_protocol(node):
		pts3 = node.call(&"blockout_face_outline", int(face["id"]))
	if pts3.is_empty():
		# Boxes, stairs, and protocol faces without an outline of their own.
		var box: AABB = CsgBlockoutShapeInfo.local_aabb(node)
		var corners: PackedVector3Array = CsgBlockoutShapeInfo.box_face_corners(box.size * 0.5, face["axis"], face["sign"])
		for p: Vector3 in corners:
			pts3.append(p + box.get_center())
	var out: PackedVector2Array = PackedVector2Array()
	for p: Vector3 in pts3:
		var w: Vector3 = xf * p
		if camera.is_position_behind(w):
			return PackedVector2Array()
		out.append(camera.unproject_position(w))
	return out
