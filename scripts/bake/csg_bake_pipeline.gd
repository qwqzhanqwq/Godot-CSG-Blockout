@tool
class_name CsgBlockoutBakePipeline
extends RefCounted
## Turns a CSG root into the outputs of a freeze, according to bake options:
##   collision: "auto" (trimesh when the CSG uses collision, else none), "none",
##              "trimesh", "primitives" (one native shape per primitive, or the convex
##              pieces of the plugin's arches, curved walls and so on; union-only
##              trees, otherwise falls back to trimesh), "convex" (one convex hull)
##   uv2 / texel: lightmap UV2 unwrap        occluder: OccluderInstance3D
##   lod: automatic LODs (ImporterMesh)
## Surfaces are already merged per material by CSGShape3D.bake_static_mesh().

const META_GENERATED: StringName = &"_csg_blockout_generated"
const COLLISION_MODES: PackedStringArray = ["auto", "none", "trimesh", "primitives", "convex"]

const SETTING_COLLISION: String = "addons/csg_blockout/bake/collision"
const SETTING_UV2: String = "addons/csg_blockout/bake/lightmap_uv2"
const SETTING_TEXEL: String = "addons/csg_blockout/bake/lightmap_texel_size"
const SETTING_OCCLUDER: String = "addons/csg_blockout/bake/occluder"
const SETTING_LOD: String = "addons/csg_blockout/bake/lod"

static func register_settings() -> void:
	var cfg: CsgBlockoutConfig = CsgBlockoutConfig.get_config()
	cfg._register(SETTING_COLLISION, "auto", TYPE_STRING, PROPERTY_HINT_ENUM, ",".join(COLLISION_MODES))
	cfg._register(SETTING_UV2, false, TYPE_BOOL)
	cfg._register(SETTING_TEXEL, 0.2, TYPE_FLOAT, PROPERTY_HINT_RANGE, "0.01,4.0,0.01")
	cfg._register(SETTING_OCCLUDER, false, TYPE_BOOL)
	cfg._register(SETTING_LOD, false, TYPE_BOOL)

## Project defaults for new freezes.
static func default_options() -> Dictionary:
	return {
		"collision": String(ProjectSettings.get_setting(SETTING_COLLISION, "auto")),
		"uv2": bool(ProjectSettings.get_setting(SETTING_UV2, false)),
		"texel": float(ProjectSettings.get_setting(SETTING_TEXEL, 0.2)),
		"occluder": bool(ProjectSettings.get_setting(SETTING_OCCLUDER, false)),
		"lod": bool(ProjectSettings.get_setting(SETTING_LOD, false)),
	}

static func normalized(options: Dictionary) -> Dictionary:
	var out: Dictionary = default_options()
	for k: String in out:
		if options.has(k):
			out[k] = options[k]
	if not COLLISION_MODES.has(String(out["collision"])):
		out["collision"] = "auto"
	return out

## Bakes `root` (a CSG root inside the tree, mesh up to date). Returns
## {"mesh": ArrayMesh, "generated": Array[Node] (owned by nothing yet), "warnings": PackedStringArray}
## or {} when the CSG has no geometry.
static func build(root: CSGShape3D, options: Dictionary) -> Dictionary:
	var opts: Dictionary = normalized(options)
	var live: ArrayMesh = root.bake_static_mesh()
	if live == null or live.get_surface_count() == 0:
		return {}
	# bake_static_mesh() hands out the CSG's own render mesh; work on a copy so the
	# unwrap below never touches it and the result doesn't alias a live node.
	var mesh: ArrayMesh = live.duplicate() as ArrayMesh
	var warnings: PackedStringArray = []
	if bool(opts["uv2"]):
		var err: Error = mesh.lightmap_unwrap(Transform3D.IDENTITY, maxf(float(opts["texel"]), 0.01))
		if err != OK:
			warnings.append("lightmap_unwrap: %s" % error_string(err))
	var collision_source: ArrayMesh = mesh
	if bool(opts["lod"]):
		mesh = _with_lods(mesh)
	var generated: Array[Node] = []
	var mode: String = String(opts["collision"])
	if mode == "auto":
		mode = "trimesh" if root.use_collision else "none"
	if mode == "primitives" and _has_cuts(root):
		warnings.append(CsgBlockoutI18n.t("WARN_PRIMITIVE_COLLISION_CUTS"))
		mode = "trimesh"
	match mode:
		"trimesh":
			generated.append(_body(root, [_shape_node(root.bake_collision_shape(), Transform3D.IDENTITY)]))
		"convex":
			generated.append(_body(root, [_shape_node(collision_source.create_convex_shape(true, false), Transform3D.IDENTITY)]))
		"primitives":
			var shapes: Array[CollisionShape3D] = []
			var inv: Transform3D = root.global_transform.affine_inverse()
			for prim: CSGShape3D in CsgBlockoutShapeInfo.primitives_under(root):
				if not prim.is_visible_in_tree():
					continue
				if prim.has_method(&"blockout_collision_pieces"):
					# Concave shapes (arch openings, curves, spirals) come in convex pieces.
					for pts: PackedVector3Array in prim.call(&"blockout_collision_pieces"):
						var hull: ConvexPolygonShape3D = ConvexPolygonShape3D.new()
						hull.points = pts
						shapes.append(_shape_node(hull, inv * prim.global_transform))
					continue
				var info: Dictionary = _native_shape(prim)
				if info.is_empty():
					continue
				shapes.append(_shape_node(info["shape"], inv * prim.global_transform * (info["offset"] as Transform3D)))
			if not shapes.is_empty():
				generated.append(_body(root, shapes))
	if bool(opts["occluder"]):
		generated.append(_occluder(collision_source))
		# Off by default; without it the occluder does nothing.
		if not bool(ProjectSettings.get_setting("rendering/occlusion_culling/use_occlusion_culling", false)):
			warnings.append(CsgBlockoutI18n.t("WARN_OCCLUSION_CULLING_OFF"))
	return {"mesh": mesh, "generated": generated, "warnings": warnings}

static func _has_cuts(root: CSGShape3D) -> bool:
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is CSGShape3D and n != root and (n as CSGShape3D).operation != CSGShape3D.OPERATION_UNION:
			return true
		for c: Node in n.get_children():
			if c is CSGShape3D:
				stack.append(c)
	return false

static func _body(root: CSGShape3D, shapes: Array) -> StaticBody3D:
	var body: StaticBody3D = StaticBody3D.new()
	body.name = CsgBlockoutFreeze.COLLISION_NAME
	body.collision_layer = root.collision_layer
	body.collision_mask = root.collision_mask
	body.set_meta(META_GENERATED, true)
	for i: int in shapes.size():
		var s: Node = shapes[i]
		s.name = "Shape" if i == 0 else "Shape%d" % (i + 1)
		body.add_child(s)
	return body

static func _shape_node(shape: Shape3D, xform: Transform3D) -> CollisionShape3D:
	var col: CollisionShape3D = CollisionShape3D.new()
	col.shape = shape
	col.transform = xform
	return col

## Native collision shape for a primitive: {"shape", "offset"} or {} if unsupported.
static func _native_shape(prim: CSGShape3D) -> Dictionary:
	if prim is CSGBox3D:
		var box: BoxShape3D = BoxShape3D.new()
		box.size = (prim as CSGBox3D).size
		return {"shape": box, "offset": Transform3D.IDENTITY}
	if prim is CSGCylinder3D:
		var c: CSGCylinder3D = prim as CSGCylinder3D
		if c.cone:
			return {"shape": CsgBlockoutShapeInfo.preview_mesh(c).create_convex_shape(true, false), "offset": Transform3D.IDENTITY}
		var cyl: CylinderShape3D = CylinderShape3D.new()
		cyl.radius = c.radius
		cyl.height = c.height
		return {"shape": cyl, "offset": Transform3D.IDENTITY}
	if prim is CSGSphere3D:
		var sph: SphereShape3D = SphereShape3D.new()
		sph.radius = (prim as CSGSphere3D).radius
		return {"shape": sph, "offset": Transform3D.IDENTITY}
	if prim is CSGPolygon3D and (prim as CSGPolygon3D).mode == CSGPolygon3D.MODE_DEPTH:
		# Convex hull of the extruded profile (stairs become a smooth ramp, which is
		# usually what you want for walking up them).
		var p: CSGPolygon3D = prim as CSGPolygon3D
		var pts: PackedVector3Array = PackedVector3Array()
		for v: Vector2 in p.polygon:
			pts.append(Vector3(v.x, v.y, 0.0))
			pts.append(Vector3(v.x, v.y, -p.depth))
		var hull: ConvexPolygonShape3D = ConvexPolygonShape3D.new()
		hull.points = pts
		return {"shape": hull, "offset": Transform3D.IDENTITY}
	if prim is CSGMesh3D and (prim as CSGMesh3D).mesh != null:
		return {"shape": (prim as CSGMesh3D).mesh.create_convex_shape(true, false), "offset": Transform3D.IDENTITY}
	if prim is CSGTorus3D:
		return {"shape": CsgBlockoutShapeInfo.preview_mesh(prim).create_trimesh_shape(), "offset": Transform3D.IDENTITY}
	return {}

static func _occluder(mesh: ArrayMesh) -> OccluderInstance3D:
	var verts: PackedVector3Array = PackedVector3Array()
	var indices: PackedInt32Array = PackedInt32Array()
	for s: int in mesh.get_surface_count():
		var arrays: Array = mesh.surface_get_arrays(s)
		var sv: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var base: int = verts.size()
		verts.append_array(sv)
		var si: Variant = arrays[Mesh.ARRAY_INDEX]
		if si is PackedInt32Array and not (si as PackedInt32Array).is_empty():
			for i: int in si:
				indices.append(base + i)
		else:
			for i: int in sv.size():
				indices.append(base + i)
	var occ: ArrayOccluder3D = ArrayOccluder3D.new()
	occ.set_arrays(verts, indices)
	var inst: OccluderInstance3D = OccluderInstance3D.new()
	inst.name = "Occluder"
	inst.occluder = occ
	inst.set_meta(META_GENERATED, true)
	return inst

static func _with_lods(mesh: ArrayMesh) -> ArrayMesh:
	var im: ImporterMesh = ImporterMesh.new()
	for s: int in mesh.get_surface_count():
		im.add_surface(mesh.surface_get_primitive_type(s), mesh.surface_get_arrays(s), [], {}, mesh.surface_get_material(s), mesh.surface_get_name(s))
	im.generate_lods(25.0, 60.0, [])
	return im.get_mesh()
