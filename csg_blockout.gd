@tool
class_name CsgBlockout extends EditorPlugin
var config: CsgBlockoutConfig:
	get: return CsgBlockoutConfig.get_config()

var sidebar: CSGSideBlockoutBar
var topbar: CSGTopBlockoutBar
var ruler_gizmo_plugin: CSGRulerGizmoPlugin
var player_ref_gizmo_plugin: CSGPlayerReferenceGizmoPlugin
var tools: CsgBlockoutToolManager
var _draw_tool: CsgBlockoutDrawTool
var _opening_tool: CsgBlockoutOpeningTool
var _export_plugin: CsgBlockoutExportPlugin
var _frozen_inspector: CsgBlockoutFrozenInspector
var _mesh_inspector: CsgBlockoutMeshInspector
var outliner: CsgBlockoutOutliner
var _outliner_dock: Control

static var csg_plugin_path: String
static var undo_manager: EditorUndoRedoManager

var pie_menu: CsgPieMenu
var pie_menu_tab_pressed_time: int = 0
# Viewport camera and cursor position where the pie menu was opened; new shapes
# are placed on the surface under that point.
var _pie_camera: Camera3D
var _pie_screen_pos: Vector2 = Vector2.ZERO
## Second click on the same tool button within this time keeps the tool on.
const TOOL_DOUBLE_CLICK_MS: int = 400
var _last_tool_click: StringName = &""
var _last_tool_click_time: int = 0

static func _icon(file_name: String) -> Texture2D:
	var path: String = csg_plugin_path.path_join("res/icons").path_join(file_name)
	return load(path) as Texture2D if ResourceLoader.exists(path) else null

## Shapes ▸: primitives created as union on the surface under the cursor.
func _get_shape_menu() -> Array[Dictionary]:
	var shapes: Array[Dictionary] = []
	for entry: Array in [
		["BOX", "CSGBox3D", "box.svg"], ["CYLINDER", "CSGCylinder3D", "cyliner.svg"],
		["STAIRS", "CSGStairs3D", "stairs.svg"], ["SPHERE", "CSGSphere3D", "sphere.svg"],
		["WEDGE", "CSGWedge3D", "wedge.svg"], ["SPIRAL_STAIRS", "CSGSpiralStairs3D", "spiral_stairs.svg"],
		["ARCH", "CSGArch3D", "arch.svg"], ["CURVED_WALL", "CSGCurvedWall3D", "curved_wall.svg"],
		["TORUS", "CSGTorus3D", "torus.svg"], ["POLYGON", "CSGPolygon3D", "polygon.svg"],
		["MESH", "CSGMesh3D", "mesh.svg"]]:
		shapes.append({"label": CsgBlockoutI18n.t(entry[0]), "type": "create_csg", "csg_type": entry[1], "icon": _icon(entry[2])})
	return shapes

## Top level, clockwise from the top: the tools, Play, then the two submenus.
func _get_pie_menu_items() -> Array[Dictionary]:
	return [
		{"label": CsgBlockoutI18n.t("TOOL_BOX"), "type": "action", "action_id": &"draw_box", "icon": _icon("box.svg")},
		{"label": CsgBlockoutI18n.t("TOOL_ROOM"), "type": "action", "action_id": &"draw_room", "icon": _icon("room.svg")},
		{"label": CsgBlockoutI18n.t("TOOL_CUT"), "type": "action", "action_id": &"draw_cut", "icon": _icon("cut.svg")},
		{"label": CsgBlockoutI18n.t("DOOR"), "type": "action", "action_id": &"opening_door", "icon": _icon("door.svg")},
		{"label": CsgBlockoutI18n.t("WINDOW"), "type": "action", "action_id": &"opening_window", "icon": _icon("window.svg")},
		{"label": CsgBlockoutI18n.t("PIE_PLAY"), "type": "action", "action_id": &"play_here_cursor", "icon": _icon("play_here.svg")},
		{"label": CsgBlockoutI18n.t("PIE_SHAPES"), "type": "submenu", "icon": _icon("cyliner.svg"), "children": _get_shape_menu()},
		{"label": CsgBlockoutI18n.t("MORE_MENU"), "type": "submenu", "children": _get_more_menu()},
	]

## More ▸: actions on the selection (dimmed until something fitting is selected).
func _get_more_menu() -> Array[Dictionary]:
	var targets: Dictionary = CsgBlockoutFreeze.selection_targets()
	var frozen: bool = not (targets["frozen"] as Array).is_empty()
	var freezable: bool = frozen or not (targets["roots"] as Array).is_empty()
	var has_selection: bool = not CsgBlockoutSelection.top_level_nodes().is_empty()
	var has_csg: bool = EditorInterface.get_selection().get_selected_nodes().any(func(n: Node) -> bool: return n is CSGShape3D)
	var need_csg: String = CsgBlockoutI18n.t("REASON_SELECT_CSG")
	var need_any: String = CsgBlockoutI18n.t("REASON_SELECT_ANY")
	return [
		{"label": CsgBlockoutI18n.t("UNFREEZE" if frozen else "FREEZE"), "type": "action", "action_id": &"freeze_toggle",
			"icon": _icon("unfreeze.svg" if frozen else "freeze.svg"), "disabled": not freezable, "reason": need_csg},
		{"label": CsgBlockoutI18n.t("ARRAY_ACTION"), "type": "action", "action_id": &"array", "disabled": not has_selection, "reason": need_any},
		{"label": CsgBlockoutI18n.t("PIE_SNAP"), "type": "action", "action_id": &"snap_to_grid", "disabled": not has_selection, "reason": need_any},
		{"label": CsgBlockoutI18n.t("PIE_TO_UNION"), "type": "action", "action_id": &"set_op_union", "icon": _icon("op_union.svg"), "disabled": not has_csg, "reason": need_csg},
		{"label": CsgBlockoutI18n.t("PIE_TO_SUBTRACT"), "type": "action", "action_id": &"set_op_subtract", "icon": _icon("op_subtract.svg"), "disabled": not has_csg, "reason": need_csg},
		{"label": CsgBlockoutI18n.t("PIE_TO_INTERSECT"), "type": "action", "action_id": &"set_op_intersect", "icon": _icon("op_intersect.svg"), "disabled": not has_csg, "reason": need_csg},
		{"label": CsgBlockoutI18n.t("CSGPlayerReference3D"), "type": "action", "action_id": &"add_player_ref"},
	]

func _enter_tree() -> void:
	csg_plugin_path = get_script().get_path().get_base_dir()
	CsgBlockoutConfig.plugin_path = csg_plugin_path
	undo_manager = get_undo_redo()

	# Custom Nodes
	add_custom_type("CSGRepeater3D", "CSGCombiner3D", preload("res://addons/csg_blockout/scripts/csg_repeater_3d.gd"), null)
	add_custom_type("CSGSpreader3D", "CSGCombiner3D", preload("res://addons/csg_blockout/scripts/csg_spreader_3d.gd"), null)
	add_custom_type("CSGStairs3D", "CSGPolygon3D", preload("res://addons/csg_blockout/scripts/csg_stairs_3d.gd"), preload("res://addons/csg_blockout/res/icons/stairs.svg"))
	# Icons loaded, not preloaded: right after an update they may not be imported yet,
	# and a missing preload would stop the whole plugin from loading.
	add_custom_type("CSGWedge3D", "CSGPolygon3D", preload("res://addons/csg_blockout/scripts/shapes/csg_wedge_3d.gd"), _icon("wedge.svg"))
	add_custom_type("CSGArch3D", "CSGPolygon3D", preload("res://addons/csg_blockout/scripts/shapes/csg_arch_3d.gd"), _icon("arch.svg"))
	add_custom_type("CSGCurvedWall3D", "CSGPolygon3D", preload("res://addons/csg_blockout/scripts/shapes/csg_curved_wall_3d.gd"), _icon("curved_wall.svg"))
	add_custom_type("CSGSpiralStairs3D", "CSGMesh3D", preload("res://addons/csg_blockout/scripts/shapes/csg_spiral_stairs_3d.gd"), _icon("spiral_stairs.svg"))
	add_custom_type("CSGRuler3D", "Node3D", preload("res://addons/csg_blockout/scripts/csg_ruler_3d.gd"), preload("res://addons/csg_blockout/res/icons/ruler.svg"))
	add_custom_type("CSGPlayerReference3D", "Node3D", preload("res://addons/csg_blockout/scripts/metrics/csg_player_reference_3d.gd"), null)

	# Gizmo Plugin
	ruler_gizmo_plugin = CSGRulerGizmoPlugin.new()
	add_node_3d_gizmo_plugin(ruler_gizmo_plugin)
	player_ref_gizmo_plugin = CSGPlayerReferenceGizmoPlugin.new()
	add_node_3d_gizmo_plugin(player_ref_gizmo_plugin)

	# Tool palette left of the viewport, global actions in the 3D toolbar.
	sidebar = CSGSideBlockoutBar.new()
	sidebar.request_create_node.connect(_on_create_requested)
	sidebar.action_requested.connect(_on_action_requested)
	add_control_to_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_SIDE_LEFT, sidebar)
	topbar = CSGTopBlockoutBar.new()
	topbar.action_requested.connect(_on_action_requested)
	add_control_to_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU, topbar)

	_export_plugin = CsgBlockoutExportPlugin.new()
	add_export_plugin(_export_plugin)
	CsgBlockoutBakePipeline.register_settings()
	_frozen_inspector = CsgBlockoutFrozenInspector.new()
	add_inspector_plugin(_frozen_inspector)
	_mesh_inspector = CsgBlockoutMeshInspector.new()
	add_inspector_plugin(_mesh_inspector)

	outliner = CsgBlockoutOutliner.new()
	_outliner_dock = CsgBlockoutCompat.add_dock(self, outliner, CsgBlockoutI18n.t("OUTLINER_TITLE"), load("res://addons/csg_blockout/res/icons/box.svg") as Texture2D)
	scene_changed.connect(_on_scene_changed)

	# Viewport tools: input is forwarded even with nothing selected, and the HUD is
	# drawn over every 3D viewport.
	CsgBlockoutShortcuts.register_all()
	tools = CsgBlockoutToolManager.new(self)
	tools.add_passive(CsgBlockoutTransformHotkeys.new())
	tools.add_passive(CsgBlockoutFaceDrag.new())
	tools.add_passive(CsgBlockoutTreeSelect.new())
	# Dimension labels are drawn over the face handles, so they get the click first.
	tools.add_passive(CsgBlockoutMeasureOverlay.new(), 10)
	_draw_tool = CsgBlockoutDrawTool.new()
	_opening_tool = CsgBlockoutOpeningTool.new()
	tools.register_tool(&"draw", _draw_tool)
	tools.register_tool(&"opening", _opening_tool)
	tools.register_tool(&"array", CsgBlockoutArrayTool.new())
	tools.active_tool_changed.connect(sidebar.set_active_tool)
	set_input_event_forwarding_always_enabled()
	set_force_draw_over_forwarding_enabled()
	var grid: CsgBlockoutGrid = CsgBlockoutGrid.get_grid()
	if not grid.changed.is_connected(update_overlays):
		grid.changed.connect(update_overlays)
	var selection: EditorSelection = EditorInterface.get_selection()
	if not selection.selection_changed.is_connected(_on_selection_changed):
		selection.selection_changed.connect(_on_selection_changed)

func _handles(object: Object) -> bool:
	return object is Node3D

func _on_selection_changed() -> void:
	update_overlays()

func _on_scene_changed(_scene_root: Node) -> void:
	CsgBlockoutValidator.clear()
	if outliner != null:
		outliner.clear_solo()
		outliner.mark_dirty()
		outliner.refresh_checks()

func _forward_3d_gui_input(viewport_camera: Camera3D, event: InputEvent) -> int:
	var result: int = _pie_menu_input(viewport_camera, event)
	if result != EditorPlugin.AFTER_GUI_INPUT_PASS:
		return result
	return tools.handle_input(viewport_camera, event)

func _forward_3d_force_draw_over_viewport(viewport_control: Control) -> void:
	if tools != null:
		tools.draw_overlay(viewport_control)

func _pie_menu_input(viewport_camera: Camera3D, event: InputEvent) -> int:
	if event is InputEventMouse:
		tools.camera = viewport_camera
		tools.mouse_pos = (event as InputEventMouse).position
		tools.has_mouse = true
	if event is InputEventKey and event.keycode == KEY_A and not event.echo and _is_action_key_held(event):
		if event.pressed:
			if not is_instance_valid(pie_menu):
				# Prevent menu from opening during viewport fly navigation
				if not Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
					_open_pie_menu(viewport_camera)
				else:
					return EditorPlugin.AFTER_GUI_INPUT_PASS
			return EditorPlugin.AFTER_GUI_INPUT_STOP
		else:
			if is_instance_valid(pie_menu):
				if Time.get_ticks_msec() - pie_menu_tab_pressed_time > 200:
					# Hold mode release
					pie_menu.execute_active_item(true)
				return EditorPlugin.AFTER_GUI_INPUT_STOP

	if is_instance_valid(pie_menu):
		if event is InputEventKey and (event as InputEventKey).keycode == KEY_ESCAPE:
			if event.pressed:
				_close_pie_menu()
			return EditorPlugin.AFTER_GUI_INPUT_STOP
		if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
				pie_menu.execute_active_item(true)
				return EditorPlugin.AFTER_GUI_INPUT_STOP
			elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
				pie_menu.execute_back()
				return EditorPlugin.AFTER_GUI_INPUT_STOP
			return EditorPlugin.AFTER_GUI_INPUT_STOP

		if event is InputEventMouseMotion:
			pie_menu.set_pointer_global(tools.to_global((event as InputEventMouseMotion).position))
			return EditorPlugin.AFTER_GUI_INPUT_STOP

	return EditorPlugin.AFTER_GUI_INPUT_PASS

func _is_action_key_held(event: InputEventWithModifiers) -> bool:
	var key: Key = config.action_key if config else KEY_SHIFT
	return (key == KEY_SHIFT and event.shift_pressed) \
		or (key == KEY_CTRL and event.ctrl_pressed) \
		or (key == KEY_ALT and event.alt_pressed) \
		or (key == KEY_META and event.meta_pressed)

func _open_pie_menu(viewport_camera: Camera3D) -> void:
	pie_menu = CsgPieMenu.new()
	pie_menu.action_triggered.connect(_on_pie_menu_action_triggered)
	pie_menu.close_requested.connect(_close_pie_menu)

	var ed_scale: float = EditorInterface.get_editor_scale() if Engine.is_editor_hint() else 1.0
	pie_menu.apply_editor_scale(ed_scale)

	var base_control: Control = EditorInterface.get_base_control()
	base_control.add_child(pie_menu)

	_pie_camera = viewport_camera
	_pie_screen_pos = tools.mouse_pos
	var global_pos: Vector2 = tools.to_global(tools.mouse_pos) if tools.has_mouse else base_control.get_global_mouse_position()
	var mouse_pos: Vector2 = base_control.get_global_transform().affine_inverse() * global_pos

	# Keep the menu and its submenus inside the window.
	var items: Array[Dictionary] = _get_pie_menu_items()
	var margin: float = pie_menu.max_extent(items) + 8.0 * ed_scale
	var rect_size: Vector2 = base_control.get_rect().size
	mouse_pos.x = clampf(mouse_pos.x, minf(margin, rect_size.x * 0.5), maxf(rect_size.x - margin, rect_size.x * 0.5))
	mouse_pos.y = clampf(mouse_pos.y, minf(margin, rect_size.y * 0.5), maxf(rect_size.y - margin, rect_size.y * 0.5))

	pie_menu.position = mouse_pos
	pie_menu.set_pointer_global(global_pos)
	pie_menu.setup(items, ed_scale)
	pie_menu_tab_pressed_time = Time.get_ticks_msec()

func _close_pie_menu() -> void:
	if is_instance_valid(pie_menu):
		if pie_menu.action_triggered.is_connected(_on_pie_menu_action_triggered):
			pie_menu.action_triggered.disconnect(_on_pie_menu_action_triggered)
		if pie_menu.close_requested.is_connected(_close_pie_menu):
			pie_menu.close_requested.disconnect(_close_pie_menu)
		pie_menu.queue_free()
		pie_menu = null

func _on_pie_menu_action_triggered(item: Dictionary) -> void:
	match String(item.get("type", "")):
		"action":
			_on_action_requested(item.get("action_id", &""), true)
		"create_csg":
			var csg_type: String = item.get("csg_type", "")
			if not csg_type.is_empty():
				CsgBlockoutNodeFactory.create(csg_type, _pie_hit(), CSGShape3D.OPERATION_UNION)

## Surface under the point where the pie menu was opened (or null).
func _pie_hit() -> CsgBlockoutRaycast.Hit:
	if not is_instance_valid(_pie_camera):
		return null
	tools.camera = _pie_camera
	return tools.cast(_pie_screen_pos)

## Palette shape buttons: next to the selection, or on the surface in the middle of
## the view when nothing is selected.
func _on_create_requested(csg_type: String) -> void:
	var hit: CsgBlockoutRaycast.Hit = null
	if EditorInterface.get_selection().get_selected_nodes().is_empty():
		hit = _viewport_center_hit()
	CsgBlockoutNodeFactory.create(csg_type, hit)

## Modal tools behind each tool action: [tool, mode].
func _tool_for(action_id: StringName) -> Array:
	match action_id:
		&"draw_box":
			return [_draw_tool, CsgBlockoutDrawTool.Mode.BOX]
		&"draw_room":
			return [_draw_tool, CsgBlockoutDrawTool.Mode.ROOM]
		&"draw_cut":
			return [_draw_tool, CsgBlockoutDrawTool.Mode.CUT]
		&"opening_door":
			return [_opening_tool, CsgBlockoutOpeningTool.Mode.DOOR]
		&"opening_window":
			return [_opening_tool, CsgBlockoutOpeningTool.Mode.WINDOW]
	return []

## Tool buttons and menu entries (top bar, sidebar, pie menu) land here. Buttons
## toggle their tool; the pie menu always starts it.
func _on_action_requested(action_id: StringName, from_pie: bool = false) -> void:
	var tool_spec: Array = _tool_for(action_id)
	if not tool_spec.is_empty():
		if from_pie:
			_start_tool(tool_spec[0], tool_spec[1])
		else:
			_toggle_tool(action_id, tool_spec[0], tool_spec[1])
		return
	match action_id:
		&"snap_to_grid":
			CsgBlockoutTransformHotkeys.snap_selection_to_grid()
		&"refresh_overlays":
			update_overlays()
		&"add_player_ref":
			CsgBlockoutNodeFactory.create("CSGPlayerReference3D", _pie_hit() if from_pie else _viewport_center_hit())
		&"add_ruler":
			topbar.set_rulers_visible(true)
			_on_create_requested("CSGRuler3D")
		&"set_op_union":
			_set_operation(CSGShape3D.OPERATION_UNION, "UNION")
		&"set_op_subtract":
			_set_operation(CSGShape3D.OPERATION_SUBTRACTION, "SUBTRACTION")
		&"set_op_intersect":
			_set_operation(CSGShape3D.OPERATION_INTERSECTION, "INTERSECTION")
		&"check_jump":
			CsgBlockoutMeasureOverlay.check_jump_between_selection()
		&"play_here_cursor":
			# From the pie menu: spawn where the menu was opened.
			if is_instance_valid(_pie_camera):
				CsgBlockoutPlayHere.launch(CsgBlockoutPlayHere.spawn_for(_pie_camera, tools.ray_pos(_pie_screen_pos)))
		&"play_here":
			var cam: Camera3D = tools.camera if tools.camera != null else EditorInterface.get_editor_viewport_3d(0).get_camera_3d()
			if cam != null:
				CsgBlockoutPlayHere.launch(CsgBlockoutPlayHere.spawn_for(cam, cam.get_viewport().get_visible_rect().get_center()))
		&"validate":
			CsgBlockoutValidator.run()
			if outliner != null:
				outliner.show_checks()
			CsgBlockoutValidator.report_results()
		&"freeze_toggle":
			# Unfreeze when frozen nodes are selected, otherwise freeze the CSG.
			if not (CsgBlockoutFreeze.selection_targets()["frozen"] as Array).is_empty():
				CsgBlockoutFreeze.unfreeze_selection()
			else:
				await CsgBlockoutFreeze.freeze_selection()
		&"freeze":
			await CsgBlockoutFreeze.freeze_selection()
		&"unfreeze":
			CsgBlockoutFreeze.unfreeze_selection()
		&"array":
			var array_tool: CsgBlockoutTool = tools.get_tool(&"array")
			if not CsgBlockoutSelection.top_level_nodes().is_empty():
				tools.activate(array_tool)

## Turns the selected CSG shapes into `op` and says so on the status line.
func _set_operation(op: CSGShape3D.Operation, op_key: String) -> void:
	var count: int = CsgBlockoutNodeFactory.set_operation_on_selection(op)
	if count < 0:
		CsgBlockoutStatus.show(CsgBlockoutI18n.t("REASON_SELECT_CSG"), true)
	else:
		CsgBlockoutStatus.show(CsgBlockoutI18n.tf("STATUS_OP_CHANGED", [count, CsgBlockoutI18n.t(op_key)]))

## Surface under the center of the last used 3D viewport (or null).
func _viewport_center_hit() -> CsgBlockoutRaycast.Hit:
	var cam: Camera3D = tools.camera if tools.camera != null else EditorInterface.get_editor_viewport_3d(0).get_camera_3d()
	if cam == null:
		return null
	var hit: CsgBlockoutRaycast.Hit = CsgBlockoutRaycast.cast(cam, cam.get_viewport().get_visible_rect().get_center())
	return hit if hit.is_valid() else null

## A tool button was clicked: start its tool for one result, or turn it off when
## it's already on. A quick second click (double-click) keeps the tool on instead.
func _toggle_tool(action_id: StringName, tool: CsgBlockoutTool, mode: int) -> void:
	var now: int = Time.get_ticks_msec()
	var same: bool = tools.active == tool and int(tool.get(&"mode")) == mode
	if same and action_id == _last_tool_click and now - _last_tool_click_time < TOOL_DOUBLE_CLICK_MS:
		_last_tool_click = &""
		tools.set_locked(true)
		# The second click toggled the button off; show the tool as on again.
		tools.active_tool_changed.emit(tool.get_id())
		return
	_last_tool_click = action_id
	_last_tool_click_time = now
	if same:
		tools.deactivate()
		return
	_start_tool(tool, mode)
	# Keyboard focus back to the viewport, so Esc and the tool keys work right away.
	CsgBlockoutToolManager.focus_viewport(tools.camera)

func _start_tool(tool: CsgBlockoutTool, mode: int, locked: bool = false) -> void:
	if tools.active == tool:
		tools.deactivate()
	tool.set(&"mode", mode)
	tools.activate(tool, locked)

func _exit_tree() -> void:
	if tools != null:
		tools.deactivate()
		tools = null
	var grid: CsgBlockoutGrid = CsgBlockoutGrid.get_grid()
	if grid.changed.is_connected(update_overlays):
		grid.changed.disconnect(update_overlays)
	var selection: EditorSelection = EditorInterface.get_selection()
	if selection.selection_changed.is_connected(_on_selection_changed):
		selection.selection_changed.disconnect(_on_selection_changed)
	CsgBlockoutRaycast.clear_cache()
	CsgBlockoutValidator.clear()

	if _export_plugin != null:
		remove_export_plugin(_export_plugin)
		_export_plugin = null
	if _frozen_inspector != null:
		remove_inspector_plugin(_frozen_inspector)
		_frozen_inspector = null
	if _mesh_inspector != null:
		remove_inspector_plugin(_mesh_inspector)
		_mesh_inspector = null
	CsgBlockoutManifoldCheck.clear_edges()
	if scene_changed.is_connected(_on_scene_changed):
		scene_changed.disconnect(_on_scene_changed)
	if _outliner_dock != null:
		CsgBlockoutCompat.remove_dock(self, _outliner_dock)
		_outliner_dock = null
		outliner = null

	if ruler_gizmo_plugin != null:
		remove_node_3d_gizmo_plugin(ruler_gizmo_plugin)
		ruler_gizmo_plugin = null
	if player_ref_gizmo_plugin != null:
		remove_node_3d_gizmo_plugin(player_ref_gizmo_plugin)
		player_ref_gizmo_plugin = null

	remove_custom_type("CSGRepeater3D")
	remove_custom_type("CSGSpreader3D")
	remove_custom_type("CSGStairs3D")
	remove_custom_type("CSGWedge3D")
	remove_custom_type("CSGArch3D")
	remove_custom_type("CSGCurvedWall3D")
	remove_custom_type("CSGSpiralStairs3D")
	remove_custom_type("CSGRuler3D")
	remove_custom_type("CSGPlayerReference3D")
	undo_manager = null

	_close_pie_menu()

	if sidebar and is_instance_valid(sidebar):
		if sidebar.request_create_node.is_connected(_on_create_requested):
			sidebar.request_create_node.disconnect(_on_create_requested)
		if sidebar.action_requested.is_connected(_on_action_requested):
			sidebar.action_requested.disconnect(_on_action_requested)
		remove_control_from_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_SIDE_LEFT, sidebar)
		sidebar.queue_free()
		sidebar = null
	if topbar and is_instance_valid(topbar):
		if topbar.action_requested.is_connected(_on_action_requested):
			topbar.action_requested.disconnect(_on_action_requested)
		remove_control_from_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU, topbar)
		topbar.queue_free()
		topbar = null
