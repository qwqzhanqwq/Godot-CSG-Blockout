@tool
class_name CSGTopBlockoutBar extends Control

func _enter_tree() -> void:
	add_to_group("csg_blockout_ui")
	var sel := EditorInterface.get_selection()
	if sel and not sel.selection_changed.is_connected(_on_selection_changed):
		sel.selection_changed.connect(_on_selection_changed)
	_on_selection_changed()
	
	var refresh_btn = find_child("Refresh", true, false)
	if refresh_btn and refresh_btn is Button:
		refresh_btn.set_meta("i18n_text_key", "REFRESH")
		refresh_btn.set_meta("i18n_tooltip_key", "REGEN_PREVIEW_TOOLTIP")

	var bake_btn = find_child("Bake", true, false)
	if bake_btn and bake_btn is Button:
		bake_btn.set_meta("i18n_text_key", "BAKE")
		bake_btn.set_meta("i18n_tooltip_key", "BAKE_INSTANCES_TOOLTIP")
		
	CsgBlockoutI18n.translate_node(self)

func update_language() -> void:
	CsgBlockoutI18n.translate_node(self)

func _exit_tree() -> void:
	var sel := EditorInterface.get_selection()
	if sel and sel.selection_changed.is_connected(_on_selection_changed):
		sel.selection_changed.disconnect(_on_selection_changed)

func _on_selection_changed() -> void:
	var selection = EditorInterface.get_selection().get_selected_nodes()
	if selection.is_empty():
		hide()
	elif selection[0] is CSGRepeater3D or selection[0] is CSGSpreader3D:
		show()
	else:
		hide()

func _on_refresh_pressed() -> void:
	var selection = EditorInterface.get_selection().get_selected_nodes()
	if (selection.is_empty()):
		return
	if selection[0] is CSGRepeater3D:
		selection[0].call("repeat_template")
	elif selection[0] is CSGSpreader3D:
		selection[0].call("spread_template")

func _on_bake_pressed() -> void:
	var selection = EditorInterface.get_selection().get_selected_nodes()
	if selection.is_empty():
		return
	if selection[0] is CSGRepeater3D or selection[0] is CSGSpreader3D:
		selection[0].call("bake_instances")
