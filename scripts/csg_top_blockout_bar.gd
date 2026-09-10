@tool
class_name CSGTopBlockoutBar extends Control

signal request_create_node(node_type: String)
signal add_ruler_requested()

const BASE_ICON_MAX_WIDTH: int = 16

var _rulers_visible: bool = true

func _enter_tree() -> void:
	if not Engine.is_editor_hint():
		return
	if not is_in_group(&"csg_blockout_ui"):
		add_to_group(&"csg_blockout_ui")
	var sel: EditorSelection = EditorInterface.get_selection()
	if sel and not sel.selection_changed.is_connected(_on_selection_changed):
		sel.selection_changed.connect(_on_selection_changed)
	
	var add_ruler_btn: Button = find_child("AddRuler", true, false) as Button
	if add_ruler_btn:
		add_ruler_btn.set_meta("i18n_text_key", "ADD_RULER")
		add_ruler_btn.set_meta("i18n_tooltip_key", "ADD_RULER_TOOLTIP")

	var toggle_rulers_btn: Button = find_child("ToggleRulers", true, false) as Button
	if toggle_rulers_btn:
		toggle_rulers_btn.set_meta("i18n_text_key", "TOGGLE_RULERS")
		toggle_rulers_btn.set_meta("i18n_tooltip_key", "TOGGLE_RULERS_TOOLTIP")

	var refresh_btn: Button = find_child("Refresh", true, false) as Button
	if refresh_btn:
		refresh_btn.set_meta("i18n_text_key", "REFRESH")
		refresh_btn.set_meta("i18n_tooltip_key", "REGEN_PREVIEW_TOOLTIP")

	var bake_btn: Button = find_child("Bake", true, false) as Button
	if bake_btn:
		bake_btn.set_meta("i18n_text_key", "BAKE")
		bake_btn.set_meta("i18n_tooltip_key", "BAKE_INSTANCES_TOOLTIP")
		
	_apply_editor_scale()
	CsgBlockoutI18n.translate_node(self)
	_on_selection_changed()

func _apply_editor_scale() -> void:
	var ed_scale: float = 1.0
	if Engine.is_editor_hint():
		ed_scale = EditorInterface.get_editor_scale()
	ed_scale = maxf(ed_scale, 0.1)
	var add_ruler_btn: Button = find_child("AddRuler", true, false) as Button
	if add_ruler_btn:
		add_ruler_btn.add_theme_constant_override("icon_max_width", int(round(BASE_ICON_MAX_WIDTH * ed_scale)))

func update_language() -> void:
	CsgBlockoutI18n.translate_node(self)

func _exit_tree() -> void:
	if not Engine.is_editor_hint():
		return
	if is_in_group(&"csg_blockout_ui"):
		remove_from_group(&"csg_blockout_ui")
	var sel: EditorSelection = EditorInterface.get_selection()
	if sel and sel.selection_changed.is_connected(_on_selection_changed):
		sel.selection_changed.disconnect(_on_selection_changed)

func _on_selection_changed() -> void:
	if not Engine.is_editor_hint():
		return
	var sel: EditorSelection = EditorInterface.get_selection()
	var selection: Array[Node] = sel.get_selected_nodes() if sel != null else []
	var has_repeater: bool = selection.any(func(node: Node) -> bool: return node is CSGRepeater3D or node is CSGSpreader3D)
	
	var repeater_tools: Control = find_child("RepeaterTools", true, false) as Control
	if repeater_tools:
		repeater_tools.visible = has_repeater
	var vsep: Control = find_child("VSeparator", true, false) as Control
	if vsep:
		vsep.visible = has_repeater

func _on_add_ruler_pressed() -> void:
	if not _rulers_visible:
		var toggle_btn: Button = find_child("ToggleRulers", true, false) as Button
		if toggle_btn:
			toggle_btn.button_pressed = true
	add_ruler_requested.emit()
	request_create_node.emit("CSGRuler3D")

func _on_toggle_rulers_toggled(toggled_on: bool) -> void:
	_rulers_visible = toggled_on
	var tree: SceneTree = get_tree()
	if tree != null:
		tree.set_group(&"csg_rulers", &"visible", toggled_on)
		tree.call_group(&"csg_rulers", &"update_gizmos")

func _on_refresh_pressed() -> void:
	var sel: EditorSelection = EditorInterface.get_selection()
	if not sel:
		return
	var selection: Array[Node] = sel.get_selected_nodes()
	for node: Node in selection:
		if node is CSGRepeater3D:
			(node as CSGRepeater3D).repeat_template()
			break
		elif node is CSGSpreader3D:
			(node as CSGSpreader3D).spread_template()
			break

func _on_bake_pressed() -> void:
	var sel: EditorSelection = EditorInterface.get_selection()
	if not sel:
		return
	var selection: Array[Node] = sel.get_selected_nodes()
	for node: Node in selection:
		if node is CSGRepeater3D or node is CSGSpreader3D:
			if node.has_method(&"bake_instances"):
				node.call(&"bake_instances")
			break
