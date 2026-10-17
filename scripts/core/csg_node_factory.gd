@tool
class_name CsgBlockoutNodeFactory
extends RefCounted
## The single creation path for the pie menu, sidebar and top bar.
## With a surface hit (pie menu): the shape joins the CSG tree it was put on, like
## a drawn box (see parent_for_hit), and sits on that surface (resting on it for
## union/intersection, half-embedded for subtraction), aligned to its normal and
## snapped to the grid.
## Without one (sidebar, top bar): a selected combiner receives the new node as a
## child; a selected shape gets it as the next sibling; otherwise it goes under the
## scene root.

const BASE_NAMES: Dictionary = {
	"CSGBox3D": "Box",
	"CSGCylinder3D": "Cylinder",
	"CSGSphere3D": "Sphere",
	"CSGTorus3D": "Torus",
	"CSGPolygon3D": "Polygon",
	"CSGMesh3D": "Mesh",
	"CSGCombiner3D": "Group",
	"CSGStairs3D": "Stairs",
	"CSGWedge3D": "Wedge",
	"CSGArch3D": "Arch",
	"CSGCurvedWall3D": "CurvedWall",
	"CSGSpiralStairs3D": "SpiralStairs",
	"CSGRuler3D": "Ruler",
	"CSGPlayerReference3D": "PlayerRef",
	"CSGRepeater3D": "Repeater",
	"CSGSpreader3D": "Spreader",
}

static func instantiate(type_name: String) -> Node3D:
	match type_name:
		"CSGStairs3D":
			return CSGStairs3D.new()
		"CSGWedge3D":
			return CSGWedge3D.new()
		"CSGArch3D":
			return CSGArch3D.new()
		"CSGCurvedWall3D":
			return CSGCurvedWall3D.new()
		"CSGSpiralStairs3D":
			return CSGSpiralStairs3D.new()
		"CSGRuler3D":
			return CSGRuler3D.new()
		"CSGPlayerReference3D":
			return CSGPlayerReference3D.new()
		"CSGRepeater3D":
			return CSGRepeater3D.new()
		"CSGSpreader3D":
			return CSGSpreader3D.new()
	if ClassDB.class_exists(type_name) and ClassDB.can_instantiate(type_name) and ClassDB.is_parent_class(type_name, &"Node3D"):
		return ClassDB.instantiate(type_name) as Node3D
	return null

## Creates `type_name` as one undo step and selects it. `hit` (optional) is a surface
## under the cursor; `op` the boolean operation of a CSG shape. Returns the created
## node or null.
static func create(type_name: String, hit: CsgBlockoutRaycast.Hit = null, op: CSGShape3D.Operation = CSGShape3D.OPERATION_UNION) -> Node3D:
	var node: Node3D = instantiate(type_name)
	if node == null:
		push_warning(CsgBlockoutI18n.t("WARN_UNSUPPORTED_CSG_TYPE"))
		return null
	var config: CsgBlockoutConfig = CsgBlockoutConfig.get_config()
	var operation: CSGShape3D.Operation = op
	if node is CSGShape3D:
		(node as CSGShape3D).operation = operation
		if config:
			(node as CSGShape3D).material = config.get_active_material()

	var root: Node = CsgBlockoutSceneOps.edited_root()
	if root == null:
		push_warning("CSG Blockout: Cannot create node; no edited scene.")
		node.free()
		return null

	var action_name: String = CsgBlockoutI18n.tf("CREATE_NODE", [CsgBlockoutI18n.t(type_name)])
	var action: CsgBlockoutSceneOps.Action = CsgBlockoutSceneOps.Action.new(action_name)
	var on_surface: bool = hit != null and hit.is_valid()
	var parent: Node
	var index: int = -1
	var xform: Transform3D
	if on_surface and node is CSGShape3D:
		var target: Dictionary = parent_for_hit(hit, operation)
		parent = target["parent"]
		index = target["index"]
		if target["wrap"] != null:
			parent = wrap_in_combiner(action, target["wrap"])
	else:
		var target: Dictionary = resolve_parent(node)
		parent = target["parent"]
		index = target["index"]
		if not on_surface:
			# No cursor surface (sidebar/top bar click): start at the selection, snapped
			# horizontally only so the height of the reference shape is kept.
			var anchor: Node3D = target["anchor"]
			var grid: CsgBlockoutGrid = CsgBlockoutGrid.get_grid()
			var origin: Vector3 = anchor.global_position if anchor != null else Vector3.ZERO
			var snapped_origin: Vector3 = grid.snap_point(origin, grid.snap_enabled)
			xform = Transform3D(Basis.IDENTITY, Vector3(snapped_origin.x, origin.y, snapped_origin.z))
	if on_surface:
		xform = surface_transform(node, hit, operation)

	init_collision(node, parent)
	node.name = CsgBlockoutSceneOps.unique_child_name(parent, BASE_NAMES.get(type_name, type_name))
	action.add_node(parent, node, index, xform).select([node]).commit()
	return node

## A shape that starts a new CSG tree under `parent` gets collision, so the test
## character can walk it and freezing it makes a collision body. Shapes inside a
## tree don't need it: only the root's setting counts.
static func init_collision(node: Node, parent: Node) -> void:
	if node is CSGShape3D and not (parent is CSGShape3D):
		(node as CSGShape3D).use_collision = true

## Parent/index/anchor for a new node based on the current selection.
static func resolve_parent(node: Node3D) -> Dictionary:
	var root: Node = CsgBlockoutSceneOps.edited_root()
	var selected: Array[Node] = EditorInterface.get_selection().get_selected_nodes()
	var first: Node3D = selected[0] as Node3D if not selected.is_empty() and selected[0] is Node3D else null
	if first == null:
		return {"parent": root, "index": -1, "anchor": null}
	if not (node is CSGShape3D):
		# Helpers (rulers, player references) never go inside a CSG tree.
		var holder: Node = first
		while holder is CSGShape3D and holder != root:
			holder = holder.get_parent()
		return {"parent": holder if holder != null else root, "index": -1, "anchor": first}
	if first is CSGCombiner3D:
		return {"parent": first, "index": -1, "anchor": first}
	if first is CSGShape3D and first != root and first.get_parent() != null:
		return {"parent": first.get_parent(), "index": first.get_index() + 1, "anchor": first}
	return {"parent": first, "index": -1, "anchor": first}

## Where a shape drawn on `hit` should go: {"parent", "index", "wrap"}. Only the
## surface decides (never the selection, which may be somewhere else entirely):
## - It joins the combiner that owns the surface it was drawn on, so a subtraction
##   cuts that geometry. A lone root primitive is returned as "wrap": the caller
##   puts it under a new combiner first (subtraction needs a parent).
## - Drawn in empty space: under the scene root.
## New shapes are appended so subtractions apply to everything before them.
static func parent_for_hit(hit: CsgBlockoutRaycast.Hit, op: CSGShape3D.Operation) -> Dictionary:
	var root: Node = CsgBlockoutSceneOps.edited_root()
	if hit != null and hit.is_valid() and hit.collider is CSGShape3D:
		var surface: CSGShape3D = hit.solid_shape if hit.solid_shape != null else hit.shape
		if surface == null:
			surface = hit.collider as CSGShape3D
		var p: Node = surface.get_parent()
		if surface is CSGCombiner3D:
			return {"parent": surface, "index": -1, "wrap": null}
		if p is CSGShape3D:
			return {"parent": p, "index": -1, "wrap": null}
		if op == CSGShape3D.OPERATION_SUBTRACTION and surface != root:
			return {"parent": p, "index": -1, "wrap": surface}
		return {"parent": p if p != null else root, "index": surface.get_index() + 1 if p != null else -1, "wrap": null}
	return {"parent": root, "index": -1, "wrap": null}

## Queues "wrap `lone` into a new combiner" on `action` and returns the combiner.
static func wrap_in_combiner(action: CsgBlockoutSceneOps.Action, lone: Node3D) -> CSGCombiner3D:
	var combiner: CSGCombiner3D = CSGCombiner3D.new()
	if lone is CSGShape3D:
		combiner.use_collision = (lone as CSGShape3D).use_collision
	var parent: Node = lone.get_parent()
	combiner.name = CsgBlockoutSceneOps.unique_child_name(parent, String(lone.name) + "_Group")
	action.add_node(parent, combiner, lone.get_index(), Transform3D(Basis.IDENTITY, lone.global_position), "self")
	action.reparent(lone, combiner)
	return combiner

## Basis whose +Y follows `normal`; floors keep the world orientation.
static func basis_from_normal(normal: Vector3) -> Basis:
	var y: Vector3 = normal.normalized()
	if y.dot(Vector3.UP) > 0.999:
		return Basis.IDENTITY
	if y.dot(Vector3.DOWN) > 0.999:
		return Basis(Vector3.RIGHT, PI)
	var ref: Vector3 = Vector3.UP if absf(y.dot(Vector3.UP)) < 0.99 else Vector3.FORWARD
	var x: Vector3 = ref.cross(y).normalized()
	var z: Vector3 = x.cross(y).normalized()
	return Basis(x, y, z)

static func surface_transform(node: Node3D, hit: CsgBlockoutRaycast.Hit, op: CSGShape3D.Operation) -> Transform3D:
	var grid: CsgBlockoutGrid = CsgBlockoutGrid.get_grid()
	var basis: Basis = basis_from_normal(hit.normal)
	var pos: Vector3 = grid.snap_in_plane(hit.position, Vector3.ZERO, basis, grid.snap_enabled)
	if node is CSGShape3D or node is CSGStairs3D:
		var box: AABB = CsgBlockoutShapeInfo.local_aabb(node)
		var lift: float
		if op == CSGShape3D.OPERATION_SUBTRACTION:
			lift = -box.get_center().y
		else:
			lift = -box.position.y
		pos += basis.y * lift
	return Transform3D(basis, pos)

## Sets the operation of every selected CSG shape as one undo step. Returns how
## many selected shapes there are (-1 when none is a CSG shape).
static func set_operation_on_selection(op: CSGShape3D.Operation) -> int:
	var action: CsgBlockoutSceneOps.Action = CsgBlockoutSceneOps.Action.new(CsgBlockoutI18n.t("CHANGE_CSG_OPS"))
	var count: int = 0
	for n: Node in EditorInterface.get_selection().get_selected_nodes():
		if not (n is CSGShape3D):
			continue
		count += 1
		if (n as CSGShape3D).operation != op:
			action.set_property(n, &"operation", op)
	action.commit()
	return count if count > 0 else -1
