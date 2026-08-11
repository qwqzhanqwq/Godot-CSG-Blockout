@tool
class_name CSGSpreader3D extends CSGCombiner3D

const SPREADER_NODE_META = "SPREADER_NODE_META"
const MAX_INSTANCES = 200

var _dirty: bool = false
var _generation_in_progress := false
var _template_node: Node3D
@export var template_node: Node3D:
	get: return _template_node
	set(value):
		_template_node = value
		_mark_dirty()

var _hide_template: bool = true
@export var hide_template: bool = true:
	get: return _hide_template
	set(value):
		_hide_template = value
		_update_template_visibility()

var _spread_area_3d: Shape3D = null
@export var spread_area_3d: Shape3D = null:
	get: return _spread_area_3d
	set(value):
		_spread_area_3d = value
		_mark_dirty()

var _max_count: int = 10
@export var max_count: int = 10:
	get: return _max_count
	set(value):
		_max_count = clamp(value, 1, 100000)
		_mark_dirty()

@export_group("Spread Options")
var _noise_threshold: float = 0.5
@export var noise_threshold: float = 0.5:
	get: return _noise_threshold
	set(value):
		_noise_threshold = clamp(value, 0.0, 1.0)
		_mark_dirty()

var _seed: int = 0
@export var seed: int = 0:
	get: return _seed
	set(value):
		_seed = value
		_mark_dirty()

var _allow_rotation: bool = false
@export var allow_rotation: bool = false:
	get: return _allow_rotation
	set(value):
		_allow_rotation = value
		_mark_dirty()

var _allow_scale: bool = false
@export var allow_scale: bool = false:
	get: return _allow_scale
	set(value):
		_allow_scale = value
		_mark_dirty()

var _snap_distance: float = 0.0
@export var snap_distance: float = 0.0:
	get: return _snap_distance
	set(value):
		_snap_distance = value
		_mark_dirty()

@export_group("Collision Options")
var _avoid_overlaps: bool = false
@export var avoid_overlaps: bool = false:
	get: return _avoid_overlaps
	set(value):
		_avoid_overlaps = value
		_mark_dirty()

var _min_distance: float = 1.0
@export var min_distance: float = 1.0:
	get: return _min_distance
	set(value):
		_min_distance = max(0.0, value)
		_mark_dirty()

var _max_placement_attempts: int = 100
@export var max_placement_attempts: int = 100:
	get: return _max_placement_attempts
	set(value):
		_max_placement_attempts = clamp(value, 10, 1000)
		_mark_dirty()

var estimated_instances: int = 0

var rng: RandomNumberGenerator

func _ready() -> void:
	rng = RandomNumberGenerator.new()
	_mark_dirty()

func _process(_delta: float) -> void:
	if not Engine.is_editor_hint(): return
	if _dirty and not _generation_in_progress:
		_dirty = false
		call_deferred("spread_template")

func _exit_tree() -> void:
	if not Engine.is_editor_hint():
		return
	clear_children()

func _mark_dirty() -> void:
	_dirty = true

func _update_template_visibility() -> void:
	if not is_inside_tree():
		return
	if is_instance_valid(_template_node):
		_template_node.visible = not _hide_template

func clear_children() -> void:
	var children_to_remove: Array[Node] = []
	for child in get_children():
		if child.has_meta(SPREADER_NODE_META):
			children_to_remove.append(child)
	for child in children_to_remove:
		remove_child(child)
		child.queue_free()

func get_random_position_in_area() -> Vector3:
	if spread_area_3d == null:
		return Vector3.ZERO
	if spread_area_3d is SphereShape3D:
		var radius = spread_area_3d.get_radius()
		var u = rng.randf()
		var v = rng.randf()
		var theta = u * TAU
		var phi = acos(2.0 * v - 1.0)
		var r = radius * pow(rng.randf(), 1.0 / 3.0)
		return Vector3(r * sin(phi) * cos(theta), r * sin(phi) * sin(theta), r * cos(phi))
	if spread_area_3d is BoxShape3D:
		var size = spread_area_3d.size
		return Vector3(
			rng.randf_range(-size.x * 0.5, size.x * 0.5),
			rng.randf_range(-size.y * 0.5, size.y * 0.5),
			rng.randf_range(-size.z * 0.5, size.z * 0.5)
		)
	if spread_area_3d is CapsuleShape3D:
		var radius = spread_area_3d.get_radius()
		var height = spread_area_3d.get_height() * 0.5
		if rng.randf() < noise_threshold:
			var angle = rng.randf() * TAU
			var r = radius * sqrt(rng.randf())
			return Vector3(r * cos(angle), rng.randf_range(-height, height), r * sin(angle))
		else:
			var hemisphere_y = height if rng.randf() < noise_threshold else -height
			var u = rng.randf()
			var v = rng.randf()
			var theta = u * TAU
			var phi = acos(1.0 - v)
			var r = radius * pow(rng.randf(), 1.0 / 3.0)
			return Vector3(
				r * sin(phi) * cos(theta),
				hemisphere_y + r * cos(phi) * (1 if hemisphere_y > 0 else -1),
				r * sin(phi) * sin(theta)
			)
	if spread_area_3d is CylinderShape3D:
		var radius = spread_area_3d.get_radius()
		var height = spread_area_3d.get_height() * 0.5
		var angle = rng.randf() * TAU
		var r = radius * sqrt(rng.randf())
		return Vector3(r * cos(angle), rng.randf_range(-height, height), r * sin(angle))
	if spread_area_3d is HeightMapShape3D:
		var width = spread_area_3d.map_width
		var depth = spread_area_3d.map_depth
		if width <= 0 or depth <= 0 or spread_area_3d.map_data.size() == 0:
			return Vector3.ZERO
		var x = rng.randi_range(0, width - 1)
		var z = rng.randi_range(0, depth - 1)
		var index = x + z * width
		if index < spread_area_3d.map_data.size():
			return Vector3(x, spread_area_3d.map_data[index], z)
		return Vector3.ZERO
	if spread_area_3d is WorldBoundaryShape3D:
		var bound = 100.0
		return Vector3(rng.randf_range(-bound, bound), 0, rng.randf_range(-bound, bound))
	if spread_area_3d is ConcavePolygonShape3D:
		var faces: PackedVector3Array = spread_area_3d.get_faces()
		if faces.size() < 3:
			return Vector3.ZERO
		var tri_count = faces.size() / 3
		var tri_idx = rng.randi_range(0, tri_count - 1) * 3
		var a = faces[tri_idx]
		var b = faces[tri_idx+1]
		var c = faces[tri_idx+2]
		var r1 = sqrt(rng.randf())
		var r2 = rng.randf()
		return (1.0 - r1) * a + (r1 * (1.0 - r2)) * b + (r1 * r2) * c
	if spread_area_3d is ConvexPolygonShape3D:
		var pts: PackedVector3Array = spread_area_3d.points
		if pts.is_empty():
			return Vector3.ZERO
		var min_point = pts[0]
		var max_point = pts[0]
		for p in pts:
			min_point = min_point.min(p)
			max_point = max_point.max(p)
		return Vector3(
			rng.randf_range(min_point.x, max_point.x),
			rng.randf_range(min_point.y, max_point.y),
			rng.randf_range(min_point.z, max_point.z)
		)
	push_warning("CSGSpreader3D: Shape type not supported")
	return Vector3.ZERO

func spread_template() -> void:
	if _generation_in_progress:
		return
	_generation_in_progress = true
	if not spread_area_3d:
		_generation_in_progress = false
		return
	clear_children()
	if not is_instance_valid(_template_node):
		_generation_in_progress = false
		return
	var template_node: Node3D = _template_node

	rng.seed = _seed
	var instances_created: int = 0
	var placed_positions: Array[Vector3] = []
	var budget: int = min(_max_count, MAX_INSTANCES)
	if _max_count > MAX_INSTANCES:
		push_warning("CSGSpreader3D: max_count %s exceeds cap %s. Limiting." % [_max_count, MAX_INSTANCES])

	# Spatial Hash Grid for O(1) distance checks
	var cell_size: float = _min_distance / sqrt(3.0)
	var spatial_grid: Dictionary = {}

	for i in range(budget):
		var noise_value: float = rng.randf()
		if noise_value <= _noise_threshold:
			continue
			
		var position_found: bool = false
		var final_position: Vector3 = Vector3.ZERO
		var attempts: int = _max_placement_attempts if _avoid_overlaps else 1
		
		for attempt in range(attempts):
			var test_position: Vector3 = get_random_position_in_area()
			if not _avoid_overlaps:
				final_position = test_position
				position_found = true
				break
				
			var overlap: bool = false
			if cell_size > 0.001:
				# O(1) spatial grid lookup
				var grid_x: int = int(floor(test_position.x / cell_size))
				var grid_y: int = int(floor(test_position.y / cell_size))
				var grid_z: int = int(floor(test_position.z / cell_size))
				
				# Check surrounding 27 cells
				for dx in range(-1, 2):
					for dy in range(-1, 2):
						for dz in range(-1, 2):
							var check_key: String = str(grid_x + dx) + "_" + str(grid_y + dy) + "_" + str(grid_z + dz)
							if spatial_grid.has(check_key):
								var existing_pos: Vector3 = spatial_grid[check_key]
								if test_position.distance_to(existing_pos) < _min_distance:
									overlap = true
									break
						if overlap: break
					if overlap: break
			else:
				# Fallback if min_distance is virtually zero
				for existing_pos in placed_positions:
					if test_position.distance_to(existing_pos) < _min_distance:
						overlap = true
						break
						
			if not overlap:
				final_position = test_position
				position_found = true
				break
				
		if not position_found:
			continue
			
		var instance: Node = template_node.duplicate()
		if instance == null:
			continue
		instance.set_meta(SPREADER_NODE_META, true)
		if instance is Node3D:
			instance.transform.origin = final_position
			instance.visible = true
			if _allow_rotation:
				var rotation_y: float = rng.randf_range(0.0, TAU)
				instance.rotate_y(rotation_y)
			if _allow_scale:
				var scale_factor: float = rng.randf_range(0.5, 2.0)
				instance.scale *= scale_factor
				
		placed_positions.append(final_position)
		if _avoid_overlaps and cell_size > 0.001:
			var grid_x: int = int(floor(final_position.x / cell_size))
			var grid_y: int = int(floor(final_position.y / cell_size))
			var grid_z: int = int(floor(final_position.z / cell_size))
			var key: String = str(grid_x) + "_" + str(grid_y) + "_" + str(grid_z)
			spatial_grid[key] = final_position
			
		add_child(instance)
		instances_created += 1
		
	estimated_instances = instances_created
	_update_template_visibility()
	_generation_in_progress = false

func bake_instances() -> void:
	if get_child_count() == 0:
		return
	var target_owner: Node = owner
	if target_owner == null:
		if get_tree() and get_tree().edited_scene_root:
			target_owner = get_tree().edited_scene_root
		else:
			target_owner = self

	for child in get_children(true):
		if child.has_meta(SPREADER_NODE_META):
			child.remove_meta(SPREADER_NODE_META)
			child.set_owner(target_owner)
			var stack: Array[Node] = []
			stack.append_array(child.get_children())
			while stack.size() > 0:
				var node: Node = stack.pop_back()
				node.set_owner(target_owner)
				stack.append_array(node.get_children())

func _get_property_list() -> Array[Dictionary]:
	return [{
		"name": "estimated_instances",
		"type": TYPE_INT,
		"usage": PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_STORAGE | PROPERTY_USAGE_READ_ONLY
	}]
