## 文件: scripts/ui/specialty_panel.gd
## 职责: 招牌菜选择面板（P7）——打烊后从日结算面板打开，选择次日招牌菜（价格加成 + 熟练度成长）
##       （#48 tscn 化：静态结构移入 scenes/ui/SpecialtyPanel.tscn，按钮换立体纹理三态）
## 依赖: GameStateManager/UITheme (autoload)；process_mode=ALWAYS（打烊暂停期间可交互，同商店模式）

@tool
extends CanvasLayer

@onready var _overlay: ColorRect = $Overlay
@onready var _panel: PanelContainer = $Overlay/CenterContainer/Panel
@onready var _current_label: RichTextLabel = $Overlay/CenterContainer/Panel/Margin/VBox/CurrentLabel
@onready var _list: VBoxContainer = $Overlay/CenterContainer/Panel/Margin/VBox/List
@onready var _back_button: Button = $Overlay/CenterContainer/Panel/Margin/VBox/BackButton

## 返回按钮信号/反馈只接一次（@tool 热重载幂等）
var _wired := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_panel.add_theme_stylebox_override("panel", UITheme.make_panel_texture_style(true))
	# #48：返回按钮立体纹理三态
	var btn_styles := UITheme.make_button_texture_styles()
	_back_button.add_theme_stylebox_override("normal", btn_styles["normal"])
	_back_button.add_theme_stylebox_override("hover", btn_styles["hover"])
	_back_button.add_theme_stylebox_override("pressed", btn_styles["pressed"])
	_back_button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	if not _wired:
		_wired = true
		UITheme.style_button_feedback(_back_button)
		_back_button.pressed.connect(_on_back_pressed)

# ==================== 展示 ====================

func show_panel() -> void:
	refresh()
	_overlay.visible = true

func hide_panel() -> void:
	_overlay.visible = false

func _on_back_pressed() -> void:
	hide_panel()

## 刷新：当前招牌 + 3 种 L1 候选按钮（含价格加成说明）
func refresh() -> void:
	if GameStateManager.specialty_dish == "":
		_current_label.text = "当前：未设置（可选一道菜加成价格）"
	else:
		_current_label.text = "当前：%s" % GameStateManager.get_dish_display_name(GameStateManager.specialty_dish)
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	for dish_id: String in GameStateManager.L1_DISHES:
		_list.add_child(_make_dish_row(dish_id, GameStateManager.DISHES[dish_id]))

## 一行菜：名称 + 价格加成说明 + 设为招牌按钮
func _make_dish_row(dish_id: String, def: Dictionary) -> Control:
	var row := PanelContainer.new()
	row.add_theme_stylebox_override("panel", _row_style())
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	row.add_child(hbox)

	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 2)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(info)
	info.add_child(_make_label(def["name"], 20, UITheme.COLOR_TEXT))
	info.add_child(_make_label("基础价 %d，招牌加成 +20%%（熟练度再 +10%%/档）" % def["price"], 14, UITheme.COLOR_TEXT_DIM))

	var is_current: bool = GameStateManager.specialty_dish == dish_id
	var btn := Button.new()
	btn.text = "当前" if is_current else "设为招牌"
	btn.disabled = is_current
	btn.custom_minimum_size = Vector2(110, 36)
	btn.add_theme_font_size_override("font_size", 18)
	# #48：按钮立体纹理三态
	var btn_styles := UITheme.make_button_texture_styles()
	btn.add_theme_stylebox_override("normal", btn_styles["normal"])
	btn.add_theme_stylebox_override("hover", btn_styles["hover"])
	btn.add_theme_stylebox_override("pressed", btn_styles["pressed"])
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	btn.add_theme_color_override("font_color", UITheme.COLOR_TEXT)
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	UITheme.style_button_feedback(btn)
	btn.pressed.connect(func() -> void: _on_select(dish_id))
	hbox.add_child(btn)
	return row

func _on_select(dish_id: String) -> void:
	GameStateManager.set_specialty_dish(dish_id)
	refresh()

# ==================== 样式辅助 ====================

func _make_label(text: String, font_size: int, color: Color, rich: bool = false) -> Control:
	if rich:
		var rl := RichTextLabel.new()
		rl.bbcode_enabled = true
		rl.fit_content = true
		rl.text = text
		rl.add_theme_font_size_override("normal_font_size", font_size)
		rl.add_theme_color_override("default_color", color)
		rl.add_theme_constant_override("outline_size", 4)
		rl.add_theme_color_override("outline_color", Color(0, 0, 0, 0.8))
		rl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rl.set("alignment", HorizontalAlignment.HORIZONTAL_ALIGNMENT_CENTER)
		return rl
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override("outline_size", 4)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _row_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.93, 0.88, 0.80, 0.45)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(10)
	return sb
