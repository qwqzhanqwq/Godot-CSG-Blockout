@tool
class_name CsgBlockoutMeasureOverlay
extends CsgBlockoutTool
## Passive overlay: dimension lines with W/H/D labels (meters) on the selected CSG
## shapes and frozen blockout, drawn along the bottom edges nearest the camera.
## The labels of boxes, cylinders, stairs, rooms and the plugin's other shapes are
## editable (the curved wall and spiral stairs only their height): click one, type a
## size, Enter (Esc cancels). Height grows from the bottom, width and depth from the
## center; rooms keep their wall thickness.
## Toggled from the "⋯" menu; the setting is stored per user.

const MAX_LABELED: int = 8
const META_KEY: String = "show_dimensions"
const COLORS: Array[Color] = [Color(1.0, 0.45, 0.45), Color(0.5, 0.95, 0.5), Color(0.45, 0.65, 1.0)]
const EDIT_ACCENT: Color = Color(0.3, 0.9, 1.0)

static var enabled: bool = true
static var _loaded: bool = false

## Clickable labels drawn last, per camera: [{"rect": Rect2, "node": Node3D, "axis": int}].
var _labels: Dictionary = {}
var _hover_label: Dictionary = {}
var _pressed_label: Dictionary = {}
var _editor: LineEdit

static func load_state() -> void:
	if _loaded:
		return
	_loaded = true
	var settings: EditorSettings = EditorInterface.get_editor_settings()
	enabled = bool(settings.get_project_metadata(CsgBlockoutGrid.META_SECTION, META_KEY, true))

static func set_enabled(value: bool) -> void:
	enabled = value
	EditorInterface.get_editor_settings().set_project_metadata(CsgBlockoutGrid.META_SECTION, META_KEY, value)

func get_id() -> StringName:
	return &"measure_overlay"

static func editable(n: Node) -> bool:
	return n is CSGBox3D or n is CSGCylinder3D or n is CSGStairs3D or CsgBlockoutShapeInfo.has_protocol(n)

## Whether the label of local `axis` (0 W, 1 H, 2 D) of an editable node takes a size.
static func editable_axis(n: Node, axis: int) -> bool:
	if CsgBlockoutShapeInfo.has_protocol(n):
		return axis in (n.call(&"blockout_editable_axes") as PackedInt32Array)
	return editable(n)

func input(camera: Camera3D, event: InputEvent) -> int:
	if manager.active != null or not enabled:
		return PASS
	if event is InputEventMouseMotion:
		var hit: Dictionary = _label_at(camera, (event as InputEventMouseMotion).position)
		if _label_key(hit) != _label_key(_hover_label):
			_hover_label = hit
			manager.refresh()
		return PASS
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if not mb.pressed:
			if _pressed_label.is_empty():
				return PASS
			# Open on release, once the viewport is done with the click (it would take
			# the focus back from the editor otherwise).
			_open_editor.call_deferred(_pressed_label)
			_pressed_label = {}
			return STOP
		var label: Dictionary = _label_at(camera, mb.position)
		if label.is_empty():
			return PASS
		_pressed_label = label
		return STOP
	return PASS

func _label_at(camera: Camera3D, pos: Vector2) -> Dictionary:
	if camera == null:
		return {}
	var p: Vector2 = manager.ray_pos(pos)
	for entry: Dictionary in _labels.get(camera.get_instance_id(), []):
		if (entry["rect"] as Rect2).grow(2.0).has_point(p) and is_instance_valid(entry["node"]) and (entry["node"] as Node).is_inside_tree():
			return entry
	return {}

static func _label_key(entry: Dictionary) -> String:
	if entry.is_empty() or not is_instance_valid(entry.get("node")):
		return ""
	return "%d:%d" % [(entry["node"] as Node).get_instance_id(), int(entry["axis"])]

func draw_overlay(overlay: Control, camera: Camera3D) -> void:
	load_state()
	if camera == null:
		return
	var labels: Array[Dictionary] = []
	_labels[camera.get_instance_id()] = labels
	if not enabled:
		return
	# Labels step aside from the face handles too, so both stay clickable.
	var placed: Array[Rect2] = _handle_rects(camera)
	var count: int = 0
	var seen: Array[Node] = []
	for n: Node in EditorInterface.get_selection().get_selected_nodes():
		if count >= MAX_LABELED:
			break
		# A room is measured (and resized) by its Shell, without the frames sticking out.
		var room: CSGCombiner3D = CsgBlockoutRoom.room_of(n)
		var target: Node = CsgBlockoutRoom.shell_of(room) if room != null else n
		if target in seen:
			continue
		seen.append(target)
		if target is CSGShape3D or CsgBlockoutFreeze.is_frozen(target):
			if _draw_dimensions(overlay, camera, target as Node3D, placed, labels):
				count += 1

## Draws three dimension lines from the bottom corner closest to the camera; labels
## step aside when they would cover one already drawn.
func _draw_dimensions(overlay: Control, camera: Camera3D, n: Node3D, placed: Array[Rect2], labels: Array[Dictionary]) -> bool:
	var box: AABB = CsgBlockoutShapeInfo.local_aabb(n) if n is CSGShape3D else (n as VisualInstance3D).get_aabb()
	if box.size == Vector3.ZERO:
		return false
	var xf: Transform3D = n.global_transform
	var cam_local: Vector3 = xf.affine_inverse() * camera.global_position
	var anchor: Vector3 = Vector3(
		box.end.x if cam_local.x > box.get_center().x else box.position.x,
		box.position.y,
		box.end.z if cam_local.z > box.get_center().z else box.position.z)
	var ends: Array[Vector3] = [
		Vector3(box.position.x + box.end.x - anchor.x, anchor.y, anchor.z),
		Vector3(anchor.x, box.end.y, anchor.z),
		Vector3(anchor.x, anchor.y, box.position.z + box.end.z - anchor.z),
	]
	var scale: float = EditorInterface.get_editor_scale()
	var font: Font = overlay.get_theme_font(&"font", &"Label")
	var font_size: int = int(round(12 * scale))
	var world_size: Vector3 = CsgBlockoutShapeInfo.world_size(n) if n is CSGShape3D else box.size * xf.basis.get_scale()
	var a_world: Vector3 = xf * anchor
	if camera.is_position_behind(a_world):
		return false
	var a2: Vector2 = camera.unproject_position(a_world)
	var can_edit: bool = editable(n)
	for axis: int in 3:
		var b_world: Vector3 = xf * ends[axis]
		if camera.is_position_behind(b_world):
			continue
		var b2: Vector2 = camera.unproject_position(b_world)
		if a2.distance_to(b2) < 12.0 * scale:
			continue
		var color: Color = COLORS[axis]
		overlay.draw_line(a2, b2, color, 2.0 * scale, true)
		var dir: Vector2 = (b2 - a2).normalized()
		var tick: Vector2 = Vector2(-dir.y, dir.x) * 5.0 * scale
		overlay.draw_line(a2 - tick, a2 + tick, color, 2.0 * scale, true)
		overlay.draw_line(b2 - tick, b2 + tick, color, 2.0 * scale, true)
		var label: String = "%s %s m" % ["WHD"[axis], CsgBlockoutDrawTool._fmt(world_size[axis])]
		var text_size: Vector2 = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		var pos: Vector2 = (a2 + b2) * 0.5 + tick * 3.5 - Vector2(text_size.x * 0.5, 0.0)
		var rect: Rect2 = _label_rect(font, font_size, pos, text_size, scale)
		# Step away from labels already drawn (small shapes put them on top of each other).
		var away: Vector2 = tick.normalized() if tick.length() > 0.001 else Vector2.DOWN
		for attempt: int in 6:
			if not placed.any(func(r: Rect2) -> bool: return r.intersects(rect)):
				break
			pos += away * (rect.size.y + 3.0 * scale)
			rect = _label_rect(font, font_size, pos, text_size, scale)
		placed.append(rect)
		var drawn: Rect2 = CsgBlockoutToolManager.draw_label(overlay, font, font_size, pos, label, false)
		if can_edit and editable_axis(n, axis):
			var entry: Dictionary = {"rect": drawn, "node": n, "axis": axis}
			labels.append(entry)
			if _label_key(entry) == _label_key(_hover_label):
				overlay.draw_rect(drawn.grow(1.0), EDIT_ACCENT, false, 1.5 * scale)
	return true

## Screen areas of the face handles' knobs and arrow tips.
func _handle_rects(camera: Camera3D) -> Array[Rect2]:
	var out: Array[Rect2] = []
	var scale: float = EditorInterface.get_editor_scale()
	var r: float = CsgBlockoutFaceDrag.PICK_RADIUS * scale
	for tool: CsgBlockoutTool in manager.passives:
		if tool is CsgBlockoutFaceDrag:
			for h: Dictionary in (tool as CsgBlockoutFaceDrag)._handles(camera):
				var knob: Vector2 = h["screen"]
				var tip: Vector2 = knob + (h["dir"] as Vector2) * CsgBlockoutFaceDrag.ARROW_LENGTH * scale
				out.append(Rect2(knob - Vector2(r, r), Vector2(r, r) * 2.0).merge(Rect2(tip - Vector2(r, r), Vector2(r, r) * 2.0)))
	return out

static func _label_rect(font: Font, font_size: int, pos: Vector2, text_size: Vector2, scale: float) -> Rect2:
	var pad: Vector2 = Vector2(6.0, 3.0) * scale
	return Rect2(pos + Vector2(-pad.x, -font.get_ascent(font_size) - pad.y), text_size + pad * 2.0)

# --- typing a size -------------------------------------------------------------------

func _open_editor(entry: Dictionary) -> void:
	_close_editor()
	var node: Node3D = entry["node"]
	var axis: int = entry["axis"]
	var scale: float = EditorInterface.get_editor_scale()
	var rect: Rect2 = entry["rect"]
	var edit: LineEdit = LineEdit.new()
	edit.name = "CsgBlockoutDimensionEdit"
	edit.text = CsgBlockoutDrawTool._fmt(CsgBlockoutShapeInfo.world_size(node)[axis])
	edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	edit.select_all_on_focus = true
	edit.custom_minimum_size = Vector2(maxf(rect.size.x, 72.0 * scale), rect.size.y + 4.0 * scale)
	edit.top_level = true
	EditorInterface.get_base_control().add_child(edit)
	edit.global_position = manager.to_global(rect.position - Vector2(0.0, 2.0 * scale))
	edit.text_submitted.connect(func(text: String) -> void:
		_close_editor()
		apply_size(node, axis, text))
	edit.focus_exited.connect(_close_editor)
	edit.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventKey and ev.is_pressed() and (ev as InputEventKey).keycode == KEY_ESCAPE:
			edit.accept_event()
			_close_editor())
	_editor = edit
	edit.grab_focus()
	edit.select_all()

func _close_editor() -> void:
	if _editor != null and is_instance_valid(_editor):
		var edit: LineEdit = _editor
		_editor = null
		edit.queue_free()
	manager.refresh()

## Sets the world size of `node` along local `axis` (0 W, 1 H, 2 D) from typed text
## such as "2.5", "2,5" or "2.5 m", as one undo step. Returns false for bad input.
static func apply_size(node: Node3D, axis: int, text: String) -> bool:
	var value: float = text.strip_edges().replace(",", ".").trim_suffix("m").strip_edges().to_float()
	if value <= 0.0 or not is_instance_valid(node) or not node.is_inside_tree():
		return false
	var xf: Transform3D = node.global_transform
	var axis_scale: float = maxf(xf.basis[axis].length(), 0.0001)
	var local: float = value / axis_scale
	var up: Vector3 = xf.basis.y.normalized()
	var room: CSGCombiner3D = CsgBlockoutRoom.room_of(node)
	if room != null and node is CSGBox3D:
		# A room's Shell: resize the room, keeping its walls as thick as they are.
		var resize: CsgBlockoutRoom.Resize = CsgBlockoutRoom.Resize.new(room, axis)
		var grow: float = value - (node as CSGBox3D).size[axis] * axis_scale
		if axis == 1:
			resize.apply(grow, 0.0)
		else:
			resize.apply(grow * 0.5, grow * 0.5)
		resize.commit(CsgBlockoutI18n.t("RESIZE_ACTION"))
		return true
	var action: CsgBlockoutSceneOps.Action = CsgBlockoutSceneOps.Action.new(CsgBlockoutI18n.t("RESIZE_ACTION"))
	if node is CSGBox3D:
		var size: Vector3 = (node as CSGBox3D).size
		var grow: float = (local - size[axis]) * axis_scale
		size[axis] = local
		action.set_property(node, &"size", size)
		if axis == 1:
			# Keep the bottom where it is: rest on the same surface, grow upward.
			action.set_property(node, &"global_position", xf.origin + up * (grow * 0.5))
	elif node is CSGCylinder3D:
		var c: CSGCylinder3D = node as CSGCylinder3D
		if axis == 1:
			action.set_property(node, &"height", local)
			action.set_property(node, &"global_position", xf.origin + up * ((local - c.height) * axis_scale * 0.5))
		else:
			action.set_property(node, &"radius", local * 0.5)
	elif node is CSGStairs3D:
		var props: Array[StringName] = [&"total_depth", &"total_height", &"width"]
		action.set_property(node, props[axis], local)
	elif CsgBlockoutShapeInfo.has_protocol(node):
		var props: Dictionary = node.call(&"blockout_size_props", axis, local)
		if props.is_empty():
			return false
		for prop: StringName in props:
			action.set_property(node, prop, props[prop])
	else:
		return false
	action.commit()
	if node is CSGBox3D:
		CsgBlockoutDrawTool.note_resized(node, (node as CSGBox3D).size)
	return true

## With exactly two nodes selected: adds a ruler between their closest top edges,
## which shows whether the gap is jumpable with the current player metrics.
static func check_jump_between_selection() -> void:
	var nodes: Array[Node3D] = CsgBlockoutSelection.top_level_nodes()
	if nodes.size() != 2:
		CsgBlockoutStatus.report(CsgBlockoutI18n.t("WARN_SELECT_TWO"), EditorToaster.SEVERITY_WARNING)
		return
	var a: AABB = CsgBlockoutSelection.world_aabb(nodes[0])
	var b: AABB = CsgBlockoutSelection.world_aabb(nodes[1])
	# Closest points between the two top rectangles (alternate clamping converges for boxes).
	var pa: Vector2 = Vector2(a.get_center().x, a.get_center().z)
	var pb: Vector2 = Vector2(b.get_center().x, b.get_center().z)
	for i: int in 3:
		pb = Vector2(clampf(pa.x, b.position.x, b.end.x), clampf(pa.y, b.position.z, b.end.z))
		pa = Vector2(clampf(pb.x, a.position.x, a.end.x), clampf(pb.y, a.position.z, a.end.z))
	var from: Vector3 = Vector3(pa.x, a.end.y, pa.y)
	var to: Vector3 = Vector3(pb.x, b.end.y, pb.y)
	# Measure from the lower top to the higher one (the direction you'd jump up).
	if from.y > to.y:
		var tmp: Vector3 = from
		from = to
		to = tmp
	var ruler: CSGRuler3D = CSGRuler3D.new()
	var parent: Node = CsgBlockoutSceneOps.edited_root()
	ruler.name = CsgBlockoutSceneOps.unique_child_name(parent, "JumpCheck")
	ruler.target_point = to - from
	CsgBlockoutSceneOps.Action.new(CsgBlockoutI18n.t("CHECK_JUMP_ACTION")).add_node(parent, ruler, -1, Transform3D(Basis.IDENTITY, from)).select([ruler]).commit()
	var gap: float = Vector2(to.x - from.x, to.z - from.z).length()
	var rise: float = to.y - from.y
	var key: String = "JUMP_RESULT_OK" if ruler.is_jump_reachable else "JUMP_RESULT_FAIL"
	CsgBlockoutStatus.report(CsgBlockoutI18n.tf(key, [CsgBlockoutDrawTool._fmt(gap), CsgBlockoutDrawTool._fmt(rise)]),
		EditorToaster.SEVERITY_INFO if ruler.is_jump_reachable else EditorToaster.SEVERITY_WARNING)
