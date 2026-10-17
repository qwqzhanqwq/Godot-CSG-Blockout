@tool
class_name CsgBlockoutNaming
extends RefCounted
## Semantic names for blockout nodes: <Role>_<Context>_<NN>, e.g. Wall_Corridor_03.
## Role comes from the shape type, its operation and proportions; Context is the name
## of the enclosing group when that name means something (not "Group", "Level", a
## class name, ...). Structural parts made by the tools (room Shell/Hollow, frame
## pieces) and frozen nodes keep their names.

const GENERIC_CONTEXTS: PackedStringArray = ["group", "level", "blockout", "root", "world", "scene", "main", "geometry", "csg"]
const STRUCTURAL_NAMES: PackedStringArray = ["Shell", "Hollow", "JambLeft", "JambRight", "Head", "Sill"]

## Role word for a node, or "" when it shouldn't be renamed.
static func role(n: Node) -> String:
	if CsgBlockoutFreeze.is_frozen(n):
		return ""
	if n is CSGRuler3D:
		return "Ruler"
	if n is CSGStairs3D:
		return "Ramp" if (n as CSGStairs3D).is_ramp else "Stairs"
	if n is CSGWedge3D:
		return "Wedge"
	if n is CSGArch3D:
		return "Arch"
	if n is CSGCurvedWall3D:
		return "CurvedWall"
	if n is CSGSpiralStairs3D:
		return "SpiralStairs"
	if n is CSGCombiner3D:
		if n.get_node_or_null("Shell") != null and n.get_node_or_null("Hollow") != null:
			return "Room"
		if n.get_node_or_null("JambLeft") != null and n.get_node_or_null("JambRight") != null:
			return "Frame"
		return "Group"
	if not (n is CSGShape3D):
		return ""
	var shape: CSGShape3D = n as CSGShape3D
	var cut: bool = shape.operation == CSGShape3D.OPERATION_SUBTRACTION
	var size: Vector3 = CsgBlockoutShapeInfo.world_size(shape)
	var box: AABB = CsgBlockoutSelection.world_aabb(shape)
	var thin: float = minf(size.x, size.z)
	var wide: float = maxf(size.x, size.z)
	if shape is CSGBox3D:
		if cut:
			if thin <= 1.0 and wide >= 0.6 and wide <= 2.6 and size.y >= 1.8 and size.y <= 3.2:
				return "Door"
			if thin <= 1.0 and wide <= 3.0 and size.y < 1.8 and box.position.y - _floor_level(shape) >= 0.3:
				return "Window"
			return "Cut"
		if size.y <= 0.6 and size.y < thin * 0.5:
			return "Floor" if box.position.y - _floor_level(shape) < 0.5 else "Platform"
		if thin <= 0.6 and size.y >= 1.5:
			return "Wall"
		if wide <= 1.2 and size.y >= 2.0:
			return "Pillar"
		return "Block"
	if shape is CSGCylinder3D:
		if cut:
			return "Hole"
		return "Column" if size.y >= wide * 1.5 else "Cylinder"
	if shape is CSGSphere3D:
		return "Sphere"
	if shape is CSGTorus3D:
		return "Torus"
	if shape is CSGPolygon3D:
		return "Polygon"
	if shape is CSGMesh3D:
		return "Mesh"
	return ""

## Lowest point of the CSG tree the shape belongs to (its local "floor").
static func _floor_level(shape: CSGShape3D) -> float:
	var root: CSGShape3D = CsgBlockoutShapeInfo.csg_root_of(shape)
	return CsgBlockoutSelection.world_aabb(root).position.y if root != null else 0.0

## Meaningful name of the enclosing group, or "".
static func context(n: Node) -> String:
	var p: Node = n.get_parent()
	var scene_root: Node = EditorInterface.get_edited_scene_root()
	while p != null and p != scene_root:
		var raw: String = String(p.name)
		var stem: String = raw.rstrip("0123456789").trim_suffix("_")
		var lowered: String = stem.to_lower()
		var is_class_name: bool = ClassDB.class_exists(StringName(stem)) or stem.begins_with("CSG")
		if not stem.is_empty() and not is_class_name and not GENERIC_CONTEXTS.has(lowered) and role(p) != "Frame":
			return raw.replace("_", "")
		p = p.get_parent()
	return ""

## Proposed new names for `nodes`: {node: new_name}, numbered per sibling group.
static func plan(nodes: Array[Node]) -> Dictionary:
	var counters: Dictionary = {}
	var result: Dictionary = {}
	for n: Node in nodes:
		if STRUCTURAL_NAMES.has(String(n.name)) and n.get_parent() is CSGCombiner3D:
			continue
		var r: String = role(n)
		if r.is_empty():
			continue
		var ctx: String = context(n)
		var stem: String = r if ctx.is_empty() else "%s_%s" % [r, ctx]
		var key: String = "%d|%s" % [n.get_parent().get_instance_id(), stem]
		var idx: int = int(counters.get(key, 0)) + 1
		counters[key] = idx
		result[n] = "%s_%02d" % [stem, idx]
	# Avoid clashing with siblings that are not being renamed.
	for n: Node in result:
		var wanted: String = result[n]
		var parent: Node = n.get_parent()
		var other: Node = parent.get_node_or_null(NodePath(wanted))
		var bump: int = 1
		while other != null and other != n and not result.has(other):
			bump += 1
			wanted = "%s_%d" % [result[n], bump]
			other = parent.get_node_or_null(NodePath(wanted))
		result[n] = wanted
	return result

const AUTO_STEMS: PackedStringArray = ["Box", "Cylinder", "Sphere", "Torus", "Polygon", "Mesh", "Stairs", "Ramp", "Ruler",
	"Floor", "Platform", "Wall", "Pillar", "Column", "Block", "Cut", "Hole", "Door", "Window", "Room", "Group", "Frame",
	"Wedge", "Arch", "CurvedWall", "SpiralStairs"]

static var _auto_regex: RegEx

## True for names the editor or CSG Blockout generated (CSGBox3D2, Box_03,
## Wall_Corridor_01, ...), as opposed to names the user typed.
static func is_auto_name(node_name: String) -> bool:
	if _auto_regex == null:
		_auto_regex = RegEx.create_from_string("^(?:CSG[A-Za-z]+3D\\d*|(?:%s)(?:_[A-Za-z0-9]+)?(?:_\\d+)?\\d*)$" % "|".join(AUTO_STEMS))
	return _auto_regex.search(node_name) != null

## Every node under `root` (depth first) that has a role and an auto-generated name.
static func collect(root: Node) -> Array[Node]:
	var out: Array[Node] = []
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_front()
		if n != root and not role(n).is_empty() and is_auto_name(String(n.name)):
			out.append(n)
		if n is CSGShape3D or n == root or (n is Node3D and not CsgBlockoutFreeze.is_frozen(n)):
			for i: int in range(n.get_child_count() - 1, -1, -1):
				stack.push_front(n.get_child(i))
	return out

## Renames `nodes` semantically as one undo step. Renames are applied through
## temporary names so swapping names between siblings never collides.
static func rename(nodes: Array[Node]) -> int:
	var names: Dictionary = plan(nodes)
	var changed: Array[Node] = []
	for n: Node in names:
		if String(n.name) != names[n]:
			changed.append(n)
	if changed.is_empty():
		return 0
	var action: CsgBlockoutSceneOps.Action = CsgBlockoutSceneOps.Action.new(CsgBlockoutI18n.t("RENAME_SEMANTIC_ACTION"))
	var temp: Dictionary = {}
	for n: Node in changed:
		temp[n] = "%s__ren_%d" % [names[n], n.get_instance_id()]
		action.rename(n, temp[n])
	for n: Node in changed:
		action.set_property_from(n, &"name", temp[n], names[n])
	action.commit()
	return changed.size()
