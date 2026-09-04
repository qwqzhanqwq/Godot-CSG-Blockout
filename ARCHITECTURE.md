# CSG_Blockout Architecture Design & Technical Internals

*Read this in other languages: [简体中文](ARCHITECTURE_CN.md) | [Back to Main Docs](README.md)*

This document is intended for developers interested in the underlying implementation, algorithmic designs, and extensibility of `CSG_Blockout`. It provides technical specifications and architectural breakdowns.

---

## Table of Contents
- [1. Core Algorithm: 3D Spatial Hash Grid](#1-core-algorithm-3d-spatial-hash-grid)
- [2. System Architecture & Design Patterns](#2-system-architecture--design-patterns)
- [3. Procedural World-Aligned Triplanar Shader](#3-procedural-world-aligned-triplanar-shader)
- [4. GDScript 2.0 Typing & Defensive Architecture](#4-gdscript-20-typing--defensive-architecture)
- [5. Node Specifications & API Reference](#5-node-specifications--api-reference)
- [6. ProjectSettings Specification](#6-projectsettings-specification)

---

## 1. Core Algorithm: 3D Spatial Hash Grid

### 1. The O(N^2) Bottleneck of Naive Checking
In scatter placement calculations (`CSGSpreader3D`), naive algorithms prevent instance overlapping by iterating through all previously placed points for each candidate point:

$$\text{Complexity} = \mathcal{O}(N^2)$$

When populating hundreds of complex CSG geometric instances in real-time, performing hundreds of thousands of 3D distance checks per second causes significant frame drops and editor freezes.

### 2. Spatial Hash Grid Implementation
`CSG_Blockout` introduces a custom 3D spatial hash grid in `scripts/csg_spatial_hash_3d.gd`:

1. **Cell Size Determination**:
   Given the user-defined minimum distance $d_{\min}$ (`min_distance`), the cubic grid cell size is calculated as:
   $$\text{Cell Size} = \frac{d_{\min}}{\sqrt{3}}$$
   This mathematical threshold ensures that no single cubic cell can contain more than one point separated by at least $d_{\min}$, drastically pruning potential collision candidates.

2. **Spatial Quantization & Hash Mapping**:
   Any continuous 3D world coordinate $\mathbf{P}(x, y, z)$ is discretized into integer cell indices:
   $$\mathbf{cell\_coords} = \left( \lfloor x / \text{CellSize} \rfloor, \lfloor y / \text{CellSize} \rfloor, \lfloor z / \text{CellSize} \rfloor \right)$$
   Stored using `Vector3i` keys inside a hash table for constant-time lookup.

3. **27-Neighborhood Search (3x3x3 Locality)**:
   When validating a placement candidate, the algorithm queries only the host cell and its immediate 26 adjacent cells (27 cells total), reducing collision verification to:
   $$\text{Collision Check Complexity} = \mathcal{O}(1)$$

---

## 2. System Architecture & Design Patterns

```mermaid
graph TD
    subgraph Editor Core
        Plugin["csg_blockout.gd (EditorPlugin)"]
        URM["EditorUndoRedoManager"]
        I18N["CsgBlockoutI18n"]
        ProjSet["ProjectSettings (addons/csg_blockout/*)"]
    end

    subgraph UI & Controls
        Pie["CSGBlockoutPieMenu (Vector 2D/3D Viewport)"]
        SideBar["CSGSideBlockoutBar (Left Viewport Bar)"]
        TopBar["CSGTopBlockoutBar (Viewport Header Bar)"]
    end

    subgraph Node Domain
        Combiner["CSGCombiner3D (Godot Built-in)"]
        Repeater["CSGRepeater3D"] --> Combiner
        Spreader["CSGSpreader3D"] --> Combiner
    end

    subgraph Strategy Pattern
        Pattern["CSGPattern (Resource)"]
        GridPat["CSGGridPattern"] --> Pattern
        CircPat["CSGCircularPattern"] --> Pattern
        SpiralPat["CSGSpiralPattern"] --> Pattern
        NoisePat["CSGNoisePattern"] --> Pattern
        Repeater -.-> Pattern
    end

    subgraph Collision & Placement
        HashGrid["CSGSpatialHash3D (O(1) Spatial Hash)"]
        Spreader -.-> HashGrid
        Spreader -.-> ShapeDomain["Shape3D (Box/Sphere/Mesh/...)"]
    end

    Plugin --> Pie
    Plugin --> SideBar
    Plugin --> TopBar
```

### 1. Strategy Pattern: Array Generator (`CSGRepeater3D`)
`CSGRepeater3D` delegates spatial array calculations to modular `CSGPattern` resources:
- **`CSGGridPattern`**: Orthogonal 3D Cartesian array with automatic bounding box (AABB) compensation.
- **`CSGCircularPattern`**: Multi-tiered radial polar array.
- **`CSGSpiralPattern`**: Archimedean/logarithmic spiral distribution with optional non-linear `Curve` radial modulation.
- **`CSGNoisePattern`**: Volumetric 3D noise threshold sampling via `FastNoiseLite`.

### 2. Shape3D Bounding Domain: Scatterer (`CSGSpreader3D`)
`CSGSpreader3D` accepts any Godot `Shape3D` as a spatial boundary:
- Computes world-space bounding boxes.
- Executes rejection sampling inside custom shapes.
- Enforces strict minimum distance thresholds via `CSGSpatialHash3D`.
- Implements fallback safety limits (`max_placement_attempts`).

---

## 3. Procedural World-Aligned Triplanar Shader

`grid_triplanar.gdshader` is engineered specifically for level prototyping:
1. **World-Space Triplanar Mapping**:
   - Bypasses mesh UV coordinates; samples texture procedurally from world coordinates $\mathbf{P}_{\text{world}}$.
   - Guarantees 1m x 1m grid alignment regardless of node transformation or boolean cutting.
2. **Hardware Screen-Derivative Anti-Aliasing**:
   - Employs `fwidth()` and `smoothstep()` for sub-pixel anti-aliased grid lines, eliminating distant moiré patterns.
3. **Zero Texture Footprint**:
   - Procedural math generation with zero VRAM bandwidth overhead.

---

## 4. GDScript 2.0 Typing & Defensive Architecture

- **Strict Static Typing**: Explicit typing on all methods and variables, optimizing engine dispatch.
- **ClassDB Validation**: Dynamic node instantiation validated via `ClassDB.instantiate()` and type checks.
- **Atomic Undo/Redo**: Full integration with `EditorUndoRedoManager` for node creation, property editing, re-parenting, and material assignments.
- **Editor / Runtime Decoupling**: Tool scripts strictly gated with `Engine.is_editor_hint()` to prevent runtime leaks and scene corruption.

---

## 5. Node Specifications & API Reference

### 1. CSGRepeater3D Properties

| Property | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `template_node` | `Node3D` | `null` | Node in scene tree used as instance template. |
| `template_node_scene` | `PackedScene` | `null` | Template PackedScene resource (fallback if `template_node` is null). |
| `hide_template` | `bool` | `true` | Automatically hides template node when array is generated. |
| `pattern` | `CSGPattern` | `null` | Pattern resource defining distribution layout. |
| `position_jitter` | `float` | `0.0` | Minor random translation variance. |
| `random_seed` | `int` | `0` | Seed for pseudorandom generator. |
| `estimated_instances` | `int` | `0` | (Read-only) Estimated number of instances to be generated. |
| `randomize_rotation` | `bool` | `false` | Enables rotation variance. |
| `randomize_rot_x/y/z` | `bool` | `false` | Per-axis rotation toggles. |
| `rotation_variance_x/y/z_deg` | `float` | `0.0` | Random variance angle in degrees (0 = full 360-degree). |
| `randomize_scale` | `bool` | `false` | Enables scale variance. |
| `scale_variance` | `float` | `0.2` | Uniform scale variance factor. |

### 2. CSGSpreader3D Properties

| Property | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `template_node` | `Node3D` | `null` | Target template node to scatter. |
| `spread_area_3d` | `Shape3D` | `null` | Spatial boundary shape (Box, Sphere, Capsule, Mesh, etc.). |
| `max_count` | `int` | `50` | Maximum instance limit (hard capped at 200). |
| `noise_threshold` | `float` | `0.0` | Noise density threshold (0.0 to 1.0). |
| `seed` | `int` | `1337` | Random seed. |
| `avoid_overlaps` | `bool` | `true` | Enables Spatial Hash collision prevention. |
| `min_distance` | `float` | `2.0` | Minimum safe distance between origins. |
| `max_placement_attempts` | `int` | `30` | Maximum candidate search attempts per instance. |
| `allow_rotation` | `bool` | `true` | Enables random Y-axis yaw rotation. |
| `allow_scale` | `bool` | `true` | Enables random scale variance (0.5x to 2.0x). |

---

## 6. ProjectSettings Specification

Configuration options are registered under `addons/csg_blockout/*`:

| Setting Path | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `addons/csg_blockout/action_key` | `int` (Key) | `KEY_SHIFT` | Primary action modifier key for 3D Pie Menu. |
| `addons/csg_blockout/auto_hide` | `bool` | `true` | Auto-hides left sidebar when no CSG node is selected. |
| `addons/csg_blockout/language_override` | `String` | `"zh_CN"` | Language preference override (`"en"` or `"zh_CN"`). |
| `addons/csg_blockout/material_preset` | `int` (Enum) | `1` (GRID_LIGHT) | Default active grid material preset. |
