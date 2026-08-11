@tool
class_name CSGTopBlockoutBar extends Control

func _enter_tree() -> void:
	add_to_group("csg_blockout_ui")
	var sel := EditorInterface.get_selection()
	if sel and not sel.selection_changed.is_connected(_on_selection_changed):
		sel.selection_changed.connect(_on_selection_changed)
	_on_selection_changed()
	CsgBlockoutI18n.translate_node(self)
	# Attempt to find buttons and add tooltips if present
	var refresh_btn = find_child("Refresh", true, false)
	if refresh_btn and refresh_btn is Button:
		refresh_btn.tooltip_text = CsgBlockoutI18n.t("重新生成预览实例")
	var bake_btn = find_child("Bake", true, false)
	if bake_btn and bake_btn is Button:
		bake_btn.tooltip_text = CsgBlockoutI18n.t("将生成的实例烘焙至场景中 (使其永久保留)")

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
