@tool
class_name CsgBlockoutI18n
extends RefCounted

const TABLE: Dictionary = {
	"CSG_BLOCKOUT_SETTINGS": {
		"zh": "CSG Blockout 设置",
		"en": "CSG Blockout Settings",
		"ja": "CSG Blockout 設定",
		"ko": "CSG Blockout 설정",
		"es": "Configuración de CSG Blockout",
		"pt": "Configurações do CSG Blockout",
		"ru": "Настройки CSG Blockout"
	},
	"BOX": {
		"zh": "立方体",
		"en": "Box",
		"ja": "直方体",
		"ko": "상자",
		"es": "Caja",
		"pt": "Caixa",
		"ru": "Куб"
	},
	"CYLINDER": {
		"zh": "圆柱体",
		"en": "Cylinder",
		"ja": "円柱",
		"ko": "원기둥",
		"es": "Cilindro",
		"pt": "Cilindro",
		"ru": "Цилиндр"
	},
	"MESH": {
		"zh": "网格",
		"en": "Mesh",
		"ja": "メッシュ",
		"ko": "메시",
		"es": "Malla",
		"pt": "Malha",
		"ru": "Сетка"
	},
	"POLYGON": {
		"zh": "多边形",
		"en": "Polygon",
		"ja": "ポリゴン",
		"ko": "다각형",
		"es": "Polígono",
		"pt": "Polígono",
		"ru": "Многоугольник"
	},
	"SPHERE": {
		"zh": "球体",
		"en": "Sphere",
		"ja": "球体",
		"ko": "구",
		"es": "Esfera",
		"pt": "Esfera",
		"ru": "Сфера"
	},
	"TORUS": {
		"zh": "圆环",
		"en": "Torus",
		"ja": "トーラス",
		"ko": "토러스",
		"es": "Toro",
		"pt": "Toro",
		"ru": "Тор"
	},
	"UNION": {
		"zh": "并集",
		"en": "Union",
		"ja": "和集合",
		"ko": "합집합",
		"es": "Unión",
		"pt": "União",
		"ru": "Объединение"
	},
	"INTERSECTION": {
		"zh": "交集",
		"en": "Intersection",
		"ja": "積集合",
		"ko": "교집합",
		"es": "Intersección",
		"pt": "Interseção",
		"ru": "Пересечение"
	},
	"SUBTRACTION": {
		"zh": "差集",
		"en": "Subtraction",
		"ja": "差集合",
		"ko": "차집합",
		"es": "Sustracción",
		"pt": "Subtração",
		"ru": "Вычитание"
	},
	"MATERIAL": {
		"zh": "材质",
		"en": "Material",
		"ja": "マテリアル",
		"ko": "머티리얼",
		"es": "Material",
		"pt": "Material",
		"ru": "Материал"
	},
	"REGEN_PREVIEW_TOOLTIP": {
		"zh": "重新生成预览实例",
		"en": "Regenerate Preview Instances",
		"ja": "プレビューインスタンスを再生成",
		"ko": "미리보기 인스턴스 재생성",
		"es": "Regenerar instancias de vista previa",
		"pt": "Regenerar instâncias de pré-visualização",
		"ru": "Перегенерировать экземпляры предпросмотра"
	},
	"BAKE_INSTANCES_TOOLTIP": {
		"zh": "将生成的实例烘焙至场景中 (使其永久保留)",
		"en": "Bake generated instances into scene (Make permanent)",
		"ja": "生成されたインスタンスをシーンにベイク (永続化)",
		"ko": "생성된 인스턴스를 씬에 베이크 (영구 유지)",
		"es": "Hornear instancias generadas en la escena (hacer permanente)",
		"pt": "Assar instâncias geradas na cena (tornar permanente)",
		"ru": "Запечь созданные экземпляры в сцену (сделать постоянными)"
	},
	"SELECT_MATERIAL": {
		"zh": "选择材质",
		"en": "Select Material",
		"ja": "マテリアルを選択",
		"ko": "머티리얼 선택",
		"es": "Seleccionar material",
		"pt": "Selecionar material",
		"ru": "Выбрать материал"
	},
	"WARN_SELECT_CSG_SHAPE": {
		"zh": "请先选择一个 CSGShape3D 节点以添加新 CSG 节点",
		"en": "Please select a CSGShape3D node first to add a new CSG node",
		"ja": "新しいCSGノードを追加するには、まずCSGShape3Dノードを選択してください",
		"ko": "새 CSG 노드를 추가하려면 먼저 CSGShape3D 노드를 선택하세요",
		"es": "Por favor, seleccione un nodo CSGShape3D primero para agregar un nuevo nodo CSG",
		"pt": "Selecione primeiro um nó CSGShape3D para adicionar um novo nó CSG",
		"ru": "Пожалуйста, сначала выберите узел CSGShape3D, чтобы добавить новый узел CSG"
	},
	"WARN_UNSUPPORTED_CSG_TYPE": {
		"zh": "未知或不支持的 CSG 节点类型",
		"en": "Unknown or unsupported CSG node type",
		"ja": "不明または未対応のCSGノードタイプです",
		"ko": "알 수 없거나 지원되지 않는 CSG 노드 유형입니다",
		"es": "Tipo de nodo CSG desconocido o no compatible",
		"pt": "Tipo de nó CSG desconhecido ou não suportado",
		"ru": "Неизвестный или неподдерживаемый тип узла CSG"
	},
	"ADD_NODE": {
		"zh": "添加 %s",
		"en": "Add %s",
		"ja": "%s を追加",
		"ko": "%s 추가",
		"es": "Añadir %s",
		"pt": "Adicionar %s",
		"ru": "Добавить %s"
	},
	"REFRESH": {
		"zh": "刷新",
		"en": "Refresh",
		"ja": "更新",
		"ko": "새로고침",
		"es": "Actualizar",
		"pt": "Atualizar",
		"ru": "Обновить"
	},
	"BAKE": {
		"zh": "烘焙",
		"en": "Bake",
		"ja": "ベイク",
		"ko": "베이크",
		"es": "Hornear",
		"pt": "Assar",
		"ru": "Запечь"
	},
	"CHANGE_CSG_OP": {
		"zh": "更改 CSG 操作",
		"en": "Change CSG Operation",
		"ja": "CSG操作を変更",
		"ko": "CSG 작업 변경",
		"es": "Cambiar operación CSG",
		"pt": "Alterar operação CSG",
		"ru": "Изменить операцию CSG"
	},
	"CREATE_NODE": {
		"zh": "创建 %s",
		"en": "Create %s",
		"ja": "%s を作成",
		"ko": "%s 생성",
		"es": "Crear %s",
		"pt": "Criar %s",
		"ru": "Создать %s"
	},
	"GRID_LIGHT": {
		"zh": "灰白网格",
		"en": "Light Grid",
		"ja": "ライトグリッド",
		"ko": "라이트 그리드",
		"es": "Cuadrícula clara",
		"pt": "Grade clara",
		"ru": "Светлая сетка"
	},
	"GRID_DARK": {
		"zh": "深灰网格",
		"en": "Dark Grid",
		"ja": "ダークグリッド",
		"ko": "다크 그리드",
		"es": "Cuadrícula oscura",
		"pt": "Grade escura",
		"ru": "Тёмная сетка"
	},
	"GRID_ORANGE": {
		"zh": "橙色网格",
		"en": "Orange Grid",
		"ja": "オレンジグリッド",
		"ko": "오렌지 그리드",
		"es": "Cuadrícula naranja",
		"pt": "Grade laranja",
		"ru": "Оранжевая сетка"
	},
	"MATERIAL_NONE": {
		"zh": "无材质(白模)",
		"en": "No Material (White)",
		"ja": "マテリアルなし(白モデル)",
		"ko": "머티리얼 없음(흰색)",
		"es": "Sin material (blanco)",
		"pt": "Sem material (branco)",
		"ru": "Без материала (белый)"
	},
	"MATERIAL_CUSTOM": {
		"zh": "自定义材质",
		"en": "Custom Material",
		"ja": "カスタムマテリアル",
		"ko": "사용자 정의 머티리얼",
		"es": "Material personalizado",
		"pt": "Material personalizado",
		"ru": "Пользовательский материал"
	},
	"APPLY_MATERIAL_TO_SELECTED": {
		"zh": "应用材质到选中节点",
		"en": "Apply Material to Selected",
		"ja": "選択したノードにマテリアルを適用",
		"ko": "선택한 노드에 머티리얼 적용",
		"es": "Aplicar material a seleccionados",
		"pt": "Aplicar material aos selecionados",
		"ru": "Применить материал к выбранным"
	},
	"APPLY_MATERIAL": {
		"zh": "应用材质",
		"en": "Apply Material",
		"ja": "マテリアルを適用",
		"ko": "머티리얼 적용",
		"es": "Aplicar material",
		"pt": "Aplicar material",
		"ru": "Применить материал"
	},
	"CLEAR_MATERIAL": {
		"zh": "清除材质",
		"en": "Clear Material",
		"ja": "マテリアルをクリア",
		"ko": "머티리얼 제거",
		"es": "Limpiar material",
		"pt": "Limpar material",
		"ru": "Очистить материал"
	},
	"LANGUAGE_TOOLTIP": {
		"zh": "语言 / Language (Auto / EN / 中文 / 日本語 / 한국어 / Español / Português / Русский)",
		"en": "Language / 语言 (Auto / EN / 中文 / 日本語 / 한국어 / Español / Português / Русский)",
		"ja": "言語 / Language (Auto / EN / 中文 / 日本語 / 한국어 / Español / Português / Русский)",
		"ko": "언어 / Language (Auto / EN / 中文 / 日本語 / 한국어 / Español / Português / Русский)",
		"es": "Idioma / Language (Auto / EN / 中文 / 日本語 / 한국어 / Español / Português / Русский)",
		"pt": "Idioma / Language (Auto / EN / 中文 / 日本語 / 한국어 / Español / Português / Русский)",
		"ru": "Язык / Language (Auto / EN / 中文 / 日本語 / 한국어 / Español / Português / Русский)"
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

static func _normalize_locale(loc: String) -> String:
	var l := loc.to_lower()
	if l.begins_with("zh"):
		return "zh"
	elif l.begins_with("ja"):
		return "ja"
	elif l.begins_with("ko"):
		return "ko"
	elif l.begins_with("es"):
		return "es"
	elif l.begins_with("pt"):
		return "pt"
	elif l.begins_with("ru"):
		return "ru"
	return "en"

static func get_locale() -> String:
	var config = CsgBlockoutConfig.get_config()
	if config:
		var override_lang: String = config.language_override
		if override_lang != "" and override_lang != "auto":
			return _normalize_locale(override_lang)
			
	# 1. Safely check EditorInterface editor settings in editor hint
	if Engine.is_editor_hint():
		var editor_settings = EditorInterface.get_editor_settings()
		if editor_settings:
			var lang_setting = editor_settings.get_setting("interface/editor/editor_language")
			if lang_setting != null:
				var s := String(lang_setting).strip_edges()
				if not s.is_empty() and s != "default" and s != "auto":
					return _normalize_locale(s)
					
	# 2. Check TranslationServer tool locale
	var tool_locale := TranslationServer.get_tool_locale()
	if not tool_locale.is_empty() and tool_locale != "en":
		return _normalize_locale(tool_locale)
		
	var general_locale := TranslationServer.get_locale()
	if not general_locale.is_empty() and general_locale != "en":
		return _normalize_locale(general_locale)
		
	# 3. Check OS locale language
	var os_locale := OS.get_locale_language()
	if not os_locale.is_empty():
		return _normalize_locale(os_locale)
		
	var os_full := OS.get_locale()
	if not os_full.is_empty():
		return _normalize_locale(os_full)
		
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
