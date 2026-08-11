@tool
class_name CsgBlockout extends EditorPlugin
var config: CsgBlockoutConfig:
	get: return CsgBlockoutConfig.get_config()

var sidebar: CSGSideBlockoutBar
var topbar: CSGTopBlockoutBar

static var csg_plugin_path: String
static var undo_manager: EditorUndoRedoManager

var pie_menu: CsgPieMenu
var pie_menu_tab_pressed_time: int = 0
var default_csg_operation: int = 0 # CSGShape3D.OPERATION_UNION

func _get_shape_menu() -> Array[Dictionary]:
	return [
		{"label": CsgBlockoutI18n.t("立方体"), "type": "create_csg", "csg_type": "CSGBox3D"},
		{"label": CsgBlockoutI18n.t("圆柱体"), "type": "create_csg", "csg_type": "CSGCylinder3D"},
		{"label": CsgBlockoutI18n.t("网格"), "type": "create_csg", "csg_type": "CSGMesh3D"},
		{"label": CsgBlockoutI18n.t("多边形"), "type": "create_csg", "csg_type": "CSGPolygon3D"},
		{"label": CsgBlockoutI18n.t("球体"), "type": "create_csg", "csg_type": "CSGSphere3D"},
		{"label": CsgBlockoutI18n.t("圆环"), "type": "create_csg", "csg_type": "CSGTorus3D"}
	]

func _get_pie_menu_items() -> Array[Dictionary]:
	return [
		{
			"label": CsgBlockoutI18n.t("并集"), "type": "submenu",
			"operation": 0,
			"children": _get_shape_menu()
		},
		{
			"label": CsgBlockoutI18n.t("交集"), "type": "submenu",
			"operation": 1,
			"children": _get_shape_menu()
		},
		{
			"label": CsgBlockoutI18n.t("差集"), "type": "submenu",
			"operation": 2,
			"children": _get_shape_menu()
		}
	]
func _enter_tree() -> void:
	csg_plugin_path = get_script().get_path().get_base_dir()
	undo_manager = get_undo_redo()
	
	# Nodes
	add_custom_type("CSGRepeater3D", "CSGCombiner3D", preload("res://addons/csg_blockout/scripts/csg_repeater_3d.gd"), null)
	add_custom_type("CSGSpreader3D", "CSGCombiner3D", preload("res://addons/csg_blockout/scripts/csg_spreader_3d.gd"), null)
	
	# Sidebar
	var sidebarScene = preload("res://addons/csg_blockout/scenes/csg_side_blockout_bar.tscn")
	sidebar = sidebarScene.instantiate()
	add_control_to_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_SIDE_LEFT, sidebar)
	
	# Topbar
	var topbarScene = preload("res://addons/csg_blockout/scenes/csg_top_blockout_bar.tscn")
	topbar = topbarScene.instantiate()
	add_control_to_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU, topbar)

func _handles(object: Object) -> bool:
	return object is Node3D

func _forward_3d_gui_input(viewport_camera: Camera3D, event: InputEvent) -> int:
	if event is InputEventKey and event.keycode == KEY_A and event.shift_pressed and not event.echo:
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

func _open_pie_menu() -> void:
	pie_menu = CsgPieMenu.new()
	pie_menu.action_triggered.connect(_on_pie_menu_action_triggered)
	pie_menu.close_requested.connect(_close_pie_menu)
	
	var base_control: Control = EditorInterface.get_base_control()
	base_control.add_child(pie_menu)
	
	var mouse_pos: Vector2 = base_control.get_local_mouse_position()
	
	# Clamp position
	var margin: float = pie_menu.outer_radius + 10.0
	var rect_size: Vector2 = base_control.get_rect().size
	mouse_pos.x = clampf(mouse_pos.x, margin, rect_size.x - margin)
	mouse_pos.y = clampf(mouse_pos.y, margin, rect_size.y - margin)
	
	pie_menu.position = mouse_pos
	pie_menu.setup(_get_pie_menu_items())
	pie_menu_tab_pressed_time = Time.get_ticks_msec()

func _close_pie_menu() -> void:
	if is_instance_valid(pie_menu):
		pie_menu.queue_free()
		pie_menu = null

func _on_pie_menu_action_triggered(item: Dictionary) -> void:
	var action_type = item.get("type", "")
	
	if action_type == "submenu" and item.has("operation"):
		var op = item.get("operation")
		default_csg_operation = op
		
		var selection = EditorInterface.get_selection().get_selected_nodes()
		if selection.size() > 0 and selection[0] is CSGShape3D:
			var node = selection[0] as CSGShape3D
			undo_manager.create_action(CsgBlockoutI18n.t("更改 CSG 操作"))
			undo_manager.add_do_property(node, "operation", op)
			undo_manager.add_undo_property(node, "operation", node.operation)
			undo_manager.commit_action()
			
	elif action_type == "create_csg":
		var csg_type = item.get("csg_type", "")
		if csg_type != "" and ClassDB.can_instantiate(csg_type):
			_create_csg_node(csg_type)

func _create_csg_node(csg_type: String) -> void:
	var new_node: Node3D = ClassDB.instantiate(csg_type) as Node3D
	if not new_node:
		return
		
	if new_node is CSGShape3D:
		new_node.operation = default_csg_operation
		
	var selection = EditorInterface.get_selection()
	var selected_nodes = selection.get_selected_nodes()
	
	var parent: Node = null
	if selected_nodes.size() > 0 and selected_nodes[0] is Node3D:
		parent = selected_nodes[0]
	else:
		parent = EditorInterface.get_edited_scene_root()
		
	if not parent:
		new_node.free()
		return
		
	undo_manager.create_action(CsgBlockoutI18n.t("创建 ") + csg_type)
	undo_manager.add_do_method(parent, "add_child", new_node, true)
	undo_manager.add_do_method(new_node, "set_owner", EditorInterface.get_edited_scene_root())
	undo_manager.add_do_reference(new_node)
	undo_manager.add_undo_method(parent, "remove_child", new_node)
	undo_manager.commit_action()
	
	selection.clear()
	selection.add_node(new_node)

func _exit_tree() -> void:
	remove_custom_type("CSGRepeater3D")
	remove_custom_type("CSGSpreader3D")
	undo_manager = null
	

	if sidebar and is_instance_valid(sidebar):
		remove_control_from_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_SIDE_LEFT, sidebar)
		sidebar.free()
	if topbar and is_instance_valid(topbar):
		remove_control_from_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU, topbar)
		topbar.free()
