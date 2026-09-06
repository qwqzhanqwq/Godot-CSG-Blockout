@tool
class_name CsgBlockoutI18n
extends RefCounted

const TABLE: Dictionary = {
	"CSG_BLOCKOUT_SETTINGS": {
		"zh": "CSG Blockout 设置",
		"en": "CSG Blockout Settings"
	},
	"BOX": {
		"zh": "立方体",
		"en": "Box"
	},
	"CYLINDER": {
		"zh": "圆柱体",
		"en": "Cylinder"
	},
	"MESH": {
		"zh": "网格",
		"en": "Mesh"
	},
	"POLYGON": {
		"zh": "多边形",
		"en": "Polygon"
	},
	"SPHERE": {
		"zh": "球体",
		"en": "Sphere"
	},
	"TORUS": {
		"zh": "圆环",
		"en": "Torus"
	},
	"UNION": {
		"zh": "并集",
		"en": "Union"
	},
	"INTERSECTION": {
		"zh": "交集",
		"en": "Intersection"
	},
	"SUBTRACTION": {
		"zh": "差集",
		"en": "Subtraction"
	},
	"MATERIAL": {
		"zh": "材质",
		"en": "Material"
	},
	"REGEN_PREVIEW_TOOLTIP": {
		"zh": "重新生成预览实例",
		"en": "Regenerate Preview Instances"
	},
	"BAKE_INSTANCES_TOOLTIP": {
		"zh": "将生成的实例烘焙至场景中 (使其永久保留)",
		"en": "Bake generated instances into scene (Make permanent)"
	},
	"SELECT_MATERIAL": {
		"zh": "选择材质",
		"en": "Select Material"
	},
	"WARN_SELECT_CSG_SHAPE": {
		"zh": "请先选择一个 CSGShape3D 节点以添加新 CSG 节点",
		"en": "Please select a CSGShape3D node first to add a new CSG node"
	},
	"WARN_UNSUPPORTED_CSG_TYPE": {
		"zh": "未知或不支持的 CSG 节点类型",
		"en": "Unknown or unsupported CSG node type"
	},
	"ADD_NODE": {
		"zh": "添加 %s",
		"en": "Add %s"
	},
	"REFRESH": {
		"zh": "刷新",
		"en": "Refresh"
	},
	"BAKE": {
		"zh": "烘焙",
		"en": "Bake"
	},
	"CHANGE_CSG_OP": {
		"zh": "更改 CSG 操作",
		"en": "Change CSG Operation"
	},
	"CREATE_NODE": {
		"zh": "创建 %s",
		"en": "Create %s"
	},
	"GRID_LIGHT": {
		"zh": "灰白网格",
		"en": "Light Grid"
	},
	"GRID_DARK": {
		"zh": "深灰网格",
		"en": "Dark Grid"
	},
	"GRID_ORANGE": {
		"zh": "橙色网格",
		"en": "Orange Grid"
	},
	"MATERIAL_NONE": {
		"zh": "无材质(白模)",
		"en": "No Material (White)"
	},
	"MATERIAL_CUSTOM": {
		"zh": "自定义材质",
		"en": "Custom Material"
	},
	"APPLY_MATERIAL_TO_SELECTED": {
		"zh": "应用材质到选中节点",
		"en": "Apply Material to Selected"
	},
	"APPLY_MATERIAL": {
		"zh": "应用材质",
		"en": "Apply Material"
	},
	"CLEAR_MATERIAL": {
		"zh": "清除材质",
		"en": "Clear Material"
	},
	"LANGUAGE_TOOLTIP": {
		"zh": "语言 / Language (Auto / EN / 中文)",
		"en": "Language / 语言 (Auto / EN / 中文)"
	}
}

static var _reverse_initialized: bool = false
static var _reverse_map: Dictionary = {}

static func _ensure_reverse_map() -> void:
	if _reverse_initialized:
		return
	_reverse_initialized = true
	for key in TABLE:
		var entry: Dictionary = TABLE[key]
		for lang in entry:
			var text: String = entry[lang]
			_reverse_map[text] = key
		_reverse_map[key] = key
	
	# Node name and legacy compatibility aliases
	_reverse_map["PresetLight"] = "GRID_LIGHT"
	_reverse_map["PRESET_LIGHT"] = "GRID_LIGHT"
	_reverse_map["PresetDark"] = "GRID_DARK"
	_reverse_map["PRESET_DARK"] = "GRID_DARK"
	_reverse_map["PresetOrange"] = "GRID_ORANGE"
	_reverse_map["PRESET_ORANGE"] = "GRID_ORANGE"
	_reverse_map["PresetNone"] = "MATERIAL_NONE"
	_reverse_map["PRESET_NONE"] = "MATERIAL_NONE"
	_reverse_map["MaterialPicker"] = "MATERIAL_CUSTOM"
	_reverse_map["MATERIAL_PICKER"] = "MATERIAL_CUSTOM"
	_reverse_map["ApplyToSelected"] = "APPLY_MATERIAL_TO_SELECTED"
	_reverse_map["APPLY_TO_SELECTED"] = "APPLY_MATERIAL_TO_SELECTED"
	_reverse_map["Refresh"] = "REFRESH"
	_reverse_map["Bake"] = "BAKE"
	_reverse_map["创建 "] = "CREATE_NODE"
	_reverse_map["Create "] = "CREATE_NODE"
	_reverse_map["Language / 语言"] = "LANGUAGE_TOOLTIP"

static func get_locale() -> String:
	var config = CsgBlockoutConfig.get_config()
	if config:
		var override_lang: String = config.language_override
		if override_lang != "" and override_lang != "auto":
			return "zh" if override_lang.begins_with("zh") else "en"
			
	# 1. Safely check EditorInterface editor settings in editor hint
	if Engine.is_editor_hint():
		var editor_settings = EditorInterface.get_editor_settings()
		if editor_settings:
			var lang_setting = editor_settings.get_setting("interface/editor/editor_language")
			if lang_setting != null:
				var s := String(lang_setting).strip_edges()
				if not s.is_empty() and s != "default" and s != "auto":
					return "zh" if s.begins_with("zh") else "en"
					
	# 2. Check TranslationServer tool locale
	var tool_locale := TranslationServer.get_tool_locale()
	if not tool_locale.is_empty() and tool_locale != "en":
		return "zh" if tool_locale.begins_with("zh") else "en"
		
	var general_locale := TranslationServer.get_locale()
	if not general_locale.is_empty() and general_locale != "en":
		return "zh" if general_locale.begins_with("zh") else "en"
		
	# 3. Check OS locale language
	var os_locale := OS.get_locale_language()
	if not os_locale.is_empty():
		return "zh" if os_locale.begins_with("zh") else "en"
		
	var os_full := OS.get_locale()
	if not os_full.is_empty():
		return "zh" if os_full.begins_with("zh") else "en"
		
	return "en"

static func t(key_or_text: String) -> String:
	_ensure_reverse_map()
	var canonical_key: String = _reverse_map.get(key_or_text, key_or_text)
	if TABLE.has(canonical_key):
		var lang = get_locale()
		return TABLE[canonical_key].get(lang, TABLE[canonical_key].get("en", key_or_text))
	return key_or_text

static func tf(key_or_text: String, args: Array = []) -> String:
	var tmpl := t(key_or_text)
	if args.is_empty():
		return tmpl
	return tmpl % args

static func translate_node(node: Node) -> void:
	if node == null:
		return
		
	# Disable Godot engine auto_translate to prevent Godot's built-in PO dictionary
	# from hijacking common English words (e.g. Box, Cylinder, Mesh, Polygon, Sphere) back into Chinese.
	if "auto_translate_mode" in node:
		node.set("auto_translate_mode", 2) # Node.AUTO_TRANSLATE_MODE_DISABLED
	if "auto_translate" in node:
		node.set("auto_translate", false)
		
	if node is OptionButton or node.name == "LanguageToggle":
		for child in node.get_children():
			translate_node(child)
		return
		
	_ensure_reverse_map()
	
	if node is Control:
		if not node.has_meta("i18n_tooltip_key"):
			var key := ""
			if node.tooltip_text != "":
				key = _reverse_map.get(node.tooltip_text, "")
			if key == "":
				var node_name_str := String(node.name)
				key = _reverse_map.get(node_name_str, "")
				if key == "":
					var snake_key := node_name_str.to_snake_case().to_upper()
					key = _reverse_map.get(snake_key, "")
			if key != "":
				node.set_meta("i18n_tooltip_key", key)
				
		if node.has_meta("i18n_tooltip_key"):
			node.tooltip_text = t(node.get_meta("i18n_tooltip_key"))
			
	if node is Button or node is Label:
		if "text" in node and typeof(node.get("text")) == TYPE_STRING and node.get("text") != "":
			if not node.has_meta("i18n_text_key"):
				var key := _reverse_map.get(node.get("text"), "")
				if key == "":
					var node_name_str := String(node.name)
					key = _reverse_map.get(node_name_str, "")
					if key == "":
						var snake_key := node_name_str.to_snake_case().to_upper()
						key = _reverse_map.get(snake_key, "")
				if key != "":
					node.set_meta("i18n_text_key", key)
			if node.has_meta("i18n_text_key"):
				node.set("text", t(node.get_meta("i18n_text_key")))
				
	for child in node.get_children():
		translate_node(child)
