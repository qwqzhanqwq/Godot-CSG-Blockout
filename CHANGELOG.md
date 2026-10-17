# Changelog

All notable changes to CSG_Blockout are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project uses [Semantic Versioning](https://semver.org/).

## [Unreleased]

## [3.1.0] - 2026-10-17

Four new shapes for blocking out (wedge, arch, curved wall and spiral stairs), a Play From Here test character that walks up stairs, and rooms that resize as rooms.

### Added
- **Four new shapes** in the palette and the pie menu's Shapes: **Wedge** (`CSGWedge3D`, a box with one sloped face for ramps, roof halves and angled walls), **Arch** (`CSGArch3D`, a wall piece with an arched opening, half-round or flatter when the opening is low), **Curved Wall** (`CSGCurvedWall3D`, a wall bent around a vertical axis, up to a closed ring) and **Spiral Stairs** (`CSGSpiralStairs3D`, stairs winding around a center well, floating steps or filled to the floor, several turns for towers, clockwise or counterclockwise). They are placed, snapped and joined to CSG trees like the other shapes.
- Their faces have arrows like boxes: wedge and arch faces change their size, the arch also has arrows for the height and width of its opening, a curved wall's arrows change its height, thickness, inner radius and how far it sweeps, and the spiral stairs' arrows change the height, the radii and how far they turn. Their dimension labels take typed sizes (only the height for the curved wall and spiral stairs).
- Spiral stairs warn in the Inspector when a step's rise is uncomfortable, and when the turn above leaves less headroom than the character height in the player metrics.
- Freezing with **one native shape per primitive** collision gives the new shapes convex pieces that follow them (the arch's opening stays open, every spiral step gets its own piece) instead of one hull.
- **The Play From Here test character walks up stairs.** A new player metric, `max_step_height` (0.3 m by default), is the highest step it walks up without jumping; stairs and spiral stairs warn in the Inspector when their steps are higher, and the player reference draws it. It only steps on the ground, so jumps are unchanged.
- Without the plugin, the wedge, arch and curved wall stay plain `CSGPolygon3D` nodes with the same shape, and the spiral stairs a `CSGMesh3D` whose mesh is saved with the scene.

### Changed
- The duplicate-along-an-axis preview shows stairs and other extruded or turned `CSGPolygon3D` shapes with their real outline instead of their bounding box.

### Fixed
- **Rooms resize as rooms.** Dragging a face of a room drawn with the Room tool moved only its outer shell: raising the top sealed the room, and pushing a wall out made that wall thicker. Now select the room (it is selected right after drawing) or click one of its walls, then drag a face arrow or type a size: walls and floor keep their thickness, an open top stays open, and doors and windows in a moved wall go with it. Godot's own size handles on a selected room shell do the same, and the room's dimension labels measure the shell without the frames sticking out.
- The Play From Here test character stopped at the first step of any stairs and hopped down them, airborne most of the way: its capsule touched each step's edge at a slope too steep to count as floor. It now walks up and down steps as high as `max_step_height` and stays on the ground.
- Selecting stairs no longer opens Godot's polygon point editor on them: their profile comes from their own properties, so points moved there were overwritten by the next change. The same goes for the new wedge, arch and curved wall.

## [3.0.0] - 2026-10-03

A major release that turns CSG_Blockout from a shape-creation helper into a level prototyping tool: draw rooms in one drag, cut doors and windows, check the level against your character, play it, and freeze it into meshes you can always turn back into CSG. The controls were rebuilt around one rule: every tool does one thing, says what the next step is, and hands control back.

### Added
- **Draw in one drag**: **Box** drags a base on any surface (or the ground) and builds the box on release, with the height you gave your last box. **Cut** drags an opening on a surface and cuts straight through it; the cut lands in the CSG tree it was drawn on (a lone wall is wrapped into a new combiner automatically). **Room** creates a shell box plus a hollow; height, wall thickness, floor thickness and open top are in Project Settings under `addons/csg_blockout/room`. Hold Shift while drawing a box to make it a separate object.
- **Door and window presets**: click a wall to cut a doorway (dropped to the floor) or a window (at sill height). The cut is aligned to the wall and goes through its measured thickness; F adds a frame. Sizes live under `addons/csg_blockout/openings`.
- **Face arrows**: a selected box, cylinder or stairs shows an arrow on each face that points toward you. Drag it to move that face along its normal; the opposite face stays put and axis-aligned faces land on grid lines. Shift-click stays Godot's multi-select.
- **Typed sizes**: click a dimension label of a selected box, cylinder or stairs and type the size (`2.5`, `2,5` or `2.5 m`); one undo step.
- **Double-click selects the whole CSG tree** a shape belongs to; a single click still selects the primitive.
- **Duplicate along an axis** (`Ctrl+Shift+D`): move the mouse along X, Y or Z to repeat the selection with its own size as the step; `+` / `-` add or remove a gap, X/Y/Z lock the axis, click to create.
- **Grid and snapping**: one grid size for all CSG Blockout tools (0.125–8 m), changed with `[` / `]` or the toolbar dropdown, with a snap toggle (hold Ctrl to invert while dragging). The current grid is shown in the viewport.
- **Keyboard editing**: arrow keys nudge the selection one grid step along the axis closest to the view, Page Up/Page Down move it up/down (Shift: quarter step); `,` / `.` rotate by 15° (Shift: 90°); End drops the selection onto the surface below. Repeated nudges undo as one step.
- **Snap Selection to Grid** (toolbar "⋯" menu or the pie menu's More): axis-aligned boxes get every face on a grid line; other nodes align their bounds to the grid.
- All new viewport shortcuts can be rebound in Editor Settings > Shortcuts > csg_blockout.
- **Reversible bake (Freeze / Unfreeze)**: freeze a CSG tree into a plain `MeshInstance3D` (plus `StaticBody3D` collision when the CSG used collision) with the same name and transform. The original CSG is stored inside the frozen node, so Unfreeze brings it back exactly. Lights, markers and other non-CSG nodes inside the tree travel with it. Whatever you add to the frozen node (script, groups, layers, children) survives the next unfreeze/freeze. Exports strip the stored CSG, so frozen blockout costs nothing at runtime.
- **Blockout outliner** (dock tab "Blockout"): only CSG trees and frozen blockout, with operation icons, show/hide, solo (editor-only, never changes the scene), lock, filtering, group/ungroup, and semantic renaming (`Wall_Corridor_01`) that leaves names you typed alone.
- **Dimension labels**: selected shapes show width × height × depth in the viewport.
- **Player reference** (`CSGPlayerReference3D`): editor-only capsule with crouch and eye height, the height you can jump onto, the sprint-jump arc and the steepest walkable slope.
- **Jump check**: select two objects to place a ruler between their closest top edges and see whether the gap is jumpable.
- **Level checks**: one click flags slopes steeper than the walkable angle and ceilings lower than standing or crouch height (ledges too narrow to stand on, like window sills, are left out), highlighted in the viewport and listed in the outliner's Checks tab. The status line names each problem in turn: **Next ›** selects the next shape to fix and frames it.
- **Semantic tags** (wall, floor, hazard, interactive): color-coded grid materials plus a `csg_blockout_tag` metadata your game can read; export an SVG legend for design docs.
- **Play From Here**: run the current scene with a first-person test character at the viewport center (or the cursor, from the pie menu or a shortcut you assign). It jumps exactly `single_jump_height` and a sprint jump covers `sprint_jump_distance`, the same numbers the ruler and the level checks use. Scenes without lights get a default sun and sky. CSG trees and frozen blockout without collision get it for that run only, and the status line says how many, so the character never falls through what you see.
- New player metrics in Project Settings: `capsule_radius`, `crouch_height`, `max_slope_angle`, `walk_speed`.
- **Bake options** for frozen blockout: collision type (automatic, none, trimesh, one native shape per primitive, or a single convex hull), lightmap UV2 with a texel size, an occluder, and automatic LODs. Defaults are in Project Settings under `addons/csg_blockout/bake`, and every frozen node keeps its own. The Inspector panel of a frozen node changes them and rebakes in place as one undo step, without unfreezing.
- **Export to MeshLibrary** ("⋯" menu): each selected CSG tree or frozen blockout (or each one directly under a selected group) becomes a GridMap item with its mesh, collision and a rendered preview. The node's origin is the tile's pivot. Exporting into an existing library updates the items with the same names and keeps the rest, so GridMaps painted with it update right away.
- **glTF round trip** for frozen blockout: export it as `.glb` (next to the scene, in `<scene>_blockout/`), refine it in Blender or any other DCC tool and save over the file. Once Godot has re-imported it, **Use Refined Mesh** swaps it in as one undo step. Surfaces whose material name survived the trip get their Godot material back, shader materials included; materials made in the DCC tool stay as imported. Collision stays the blockout's and the CSG stays inside the node. Exporting over refined work and unfreezing a node that uses a refined mesh both ask first.
- **Non-manifold warning** for `CSGMesh3D`: since Godot 4.4, CSG runs on the Manifold library and quietly gives empty or broken results for meshes that aren't closed. The Inspector now counts open edges, edges shared by more than two faces and flipped faces, can mark them in the viewport, and the outliner flags such meshes.

### Changed
- Supports Godot 4.6 and later (previously 4.7 and later).
- **Tools are one-shot**: each tool makes one result and hands control back; double-click its button to keep it on. A click without a drag leaves the tool and selects what's under the cursor. `Esc` or a right-click leaves a tool.
- **Hint card and status line**: the active tool is described by a card at the top of the viewport (tool name, next step, the keys it takes, a clickable **Esc**). Feedback (exports, freezing, jump checks, check results) appears on a status line under it instead of in editor toasts; errors and warnings that matter later still go to the toaster too.
- **Tool palette**: the sidebar is now an always-visible palette with named tools (Box, Room, Cut, Door, Window), shapes, the operation of the selected shapes, materials, the ruler and the player reference. Its union/subtraction/intersection buttons change the selected shapes and show which operation they have. There is no longer a hidden "current operation": new shapes are always unions (the `auto_hide` and `default_operation` project settings are removed).
- **Pie menu**: pills sized to their labels, so no text spills out in any language. Top level: Box, Room, Cut, Door, Window, Play, Shapes ›, More › (freeze/unfreeze, duplicate, snap, make union/subtraction/intersection, player reference); entries that need a selection are dimmed until there is one. Shapes are placed on the surface under the cursor, aligned to its normal and snapped to the grid, and join the CSG tree they land on.
- **Toolbar**: only actions for the whole level stay (grid, snap, Check, Play, Freeze, "⋯"). The "⋯" menu gained **Shortcuts** (every key, with your current bindings) and **Language**. Repeater/Spreader Refresh and Bake, and the view toggles (dimension labels, ruler visibility), are in the "⋯" menu too. Shape buttons with nothing selected create the shape on the surface in the middle of the view.
- New shapes get readable names (`Box`, `Floor`, `Wall`, `Cut`, `Room`, ...) instead of `CSGBox3D2`.
- New CSG trees made with the plugin (rooms, boxes drawn as their own object, shapes created outside a tree) have collision on, so the test character can walk them and freezing them makes a collision body. Grouping in the outliner keeps the grouped trees' collision, and ungrouping hands it back.
- Rulers and player references are placed next to the selected CSG tree instead of inside it.

### Removed
- The pie menu's Union / Intersection / Subtraction submenus and the "current operation" they set: new shapes are always unions, and the operation of existing shapes is changed on the selection (palette buttons or the pie menu's More).
- Project settings `addons/csg_blockout/auto_hide` (the palette is always shown) and `addons/csg_blockout/default_operation`; they are cleared from `project.godot` when the plugin loads.

### Fixed
- Repeater, Spreader and Ruler scripts no longer reference editor-only classes, which could make them fail to compile in exported games. Exports now also drop editor-only helper nodes (rulers, player references).
- Godot no longer shows import errors for the animated images in `DocsImages/` (the folder is now ignored by the importer).
- The material preset icons in the palette now scale with the editor's display scale like the other icons.
- The pie menu no longer opens when you press `Shift + A` while holding the right mouse button to fly the viewport camera. The key press is passed on to the editor and other plugins instead of being swallowed. ([#4](https://github.com/qwqzhanqwq/Godot-CSG-Blockout/pull/4), thanks [@SuzukaDev](https://github.com/SuzukaDev))

### Documentation
- README rewritten around the plugin's purpose and the new workflow (draw, cut, measure, play, freeze), with a shortcut table and a performance summary. Repeater/Spreader moved to a "procedural extras" section.
- The tutorial now walks from an empty scene to a playable, frozen level; its old "bake to mesh and delete the CSG" section is replaced by reversible bake, and MeshLibrary and glTF export are covered. The architecture document now describes the module layout, viewport input routing, undo, how freezing stores the CSG, raycasting and the level check, Play From Here, and every setting. The stairs axes are corrected there: the steps run along +X and the width extrudes along -Z.
- Added a contributing guide (`CONTRIBUTING.md`, `CONTRIBUTING_CN.md`), issue templates, a pull request template, and this changelog.
- Added `BENCHMARKS.md` / `BENCHMARKS_CN.md`: edit latency, freeze time and in-game startup and frame time for levels of 24–400 primitives, with a benchmark you can run yourself (`benchmarks/run_benchmarks.gd`; left out of Asset Library downloads).

## [2.1.0] - 2026-09-10

### Added
- **Parametric stairs and ramps (`CSGStairs3D`)**: set total height, depth, width, and step count (1–100). Toggle ramp mode for a smooth slope. The Inspector warns when step height or tread depth falls outside a comfortable range (rise 0.15–0.20 m, run 0.25–0.30 m).
- **Level ruler (`CSGRuler3D`)**: drag two endpoint handles in the viewport to read 3D distance, horizontal span, and height difference. Reports whether the target is reachable with a single jump or a sprint jump.
- **Player metrics in Project Settings**: `addons/csg_blockout/player_metrics/character_height`, `single_jump_height`, and `sprint_jump_distance`. Rulers use them by default and can override them individually.
- Stairs in the pie menu; stairs and ruler buttons in the sidebar; **Add Ruler** and **Toggle Rulers** in the top toolbar.
- Translations for all new UI in all 7 languages.

## [2.0.2] - 2026-09-08

### Added
- Japanese, Korean, Spanish, Portuguese, and Russian interface languages (7 in total).
- **Bake** button in the top toolbar for `CSGRepeater3D` and `CSGSpreader3D`. Baking turns preview instances into regular scene nodes and can be undone.
- The default boolean operation and the custom material slot are saved in Project Settings and survive editor restarts.

### Fixed
- Editor crash during locale detection.
- Godot's built-in translation catalog overriding plugin tooltips.
- Spreader: with overlap avoidance on, capsule volumes are now sampled inside the actual capsule, and `min_distance` is always respected.
- Repeater/Spreader: preview bounds were wrong for rotated templates.

## [2.0.1] - 2026-09-04

### Changed
- Plugin icons are now vector SVGs that stay sharp at any editor scale.

### Fixed
- The pie menu modifier key setting (Shift / Ctrl / Alt / Meta) now takes effect and can be picked from a dropdown in Project Settings.
- Repeater no longer accepts the abstract base pattern resource.
- Noise pattern: positions no longer blow up when "use template size" is enabled.

## [1.0.0] - 2026-08-27

First public release of the rewrite of [CSG Toolkit](https://godotengine.org/asset-library/asset/3057).

### Added
- Pie menu at the cursor (`Shift + A`) for creating CSG shapes and switching boolean operations.
- Viewport sidebar for one-click shape creation. New nodes go inside a selected combiner, or right after a selected shape.
- World-aligned grid materials (light, dark, orange accent, unshaded) with one-click apply to the selection.
- `CSGRepeater3D` with grid, circular, spiral, and noise patterns.
- `CSGSpreader3D` for scattering instances inside a `Shape3D`, with optional overlap avoidance.
- English and Simplified Chinese interface.
- Pie menu and sidebar scale with the editor's display scale.

### Fixed
- Repeater/Spreader regeneration is throttled and capped at 200 instances so large values no longer stall the editor.
