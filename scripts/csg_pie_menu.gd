@tool
class_name CsgPieMenu extends Control

signal action_triggered(item: Dictionary)
signal close_requested()

var items: Array = [] # Array[Dictionary]
var menu_stack: Array = [] # Array[Array]
var inner_radius: float = 30.0
var outer_radius: float = 120.0
var active_item_index: int = -1
var is_in_deadzone: bool = true

# Style configuration
var bg_color: Color = Color(0.1, 0.1, 0.15, 0.85)
var hover_color: Color = Color(0.3, 0.5, 0.8, 0.95)
var text_color: Color = Color.WHITE
var line_color: Color = Color(0.2, 0.2, 0.2, 0.8)
var line_width: float = 2.0
var font_size: int = 14

# Animation state
var anim_progress: float = 0.0
var popup_tween: Tween
var item_hover_progress: Array[float] = []

func _ready() -> void:
	set_process(true)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func setup(menu_items: Array) -> void:
	items = menu_items
	menu_stack.clear()
	active_item_index = -1
	_play_popup_anim()

func _play_popup_anim() -> void:
	item_hover_progress.resize(items.size())
	item_hover_progress.fill(0.0)
	
	anim_progress = 0.0
	if popup_tween and popup_tween.is_valid():
		popup_tween.kill()
	popup_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	popup_tween.tween_property(self, "anim_progress", 1.0, 0.25)
	
	queue_redraw()

func _process(delta: float) -> void:
	if items.is_empty():
		return
		
	var mouse_pos: Vector2 = get_local_mouse_position()
	var distance: float = mouse_pos.length()
	var new_active_index: int = -1
	
	is_in_deadzone = distance < inner_radius
	
	if not is_in_deadzone and distance < outer_radius * 2.0:
		var angle: float = mouse_pos.angle()
		var sector_angle: float = TAU / items.size()
		var shifted_angle: float = wrapf(angle + sector_angle / 2.0, 0.0, TAU)
		new_active_index = int(shifted_angle / sector_angle) % items.size()
		
	if new_active_index != active_item_index:
		active_item_index = new_active_index
		
	var needs_redraw: bool = false
	if popup_tween and popup_tween.is_running():
		needs_redraw = true
		
	for i in range(items.size()):
		var target: float = 1.0 if i == active_item_index else 0.0
		if abs(item_hover_progress[i] - target) > 0.01:
			item_hover_progress[i] = lerpf(item_hover_progress[i], target, 20.0 * delta)
			needs_redraw = true
			
	if needs_redraw:
		queue_redraw()

func _draw() -> void:
	if items.is_empty():
		return
		
	var current_outer: float = outer_radius * anim_progress
	var current_inner: float = inner_radius * anim_progress
	
	if current_outer <= 0.01:
		return
		
	var num_items: int = items.size()
	var sector_angle: float = TAU / num_items
	var font: Font = get_theme_font("font", "Label")
	
	# Draw shadow
	draw_circle(Vector2.ZERO, current_outer + 2.0, Color(0, 0, 0, 0.3 * anim_progress))
	
	for i in range(num_items):
		var start_angle: float = i * sector_angle - sector_angle / 2.0
		var end_angle: float = start_angle + sector_angle
		var hover_t: float = item_hover_progress[i]
		
		# Base color lerp + global alpha
		var color: Color = bg_color.lerp(hover_color, hover_t)
		color.a *= anim_progress
		
		# Draw sector polygon
		var points: PackedVector2Array = _get_sector_polygon(start_angle, end_angle, current_inner, current_outer, 16)
		draw_polygon(points, PackedColorArray([color]))
		
		# Draw separator lines
		var line_start: Vector2 = Vector2(cos(start_angle), sin(start_angle)) * current_inner
		var line_end: Vector2 = Vector2(cos(start_angle), sin(start_angle)) * current_outer
		var l_color: Color = line_color
		l_color.a *= anim_progress
		draw_line(line_start, line_end, l_color, line_width, true)
		
		# Draw item text
		var center_angle: float = i * sector_angle
		var text_radius: float = (current_inner + current_outer) / 2.0
		var text_pos: Vector2 = Vector2(cos(center_angle), sin(center_angle)) * text_radius
		
		var item: Dictionary = items[i]
		var text: String = item.get("label", "")
		var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		text_pos -= text_size / 2.0
		text_pos.y += font.get_ascent(font_size) / 2.0
		
		var t_color: Color = text_color
		t_color.a *= anim_progress
		draw_string(font, text_pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, t_color)

	# Draw center deadzone indicator
	if not menu_stack.is_empty():
		var back_color: Color = hover_color if is_in_deadzone else Color(0.2, 0.2, 0.2, 0.8)
		back_color.a *= anim_progress
		draw_circle(Vector2.ZERO, current_inner - 2.0, back_color)
		var back_text: String = "<"
		var bt_size: Vector2 = font.get_string_size(back_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		var bt_pos: Vector2 = - bt_size / 2.0
		bt_pos.y += font.get_ascent(font_size) / 2.0
		
		var bt_color: Color = text_color
		bt_color.a *= anim_progress
		draw_string(font, bt_pos, back_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, bt_color)

func _get_sector_polygon(start_angle: float, end_angle: float, inner_r: float, outer_r: float, point_count: int) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	for i in range(point_count + 1):
		var t: float = float(i) / float(point_count)
		var angle: float = lerpf(start_angle, end_angle, t)
		points.append(Vector2(cos(angle), sin(angle)) * outer_r)
	for i in range(point_count + 1):
		var t: float = float(point_count - i) / float(point_count)
		var angle: float = lerpf(start_angle, end_angle, t)
		points.append(Vector2(cos(angle), sin(angle)) * inner_r)
	return points

func execute_active_item(trigger_close_on_empty: bool = false) -> void:
	if is_in_deadzone:
		if not menu_stack.is_empty():
			go_back()
		elif trigger_close_on_empty:
			close_requested.emit()
		return

	if active_item_index >= 0 and active_item_index < items.size():
		var item: Dictionary = items[active_item_index]
		if item.get("type") == "submenu":
			action_triggered.emit(item)
			menu_stack.push_back(items)
			items = item.get("children", [])
			active_item_index = -1
			_play_popup_anim()
		else:
			action_triggered.emit(item)
			close_requested.emit()
	else:
		if trigger_close_on_empty:
			close_requested.emit()

func execute_back() -> void:
	if not menu_stack.is_empty():
		go_back()
	else:
		close_requested.emit()

func go_back() -> void:
	if not menu_stack.is_empty():
		items = menu_stack.pop_back()
		active_item_index = -1
		_play_popup_anim()
