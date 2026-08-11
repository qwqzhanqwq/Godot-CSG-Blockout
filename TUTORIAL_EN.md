# CSG Blockout: Rapid Prototyping & Advanced Workflow Tutorial

*其他语言版本：[简体中文](TUTORIAL_CN.md).*

## Table of Contents
- [1. Basics: Understanding CSG](#1-basics-understanding-csg)
- [2. Workflow: Rapid Blockout using Sidebar and Pie Menu](#2-workflow-rapid-blockout-using-sidebar-and-pie-menu)
- [3. Advanced: The Array and Scatter Systems](#3-advanced-the-array-and-scatter-systems)
- [4. Ultimate Technique: Performance Optimization Workflow (Must Read)](#4-ultimate-technique-performance-optimization-workflow-must-read)

---

## 1. Basics: Understanding CSG

**CSG (Constructive Solid Geometry)** is a modeling technique that allows you to construct complex 3D models using boolean operations on simple geometric shapes (e.g., cubes, spheres, cylinders).

In Godot, CSG is a powerful tool for level designers to block out levels or create rapid prototypes. Its core functionality is based on three boolean operations:
- **Union**: Merges two geometries into a single solid shape.
- **Intersection**: Retains only the overlapping portion of two geometries.
- **Subtraction**: Carves out the volume of one geometry from another.

![CSG Subtraction Demo](DocsImages/Subtraction.gif)

Using these simple operations, you can quickly cut out doors, dig tunnels, or assemble complex architectural structures directly in the engine, completely bypassing external software like Blender.

---

## 2. Workflow: Rapid Blockout using Sidebar and Pie Menu

The CSG_Blockout plugin is designed to eliminate tedious hierarchy management, providing an ultra-fast, WYSIWYG (What You See Is What You Get) experience. Whether you prefer mouse clicks or keyboard shortcuts, the plugin adapts to your workflow.

### Recommended Blockout Process
1. **Create the Root Node**: Add a `CSGCombiner3D` node to your scene. This will act as the root container for your geometry block. All subsequently added basic shapes will merge under this node.
2. **Select the Target**: Make sure this `CSGCombiner3D` node (or any CSG shape inside it) is selected in the Scene Tree.
3. **Summon the Menu**:
   - **Method A (Pie Menu)**: Move your mouse over the 3D viewport and press `Shift + A`. A radial Pie Menu will appear at your cursor. Simply flick your mouse in the direction of your desired boolean operation and primitive shape.
     
     ![Pie Menu Demo](DocsImages/PieMenu.gif)
     
   - **Method B (Sidebar)**: Use the newly added plugin sidebar on the left side of the 3D viewport. First, click the bottom icons to select a boolean operation (Union, Intersection, or Subtraction), and then click the top primitive shape icons (e.g., cube, sphere) to instantly add a CSG node with that operation.
     
     ![Sidebar Demo](DocsImages/Sidebar.gif)
4. **Tweak and Adjust**: Drag the handles directly in the viewport to resize and position. The plugin fully supports `Ctrl+Z`, so feel free to experiment without fear of breaking things.

---

## 3. Advanced: The Array and Scatter Systems

### 1. The Array System (CSGRepeater3D)
`CSGRepeater3D` allows you to rapidly generate duplicated geometries using specific mathematical patterns. It is perfect for creating stairs, fences, pillars, or circular structures.

**Workflow**:
1. **Create Node**: Add a `CSGRepeater3D` node to your scene.
2. **Set Template**: You can either add a basic CSG primitive (e.g., `CSGBox3D`) as a direct child of the Repeater, or assign a target node to the `Template Node` property in the Inspector.
3. **Select a Pattern**: In the Inspector, locate the `Pattern` property, create a new resource, and choose your desired pattern strategy:
   - `CSGGridPattern`: **Grid Array**, easily adjust count and spacing along the X/Y/Z axes.
   - `CSGCircularPattern`: **Circular Array**, distribute items in a ring by configuring radius and count.
   - `CSGSpiralPattern`: **Spiral Array**, adds a height offset to circular arrays, perfect for spiral staircases.
   - `CSGNoisePattern`: **Noise Array**, organic distribution driven by 3D noise functions.

### 2. The Scatter System (CSGSpreader3D)
`CSGSpreader3D` integrates a proprietary **Spatial Hash Grid** algorithm. It randomly scatters geometry within any 3D collision shape efficiently and **without overlaps**. Even with hundreds of scattered instances, the O(1) collision avoidance ensures the editor remains completely lag-free.

**Workflow**:
1. **Create Node**: Add a `CSGSpreader3D` node and assign it a child node to use as the scatter template.
2. **Define Scatter Volume**: Assign a `Shape3D` (such as `BoxShape3D` or `SphereShape3D`) in the properties. Objects will only be spawned strictly within this shape's boundaries.
3. **Adjust Density & Randomness**:
   - **Min Distance**: This is the most crucial property. It dictates the scatter density. A larger value yields sparse distribution, while a smaller value makes it dense. 
   - Combine this with Random Rotation and Random Scale settings to instantly generate chaotic yet organic scene blockouts, like rocky terrains or rubble.

---

## 4. Ultimate Technique: Performance Optimization Workflow (Must Read)

While CSG nodes are incredibly convenient during the editing phase, retaining a large number of them during the final game runtime will cause **severe performance degradation (FPS drops)** due to real-time boolean calculations.
When a specific room or architectural block is "finalized and won't be changed," you **must** convert it into a static mesh and collision body.

**Standard 1-Click Conversion Process**:
1. **Finalize Blockout**: Select the top-level `CSGCombiner3D` node that contains all your operations.
2. **Bake to Mesh**: In the editor's top menu bar, click the contextual options for `CSGCombiner3D` and select **"Bake to MeshInstance3D"**.
3. **Generate Collision**: Select the newly generated `MeshInstance3D`, click "Mesh" in the top menu bar, and select **"Create Trimesh Static Body"**. This will automatically generate a highly accurate collision shape that perfectly wraps your geometry.
4. **Clean up Structure**: Move the generated `MeshInstance3D` (along with its internal `CollisionShape3D`) under a clean `StaticBody3D` hierarchy.
5. **Delete Original CSG**: **Delete** the original `CSGCombiner3D` node and all its children. At this point, the heavy boolean calculations are completely unloaded, leaving you with an ultra-performant static game asset with perfect collisions!

> [!WARNING]
> ⚠️**Note**: Before deleting the CSG nodes, it is highly recommended to save the original CSG structure as a separate scene file (e.g., `CSG_Source.tscn`) or keep a backup, so you can easily modify the level structure later.
