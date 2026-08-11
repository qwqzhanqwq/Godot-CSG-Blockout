@tool
class_name CSGSideBlockoutBar extends Control

var config: CsgBlockoutConfig:
	get: return CsgBlockoutConfig.get_config()

var operation: CSGShape3D.Operation = CSGShape3D.OPERATION_UNION
var selected_material: BaseMaterial3D = null
var selected_shader: ShaderMaterial = null

@onready var picker_button: Button = $ScrollContainer/HBoxContainer/Material/MaterialPicker

var button_tweens: Dictionary = {}
var visibility_tween: Tween

func _enter_tree() -> void:
	var sel := EditorInterface.get_selection()
	if sel and not sel.selection_changed.is_connected(_on_selection_changed):
		sel.selection_changed.connect(_on_selection_changed)

func _exit_tree() -> void:
	var sel := EditorInterface.get_selection()
	if sel and sel.selection_changed.is_connected(_on_selection_changed):
		sel.selection_changed.disconnect(_on_selection_changed)

func _on_selection_changed() -> void:
	var auto_hide_enabled := config.auto_hide if config else true
	if not auto_hide_enabled:
		_fade_in()
		return
	var selection = EditorInterface.get_selection().get_selected_nodes()
	if selection.any(func(node): return node is CSGShape3D):
		_fade_in()
	else:
		_fade_out()

func _fade_in() -> void:
	if visible and modulate.a >= 0.99: return
	if visibility_tween and visibility_tween.is_valid():
		visibility_tween.kill()
	if not visible:
		modulate.a = 0.0
		show()
	visibility_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	visibility_tween.tween_property(self, "modulate:a", 1.0, 0.2)

func _fade_out() -> void:
	if not visible: return
	if visibility_tween and visibility_tween.is_valid():
		visibility_tween.kill()
	visibility_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	visibility_tween.tween_property(self, "modulate:a", 0.0, 0.15)
	visibility_tween.tween_callback(self.hide)

func _ready() -> void:
	picker_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Connect material picker button if not connected via scene
	if not picker_button.pressed.is_connected(_on_material_picker_pressed):
		picker_button.pressed.connect(_on_material_picker_pressed)
	
	add_to_group("csg_blockout_ui")
	CsgBlockoutI18n.translate_node(self)
	
	var lang_btn = find_child("LanguageToggle", true, false)
	if lang_btn and lang_btn is OptionButton:
		lang_btn.clear()
		lang_btn.add_item("EN", 0)
		lang_btn.add_item("中文", 1)
		_update_language_toggle_text()
		
	_setup_button_animations(self)

func update_language() -> void:
	CsgBlockoutI18n.translate_node(self)
	_update_language_toggle_text()

func _update_language_toggle_text() -> void:
	var btn = find_child("LanguageToggle", true, false)
	if btn and btn is OptionButton:
		var override = config.language_override if config else "zh_CN"
		if override == "en":
			btn.select(0)
		else:
			btn.select(1)

func _setup_button_animations(node: Node) -> void:
	if node is Button and not (node is OptionButton):
		# Use deferred call to ensure size is initialized
		call_deferred("_apply_pivot", node)
		node.mouse_entered.connect(_on_btn_mouse_entered.bind(node))
		node.mouse_exited.connect(_on_btn_mouse_exited.bind(node))
		node.button_down.connect(_on_btn_down.bind(node))
		node.button_up.connect(_on_btn_up.bind(node))
		if node.toggle_mode:
			node.toggled.connect(_on_btn_toggled.bind(node))
			
	for child in node.get_children():
		_setup_button_animations(child)

func _apply_pivot(btn: Button) -> void:
	btn.pivot_offset = btn.size / 2.0

func _animate_button(btn: Button, target_scale: Vector2, target_modulate: Color, duration: float, is_punch: bool = false) -> void:
	if button_tweens.has(btn) and is_instance_valid(button_tweens[btn]):
		button_tweens[btn].kill()
	var tw = create_tween()
	if not is_punch:
		tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		tw.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.set_parallel(true)
	tw.tween_property(btn, "scale", target_scale, duration)
	tw.tween_property(btn, "modulate", target_modulate, duration)
	button_tweens[btn] = tw

func _on_btn_mouse_entered(btn: Button) -> void:
	var color = Color(1.3, 1.3, 1.3, 1.0) if not btn.button_pressed else Color(1.3, 1.5, 2.0, 1.0)
	_animate_button(btn, Vector2(1.08, 1.08), color, 0.2)

func _on_btn_mouse_exited(btn: Button) -> void:
	var color = Color.WHITE if not btn.button_pressed else Color(0.8, 1.2, 2.0, 1.0)
	_animate_button(btn, Vector2(1.0, 1.0), color, 0.2)

func _on_btn_down(btn: Button) -> void:
	_animate_button(btn, Vector2(0.9, 0.9), btn.modulate, 0.1, true)

func _on_btn_up(btn: Button) -> void:
	var is_hovered = btn.get_global_rect().has_point(get_global_mouse_position())
	var scale = Vector2(1.08, 1.08) if is_hovered else Vector2(1.0, 1.0)
	var mod = Color(1.3, 1.3, 1.3, 1.0) if is_hovered else Color.WHITE
	if btn.toggle_mode and btn.button_pressed:
		mod = Color(1.3, 1.5, 2.0, 1.0) if is_hovered else Color(0.8, 1.2, 2.0, 1.0)
	_animate_button(btn, scale, mod, 0.2)

func _on_btn_toggled(pressed: bool, btn: Button) -> void:
	var is_hovered = btn.get_global_rect().has_point(get_global_mouse_position())
	var scale = Vector2(1.08, 1.08) if is_hovered else Vector2(1.0, 1.0)
	var mod = Color(1.3, 1.3, 1.3, 1.0) if is_hovered else Color.WHITE
	if pressed:
		mod = Color(1.3, 1.5, 2.0, 1.0) if is_hovered else Color(0.8, 1.2, 2.0, 1.0)
	_animate_button(btn, scale, mod, 0.2)

func _on_box_pressed() -> void:
	create_csg(CSGBox3D)

func _on_cylinder_pressed() -> void:
	create_csg(CSGCylinder3D)

func _on_mesh_pressed() -> void:
	create_csg(CSGMesh3D)

func _on_polygon_pressed() -> void:
	create_csg(CSGPolygon3D)

func _on_sphere_pressed() -> void:
	create_csg(CSGSphere3D)

func _on_torus_pressed() -> void:
	create_csg(CSGTorus3D)

# Operation Toggle (accept optional arg for signal variations)
func _on_operation_pressed(val := 0) -> void:
	set_operation(val)

func _request_material() -> void:
	var dialog := EditorFileDialog.new()
	dialog.title = CsgBlockoutI18n.t("选择材质")
	dialog.display_mode = EditorFileDialog.DISPLAY_LIST
	dialog.filters = ["*.tres, *.material, *.res"]
	dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
	if EditorInterface.get_base_control():
		dialog.position = ((EditorInterface.get_base_control().size / 2) as Vector2i) - dialog.size

	var cleanup_dialog := func() -> void:
		if is_instance_valid(dialog) and dialog.get_parent():
			dialog.get_parent().remove_child(dialog)
			dialog.queue_free()

	var on_file_selected := func(path: String) -> void:
		cleanup_dialog.call()
		if path.is_empty():
			return
		var res = ResourceLoader.load(path)
		if res == null:
			return
		if res is BaseMaterial3D:
			update_material(res)
		elif res is ShaderMaterial:
			update_shader(res)
		else:
			return
		var previewer = EditorInterface.get_resource_previewer()
		if previewer:
			previewer.queue_edited_resource_preview(res, self, "_update_picker_icon", null)

	var on_canceled := func() -> void:
		cleanup_dialog.call()

	dialog.file_selected.connect(on_file_selected)
	dialog.canceled.connect(on_canceled)

	get_tree().root.add_child(dialog)
	dialog.show()

func _update_picker_icon(path, preview, thumbnail, userdata):
	if preview:
		picker_button.icon = preview

func set_operation(val: int) -> void:
	match val:
		0: operation = CSGShape3D.OPERATION_UNION
		1: operation = CSGShape3D.OPERATION_INTERSECTION
		2: operation = CSGShape3D.OPERATION_SUBTRACTION
		_: operation = CSGShape3D.OPERATION_UNION

func update_material(material: BaseMaterial3D) -> void:
	selected_material = material
	selected_shader = null

func update_shader(shader: ShaderMaterial) -> void:
	selected_material = null
	selected_shader = shader

func create_csg(type: Variant) -> void:
	var selection = EditorInterface.get_selection()
	var selected_nodes = selection.get_selected_nodes()
	if selected_nodes.is_empty() or !(selected_nodes[0] is CSGShape3D):
		push_warning(CsgBlockoutI18n.t("请先选择一个 CSGShape3D 节点以添加新 CSG 节点"))
		return
	var selected_node: CSGShape3D = selected_nodes[0]
	var csg: CSGShape3D
	match type:
		CSGBox3D: csg = CSGBox3D.new()
		CSGCylinder3D: csg = CSGCylinder3D.new()
		CSGSphere3D: csg = CSGSphere3D.new()
		CSGMesh3D: csg = CSGMesh3D.new()
		CSGPolygon3D: csg = CSGPolygon3D.new()
		CSGTorus3D: csg = CSGTorus3D.new()
		_:
			push_warning(CsgBlockoutI18n.t("未知或不支持的 CSG 节点类型"))
			return

	csg.operation = operation
	if selected_material:
		csg.material = selected_material
	elif selected_shader:
		csg.material = selected_shader

	var owner_ref = selected_node.get_owner()
	if owner_ref == null:
		owner_ref = selected_node

	var parent: Node
	var add_as_child := false

	# Behavior inversion now uses secondary_action_key (e.g. Alt) instead of primary action key
	var sec_key: Key = config.secondary_action_key if config else KEY_ALT
	var invert := Input.is_key_pressed(sec_key)
	var default_behavior = config.default_behavior if config else CsgBlockoutConfig.CSGBehavior.SIBLING
	if default_behavior == CsgBlockoutConfig.CSGBehavior.SIBLING:
		add_as_child = invert
	else:
		add_as_child = !invert

	parent = selected_node if add_as_child else selected_node.get_parent()
	if parent == null:
		return

	# Try undo manager path if plugin provided one
	if CsgBlockout.undo_manager:
		var insert_index := parent.get_child_count()
		CsgBlockout.undo_manager.create_action(CsgBlockoutI18n.t("添加 %s") % csg.get_class())
		CsgBlockout.undo_manager.add_undo_reference(csg)
		CsgBlockout.undo_manager.add_do_method(self, "_undoable_add_csg", parent, csg, owner_ref, selected_node.global_position, insert_index)
		CsgBlockout.undo_manager.add_do_method(self, "_select_created_csg", csg)
		CsgBlockout.undo_manager.add_undo_method(self, "_undoable_remove_csg", parent, csg)
		CsgBlockout.undo_manager.add_undo_method(self, "_clear_selection_if", csg)
		CsgBlockout.undo_manager.commit_action()
	else:
		parent.add_child(csg, true)
		csg.owner = owner_ref
		csg.global_position = selected_node.global_position
		call_deferred("_select_created_csg", csg)

func _deferred_select(csg: Node) -> void:
	call_deferred("_select_created_csg", csg)

func _undoable_add_csg(parent: Node, csg: CSGShape3D, owner_ref: Node, global_pos: Vector3, insert_index: int) -> void:
	if csg.get_parent() != parent:
		parent.add_child(csg, true)
		if insert_index >= 0 and insert_index < parent.get_child_count():
			parent.move_child(csg, insert_index)
	csg.owner = owner_ref
	csg.global_position = global_pos

func _undoable_remove_csg(parent: Node, csg: CSGShape3D) -> void:
	if is_instance_valid(csg) and csg.get_parent() == parent:
		parent.remove_child(csg)
	# Intentionally do NOT free node so redo can re-add it. If you need memory, implement a recreate pattern instead.

func _clear_selection_if(csg: Node) -> void:
	var selection = EditorInterface.get_selection()
	if selection:
		var nodes: Array = selection.get_selected_nodes()
		if csg in nodes:
			selection.remove_node(csg)

func _select_created_csg(csg: Node) -> void:
	if not is_instance_valid(csg) or not csg.is_inside_tree():
		return
	var selection = EditorInterface.get_selection()
	selection.clear()
	selection.add_node(csg)

func _on_material_picker_pressed() -> void:
	_request_material()

func _on_language_toggle_item_selected(index: int) -> void:
	if config:
		match index:
			0: config.language_override = "en"
			1: config.language_override = "zh_CN"
		config.save_config()
		
		get_tree().call_group("csg_blockout_ui", "update_language")
