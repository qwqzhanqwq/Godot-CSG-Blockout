@tool
class_name CSGSideBlockoutBar extends MarginContainer
## Tool palette on the left of the 3D viewport, always visible. Top to bottom:
## the drawing tools with their names (one use per click, a double-click keeps the
## tool on), shapes (created next to the selection, or in the middle of the view),
## the boolean operation of the selected shapes, materials, and level helpers.

signal request_create_node(node_type: String)
## A tool or action button was pressed; the plugin dispatches it (same ids as the
## pie menu and the top bar).
signal action_requested(action_id: StringName)

var config: CsgBlockoutConfig:
	get: return CsgBlockoutConfig.get_config()

const BASE_WIDTH: float = 72.0
const BASE_TOOL_HEIGHT: float = 44.0
const BASE_CELL_HEIGHT: float = 28.0
const BASE_ICON: float = 18.0
const BASE_FONT_SIZE: float = 11.0
const BASE_SEPARATION: float = 2.0
const BASE_MARGIN: float = 6.0

## [action id, label key, tooltip key, icon]
const TOOLS: Array = [
	[&"draw_box", "TOOL_BOX", "DRAW_BOX_TOOLTIP", "box.svg"],
	[&"draw_room", "TOOL_ROOM", "DRAW_ROOM_TOOLTIP", "room.svg"],
	[&"draw_cut", "TOOL_CUT", "DRAW_CUT_TOOLTIP", "cut.svg"],
	[&"opening_door", "DOOR", "OPENING_DOOR_TOOLTIP", "door.svg"],
	[&"opening_window", "WINDOW", "OPENING_WINDOW_TOOLTIP", "window.svg"],
]
## [node name, class, label key, icon]
const SHAPES: Array = [
	["Box", "CSGBox3D", "BOX", "box.svg"],
	["Cylinder", "CSGCylinder3D", "CYLINDER", "cyliner.svg"],
	["Sphere", "CSGSphere3D", "SPHERE", "sphere.svg"],
	["Stairs", "CSGStairs3D", "STAIRS", "stairs.svg"],
	["Wedge", "CSGWedge3D", "WEDGE", "wedge.svg"],
	["SpiralStairs", "CSGSpiralStairs3D", "SPIRAL_STAIRS", "spiral_stairs.svg"],
	["Arch", "CSGArch3D", "ARCH", "arch.svg"],
	["CurvedWall", "CSGCurvedWall3D", "CURVED_WALL", "curved_wall.svg"],
	["Torus", "CSGTorus3D", "TORUS", "torus.svg"],
	["Polygon", "CSGPolygon3D", "POLYGON", "polygon.svg"],
	["Mesh", "CSGMesh3D", "MESH", "mesh.svg"],
]
## [node name, operation, action id, tooltip key, icon]
const OPERATIONS: Array = [
	["Union", CSGShape3D.OPERATION_UNION, &"set_op_union", "OP_UNION_TOOLTIP", "op_union.svg"],
	["Subtraction", CSGShape3D.OPERATION_SUBTRACTION, &"set_op_subtract", "OP_SUBTRACT_TOOLTIP", "op_subtract.svg"],
	["Intersection", CSGShape3D.OPERATION_INTERSECTION, &"set_op_intersect", "OP_INTERSECT_TOOLTIP", "op_intersect.svg"],
]
## [node name, preset, tooltip key, icon]
const MATERIALS: Array = [
	["PresetLight", CsgBlockoutConfig.MaterialPreset.GRID_LIGHT, "GRID_LIGHT", "grid_light.svg"],
	["PresetDark", CsgBlockoutConfig.MaterialPreset.GRID_DARK, "GRID_DARK", "grid_dark.svg"],
	["PresetOrange", CsgBlockoutConfig.MaterialPreset.GRID_ORANGE, "GRID_ORANGE", "grid_orange.svg"],
	["PresetNone", CsgBlockoutConfig.MaterialPreset.NONE, "MATERIAL_NONE", "material_none.svg"],
]

var _tool_buttons: Array[Button] = []
var _op_buttons: Array[Button] = []
var _material_buttons: Dictionary = {} # MaterialPreset -> Button
var _picker: Button
var _apply: Button
var _material_group: ButtonGroup = ButtonGroup.new()
var _sync_queued: bool = false

func _init() -> void:
	name = "CsgBlockoutPalette"

func _enter_tree() -> void:
	if not Engine.is_editor_hint():
		return
	if not is_in_group(&"csg_blockout_ui"):
		add_to_group(&"csg_blockout_ui")
	var sel: EditorSelection = EditorInterface.get_selection()
	if not sel.selection_changed.is_connected(_queue_sync):
		sel.selection_changed.connect(_queue_sync)
	# Undo/redo can change the selection's operation without changing the selection.
	var ur: EditorUndoRedoManager = EditorInterface.get_editor_undo_redo()
	if not ur.version_changed.is_connected(_queue_sync):
		ur.version_changed.connect(_queue_sync)
	if not ur.history_changed.is_connected(_queue_sync):
		ur.history_changed.connect(_queue_sync)
	if get_child_count() == 0:
		_build()
	_queue_sync()

func _exit_tree() -> void:
	if not Engine.is_editor_hint():
		return
	if is_in_group(&"csg_blockout_ui"):
		remove_from_group(&"csg_blockout_ui")
	var sel: EditorSelection = EditorInterface.get_selection()
	if sel.selection_changed.is_connected(_queue_sync):
		sel.selection_changed.disconnect(_queue_sync)
	var ur: EditorUndoRedoManager = EditorInterface.get_editor_undo_redo()
	if ur.version_changed.is_connected(_queue_sync):
		ur.version_changed.disconnect(_queue_sync)
	if ur.history_changed.is_connected(_queue_sync):
		ur.history_changed.disconnect(_queue_sync)

static func _scale() -> float:
	return maxf(EditorInterface.get_editor_scale(), 0.1) if Engine.is_editor_hint() else 1.0

static func _icon(file_name: String) -> Texture2D:
	var path: String = CsgBlockoutConfig.plugin_path.path_join("res/icons").path_join(file_name)
	return load(path) as Texture2D if ResourceLoader.exists(path) else null

func _build() -> void:
	var s: float = _scale()
	custom_minimum_size.x = round(BASE_WIDTH * s)
	add_theme_constant_override(&"margin_top", int(round(BASE_MARGIN * s)))
	add_theme_constant_override(&"margin_bottom", int(round(BASE_MARGIN * s)))
	add_theme_constant_override(&"margin_left", int(round(2.0 * s)))
	add_theme_constant_override(&"margin_right", int(round(2.0 * s)))
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var column: VBoxContainer = VBoxContainer.new()
	column.name = "Palette"
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override(&"separation", int(round(BASE_SEPARATION * s)))
	scroll.add_child(column)

	for spec: Array in TOOLS:
		column.add_child(_tool_button(spec, s))
	column.add_child(HSeparator.new())

	var shapes: GridContainer = _grid("ShapeGrid", s)
	column.add_child(shapes)
	for spec: Array in SHAPES:
		var type_name: String = spec[1]
		var btn: Button = _cell(spec[0], _icon(spec[3]), s, func() -> void: request_create_node.emit(type_name))
		btn.set_meta("label_key", spec[2])
		shapes.add_child(btn)
	column.add_child(HSeparator.new())

	var ops: GridContainer = _grid("OperationGrid", s)
	column.add_child(ops)
	for spec: Array in OPERATIONS:
		var action_id: StringName = spec[2]
		var btn: Button = _cell(spec[0], _icon(spec[4]), s, func() -> void: action_requested.emit(action_id))
		btn.toggle_mode = true
		btn.set_meta("operation", spec[1])
		btn.set_meta("tooltip_key", spec[3])
		ops.add_child(btn)
		_op_buttons.append(btn)
	column.add_child(HSeparator.new())

	var materials: GridContainer = _grid("MaterialGrid", s)
	column.add_child(materials)
	for spec: Array in MATERIALS:
		var preset: CsgBlockoutConfig.MaterialPreset = spec[1]
		var btn: Button = _cell(spec[0], _icon(spec[3]), s, func() -> void: _set_preset(preset))
		btn.toggle_mode = true
		btn.button_group = _material_group
		btn.set_meta("i18n_tooltip_key", spec[2])
		materials.add_child(btn)
		_material_buttons[preset] = btn
	_picker = _cell("MaterialPicker", _icon("empty-material.svg"), s, _request_material)
	_picker.toggle_mode = true
	_picker.button_group = _material_group
	_picker.set_meta("i18n_tooltip_key", "MATERIAL_CUSTOM")
	materials.add_child(_picker)
	_apply = _cell("ApplyToSelected", _icon("apply_material.svg"), s, _apply_to_selected)
	materials.add_child(_apply)
	column.add_child(HSeparator.new())

	var helpers: GridContainer = _grid("HelperGrid", s)
	column.add_child(helpers)
	var ruler: Button = _cell("Ruler", _icon("ruler.svg"), s, func() -> void: action_requested.emit(&"add_ruler"))
	ruler.set_meta("i18n_tooltip_key", "ADD_RULER_TOOLTIP")
	helpers.add_child(ruler)
	var player_ref: Button = _cell("Action_add_player_ref", CSGTopBlockoutBar.editor_icon(&"CharacterBody3D"), s, func() -> void: action_requested.emit(&"add_player_ref"))
	player_ref.set_meta("i18n_tooltip_key", "PLAYER_REF_TOOLTIP")
	helpers.add_child(player_ref)

	_apply_styles(s)
	_translate()
	_sync_materials()

## Clear at rest, a light tint on hover, the editor accent while on (a tool in use,
## the selection's operation, the current material). Narrow side padding: the tool
## names need the whole width in some languages.
func _apply_styles(s: float) -> void:
	var accent: Color = get_theme_color(&"accent_color", &"Editor") if has_theme_color(&"accent_color", &"Editor") else Color(0.44, 0.73, 0.98)
	var font: Color = get_theme_color(&"font_color", &"Label") if has_theme_color(&"font_color", &"Label") else Color(0.88, 0.88, 0.88)
	var normal: StyleBoxEmpty = StyleBoxEmpty.new()
	var hover: StyleBoxFlat = _box(Color(font, 0.08), Color(0, 0, 0, 0), s)
	var pressed: StyleBoxFlat = _box(Color(accent, 0.22), Color(accent, 0.9), s)
	var hover_pressed: StyleBoxFlat = _box(Color(accent, 0.3), Color(accent, 1.0), s)
	for box: StyleBox in [normal, hover, pressed, hover_pressed]:
		box.content_margin_left = 2.0 * s
		box.content_margin_right = 2.0 * s
		box.content_margin_top = 3.0 * s
		box.content_margin_bottom = 3.0 * s
	for btn: Node in find_children("*", "Button", true, false):
		var b: Button = btn as Button
		b.flat = false
		b.add_theme_stylebox_override(&"normal", normal)
		b.add_theme_stylebox_override(&"disabled", normal)
		b.add_theme_stylebox_override(&"focus", StyleBoxEmpty.new())
		b.add_theme_stylebox_override(&"hover", hover)
		b.add_theme_stylebox_override(&"pressed", pressed)
		b.add_theme_stylebox_override(&"hover_pressed", hover_pressed)

static func _box(bg: Color, border: Color, s: float) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(maxi(1, int(round(1.0 * s))) if border.a > 0.0 else 0)
	box.set_corner_radius_all(int(round(4.0 * s)))
	return box

## Tool button: icon above its name, toggled while the tool is on.
func _tool_button(spec: Array, s: float) -> Button:
	var btn: Button = Button.new()
	var tool_id: StringName = spec[0]
	btn.name = "Tool_" + String(tool_id)
	btn.flat = true
	btn.toggle_mode = true
	# Keep keyboard focus in the viewport, so Esc and the tool keys keep working.
	btn.focus_mode = Control.FOCUS_NONE
	btn.icon = _icon(spec[3])
	btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	btn.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
	btn.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	btn.clip_text = true
	btn.add_theme_constant_override(&"icon_max_width", int(round(BASE_ICON * s)))
	btn.add_theme_font_size_override(&"font_size", int(round(BASE_FONT_SIZE * s)))
	btn.custom_minimum_size = Vector2(0.0, round(BASE_TOOL_HEIGHT * s))
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.text = CsgBlockoutI18n.t(spec[1])
	btn.set_meta("i18n_text_key", spec[1])
	btn.set_meta("i18n_tooltip_key", spec[2])
	btn.set_meta("tool_id", tool_id)
	btn.toggled.connect(func(_on: bool) -> void: action_requested.emit(tool_id))
	_tool_buttons.append(btn)
	return btn

func _grid(grid_name: String, s: float) -> GridContainer:
	var grid: GridContainer = GridContainer.new()
	grid.name = grid_name
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override(&"h_separation", int(round(2.0 * s)))
	grid.add_theme_constant_override(&"v_separation", int(round(2.0 * s)))
	return grid

## Icon-only cell of a two-column grid.
func _cell(cell_name: String, icon: Texture2D, s: float, on_pressed: Callable) -> Button:
	var btn: Button = Button.new()
	btn.name = cell_name
	btn.flat = true
	btn.focus_mode = Control.FOCUS_NONE
	btn.icon = icon
	btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	btn.add_theme_constant_override(&"icon_max_width", int(round(BASE_ICON * s)))
	btn.custom_minimum_size = Vector2(0.0, round(BASE_CELL_HEIGHT * s))
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.pressed.connect(on_pressed)
	return btn

## Texts and tooltips in the current language.
func _translate() -> void:
	CsgBlockoutI18n.translate_node(self)
	var hint: String = CsgBlockoutI18n.t("SHAPE_BUTTON_HINT")
	var shapes: Node = find_child("ShapeGrid", true, false)
	if shapes != null:
		for btn: Node in shapes.get_children():
			(btn as Button).tooltip_text = "%s\n%s" % [CsgBlockoutI18n.t(btn.get_meta("label_key")), hint]
	_sync_operations()

func update_language() -> void:
	_translate()

## Reflects the active viewport tool on the tool buttons.
func set_active_tool(tool_id: StringName) -> void:
	for btn: Button in _tool_buttons:
		btn.set_pressed_no_signal(btn.get_meta("tool_id") == tool_id)

func _queue_sync() -> void:
	if _sync_queued:
		return
	_sync_queued = true
	_sync.call_deferred()

func _sync() -> void:
	_sync_queued = false
	if not is_inside_tree():
		return
	_sync_operations()
	_sync_materials()

## Operation buttons act on the selected CSG shapes: dimmed without any, and the
## operation they all share shows as pressed.
func _sync_operations() -> void:
	var ops: Dictionary = {}
	for n: Node in EditorInterface.get_selection().get_selected_nodes():
		if n is CSGShape3D:
			ops[(n as CSGShape3D).operation] = true
	var reason: String = CsgBlockoutI18n.t("REASON_SELECT_CSG")
	for btn: Button in _op_buttons:
		btn.disabled = ops.is_empty()
		btn.set_pressed_no_signal(ops.size() == 1 and ops.has(btn.get_meta("operation")))
		var tip: String = CsgBlockoutI18n.t(btn.get_meta("tooltip_key"))
		btn.tooltip_text = tip if not ops.is_empty() else "%s\n(%s)" % [tip, reason]
	if _apply != null:
		_apply.disabled = ops.is_empty()

func _sync_materials() -> void:
	var preset: int = config.material_preset if config else CsgBlockoutConfig.MaterialPreset.GRID_LIGHT
	for key: int in _material_buttons:
		(_material_buttons[key] as Button).set_pressed_no_signal(key == preset)
	if _picker != null:
		_picker.set_pressed_no_signal(preset == CsgBlockoutConfig.MaterialPreset.CUSTOM)

func _set_preset(preset: CsgBlockoutConfig.MaterialPreset) -> void:
	if config:
		config.material_preset = preset
		config.save_config()
	_sync_materials()

func _apply_to_selected() -> void:
	var nodes: Array[Node] = []
	for n: Node in EditorInterface.get_selection().get_selected_nodes():
		if n is CSGShape3D:
			nodes.append(n)
	if nodes.is_empty():
		CsgBlockoutStatus.show(CsgBlockoutI18n.t("REASON_SELECT_CSG"), true)
		return
	var material: Material = config.get_active_material() if config else null
	var action: CsgBlockoutSceneOps.Action = CsgBlockoutSceneOps.Action.new(CsgBlockoutI18n.t("APPLY_MATERIAL"))
	for n: Node in nodes:
		action.set_property(n, &"material", material)
	action.commit()
	CsgBlockoutStatus.show(CsgBlockoutI18n.tf("STATUS_MATERIAL_APPLIED", [nodes.size()]))

func _request_material() -> void:
	var dialog: EditorFileDialog = EditorFileDialog.new()
	dialog.title = CsgBlockoutI18n.t("SELECT_MATERIAL")
	dialog.display_mode = EditorFileDialog.DISPLAY_LIST
	dialog.filters = ["*.tres, *.material, *.res"]
	dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
	var cleanup: Callable = func() -> void:
		if is_instance_valid(dialog) and dialog.get_parent():
			dialog.get_parent().remove_child(dialog)
			dialog.queue_free()
	dialog.file_selected.connect(func(path: String) -> void:
		cleanup.call()
		var res: Resource = ResourceLoader.load(path) if not path.is_empty() else null
		if res is Material and config:
			config.custom_material = res as Material
			config.material_preset = CsgBlockoutConfig.MaterialPreset.CUSTOM
			config.save_config()
			EditorInterface.get_resource_previewer().queue_edited_resource_preview(res, self, &"_update_picker_icon", null)
		_sync_materials())
	dialog.canceled.connect(func() -> void:
		cleanup.call()
		_sync_materials())
	EditorInterface.get_base_control().add_child(dialog)
	dialog.popup_centered_clamped(Vector2(680, 480) * _scale())

func _update_picker_icon(_path: String, preview: Texture2D, _thumbnail: Texture2D, _userdata: Variant) -> void:
	if preview != null and _picker != null:
		_picker.icon = preview
