@tool
class_name CsgBlockoutI18n
extends RefCounted

const EN = {
	"CSG Blockout 设置": "CSG Blockout Settings",
	"立方体": "Box",
	"圆柱体": "Cylinder",
	"网格": "Mesh",
	"多边形": "Polygon",
	"球体": "Sphere",
	"圆环": "Torus",
	"并集": "Union",
	"交集": "Intersection",
	"差集": "Subtraction",
	"材质": "Material",
	"重新生成预览实例": "Regenerate Preview Instances",
	"将生成的实例烘焙至场景中 (使其永久保留)": "Bake generated instances into scene (Make permanent)",
	"选择材质": "Select Material",
	"请先选择一个 CSGShape3D 节点以添加新 CSG 节点": "Please select a CSGShape3D node first to add a new CSG node",
	"未知或不支持的 CSG 节点类型": "Unknown or unsupported CSG node type",
	"添加 %s": "Add %s",
	"刷新": "Refresh",
	"烘焙": "Bake",
	"请选择要打组的子节点。": "Please select child nodes to group.",
	"操作已取消，需要子节点。": "Operation cancelled, child nodes required.",
	"斜坡": "Slope",
	"阶梯": "Stairs",
	"门框": "Door Frame",
	"更改 CSG 操作": "Change CSG Operation",
	"创建 ": "Create "
}

static func get_locale() -> String:
	var config = CsgBlockoutConfig.get_config()
	if config:
		return config.language_override
		
	if Engine.is_editor_hint():
		var editor_settings = EditorInterface.get_editor_settings()
		if editor_settings and editor_settings.has_setting("interface/editor/editor_language"):
			return editor_settings.get_setting("interface/editor/editor_language")
	return TranslationServer.get_tool_locale()

static func t(text: String) -> String:
	var locale = get_locale()
	if locale.begins_with("zh"):
		return text
	return EN.get(text, text)

static func translate_node(node: Node) -> void:
	if node is OptionButton or node.name == "LanguageToggle":
		for child in node.get_children():
			translate_node(child)
		return
		
	if node is Control:
		if node.tooltip_text != "" and not node.has_meta("i18n_orig_tooltip_text"):
			node.set_meta("i18n_orig_tooltip_text", node.tooltip_text)
		if node.has_meta("i18n_orig_tooltip_text"):
			node.tooltip_text = t(node.get_meta("i18n_orig_tooltip_text"))
			
	if node is Button or node is Label:
		if "text" in node and typeof(node.get("text")) == TYPE_STRING and node.get("text") != "" and not node.has_meta("i18n_orig_text"):
			node.set_meta("i18n_orig_text", node.get("text"))
		if node.has_meta("i18n_orig_text"):
			node.set("text", t(node.get_meta("i18n_orig_text")))
	
	for child in node.get_children():
		translate_node(child)
