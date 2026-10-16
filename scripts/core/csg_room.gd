@tool
class_name CsgBlockoutRoom
extends RefCounted
## Rooms drawn with the Room tool: a CSGCombiner3D holding a "Shell" box and a
## subtracting "Hollow" box. A room is resized through its Shell's faces, and every
## moved face takes the matching Hollow face along, so walls and floor keep their
## thickness and an open top stays open. Doors, windows and cuts set into a moved wall
## go with it; everything else in the room stays where it is. The room node follows
## the Shell's center, so it stays the room's pivot.

const SHELL: String = "Shell"
const HOLLOW: String = "Hollow"
## Smallest inside a shrinking room keeps (meters, local to the Hollow).
const MIN_INNER: float = 0.01
## A part counts as set into a wall when its center is within this of the wall.
const WALL_TOLERANCE: float = 0.01

## The room `n` is, or whose Shell it is; null for anything else. A room whose Hollow
## was turned off the Shell's axes doesn't count (its Shell resizes as a plain box).
static func room_of(n: Node) -> CSGCombiner3D:
	if n == null:
		return null
	var room: Node = n
	if n is CSGBox3D and n.name == SHELL:
		room = n.get_parent()
	if not (room is CSGCombiner3D):
		return null
	var shell: CSGBox3D = room.get_node_or_null(SHELL) as CSGBox3D
	var hollow: CSGBox3D = room.get_node_or_null(HOLLOW) as CSGBox3D
	if shell == null or hollow == null or hollow.operation != CSGShape3D.OPERATION_SUBTRACTION:
		return null
	for axis: int in 3:
		if _matching_axis(hollow.transform.basis, shell.transform.basis[axis]) < 0:
			return null
	return room as CSGCombiner3D

static func shell_of(room: Node) -> CSGBox3D:
	return room.get_node_or_null(SHELL) as CSGBox3D

static func hollow_of(room: Node) -> CSGBox3D:
	return room.get_node_or_null(HOLLOW) as CSGBox3D

## Index of the axis of `b` that runs along `dir` (either way), or -1.
static func _matching_axis(b: Basis, dir: Vector3) -> int:
	var d: Vector3 = dir.normalized()
	for i: int in 3:
		if absf(b[i].normalized().dot(d)) > 0.999:
			return i
	return -1


## One resize of a room along one axis of its Shell, applied live from where it
## started; commit() records start -> end as a single undo step.
class Resize:
	extends RefCounted

	var room: CSGCombiner3D
	var shell: CSGBox3D
	var hollow: CSGBox3D
	var axis: int
	var _hollow_axis: int
	## World direction of the Shell's +axis.
	var _dir: Vector3
	var _shell_scale: float
	var _hollow_scale: float
	## How far the room may shrink along the axis (world meters, <= 0).
	var _min_growth: float
	var _room_start: Vector3
	var _shell_size: Vector3
	var _hollow_size: Vector3
	## The room's other parts: [{"node", "start" (global position), "side"}]; side is +1
	## or -1 for parts set into the wall of the +axis or -axis face, 0 for the rest.
	var _parts: Array[Dictionary] = []
	## [object, property, start value] of everything a resize changes.
	var _tracked: Array[Array] = []

	func _init(p_room: CSGCombiner3D, p_axis: int) -> void:
		room = p_room
		shell = CsgBlockoutRoom.shell_of(room)
		hollow = CsgBlockoutRoom.hollow_of(room)
		axis = p_axis
		var sb: Basis = shell.global_transform.basis
		_dir = sb[axis].normalized()
		_shell_scale = maxf(sb[axis].length(), 0.0001)
		var hb: Basis = hollow.global_transform.basis
		_hollow_axis = CsgBlockoutRoom._matching_axis(hb, _dir)
		_hollow_scale = maxf(hb[_hollow_axis].length(), 0.0001)
		_room_start = room.global_position
		_shell_size = shell.size
		_hollow_size = hollow.size
		var outer: float = _shell_size[axis] * _shell_scale
		var inner: float = _hollow_size[_hollow_axis] * _hollow_scale
		_min_growth = minf(maxf(CsgBlockoutRoom.MIN_INNER * _shell_scale - outer, CsgBlockoutRoom.MIN_INNER * _hollow_scale - inner), 0.0)
		_tracked = [[room, &"position", room.position], [shell, &"size", _shell_size], [hollow, &"size", _hollow_size]]
		# The wall behind each face: from the Shell face to the matching Hollow face.
		var c: float = _dir.dot(shell.global_position)
		var hc: float = _dir.dot(hollow.global_position)
		var plus: Vector2 = Vector2(minf(c + outer * 0.5, hc + inner * 0.5), maxf(c + outer * 0.5, hc + inner * 0.5))
		var minus: Vector2 = Vector2(minf(c - outer * 0.5, hc - inner * 0.5), maxf(c - outer * 0.5, hc - inner * 0.5))
		var tol: float = CsgBlockoutRoom.WALL_TOLERANCE
		for child: Node in room.get_children():
			if child == shell or child == hollow or not (child is Node3D):
				continue
			var part: Node3D = child as Node3D
			var p: float = _dir.dot(CsgBlockoutSelection.world_aabb(part).get_center())
			var side: int = 0
			if p >= plus.x - tol and p <= plus.y + tol:
				side = 1
			elif p >= minus.x - tol and p <= minus.y + tol:
				side = -1
			_parts.append({"node": part, "start": part.global_position, "side": side})
			_tracked.append([part, &"position", part.position])

	## Moves the +axis face out by `grow_pos` and the -axis face out by `grow_neg` (world
	## meters, negative shrinks), never closing the inside. Returns what was applied.
	func apply(grow_pos: float, grow_neg: float) -> Vector2:
		var total: float = grow_pos + grow_neg
		if total < _min_growth:
			var k: float = _min_growth / total
			grow_pos *= k
			grow_neg *= k
			total = _min_growth
		var s: Vector3 = _shell_size
		s[axis] += total / _shell_scale
		shell.size = s
		var h: Vector3 = _hollow_size
		h[_hollow_axis] += total / _hollow_scale
		hollow.size = h
		# Shell and Hollow ride on the room; the other parts keep their place in the world.
		room.global_position = _room_start + _dir * ((grow_pos - grow_neg) * 0.5)
		for part: Dictionary in _parts:
			var move: Vector3 = Vector3.ZERO
			match int(part["side"]):
				1:
					move = _dir * grow_pos
				-1:
					move = -_dir * grow_neg
			(part["node"] as Node3D).global_position = (part["start"] as Vector3) + move
		return Vector2(grow_pos, grow_neg)

	## Records the current state as one undo step (restoring the start first) and
	## returns false when nothing changed.
	func commit(action_name: String) -> bool:
		var finals: Array = []
		for t: Array in _tracked:
			finals.append((t[0] as Object).get(t[1]))
			(t[0] as Object).set(t[1], t[2])
		var action: CsgBlockoutSceneOps.Action = CsgBlockoutSceneOps.Action.new(action_name)
		for i: int in _tracked.size():
			var t: Array = _tracked[i]
			if not (finals[i] as Vector3).is_equal_approx(t[2]):
				action.set_property(t[0], t[1], finals[i])
		if action.is_empty():
			return false
		action.commit()
		return true
