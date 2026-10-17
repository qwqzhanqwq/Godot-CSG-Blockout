@tool
class_name CSGPlayerReference3D extends Node3D
## Player scale reference for blockout: shows the character capsule, crouch and eye
## height, the height you can jump onto, the sprint-jump arc (forward = -Z), the
## steepest walkable slope and the highest step it walks up. Uses the project's player
## metrics unless overridden.
## Editor-only: removed when the game runs.

const GROUP: StringName = &"csg_player_refs"

@export var use_global_metrics: bool = true:
	set(value):
		use_global_metrics = value
		_refresh()

@export_group("Overrides")
@export_range(0.1, 10.0, 0.05, "or_greater", "suffix:m") var character_height: float = 1.8:
	set(value):
		character_height = maxf(value, 0.1)
		_refresh()
@export_range(0.05, 2.0, 0.01, "or_greater", "suffix:m") var capsule_radius: float = 0.35:
	set(value):
		capsule_radius = maxf(value, 0.05)
		_refresh()
@export_range(0.1, 5.0, 0.05, "or_greater", "suffix:m") var crouch_height: float = 1.0:
	set(value):
		crouch_height = maxf(value, 0.1)
		_refresh()
@export_range(0.05, 10.0, 0.05, "or_greater", "suffix:m") var single_jump_height: float = 1.5:
	set(value):
		single_jump_height = maxf(value, 0.05)
		_refresh()
@export_range(0.1, 20.0, 0.05, "or_greater", "suffix:m") var sprint_jump_distance: float = 4.0:
	set(value):
		sprint_jump_distance = maxf(value, 0.1)
		_refresh()
@export_range(1.0, 89.0, 0.5, "suffix:°") var max_slope_angle: float = 45.0:
	set(value):
		max_slope_angle = clampf(value, 1.0, 89.0)
		_refresh()

@export_group("Display")
@export var show_jump_arc: bool = true:
	set(value):
		show_jump_arc = value
		_refresh()
@export var show_slope: bool = true:
	set(value):
		show_slope = value
		_refresh()

func _ready() -> void:
	if not Engine.is_editor_hint():
		queue_free()
		return
	if not is_in_group(GROUP):
		add_to_group(GROUP)
	var cfg: CsgBlockoutConfig = CsgBlockoutConfig.get_config()
	if not cfg.player_metrics_changed.is_connected(_on_metrics_changed):
		cfg.player_metrics_changed.connect(_on_metrics_changed)

func _exit_tree() -> void:
	var cfg: CsgBlockoutConfig = CsgBlockoutConfig.get_config()
	if cfg.player_metrics_changed.is_connected(_on_metrics_changed):
		cfg.player_metrics_changed.disconnect(_on_metrics_changed)

func _on_metrics_changed() -> void:
	if use_global_metrics:
		_refresh()

func _refresh() -> void:
	if is_inside_tree():
		update_gizmos()

## Effective metrics: the project's player metrics, or this node's overrides.
func metrics() -> Dictionary:
	if use_global_metrics:
		return CsgBlockoutConfig.get_config().get_player_metrics()
	return {
		"character_height": character_height,
		"capsule_radius": capsule_radius,
		"crouch_height": crouch_height,
		"single_jump_height": single_jump_height,
		"sprint_jump_distance": sprint_jump_distance,
		"max_slope_angle": max_slope_angle,
		"walk_speed": CsgBlockoutConfig.get_config().get_walk_speed(),
		"max_step_height": CsgBlockoutConfig.get_config().get_max_step_height(),
	}
