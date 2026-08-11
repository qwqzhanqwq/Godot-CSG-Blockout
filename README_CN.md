# CSG_Blockout

**CSG_Blockout** 是一个专为 Godot 4.7 打造的高性能、现代化的 3D 关卡白盒（Blockout）原型设计插件。

本插件在继承 [CSG Toolkit](https://godotengine.org/asset-library/asset/3057) 设计概念的基础上，进行了彻底的代码重构与架构升级。引入了基于空间哈希网格（Spatial Hash Grid）的碰撞避障算法、响应式 3D 轮盘菜单（Pie Menu）、模块化阵列与散布节点系统，以及全静态类型的 GDScript 2.0 防御性架构，旨在为游戏开发者提供极速、稳定、无崩溃的关卡原型搭建体验。

*其他语言版本：[English](README.md), [简体中文](README_CN.md).*

*📖 教程文档：[简体中文教程](TUTORIAL_CN.md) | [English Tutorial](TUTORIAL_EN.md)*

---

## 架构与核心技术亮点

### 1. 空间哈希网格算法 (Spatial Hash Grid)
在散布计算（`CSGSpreader3D`）中，传统的双重循环距离检测会导致 O(N^2) 的时间复杂度，当物体数量较多时会引发编辑器卡顿甚至未响应。
`CSG_Blockout` 采用了 **3D 空间哈希网格算法**：
- 根据最小安全距离 `min_distance` 将三维空间划分为连续的立方体网格单元（Cell Size = `min_distance / sqrt(3)`）。
- 每次放置新节点时，仅检索并比较目标位置所在单元格及相邻 27 个网格内的已存在节点。
- 将重叠检测的时间复杂度降低至 **O(1)**，在包含数百个组合 CSG 几何体的复杂关卡中依然可以做到实时计算与瞬时响应。

### 2. 交互式 3D 轮盘菜单 (3D Pie Menu)
- **快捷键调用：** 在 3D 编辑器视口中按下 `Shift + A` 即可在鼠标指针所在位置呼出矢量绘制的 3D 轮盘菜单。
- **层级导航：** 外围分为并集（Union）、交集（Intersection）、差集（Subtraction）三大布尔操作分支，进入分支后可快速选取基础 CSG 形状（立方体、圆柱体、网格、多边形、球体、圆环）。
- **智能节点操作：** 若当前已选中某个 `CSGShape3D` 节点，在轮盘菜单中选择布尔运算会自动更新该节点的 `operation` 属性；若未选择或在子菜单中点击形状，则自动创建并配置对应布尔操作的新 CSG 节点。
- **手势与死区控制：** 内置中央死区（Deadzone），点击死区或鼠标右键可返回上一级菜单或关闭轮盘。

### 3. 高度可扩展的阵列与散布节点系统
- **`CSGRepeater3D`：** 继承自 `CSGCombiner3D`。支持通过策略模式接入自定义 `CSGPattern` 资源，实现网格阵列（`CSGGridPattern`）、环形阵列（`CSGCircularPattern`）、螺旋阵列（`CSGSpiralPattern`）以及三维噪声采样散布（`CSGNoisePattern`）。
- **`CSGSpreader3D`：** 继承自 `CSGCombiner3D`。支持基于各种 3D 碰撞体形状（`BoxShape3D`、`SphereShape3D`、`CapsuleShape3D`、`CylinderShape3D`、`HeightMapShape3D`、`ConcavePolygonShape3D`、`ConvexPolygonShape3D` 等）的体域内随机填充与防重叠布置。

### 4. 纯血 GDScript 2.0 与防御性设计
- 代码库全线启用静态类型标注（Static Typing）与 `ClassDB` 实例化校验。
- 完整接入 `EditorUndoRedoManager`，所有节点创建、层级变更与布尔属性修改均支持 `Ctrl + Z` / `Ctrl + Y` 撤销重做。
- 针对编辑器模式与运行时环境做了严格解耦，防止垃圾节点遗留或编辑态数据污染。

### 5. 原生中英双语国际化 (i18n)
- 插件内置 `CsgBlockoutI18n` 翻译引擎，可在界面中自由切换英文 (`en`) 与中文 (`zh_CN`)。

---

## 节点与组件详细说明

### 1. CSGRepeater3D (阵列重复器)

`CSGRepeater3D` 用于按照特定几何规律重复生成模板几何体。

#### 核心属性表
| 属性名 | 类型 | 说明 |
| :--- | :--- | :--- |
| `template_node` | `Node3D` | 场景内指定的模板节点引用。 |
| `template_node_scene` | `PackedScene` | 预制体资源文件模板（当未指定场景节点时优先使用）。 |
| `hide_template` | `bool` | 是否在生成阵列时隐藏原始模板节点（默认开启）。 |
| `pattern` | `CSGPattern` | 阵列生成模式资源（网格、环形、螺旋、噪声等）。 |
| `position_jitter` | `float` | 位置随机偏移抖动幅度。 |
| `random_seed` | `int` | 随机生成种子。 |
| `estimated_instances` | `int` | (只读) 当前计算出的预估生成实例数量。 |

#### 随机变异控制 (Variation Options)
- **旋转随机化 (`randomize_rotation`)：**
  - 可独立开启 X / Y / Z 轴的随机旋转 (`randomize_rot_x/y/z`)。
  - 支持指定各轴的旋转方差角度范围 (`rotation_variance_x/y/z_deg`)，为 0 时表示 0~360 度全随机。
- **缩放随机化 (`randomize_scale`)：**
  - 支持全局缩放方差 (`scale_variance`) 及分轴缩放控制 (`randomize_scale_x/y/z` 与 `scale_variance_x/y/z`)。

#### 支持的模式资源 (CSGPattern Subclasses)
1. **`CSGGridPattern` (网格模式)：**
   - `count_x`, `count_y`, `count_z`：各方向重复次数。
   - `spacing`：三维间距向量。
   - `use_template_size`：自动叠加模板节点的 AABB 包围盒尺寸。
2. **`CSGCircularPattern` (环形模式)：**
   - `radius`：分布半径。
   - `points`：单层生成点数。
   - `layers`：垂直层数。
   - `layer_height`, `layer_spacing`：层高与额外层间距。
3. **`CSGSpiralPattern` (螺旋模式)：**
   - `turns`：圈数。
   - `start_radius`, `end_radius`：起始与终止半径。
   - `total_height`：螺旋总高度。
   - `use_radius_curve`, `radius_curve`：支持通过 `Curve` 资源精确控制半径变化曲线。
4. **`CSGNoisePattern` (噪声模式)：**
   - 基于 `FastNoiseLite` 在 3D 体域内采样。
   - 包含 `bounds`, `sample_density`, `noise_threshold`, `noise_type` (Simplex, Perlin, Cellular 等), `fractal_type` 等丰富参数。

---

### 2. CSGSpreader3D (体域散布器)

`CSGSpreader3D` 用于在指定的 `Shape3D` 空间区域内随机散射几何体实例，并进行碰撞避障。

#### 核心属性表
| 属性名 | 类型 | 说明 |
| :--- | :--- | :--- |
| `template_node` | `Node3D` | 散布目标模板节点。 |
| `spread_area_3d` | `Shape3D` | 散布区域形状（支持 Box, Sphere, Capsule, Cylinder, HeightMap, Mesh 凸包/凹包等）。 |
| `max_count` | `int` | 最大生成实例上限 (上限为安全保护值 200)。 |
| `noise_threshold` | `float` | 噪声概率过滤阈值 (0.0 ~ 1.0)。 |
| `seed` | `int` | 随机种子。 |
| `allow_rotation` | `bool` | 是否允许随机 Y 轴旋转。 |
| `allow_scale` | `bool` | 是否允许随机 0.5x~2.0x 缩放。 |

#### 碰撞与避障控制 (Collision Options)
| 属性名 | 类型 | 说明 |
| :--- | :--- | :--- |
| `avoid_overlaps` | `bool` | 是否启用空间哈希碰撞避障。 |
| `min_distance` | `float` | 实例之间的最小安全隔离距离。 |
| `max_placement_attempts` | `int` | 单个实例寻找无碰撞位置的最大尝试次数。 |

---

### 3. 编辑器界面与工具栏说明

#### 左侧工具栏 (CSGSideBlockoutBar)
- **快捷创建按钮：** 快速放置 `CSGBox3D`、`CSGCylinder3D`、`CSGMesh3D`、`CSGPolygon3D`、`CSGSphere3D`、`CSGTorus3D`。
- **操作符切换：** 自由切换生成节点的布尔类型：并集（Union）、交集（Intersection）、差集（Subtraction）。
- **材质指定 (Material Picker)：** 点击材质图标打开资源选择器，可为新创建的 CSG 节点自动应用指定的 `BaseMaterial3D` 或 `ShaderMaterial`，并实时生成微缩预览图。
- **按键反转层级：** 默认情况下，新节点作为兄弟节点（Sibling）创建；按住 `Alt` 键（可配置）点击创建按钮，可将新节点作为当前选中节点的子节点（Child）创建。
- **自动隐藏：** 当未选中任何 CSG 节点时，左侧栏将平滑淡出隐藏（可在配置中关闭）。

#### 顶部工具栏 (CSGTopBlockoutBar)
- 当在场景树中选中 `CSGRepeater3D` 或 `CSGSpreader3D` 时自动出现在 3D 编辑器上方。
- **刷新 (Refresh)：** 重新计算并刷新生成预览实例。
- **烘焙 (Bake)：** 将当前预览的动态子节点脱离生成器控制，设置其 `owner` 并转化为场景中的永久实体节点，方便后续手动调整。

---

## 项目全局配置 (ProjectSettings)

插件配置会自动注册至 Godot 的 `ProjectSettings` 中，路径位于 `addons/csg_blockout/*`：

| 设置项路径 | 数据类型 | 默认值 | 说明 |
| :--- | :--- | :--- | :--- |
| `addons/csg_blockout/default_behavior` | `int` (Enum) | `Sibling` (0) | 新建 CSG 节点的默认层级行为：`0: Sibling`, `1: Child`。 |
| `addons/csg_blockout/action_key` | `int` (Key) | `KEY_SHIFT` | 主操作修饰键。 |
| `addons/csg_blockout/secondary_action_key` | `int` (Key) | `KEY_ALT` | 次级修饰键（按住可反转层级创建逻辑）。 |
| `addons/csg_blockout/auto_hide` | `bool` | `true` | 是否在取消选择 CSG 节点时自动隐藏左侧面板。 |
| `addons/csg_blockout/language_override` | `String` | `"zh_CN"` | 语言偏好设置：`"en"` 或 `"zh_CN"`。 |

---

## 安装与启用步骤

1. 下载插件压缩包并解压。
2. 将 `addons/csg_blockout` 目录复制到你的 Godot 4.7 项目的 `addons/` 目录下。
3. 打开 Godot 编辑器，点击菜单栏 **项目 (Project) -> 项目设置 (Project Settings)**。
4. 切换至 **插件 (Plugins)** 标签页。
5. 找到 **CSG_Blockout**，勾选右侧的 **启用 (Enable)** 复选框。

---

## 开源致谢与协议

本插件由 [qwqzhanqwq](https://github.com/qwqzhanqwq) 基于开源项目 [CSG Toolkit](https://godotengine.org/asset-library/asset/3057) 进行重构与二次开发。

- **原版概念设计与 UI 布局：** [LuckyTepot](https://github.com/LuckyTepot) (Copyright (c) 2023).
- **架构重构、3D 轮盘菜单、空间哈希算法优化与 GDScript 2.0 重写：** [qwqzhanqwq](https://github.com/qwqzhanqwq) (Copyright (c) 2026).

开源许可协议：[MIT License](LICENSE)

