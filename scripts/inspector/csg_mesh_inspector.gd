@tool
class_name CsgBlockoutMeshInspector
extends EditorInspectorPlugin
## Warns in the Inspector when a CSGMesh3D's mesh isn't manifold, and can mark the
## offending edges in the viewport. Spiral stairs build their own (closed) mesh and
## are left out.

func _can_handle(object: Object) -> bool:
	return object is CSGMesh3D and not (object is CSGSpiralStairs3D)

func _parse_begin(object: Object) -> void:
	var node: CSGMesh3D = object as CSGMesh3D
	if node.mesh == null:
		return
	var result: Dictionary = CsgBlockoutManifoldCheck.analyze_cached(node.mesh)
	var panel: VBoxContainer = VBoxContainer.new()
	panel.name = "CsgBlockoutManifoldPanel"
	var label: Label = Label.new()
	label.name = "Status"
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = 200.0
	label.text = CsgBlockoutManifoldCheck.describe(result)
	var good: bool = bool(result["ok"]) or bool(result["skipped"])
	label.add_theme_color_override(&"font_color", Color(0.5, 0.9, 0.55) if good else Color(1.0, 0.45, 0.4))
	panel.add_child(label)
	if not good:
		var toggle: CheckButton = CheckButton.new()
		toggle.name = "ShowEdges"
		toggle.text = CsgBlockoutI18n.t("MANIFOLD_SHOW_EDGES")
		CsgBlockoutFrozenInspector.compact(toggle)
		toggle.toggled.connect(func(on: bool) -> void:
			if on:
				CsgBlockoutManifoldCheck.show_edges(node, result)
			else:
				CsgBlockoutManifoldCheck.clear_edges())
		panel.add_child(toggle)
		# The highlight belongs to this inspector view; drop it when the view goes away.
		panel.tree_exiting.connect(CsgBlockoutManifoldCheck.clear_edges)
	panel.add_child(HSeparator.new())
	add_custom_control(panel)
