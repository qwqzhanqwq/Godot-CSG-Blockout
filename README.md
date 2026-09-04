<div align="center">
  <img src="res/icon_transparent.svg" alt="CSG_Blockout Logo" width="180" />
  <h1>CSG_Blockout</h1>

  <p>
    <a href="README.md"><img src="https://img.shields.io/badge/Docs-English-blue?style=flat-square" alt="Docs English" /></a>
    <a href="README_CN.md"><img src="https://img.shields.io/badge/%E6%96%87%E6%A1%A3-%E7%AE%80%E4%BD%93%E4%B8%AD%E6%96%87-blue?style=flat-square" alt="文档 简体中文" /></a>
    <a href="TUTORIAL_EN.md"><img src="https://img.shields.io/badge/Tutorial-English-orange?style=flat-square" alt="Tutorial English" /></a>
    <a href="TUTORIAL_CN.md"><img src="https://img.shields.io/badge/%E6%95%99%E7%A8%8B-%E7%AE%80%E4%BD%93%E4%B8%AD%E6%96%87-orange?style=flat-square" alt="教程 简体中文" /></a>
  </p>

  <p>
    <a href="https://godotengine.org"><img src="https://img.shields.io/badge/Godot-4.7%2B-478cbf?style=flat-square&logo=godotengine&logoColor=white" alt="Godot Engine" /></a>
    <a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT-success?style=flat-square" alt="License: MIT" /></a>
  </p>

  <p>
    <strong>A high-performance, modernized 3D level blockout and rapid prototyping plugin designed specifically for Godot 4.7.</strong>
  </p>
</div>

---

## Architectural & Technical Highlights

### 1. Spatial Hash Grid Algorithm
In scatter placement calculations (`CSGSpreader3D`), traditional nested double-loop distance checks incur O(N^2) time complexity, leading to severe editor stuttering when instantiating large numbers of nodes.
`CSG_Blockout` introduces a **3D Spatial Hash Grid algorithm**:
- Divides 3D space into uniform cubic grid cells based on the minimum safe distance `min_distance` (Cell Size = `min_distance / sqrt(3)`).
- When attempting to place a new node, it only queries and compares existing positions within the candidate's cell and its 27 neighboring cells.
- Reduces collision detection complexity to **O(1)**, enabling instantaneous calculations even in complex blockouts containing hundreds of combined CSG primitives.

### 2. Interactive 3D Pie Menu
- **Shortcut Activated:** Press `Shift + A` inside the 3D editor viewport to trigger a radial vector Pie Menu directly at your mouse cursor.
- **Hierarchical Navigation:** The outer menu branches into Union, Intersection, and Subtraction CSG operations. Selecting an operation opens a shape submenu containing `CSGBox3D`, `CSGCylinder3D`, `CSGMesh3D`, `CSGPolygon3D`, `CSGSphere3D`, and `CSGTorus3D`.
- **Context Awareness:** If a `CSGShape3D` node is currently selected, selecting an operation updates the node's `operation` property via UndoRedo. If no node is selected, choosing a primitive creates and configures a new CSG shape node.
- **Deadzone & Gesture Controls:** Features a central deadzone. Clicking inside the deadzone or pressing right-click navigates back to the parent menu level or closes the Pie Menu.

### 3. Modular Pattern Repeaters & Volume Spreaders
- **`CSGRepeater3D`:** Extends `CSGCombiner3D`. Utilizes a Strategy pattern via custom `CSGPattern` resources (`CSGGridPattern`, `CSGCircularPattern`, `CSGSpiralPattern`, and `CSGNoisePattern`).
- **`CSGSpreader3D`:** Extends `CSGCombiner3D`. Supports scattering template instances within any 3D collision shape (`BoxShape3D`, `SphereShape3D`, `CapsuleShape3D`, `CylinderShape3D`, `HeightMapShape3D`, `ConcavePolygonShape3D`, `ConvexPolygonShape3D`) with overlap avoidance.

### 4. Procedural World-Aligned Grid & Material Presets
- **Triplanar Grid Shader:** Procedural world-aligned grid material with anti-aliased sub-pixel lines and checkerboard style. Remains perfectly aligned without texture stretching as objects move, rotate, or scale.
- **Built-in Presets:** Includes Light Grid, Dark Grid, Orange Accent Grid, Unshaded (None), and Custom Material slots.
- **Batch Application:** Quickly assign the active material preset to any selected `CSGShape3D` nodes in batch with full Undo/Redo integration.

### 5. GDScript 2.0 Static Typing & Defensive Design
- Strict static typing and `ClassDB` runtime validation across all codebase scripts.
- Integrated with `EditorUndoRedoManager` for complete `Ctrl + Z` / `Ctrl + Y` support on node creations, property modifications, and hierarchy shifts.
- Complete decoupling of editor-only logic from runtime builds, preventing orphan node leaks and scene data corruption.

### 6. Built-in Dual Language Localization (i18n)
- Powered by `CsgBlockoutI18n`. Supports seamless switching between English (`en`) and Simplified Chinese (`zh_CN`).
---

## Node & Component Specifications

### 1. CSGRepeater3D

`CSGRepeater3D` generates geometric arrays by duplicating a template node according to mathematical patterns.

#### Core Properties
| Property | Type | Description |
| :--- | :--- | :--- |
| `template_node` | `Node3D` | Reference to a scene node used as a template. |
| `template_node_scene` | `PackedScene` | PackedScene template resource (used if `template_node` is unassigned). |
| `hide_template` | `bool` | Automatically hides original template node when array is generated (default: `true`). |
| `pattern` | `CSGPattern` | Pattern resource defining distribution logic (Grid, Circular, Spiral, Noise). |
| `position_jitter` | `float` | Random positional offset jitter. |
| `random_seed` | `int` | Seed for pseudorandom number generator. |
| `estimated_instances` | `int` | (Read-only) Estimated number of instances to be generated. |

#### Variation Options
- **Rotation Randomization (`randomize_rotation`):**
  - Per-axis toggles (`randomize_rot_x/y/z`).
  - Adjustable variance angles (`rotation_variance_x/y/z_deg`) in degrees (0 = full 360-degree randomization).
- **Scale Randomization (`randomize_scale`):**
  - Uniform scale variance (`scale_variance`) and per-axis scale toggles (`randomize_scale_x/y/z` with `scale_variance_x/y/z`).

#### Available Pattern Resources
1. **`CSGGridPattern`:**
   - `count_x`, `count_y`, `count_z`: Repetition counts per axis.
   - `spacing`: 3D spacing vector.
   - `use_template_size`: Automatically factors template AABB bounding box dimensions into spacing.
2. **`CSGCircularPattern`:**
   - `radius`: Ring radius.
   - `points`: Number of points per layer.
   - `layers`: Vertical layer count.
   - `layer_height`, `layer_spacing`: Base layer height and additional spacing offsets.
3. **`CSGSpiralPattern`:**
   - `turns`: Total revolution count.
   - `start_radius`, `end_radius`: Inner and outer radii.
   - `total_height`: Overall spiral height.
   - `use_radius_curve`, `radius_curve`: Optional `Curve` resource for non-linear radial scaling.
4. **`CSGNoisePattern`:**
   - 3D noise volume sampling powered by `FastNoiseLite`.
   - Options include `bounds`, `sample_density`, `noise_threshold`, `noise_type` (Simplex, Perlin, Cellular, etc.), and `fractal_type`.

---

### 2. CSGSpreader3D

`CSGSpreader3D` scatters geometric instances randomly within a 3D `Shape3D` region while preventing overlap.

#### Core Properties
| Property | Type | Description |
| :--- | :--- | :--- |
| `template_node` | `Node3D` | Target template node to scatter. |
| `spread_area_3d` | `Shape3D` | Spatial bounds shape (Box, Sphere, Capsule, Cylinder, HeightMap, Mesh, etc.). |
| `max_count` | `int` | Maximum allowed instances (capped at safety threshold of 200). |
| `noise_threshold` | `float` | Noise filtering probability threshold (0.0 to 1.0). |
| `seed` | `int` | Pseudorandom seed. |
| `allow_rotation` | `bool` | Enables random Y-axis rotation. |
| `allow_scale` | `bool` | Enables random scale variance (0.5x to 2.0x). |

#### Collision & Avoidance Options
| Property | Type | Description |
| :--- | :--- | :--- |
| `avoid_overlaps` | `bool` | Enables Spatial Hash Grid collision checking. |
| `min_distance` | `float` | Minimum safe distance between instance origins. |
| `max_placement_attempts` | `int` | Maximum candidate search attempts per instance. |

---

### 3. Editor UI & Toolbar Integration

#### Left Sidebar (`CSGSideBlockoutBar`)
- **Quick Creation Buttons:** One-click instantiation for `CSGBox3D`, `CSGCylinder3D`, `CSGMesh3D`, `CSGPolygon3D`, `CSGSphere3D`, and `CSGTorus3D`.
- **Boolean Operation Toggle:** Switch between Union, Intersection, and Subtraction modes.
- **Procedural Grid Material Presets:** Instantly switch between Light Grid, Dark Grid, Orange Accent Grid, Unshaded (None), and Custom Material picker.
- **Apply Material to Selected:** One-click batch application of active material preset to all selected `CSGShape3D` nodes with full Undo/Redo support.
- **Smart Hierarchy Placement:** Automatically creates new nodes as children when selecting a `CSGCombiner3D` (including Repeater/Spreader), or as siblings directly following the selected node when selecting a standard `CSGShape3D` (e.g. Box, Sphere).
- **Auto-Hide:** Automatically fades out when no CSG nodes are selected in the editor.

#### Top Toolbar (`CSGTopBlockoutBar`)
- Appears automatically in the 3D editor header when a `CSGRepeater3D` or `CSGSpreader3D` node is selected.
- **Refresh:** Forces regeneration of preview instances.
- **Bake:** Detaches generated preview instances from generator control, setting their `owner` and converting them into permanent scene nodes.

---

## ProjectSettings Reference

Global configuration options are automatically registered in Godot's `ProjectSettings` under `addons/csg_blockout/*`:

| Setting Path | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `addons/csg_blockout/action_key` | `int` (Key) | `KEY_SHIFT` | Primary action modifier key. |
| `addons/csg_blockout/auto_hide` | `bool` | `true` | Auto-hides left sidebar when selection is cleared. |
| `addons/csg_blockout/language_override` | `String` | `"zh_CN"` | Language preference override (`"en"` or `"zh_CN"`). |
| `addons/csg_blockout/material_preset` | `int` (Enum) | `1` (GRID_LIGHT) | Default material grid preset. |

---

## Installation

1. Download and extract the release package.
2. Copy the `addons/csg_blockout` directory into your Godot 4.7 project's `addons/` folder.
3. Open Godot and navigate to **Project -> Project Settings -> Plugins**.
4. Locate **CSG_Blockout** and check the **Enable** checkbox.

---

## Credits & License

This plugin is a complete architectural overhaul and refactor of [CSG Toolkit](https://godotengine.org/asset-library/asset/3057) by **LuckyTepot**.

- **Original Concept & Layout Design:** [LuckyTepot](https://github.com/LuckyTepot) (Copyright (c) 2023).
- **Architecture Refactor, 3D Pie Menu, Spatial Hash Grid Optimization, & GDScript 2.0 Rewrite:** [qwqzhanqwq](https://github.com/qwqzhanqwq) (Copyright (c) 2026).

License: [MIT License](LICENSE)

