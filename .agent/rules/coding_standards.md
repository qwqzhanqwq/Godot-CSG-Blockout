# Godot 4.7 / GDScript 2.0 规范契约

## 架构与性能红线
- **算法资源化**：几何计算必须封装为 `Resource` (`CSGPattern`)；更换资源前必须防重入解绑：`if res.changed.is_connected(cb): res.changed.disconnect(cb)`。
- **单向拓扑**：严禁 `get_parent()` 与 `get_node("../../")`；父调子方法，子向上只发 Signal。
- **计算节流**：setter 严禁触发 CSG 重算，仅置 `_dirty = true`；必须在 `_process` 中基于时间戳节流（`REGEN_THROTTLE_MS`）与锁防抖。
- **生命周期与所有权隔离**：
  - 编辑器专有逻辑（预览重构、清理）必须门控：`if not Engine.is_editor_hint(): return`。
  - 动态生成的**过程式预览实例严禁设置 `owner`**；**仅在烘焙（Bake）或新建场景实体时**，在 `add_child()` 之后显式指定 `node.owner = get_tree().edited_scene_root`。
- **场景事务边界**：视口与 UI 交互层引起场景树变动，必须经由 `EditorUndoRedoManager` 提交 Do/Undo 事务。

## 语法与实现硬标准
- **全静态强类型**：严禁未注类型的裸变量；容器必须带泛型：`Array[Type]` 与 `Dictionary[KeyType, ValueType]`（异构值必须显式标为 `Variant`）。
- **StringName 优先**：高频查找键与元数据必须使用 `&"literal"`。
- **现代工具按钮**：Inspector 触发操作统一采用 `@export_tool_button("Label") var btn: Callable = _callback`（仅修饰 Callable 变量，禁止修饰函数）。
- **强类型事件**：禁止字符串反射；统一使用 `signal.connect(callable)`。
- **安全解引用**：跨帧与外部 Node3D 引用访问前必须通过 `is_instance_valid(node)` 拦截；依赖统一 `@onready` / `@export`。
- **工程单点接入**：多语言统一 `CsgBlockoutI18n.t("KEY")`；配置统一 `CsgBlockoutConfig.get_config()`；魔数统一提升为 `const`。
