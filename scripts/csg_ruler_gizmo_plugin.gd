@tool
class_name CSGRulerGizmoPlugin extends EditorNode3DGizmoPlugin

const HANDLE_TARGET: int = 0
const SNAP_METADATA_SECTION: String = "3d_editor"
const SNAP_METADATA_KEY: String = "snap_translate_value"
const DEFAULT_SNAP_STEP: float = 1.0
const FINE_SNAP_DIVISOR: float = 10.0
const DASH_LENGTH: float = 0.2
const DASH_GAP: float = 0.12
const MIN_SEGMENT_LENGTH: float = 0.001
const COLOR_REACHABLE: Color = Color(0.35, 0.85, 0.45, 0.55)
const COLOR_UNREACHABLE: Color = Color(0.95, 0.35, 0.35, 0.55)
const RULER_SCRIPT = preload("csg_ruler_3d.gd")

func _init() -> void:
	add_material(&"reachable_mat", _build_line_material(COLOR_REACHABLE))
	add_material(&"unreachable_mat", _build_line_material(COLOR_UNREACHABLE))
	create_handle_material(&"handles")

func _build_line_material(color: Color) -> StandardMaterial3D:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.no_depth_test = true
	mat.albedo_color = color
	return mat

func _has_gizmo(for_node_3d: Node3D) -> bool:
	return for_node_3d is RULER_SCRIPT

func _get_gizmo_name() -> String:
	return "CSGRuler"

func _redraw(gizmo: EditorNode3DGizmo) -> void:
	gizmo.clear()
	var ruler: RULER_SCRIPT = gizmo.get_node_3d() as RULER_SCRIPT
	if ruler == null or not ruler.is_visible_in_tree():
		return
	var target: Vector3 = ruler.target_point
	var mat_name: StringName = &"reachable_mat" if ruler.is_jump_reachable else &"unreachable_mat"
	var line_material: StandardMaterial3D = get_material(mat_name, gizmo)
	var origin: Vector3 = Vector3.ZERO
	var ground: Vector3 = Vector3(target.x, 0.0, target.z)
	gizmo.add_lines(PackedVector3Array([origin, target]), line_material)
	gizmo.add_lines(_build_dashed_polyline([origin, ground, target]), line_material)
	gizmo.add_collision_segments(PackedVector3Array([origin, target]))
	gizmo.add_handles(PackedVector3Array([target]), get_material(&"handles", gizmo), PackedInt32Array([HANDLE_TARGET]))

func _build_dashed_polyline(points: Array[Vector3]) -> PackedVector3Array:
	var segments: PackedVector3Array = PackedVector3Array()
	for i: int in range(points.size() - 1):
		var from: Vector3 = points[i]
		var to: Vector3 = points[i + 1]
		var direction: Vector3 = to - from
		var length: float = direction.length()
		if length < MIN_SEGMENT_LENGTH:
			continue
		var distance: float = 0.0
		while distance + DASH_LENGTH <= length:
			var start: Vector3 = from + direction * (distance / length)
			var end: Vector3 = from + direction * ((distance + DASH_LENGTH) / length)
			segments.append(start)
			segments.append(end)
			distance += DASH_LENGTH + DASH_GAP
	return segments

func _get_handle_name(_gizmo: EditorNode3DGizmo, _handle_id: int, _secondary: bool) -> String:
	return "Target Point"

func _get_handle_value(gizmo: EditorNode3DGizmo, _handle_id: int, _secondary: bool) -> Variant:
	var ruler: RULER_SCRIPT = gizmo.get_node_3d() as RULER_SCRIPT
	if ruler == null:
		return Vector3.ZERO
	return ruler.target_point

func _set_handle(gizmo: EditorNode3DGizmo, _handle_id: int, _secondary: bool, camera: Camera3D, screen_pos: Vector2) -> void:
	var ruler: RULER_SCRIPT = gizmo.get_node_3d() as RULER_SCRIPT
	if ruler == null or not is_instance_valid(camera):
		return
	var ray_origin: Vector3 = camera.project_ray_origin(screen_pos)
	var ray_direction: Vector3 = camera.project_ray_normal(screen_pos)
	var local_transform: Transform3D = ruler.global_transform.affine_inverse()
	var local_origin: Vector3 = local_transform * ray_origin
	var local_direction: Vector3 = (local_transform.basis * ray_direction).normalized()
	var plane: Plane = Plane(local_direction, ruler.target_point)
	var hit: Variant = plane.intersects_ray(local_origin, local_direction)
	if hit is Vector3:
		ruler.target_point = _snap_point(hit)

func _commit_handle(gizmo: EditorNode3DGizmo, _handle_id: int, _secondary: bool, restore: Variant, cancel: bool) -> void:
	var ruler: RULER_SCRIPT = gizmo.get_node_3d() as RULER_SCRIPT
	if ruler == null:
		return
	if not (restore is Vector3):
		return
	var previous: Vector3 = restore
	if cancel:
		ruler.target_point = previous
		return
	var current: Vector3 = ruler.target_point
	if current == previous:
		return
	var undo_redo: EditorUndoRedoManager = EditorInterface.get_editor_undo_redo()
	undo_redo.create_action("Set CSGRuler3D Target Point")
	undo_redo.add_do_property(ruler, "target_point", current)
	undo_redo.add_undo_property(ruler, "target_point", previous)
	undo_redo.commit_action()

func _snap_point(point: Vector3) -> Vector3:
	var step: float = _get_snap_step()
	if step <= 0.0:
		return point
	return point.snapped(Vector3(step, step, step))

func _get_snap_step() -> float:
	var settings: EditorSettings = EditorInterface.get_editor_settings()
	if settings == null:
		return DEFAULT_SNAP_STEP
	var raw: Variant = settings.get_project_metadata(SNAP_METADATA_SECTION, SNAP_METADATA_KEY, DEFAULT_SNAP_STEP)
	var step: float = DEFAULT_SNAP_STEP
	if raw is float or raw is int:
		step = float(raw)
	if step <= 0.0:
		return 0.0
	if Input.is_key_pressed(KEY_SHIFT):
		step /= FINE_SNAP_DIVISOR
	return step

