class_name CSGBlockoutTestPawn
extends CharacterBody3D
## First-person test character spawned by "Play From Here".
## Reads physical keys directly (no InputMap changes): WASD / arrows move, Space
## jumps, Shift sprints, Ctrl crouches, R respawns, Esc frees the mouse.
## Its numbers come from the player metrics: the jump reaches single_jump_height and
## a sprint jump on flat ground covers sprint_jump_distance, the same values the
## level ruler and checks use. On the ground it walks up steps as high as
## max_step_height (stairs warn when theirs are higher); in the air it doesn't, so jumps
## stay exactly as high as the ruler says. Runtime script: must not reference editor
## classes.

const MOUSE_SENSITIVITY: float = 0.0025
const EYE_OFFSET: float = 0.12
const ACCELERATION: float = 40.0
## How fast (m/s) the view catches up after a step, so climbing doesn't jolt it.
const STEP_CAMERA_SPEED: float = 2.5

var metrics: Dictionary = {}
var spawn: Transform3D = Transform3D.IDENTITY
## False for automated runs, so the real mouse is never grabbed.
var capture_mouse: bool = true
## Localized controls line provided by the editor (runtime has no i18n tables).
var hud_text: String = ""

var _camera: Camera3D
var _shape: CollisionShape3D
var _capsule: CapsuleShape3D
var _hud: Label
var _gravity: float = 9.8
var _walk_speed: float = 5.0
var _sprint_speed: float = 7.0
var _jump_velocity: float = 5.0
var _height: float = 1.8
var _crouch_height: float = 1.0
var _step_height: float = 0.3
## How far the camera still trails below the eye after the last steps.
var _camera_drop: float = 0.0
## Held on a step's edge or tread by _follow_ground (counts as standing).
var _supported: bool = false
var _crouched: bool = false
var _pitch: float = 0.0

func setup(p_metrics: Dictionary, p_spawn: Transform3D) -> void:
	metrics = p_metrics
	spawn = p_spawn
	_gravity = float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
	_height = float(metrics.get("character_height", 1.8))
	_crouch_height = minf(float(metrics.get("crouch_height", 1.0)), _height)
	var radius: float = minf(float(metrics.get("capsule_radius", 0.35)), _height * 0.5)
	var jump_height: float = float(metrics.get("single_jump_height", 1.5))
	var jump_distance: float = float(metrics.get("sprint_jump_distance", 4.0))
	_walk_speed = float(metrics.get("walk_speed", 5.0))
	_jump_velocity = sqrt(2.0 * _gravity * jump_height)
	# Time in the air for a jump on flat ground; sprinting covers jump_distance in it.
	var airtime: float = 2.0 * _jump_velocity / _gravity
	_sprint_speed = jump_distance / airtime
	# Walking never outruns sprinting, so no jump exceeds sprint_jump_distance.
	_walk_speed = minf(_walk_speed, _sprint_speed)
	floor_max_angle = deg_to_rad(float(metrics.get("max_slope_angle", 45.0)))
	_step_height = maxf(float(metrics.get("max_step_height", 0.3)), 0.0)
	# Stays on the ground walking down anything it can walk up.
	floor_snap_length = maxf(_step_height + 0.05, 0.1)

	_capsule = CapsuleShape3D.new()
	_capsule.radius = radius
	_capsule.height = _height
	_shape = CollisionShape3D.new()
	_shape.shape = _capsule
	_shape.position.y = _height * 0.5
	add_child(_shape)

	_camera = Camera3D.new()
	_camera.position.y = _height - EYE_OFFSET
	_camera.fov = 75.0
	_camera.near = 0.05
	add_child(_camera)

	var layer: CanvasLayer = CanvasLayer.new()
	_hud = Label.new()
	_hud.position = Vector2(16, 12)
	_hud.add_theme_color_override(&"font_color", Color(1, 1, 1))
	_hud.add_theme_color_override(&"font_outline_color", Color(0, 0, 0))
	_hud.add_theme_constant_override(&"outline_size", 4)
	layer.add_child(_hud)
	add_child(layer)

func _ready() -> void:
	global_transform = spawn
	_camera.make_current()
	if capture_mouse:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func respawn() -> void:
	global_transform = spawn
	velocity = Vector3.ZERO
	_supported = false
	_pitch = 0.0
	_camera.rotation.x = 0.0

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var mm: InputEventMouseMotion = event as InputEventMouseMotion
		rotate_y(-mm.screen_relative.x * MOUSE_SENSITIVITY)
		_pitch = clampf(_pitch - mm.screen_relative.y * MOUSE_SENSITIVITY, -1.5, 1.5)
		_camera.rotation.x = _pitch
	elif event is InputEventKey and event.is_pressed() and not event.is_echo():
		match (event as InputEventKey).physical_keycode:
			KEY_ESCAPE:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED
			KEY_R:
				respawn()
	elif event is InputEventMouseButton and event.is_pressed() and capture_mouse and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _physics_process(delta: float) -> void:
	_update_crouch()
	var grounded: bool = is_on_floor() or _supported
	if not grounded:
		velocity.y -= _gravity * delta
	elif Input.is_physical_key_pressed(KEY_SPACE) and not _crouched:
		velocity.y = _jump_velocity
	var input: Vector2 = Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		input.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		input.y += 1.0
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		input.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		input.x += 1.0
	var dir: Vector3 = (global_transform.basis * Vector3(input.x, 0.0, input.y))
	dir.y = 0.0
	dir = dir.normalized()
	var speed: float = _walk_speed
	if Input.is_physical_key_pressed(KEY_SHIFT) and not _crouched:
		speed = _sprint_speed
	elif _crouched:
		speed = _walk_speed * 0.5
	var target: Vector3 = dir * speed
	var accel: float = ACCELERATION if grounded else ACCELERATION * 0.25
	velocity.x = move_toward(velocity.x, target.x, accel * delta)
	velocity.z = move_toward(velocity.z, target.z, accel * delta)
	if _step_up(delta, grounded):
		_supported = true
	else:
		move_and_slide()
		_supported = _follow_ground(grounded)
	_camera_drop = move_toward(_camera_drop, 0.0, STEP_CAMERA_SPEED * delta)
	_place_camera()
	if global_position.y < spawn.origin.y - 100.0:
		respawn()
	_update_hud()

func _update_crouch() -> void:
	var want: bool = Input.is_physical_key_pressed(KEY_CTRL)
	if want == _crouched:
		return
	if not want and not _can_stand():
		return
	_crouched = want
	var h: float = _crouch_height if _crouched else _height
	_capsule.height = maxf(h, _capsule.radius * 2.0)
	_shape.position.y = _capsule.height * 0.5
	_place_camera()

func _place_camera() -> void:
	var h: float = _crouch_height if _crouched else _height
	_camera.position.y = h - EYE_OFFSET - _camera_drop

## Walks up a step: on the ground, when this frame's move runs into something too
## steep to walk on, looks for a walkable tread just past the contact no higher than
## max_step_height, lifts the pawn onto it and makes the move there. A capsule rests
## on a step's edge first, so climbing one takes a few frames at walking speed.
## Returns true when it moved the pawn (instead of move_and_slide).
func _step_up(delta: float, grounded: bool) -> bool:
	if _step_height <= 0.0 or not grounded or velocity.y > 0.0:
		return false
	var motion: Vector3 = Vector3(velocity.x, 0.0, velocity.z) * delta
	if motion.length() < 0.0001:
		return false
	var from: Transform3D = global_transform
	var blocked: KinematicCollision3D = KinematicCollision3D.new()
	if not test_move(from, motion, blocked) or blocked.get_normal().angle_to(Vector3.UP) <= floor_max_angle:
		return false
	var probe: Vector3 = blocked.get_position() + motion.normalized() * 0.05
	var tread: Dictionary = _walkable_hit(Vector3(probe.x, from.origin.y + _step_height + 0.05, probe.z), Vector3(probe.x, from.origin.y, probe.z))
	if tread.is_empty():
		return false
	var rise: float = (tread["position"] as Vector3).y - from.origin.y
	if rise <= 0.001 or rise > _step_height:
		return false
	var lift: Vector3 = Vector3.UP * (rise + 0.01)
	if test_move(from, lift):
		return false
	var raised: Transform3D = from.translated(lift)
	if test_move(raised, motion):
		return false
	var ahead: Transform3D = raised.translated(motion)
	var landing: KinematicCollision3D = KinematicCollision3D.new()
	if not test_move(ahead, -lift, landing):
		return false
	var landed: Vector3 = ahead.origin + landing.get_travel()
	_camera_drop = minf(_camera_drop + landed.y - from.origin.y, _step_height)
	global_position = landed
	return true

## Walks down steps on the ground: rounding a step's edge, the capsule touches it at a
## slope too steep to count as floor, so Godot's floor snap lets go and the pawn would
## hop down every step. After walking (not jumping) off something, when a walkable
## surface lies at most max_step_height below its center, settles it down onto the
## edge or tread instead. Returns true when it holds the pawn that way.
func _follow_ground(was_grounded: bool) -> bool:
	if is_on_floor() or not was_grounded or velocity.y > 0.0 or _step_height <= 0.0:
		return false
	var feet: Vector3 = global_position
	if _walkable_hit(feet + Vector3.UP * 0.05, feet + Vector3.DOWN * (_step_height + 0.05)).is_empty():
		return false
	var settle: KinematicCollision3D = KinematicCollision3D.new()
	if not test_move(global_transform, Vector3.DOWN * (_step_height + 0.05), settle):
		return false
	global_position += settle.get_travel()
	velocity.y = 0.0
	return true

## Ray hit on a surface the pawn can stand on, or {}.
func _walkable_hit(from: Vector3, to: Vector3) -> Dictionary:
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to, collision_mask, [get_rid()])
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or (hit["normal"] as Vector3).angle_to(Vector3.UP) > floor_max_angle:
		return {}
	return hit

## True when nothing blocks standing up from a crouch.
func _can_stand() -> bool:
	var params: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	var tall: CapsuleShape3D = CapsuleShape3D.new()
	tall.radius = _capsule.radius * 0.9
	tall.height = _height
	params.shape = tall
	params.transform = Transform3D(Basis.IDENTITY, global_position + Vector3(0, _height * 0.5 + 0.02, 0))
	params.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_shape(params, 1).is_empty()

func _update_hud() -> void:
	var flat: Vector2 = Vector2(velocity.x, velocity.z)
	var controls: String = hud_text if not hud_text.is_empty() else "WASD move · Space jump · Shift sprint · Ctrl crouch · R respawn · Esc mouse · F8 stop"
	_hud.text = "CSG Blockout · Play From Here\n%s\n%.1f m/s%s" % [controls, flat.length(), "  (crouched)" if _crouched else ""]
