@tool
class_name CsgBlockout extends EditorPlugin
var config: CsgBlockoutConfig:
	get: return CsgBlockoutConfig.get_config()

var sidebar: CSGSideBlockoutBar
var topbar: CSGTopBlockoutBar
var ruler_gizmo_plugin: CSGRulerGizmoPlugin

static var csg_plugin_path: String
static var undo_manager: EditorUndoRedoManager

var pie_menu: CsgPieMenu
var pie_menu_tab_pressed_time: int = 0

func _get_shape_menu() -> Array[Dictionary]:
	return [
		{"label": CsgBlockoutI18n.t("BOX"), "type": "create_csg", "csg_type": "CSGBox3D"},
		{"label": CsgBlockoutI18n.t("CYLINDER"), "type": "create_csg", "csg_type": "CSGCylinder3D"},
		{"label": CsgBlockoutI18n.t("MESH"), "type": "create_csg", "csg_type": "CSGMesh3D"},
		{"label": CsgBlockoutI18n.t("POLYGON"), "type": "create_csg", "csg_type": "CSGPolygon3D"},
		{"label": CsgBlockoutI18n.t("SPHERE"), "type": "create_csg", "csg_type": "CSGSphere3D"},
		{"label": CsgBlockoutI18n.t("TORUS"), "type": "create_csg", "csg_type": "CSGTorus3D"},
		{"label": CsgBlockoutI18n.t("STAIRS"), "type": "create_csg", "csg_type": "CSGStairs3D"}
	]

func _get_pie_menu_items() -> Array[Dictionary]:
	return [
		{
			"label": CsgBlockoutI18n.t("UNION"), "type": "submenu",
			"operation": 0,
			"children": _get_shape_menu()
		},
		{
			"label": CsgBlockoutI18n.t("INTERSECTION"), "type": "submenu",
			"operation": 1,
			"children": _get_shape_menu()
		},
		{
			"label": CsgBlockoutI18n.t("SUBTRACTION"), "type": "submenu",
			"operation": 2,
			"children": _get_shape_menu()
		}
	]
func _enter_tree() -> void:
	csg_plugin_path = get_script().get_path().get_base_dir()
	undo_manager = get_undo_redo()
	
	# Custom Nodes
	add_custom_type("CSGRepeater3D", "CSGCombiner3D", preload("res://addons/csg_blockout/scripts/csg_repeater_3d.gd"), null)
	add_custom_type("CSGSpreader3D", "CSGCombiner3D", preload("res://addons/csg_blockout/scripts/csg_spreader_3d.gd"), null)
	add_custom_type("CSGStairs3D", "CSGPolygon3D", preload("res://addons/csg_blockout/scripts/csg_stairs_3d.gd"), preload("res://addons/csg_blockout/res/icons/stairs.svg"))
	add_custom_type("CSGRuler3D", "Node3D", preload("res://addons/csg_blockout/scripts/csg_ruler_3d.gd"), preload("res://addons/csg_blockout/res/icons/ruler.svg"))
	
	# Gizmo Plugin
	ruler_gizmo_plugin = CSGRulerGizmoPlugin.new()
	add_node_3d_gizmo_plugin(ruler_gizmo_plugin)

	# Sidebar
	var sidebar_scene: PackedScene = preload("res://addons/csg_blockout/scenes/csg_side_blockout_bar.tscn")
	sidebar = sidebar_scene.instantiate() as CSGSideBlockoutBar
	sidebar.request_create_node.connect(_create_csg_node)
	add_control_to_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_SIDE_LEFT, sidebar)
	
	# Topbar
	var topbar_scene: PackedScene = preload("res://addons/csg_blockout/scenes/csg_top_blockout_bar.tscn")
	topbar = topbar_scene.instantiate() as CSGTopBlockoutBar
	topbar.request_create_node.connect(_create_csg_node)
	add_control_to_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU, topbar)

func _handles(object: Object) -> bool:
	return object is Node3D

func _forward_3d_gui_input(viewport_camera: Camera3D, event: InputEvent) -> int:
	if event is InputEventKey and event.keycode == KEY_A and not event.echo and _is_action_key_held(event):
		if event.pressed:
			if not is_instance_valid(pie_menu):
				_open_pie_menu()
			return EditorPlugin.AFTER_GUI_INPUT_STOP
		else:
			if is_instance_valid(pie_menu):
				if Time.get_ticks_msec() - pie_menu_tab_pressed_time > 200:
					# Hold mode release
					pie_menu.execute_active_item(true)
				return EditorPlugin.AFTER_GUI_INPUT_STOP
				
	if is_instance_valid(pie_menu):
		if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
				pie_menu.execute_active_item(true)
				return EditorPlugin.AFTER_GUI_INPUT_STOP
			elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
				pie_menu.execute_back()
				return EditorPlugin.AFTER_GUI_INPUT_STOP
			return EditorPlugin.AFTER_GUI_INPUT_STOP
			
		if event is InputEventMouseMotion:
			return EditorPlugin.AFTER_GUI_INPUT_STOP
			
	return EditorPlugin.AFTER_GUI_INPUT_PASS

func _is_action_key_held(event: InputEventWithModifiers) -> bool:
	var key: Key = config.action_key if config else KEY_SHIFT
	return (key == KEY_SHIFT and event.shift_pressed) \
		or (key == KEY_CTRL and event.ctrl_pressed) \
		or (key == KEY_ALT and event.alt_pressed) \
		or (key == KEY_META and event.meta_pressed)

func _open_pie_menu() -> void:
	pie_menu = CsgPieMenu.new()
	pie_menu.action_triggered.connect(_on_pie_menu_action_triggered)
	pie_menu.close_requested.connect(_close_pie_menu)
	
	var ed_scale: float = EditorInterface.get_editor_scale() if Engine.is_editor_hint() else 1.0
	pie_menu.apply_editor_scale(ed_scale)
	
	var base_control: Control = EditorInterface.get_base_control()
	base_control.add_child(pie_menu)
	
	var mouse_pos: Vector2 = base_control.get_local_mouse_position()
	
	# Clamp position
	var margin: float = pie_menu.outer_radius + 10.0 * ed_scale
	var rect_size: Vector2 = base_control.get_rect().size
	mouse_pos.x = clampf(mouse_pos.x, margin, rect_size.x - margin)
	mouse_pos.y = clampf(mouse_pos.y, margin, rect_size.y - margin)
	
	pie_menu.position = mouse_pos
	pie_menu.setup(_get_pie_menu_items(), ed_scale)
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
	var action_type = item.get("type", "")
	
	if action_type == "submenu" and item.has("operation"):
		var op = item.get("operation")
		if config:
			config.default_operation = op
		
		var selection = EditorInterface.get_selection().get_selected_nodes()
		if selection.size() > 0 and selection[0] is CSGShape3D:
			var node = selection[0] as CSGShape3D
			undo_manager.create_action(CsgBlockoutI18n.t("CHANGE_CSG_OP"))
			undo_manager.add_do_property(node, "operation", op)
			undo_manager.add_undo_property(node, "operation", node.operation)
			undo_manager.commit_action()
			
	elif action_type == "create_csg":
		var csg_type: String = item.get("csg_type", "")
		if not csg_type.is_empty():
			_create_csg_node(csg_type)

func _create_csg_node(csg_type: String) -> void:
	var new_node: Node3D = null
	if csg_type == "CSGStairs3D":
		new_node = CSGStairs3D.new()
	elif csg_type == "CSGRuler3D":
		new_node = CSGRuler3D.new()
	elif csg_type == "CSGRepeater3D":
		new_node = CSGRepeater3D.new()
	elif csg_type == "CSGSpreader3D":
		new_node = CSGSpreader3D.new()
	elif ClassDB.can_instantiate(csg_type):
		new_node = ClassDB.instantiate(csg_type) as Node3D
	
	if not new_node:
		return
		
	if new_node is CSGShape3D:
		var shape_node: CSGShape3D = new_node as CSGShape3D
		shape_node.operation = config.default_operation if config else CSGShape3D.OPERATION_UNION
		if config:
			shape_node.material = config.get_active_material()
		
	var selection: EditorSelection = EditorInterface.get_selection()
	var selected_nodes: Array[Node] = selection.get_selected_nodes()
	
	var parent: Node = null
	var insert_index: int = -1
	var target_pos: Vector3 = Vector3.ZERO
	
	if not (new_node is CSGShape3D):
		if not selected_nodes.is_empty() and selected_nodes[0] is Node3D:
			var selected_node: Node3D = selected_nodes[0] as Node3D
			parent = selected_node
			target_pos = selected_node.global_position
			insert_index = parent.get_child_count()
		else:
			parent = EditorInterface.get_edited_scene_root()
			if parent:
				insert_index = parent.get_child_count()
	else:
		if not selected_nodes.is_empty() and selected_nodes[0] is Node3D:
			var selected_node: Node3D = selected_nodes[0] as Node3D
			target_pos = selected_node.global_position
			if selected_node is CSGCombiner3D:
				parent = selected_node
				insert_index = parent.get_child_count()
			elif selected_node is CSGShape3D:
				parent = selected_node.get_parent()
				if parent == null:
					parent = selected_node
					insert_index = parent.get_child_count()
				else:
					insert_index = selected_node.get_index() + 1
			else:
				parent = selected_node
				insert_index = parent.get_child_count()
		else:
			parent = EditorInterface.get_edited_scene_root()
			if parent:
				insert_index = parent.get_child_count()
		
	if not parent:
		push_warning("CSG Blockout: Cannot create node; no active scene root or parent available.")
		new_node.free()
		return
		
	var owner_ref: Node = EditorInterface.get_edited_scene_root()
	if owner_ref == null:
		owner_ref = parent
		
	var ur: EditorUndoRedoManager = undo_manager if undo_manager != null else get_undo_redo()
	if not ur:
		parent.add_child(new_node, true)
		if owner_ref != new_node:
			new_node.owner = owner_ref
		new_node.global_position = target_pos
		_select_node(new_node)
		return

	ur.create_action(CsgBlockoutI18n.tf("CREATE_NODE", [CsgBlockoutI18n.t(csg_type)]))
	ur.add_undo_reference(new_node)
	ur.add_do_method(self, "_undoable_create_csg", parent, new_node, owner_ref, target_pos, insert_index)
	ur.add_do_method(self, "_select_node", new_node)
	ur.add_undo_method(self, "_undoable_remove_csg", parent, new_node)
	if not selected_nodes.is_empty() and is_instance_valid(selected_nodes[0]):
		ur.add_undo_method(self, "_select_node", selected_nodes[0])
	else:
		ur.add_undo_method(self, "_clear_selection_if", new_node)
	ur.commit_action()

func _undoable_create_csg(parent: Node, node: Node3D, owner_ref: Node, global_pos: Vector3, insert_index: int) -> void:
	if node.get_parent() != parent:
		parent.add_child(node, true)
		if insert_index >= 0 and insert_index < parent.get_child_count():
			parent.move_child(node, insert_index)
	if owner_ref != node:
		node.owner = owner_ref
	node.global_position = global_pos

func _undoable_remove_csg(parent: Node, node: Node3D) -> void:
	if is_instance_valid(node) and node.get_parent() == parent:
		parent.remove_child(node)

func _clear_selection_if(node: Node) -> void:
	var selection: EditorSelection = EditorInterface.get_selection()
	if selection:
		var nodes: Array[Node] = selection.get_selected_nodes()
		if node in nodes:
			selection.remove_node(node)

func _select_node(node: Node) -> void:
	if not is_instance_valid(node) or not node.is_inside_tree():
		return
	var selection: EditorSelection = EditorInterface.get_selection()
	if selection:
		selection.clear()
		selection.add_node(node)

func _exit_tree() -> void:
	if ruler_gizmo_plugin != null:
		remove_node_3d_gizmo_plugin(ruler_gizmo_plugin)
		ruler_gizmo_plugin = null

	remove_custom_type("CSGRepeater3D")
	remove_custom_type("CSGSpreader3D")
	remove_custom_type("CSGStairs3D")
	remove_custom_type("CSGRuler3D")
	undo_manager = null
	
	_close_pie_menu()

	if sidebar and is_instance_valid(sidebar):
		if sidebar.request_create_node.is_connected(_create_csg_node):
			sidebar.request_create_node.disconnect(_create_csg_node)
		remove_control_from_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_SIDE_LEFT, sidebar)
		sidebar.queue_free()
		sidebar = null
	if topbar and is_instance_valid(topbar):
		if topbar.request_create_node.is_connected(_create_csg_node):
			topbar.request_create_node.disconnect(_create_csg_node)
		remove_control_from_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU, topbar)
		topbar.queue_free()
		topbar = null
