@tool
class_name CsgBlockoutOutliner
extends VBoxContainer
## Blockout outliner: only CSG trees and frozen blockout, with operation icons,
## visibility / solo / lock toggles, filtering, grouping and semantic renaming.
## Selection is synced both ways with the editor. Solo hides the other blockout
## roots in the editor only (RenderingServer), so it never changes the scene.

signal action_requested(action_id: StringName)

enum Col { NAME, VISIBLE, SOLO, LOCK }
enum Btn { VISIBLE, SOLO, LOCK }

const REFRESH_INTERVAL_MS: int = 250

var tabs: TabContainer
var tree: Tree
var _filter: LineEdit
var _status: Label
var _dirty: bool = true
var _last_refresh_ms: int = 0
var _syncing: bool = false
var _solo: Node
var _collapsed: Dictionary = {}

func _init() -> void:
	name = "CsgBlockoutOutliner"
	size_flags_vertical = Control.SIZE_EXPAND_FILL

func _ready() -> void:
	if get_child_count() > 0:
		return
	tabs = TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(tabs)

	var page: VBoxContainer = VBoxContainer.new()
	page.name = "OutlinerPage"
	tabs.add_child(page)
	tabs.set_tab_title(0, CsgBlockoutI18n.t("OUTLINER_TAB"))

	var bar: HBoxContainer = HBoxContainer.new()
	page.add_child(bar)
	_filter = LineEdit.new()
	_filter.placeholder_text = CsgBlockoutI18n.t("OUTLINER_FILTER")
	_filter.clear_button_enabled = true
	_filter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_filter.right_icon = _icon(&"Search")
	_filter.text_changed.connect(func(_t: String) -> void: mark_dirty())
	bar.add_child(_filter)
	_add_bar_button(bar, &"Group", "OUTLINER_GROUP", _group_selection)
	_add_bar_button(bar, &"Ungroup", "OUTLINER_UNGROUP", _ungroup_selection)
	_add_bar_button(bar, &"Rename", "OUTLINER_RENAME", _rename_semantic)

	tree = Tree.new()
	tree.name = "OutlinerTree"
	tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tree.columns = 4
	tree.hide_root = true
	tree.select_mode = Tree.SELECT_MULTI
	tree.set_column_expand(Col.NAME, true)
	for c: int in [Col.VISIBLE, Col.SOLO, Col.LOCK]:
		tree.set_column_expand(c, false)
		tree.set_column_custom_minimum_width(c, int(26 * EditorInterface.get_editor_scale()))
	tree.multi_selected.connect(_on_tree_multi_selected)
	tree.button_clicked.connect(_on_tree_button_clicked)
	tree.item_collapsed.connect(_on_item_collapsed)
	page.add_child(tree)

	_status = Label.new()
	_status.add_theme_color_override(&"font_color", Color(0.7, 0.72, 0.78))
	page.add_child(_status)

	_build_checks_page()

	var tree_signals: SceneTree = get_tree()
	if tree_signals != null:
		tree_signals.node_added.connect(_on_node_changed)
		tree_signals.node_removed.connect(_on_node_changed)
		tree_signals.node_renamed.connect(_on_node_changed)
	EditorInterface.get_selection().selection_changed.connect(_on_editor_selection_changed)
	EditorInterface.get_inspector().property_edited.connect(func(_p: String) -> void: mark_dirty())

func _exit_tree() -> void:
	clear_solo()
	var tree_signals: SceneTree = get_tree()
	if tree_signals != null:
		for sig: Signal in [tree_signals.node_added, tree_signals.node_removed, tree_signals.node_renamed]:
			if sig.is_connected(_on_node_changed):
				sig.disconnect(_on_node_changed)
	var sel: EditorSelection = EditorInterface.get_selection()
	if sel.selection_changed.is_connected(_on_editor_selection_changed):
		sel.selection_changed.disconnect(_on_editor_selection_changed)

func _add_bar_button(bar: Control, icon_name: StringName, tooltip_key: String, callback: Callable) -> Button:
	var b: Button = Button.new()
	b.flat = true
	b.icon = _icon(icon_name)
	if b.icon == null:
		b.text = CsgBlockoutI18n.t(tooltip_key)
	b.tooltip_text = CsgBlockoutI18n.t(tooltip_key)
	b.pressed.connect(callback)
	bar.add_child(b)
	return b

static func _icon(icon_name: StringName) -> Texture2D:
	return CSGTopBlockoutBar.editor_icon(icon_name)

func mark_dirty() -> void:
	_dirty = true

func _on_node_changed(n: Node) -> void:
	var root: Node = EditorInterface.get_edited_scene_root()
	if root != null and (n == root or root.is_ancestor_of(n)):
		_dirty = true

func _process(_delta: float) -> void:
	if not _dirty or not is_visible_in_tree():
		return
	var now: int = Time.get_ticks_msec()
	if now - _last_refresh_ms < REFRESH_INTERVAL_MS:
		return
	_last_refresh_ms = now
	_dirty = false
	rebuild()

# --- building ----------------------------------------------------------------------

func rebuild() -> void:
	if tree == null:
		return
	tree.clear()
	var root_item: TreeItem = tree.create_item()
	var scene_root: Node = EditorInterface.get_edited_scene_root()
	var counts: Dictionary = {"trees": 0, "nodes": 0}
	if scene_root is CSGShape3D:
		counts["trees"] += 1
		_add_item(scene_root, root_item, counts)
	elif scene_root != null:
		_add_children(scene_root, root_item, counts)
	if _solo != null and not is_instance_valid(_solo):
		_solo = null
	_apply_solo()
	_sync_selection_to_tree()
	_status.text = CsgBlockoutI18n.tf("OUTLINER_STATUS", [counts["trees"], counts["nodes"]])

## Adds blockout nodes under `n`; non-CSG containers (Node3D groups) are walked through.
func _add_children(n: Node, parent_item: TreeItem, counts: Dictionary) -> void:
	for child: Node in n.get_children():
		if child.owner != EditorInterface.get_edited_scene_root():
			continue
		if child is CSGShape3D or CsgBlockoutFreeze.is_frozen(child):
			var is_root: bool = not (n is CSGShape3D)
			if is_root:
				counts["trees"] += 1
			_add_item(child, parent_item, counts)
		elif child is Node3D and not (child is CSGShape3D):
			_add_children(child, parent_item, counts)

func _add_item(n: Node, parent_item: TreeItem, counts: Dictionary) -> void:
	var scene_root: Node = EditorInterface.get_edited_scene_root()
	var filter: String = _filter.text.strip_edges().to_lower() if _filter else ""
	var matches: bool = filter.is_empty() or String(n.name).to_lower().contains(filter)
	var item: TreeItem = tree.create_item(parent_item)
	counts["nodes"] += 1
	item.set_text(Col.NAME, String(n.name))
	item.set_metadata(Col.NAME, n.get_instance_id())
	item.set_icon(Col.NAME, _node_icon(n))
	if n is CSGMesh3D and (n as CSGMesh3D).mesh != null:
		var check: Dictionary = CsgBlockoutManifoldCheck.analyze_cached((n as CSGMesh3D).mesh)
		if not bool(check["ok"]) and not bool(check["skipped"]):
			item.set_icon(Col.NAME, _icon(&"StatusWarning"))
			item.set_tooltip_text(Col.NAME, CsgBlockoutManifoldCheck.describe(check))
	var tag: StringName = CsgBlockoutTags.tag_of(n)
	if CsgBlockoutTags.COLORS.has(tag):
		item.set_icon_modulate(Col.NAME, CsgBlockoutTags.COLORS[tag])
		item.set_tooltip_text(Col.NAME, "%s · %s" % [String(n.name), CsgBlockoutTags.label(tag)])
	item.set_icon_max_width(Col.NAME, int(16 * EditorInterface.get_editor_scale()))
	if n is CSGShape3D:
		match (n as CSGShape3D).operation:
			CSGShape3D.OPERATION_SUBTRACTION:
				item.set_custom_color(Col.NAME, Color(1.0, 0.55, 0.5))
			CSGShape3D.OPERATION_INTERSECTION:
				item.set_custom_color(Col.NAME, Color(1.0, 0.85, 0.45))
	if CsgBlockoutFreeze.is_frozen(n):
		item.set_custom_color(Col.NAME, Color(0.55, 0.85, 1.0))
		item.set_tooltip_text(Col.NAME, CsgBlockoutI18n.t("OUTLINER_FROZEN_TOOLTIP"))
	var n3d: Node3D = n as Node3D
	item.add_button(Col.VISIBLE, _icon(&"GuiVisibilityVisible" if n3d.visible else &"GuiVisibilityHidden"), Btn.VISIBLE, false, CsgBlockoutI18n.t("OUTLINER_VISIBLE"))
	if not (n.get_parent() is CSGShape3D) or n == scene_root:
		var solo_icon: Texture2D = _icon(&"AudioBusSolo")
		item.add_button(Col.SOLO, solo_icon, Btn.SOLO, false, CsgBlockoutI18n.t("OUTLINER_SOLO"))
		if _solo == n:
			item.set_button_color(Col.SOLO, 0, Color(1.0, 0.85, 0.3))
		elif solo_icon != null:
			item.set_button_color(Col.SOLO, 0, Color(1, 1, 1, 0.35))
	var locked: bool = n.get_meta(&"_edit_lock_", false) == true
	item.add_button(Col.LOCK, _icon(&"Lock" if locked else &"Unlock"), Btn.LOCK, false, CsgBlockoutI18n.t("OUTLINER_LOCK"))
	if not locked:
		item.set_button_color(Col.LOCK, 0, Color(1, 1, 1, 0.35))
	if n is CSGShape3D:
		for child: Node in n.get_children():
			if child is CSGShape3D and child.owner == scene_root:
				_add_item(child, item, counts)
	item.collapsed = _collapsed.get(n.get_instance_id(), false)
	if not matches and item.get_first_child() == null:
		item.free()
		counts["nodes"] -= 1
	elif not matches:
		item.set_custom_color(Col.NAME, Color(0.6, 0.6, 0.6, 0.7))

func _node_icon(n: Node) -> Texture2D:
	if CsgBlockoutFreeze.is_frozen(n):
		return load("res://addons/csg_blockout/res/icons/freeze.svg") as Texture2D
	if n is CSGShape3D:
		match (n as CSGShape3D).operation:
			CSGShape3D.OPERATION_SUBTRACTION:
				return load("res://addons/csg_blockout/res/icons/subtraction.svg") as Texture2D
			CSGShape3D.OPERATION_INTERSECTION:
				return load("res://addons/csg_blockout/res/icons/intersection.svg") as Texture2D
	if n is CSGStairs3D:
		return load("res://addons/csg_blockout/res/icons/stairs.svg") as Texture2D
	if n is CSGWedge3D:
		return load("res://addons/csg_blockout/res/icons/wedge.svg") as Texture2D
	if n is CSGArch3D:
		return load("res://addons/csg_blockout/res/icons/arch.svg") as Texture2D
	if n is CSGCurvedWall3D:
		return load("res://addons/csg_blockout/res/icons/curved_wall.svg") as Texture2D
	if n is CSGSpiralStairs3D:
		return load("res://addons/csg_blockout/res/icons/spiral_stairs.svg") as Texture2D
	var icon: Texture2D = _icon(StringName(n.get_class()))
	return icon if icon != null else _icon(&"Node3D")

func _node_of(item: TreeItem) -> Node:
	if item == null:
		return null
	var id: Variant = item.get_metadata(Col.NAME)
	if id == null:
		return null
	var obj: Object = instance_from_id(int(id))
	return obj as Node if is_instance_valid(obj) else null

func _find_item(n: Node, from: TreeItem = null) -> TreeItem:
	var start: TreeItem = from if from != null else tree.get_root()
	if start == null:
		return null
	var it: TreeItem = start.get_first_child()
	while it != null:
		if _node_of(it) == n:
			return it
		var deep: TreeItem = _find_item(n, it)
		if deep != null:
			return deep
		it = it.get_next()
	return null

# --- selection sync ---------------------------------------------------------------

func _on_tree_multi_selected(_item: TreeItem, _column: int, _selected: bool) -> void:
	if _syncing:
		return
	_push_selection.call_deferred()

func _push_selection() -> void:
	_syncing = true
	var sel: EditorSelection = EditorInterface.get_selection()
	sel.clear()
	var it: TreeItem = tree.get_next_selected(null)
	while it != null:
		var n: Node = _node_of(it)
		if n != null:
			sel.add_node(n)
		it = tree.get_next_selected(it)
	_syncing = false

func _on_editor_selection_changed() -> void:
	if not _syncing:
		_sync_selection_to_tree()

func _sync_selection_to_tree() -> void:
	if tree == null or tree.get_root() == null:
		return
	_syncing = true
	tree.deselect_all()
	var first: TreeItem = null
	for n: Node in EditorInterface.get_selection().get_selected_nodes():
		var item: TreeItem = _find_item(n)
		if item != null:
			item.select(Col.NAME)
			if first == null:
				first = item
	if first != null:
		tree.scroll_to_item(first)
	_syncing = false

func _on_item_collapsed(item: TreeItem) -> void:
	var n: Node = _node_of(item)
	if n != null:
		_collapsed[n.get_instance_id()] = item.collapsed

# --- row buttons ---------------------------------------------------------------------

func _on_tree_button_clicked(item: TreeItem, _column: int, id: int, mouse_button_index: int) -> void:
	if mouse_button_index != MOUSE_BUTTON_LEFT:
		return
	var n: Node = _node_of(item)
	if n == null:
		return
	match id:
		Btn.VISIBLE:
			CsgBlockoutSceneOps.Action.new(CsgBlockoutI18n.t("OUTLINER_VISIBLE")).set_property(n, &"visible", not (n as Node3D).visible).commit()
		Btn.SOLO:
			set_solo(null if _solo == n else n)
		Btn.LOCK:
			var locked: bool = n.get_meta(&"_edit_lock_", false) == true
			CsgBlockoutSceneOps.Action.new(CsgBlockoutI18n.t("OUTLINER_LOCK")).assign_meta(n, &"_edit_lock_", null if locked else true).commit()
	mark_dirty()

# --- solo ------------------------------------------------------------------------------

## Renderable blockout roots of the edited scene (CSG roots and frozen nodes).
func _render_roots() -> Array[GeometryInstance3D]:
	var out: Array[GeometryInstance3D] = []
	var scene_root: Node = EditorInterface.get_edited_scene_root()
	if scene_root == null:
		return out
	var stack: Array[Node] = [scene_root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if (n is CSGShape3D and (n as CSGShape3D).is_root_shape()) or CsgBlockoutFreeze.is_frozen(n):
			out.append(n as GeometryInstance3D)
			continue
		stack.append_array(n.get_children())
	return out

func set_solo(n: Node) -> void:
	clear_solo()
	_solo = n
	_apply_solo()
	mark_dirty()

func get_solo() -> Node:
	return _solo

func _apply_solo() -> void:
	if _solo == null or not is_instance_valid(_solo):
		return
	for r: GeometryInstance3D in _render_roots():
		var keep: bool = r == _solo or r.is_ancestor_of(_solo) or _solo.is_ancestor_of(r)
		RenderingServer.instance_set_visible(r.get_instance(), keep and r.is_visible_in_tree())

func clear_solo() -> void:
	for r: GeometryInstance3D in _render_roots():
		RenderingServer.instance_set_visible(r.get_instance(), r.is_visible_in_tree())
	_solo = null

# --- checks page -----------------------------------------------------------------------

var checks_tree: Tree
var _checks_summary: Label

func _build_checks_page() -> void:
	var page: VBoxContainer = VBoxContainer.new()
	page.name = "ChecksPage"
	tabs.add_child(page)
	tabs.set_tab_title(1, CsgBlockoutI18n.t("CHECKS_TAB"))
	var bar: HBoxContainer = HBoxContainer.new()
	page.add_child(bar)
	var run_btn: Button = Button.new()
	run_btn.text = CsgBlockoutI18n.t("RUN_CHECKS")
	run_btn.icon = _icon(&"Play")
	run_btn.pressed.connect(func() -> void:
		CsgBlockoutValidator.run()
		refresh_checks())
	bar.add_child(run_btn)
	var clear_btn: Button = Button.new()
	clear_btn.text = CsgBlockoutI18n.t("CLEAR_CHECKS")
	clear_btn.pressed.connect(func() -> void:
		CsgBlockoutValidator.clear()
		refresh_checks())
	bar.add_child(clear_btn)
	_checks_summary = Label.new()
	_checks_summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_checks_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	bar.add_child(_checks_summary)
	checks_tree = Tree.new()
	checks_tree.name = "ChecksTree"
	checks_tree.hide_root = true
	checks_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	checks_tree.item_selected.connect(_on_check_selected)
	page.add_child(checks_tree)

## Shows the checks tab (and the dock) with the latest validation results.
func show_checks() -> void:
	refresh_checks()
	tabs.current_tab = 1
	var dock: Node = get_parent()
	if dock != null and dock.has_method(&"make_visible"):
		dock.call(&"make_visible")

func refresh_checks() -> void:
	if checks_tree == null:
		return
	checks_tree.clear()
	var root_item: TreeItem = checks_tree.create_item()
	var issues: Array[Dictionary] = CsgBlockoutValidator.issues
	if issues.is_empty():
		_checks_summary.text = CsgBlockoutI18n.t("CHECKS_NONE")
		return
	_checks_summary.text = CsgBlockoutI18n.tf("CHECKS_SUMMARY", [issues.size()])
	for i: int in issues.size():
		var issue: Dictionary = issues[i]
		var item: TreeItem = checks_tree.create_item(root_item)
		var node: Node = issue["node"]
		var owner_name: String = String(node.name) if is_instance_valid(node) else "?"
		item.set_text(0, "%s — %s" % [owner_name, CsgBlockoutValidator.describe(issue)])
		item.set_custom_color(0, (CsgBlockoutValidator.COLORS[issue["kind"]] as Color).lightened(0.25))
		item.set_icon(0, _icon(&"StatusError" if issue["kind"] == "blocked" else &"StatusWarning"))
		item.set_metadata(0, i)

func _on_check_selected() -> void:
	var item: TreeItem = checks_tree.get_selected()
	if item == null:
		return
	var idx: int = int(item.get_metadata(0))
	if idx < 0 or idx >= CsgBlockoutValidator.issues.size():
		return
	var node: Node = CsgBlockoutValidator.issues[idx]["node"]
	if is_instance_valid(node):
		var sel: EditorSelection = EditorInterface.get_selection()
		sel.clear()
		sel.add_node(node)

# --- toolbar actions -------------------------------------------------------------------

func _selected_shapes() -> Array[Node3D]:
	var out: Array[Node3D] = []
	for n: Node3D in CsgBlockoutSelection.top_level_nodes():
		if n is CSGShape3D or CsgBlockoutFreeze.is_frozen(n):
			out.append(n)
	return out

func _group_selection() -> void:
	group_nodes(_selected_shapes())

## Wraps `nodes` into a new CSGCombiner3D placed where the first node was.
static func group_nodes(nodes: Array[Node3D]) -> CSGCombiner3D:
	if nodes.is_empty():
		return null
	var first: Node3D = nodes[0]
	var parent: Node = first.get_parent()
	var combiner: CSGCombiner3D = CSGCombiner3D.new()
	combiner.name = CsgBlockoutSceneOps.unique_child_name(parent, "Group")
	# The grouped trees stop being roots, so the group takes over their collision.
	combiner.use_collision = nodes.any(func(n: Node3D) -> bool: return n is CSGShape3D and (n as CSGShape3D).use_collision)
	var center: Vector3 = Vector3.ZERO
	for n: Node3D in nodes:
		center += n.global_position
	center /= float(nodes.size())
	var action: CsgBlockoutSceneOps.Action = CsgBlockoutSceneOps.Action.new(CsgBlockoutI18n.t("OUTLINER_GROUP"))
	action.add_node(parent, combiner, first.get_index(), Transform3D(Basis.IDENTITY, center), "self")
	for n: Node3D in nodes:
		action.reparent(n, combiner)
	action.select([combiner])
	action.commit()
	return combiner

func _ungroup_selection() -> void:
	for n: Node in EditorInterface.get_selection().get_selected_nodes():
		if n is CSGCombiner3D and n != EditorInterface.get_edited_scene_root():
			ungroup(n as CSGCombiner3D)
			return

## Moves the combiner's children up to its parent (in place) and removes it.
static func ungroup(combiner: CSGCombiner3D) -> void:
	var parent: Node = combiner.get_parent()
	var index: int = combiner.get_index()
	var children: Array[Node] = []
	for c: Node in combiner.get_children():
		if c.owner == EditorInterface.get_edited_scene_root():
			children.append(c)
	var action: CsgBlockoutSceneOps.Action = CsgBlockoutSceneOps.Action.new(CsgBlockoutI18n.t("OUTLINER_UNGROUP"))
	for i: int in children.size():
		# The children become roots of their own: they keep the group's collision.
		if combiner.use_collision and not (parent is CSGShape3D) and children[i] is CSGShape3D and not (children[i] as CSGShape3D).use_collision:
			action.set_property(children[i], &"use_collision", true)
		action.reparent(children[i], parent, index + i)
	action.remove_node(combiner)
	action.select(children)
	action.commit()

func _rename_semantic() -> void:
	var targets: Array[Node] = []
	var selected: Array[Node] = EditorInterface.get_selection().get_selected_nodes()
	if selected.is_empty():
		var scene_root: Node = EditorInterface.get_edited_scene_root()
		if scene_root != null:
			targets = CsgBlockoutNaming.collect(scene_root)
	else:
		for n: Node in selected:
			if not targets.has(n):
				targets.append(n)
			for d: Node in CsgBlockoutNaming.collect(n):
				if not targets.has(d):
					targets.append(d)
	CsgBlockoutNaming.rename(targets)
	mark_dirty()
