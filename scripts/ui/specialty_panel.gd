## 文件: scripts/ui/specialty_panel.gd
## 职责: 招牌菜选择面板（P7）——打烊后从日结算面板打开，选择次日招牌菜（价格加成 + 熟练度成长）
## 依赖: GameStateManager/UITheme (autoload)；process_mode=ALWAYS（打烊暂停期间可交互，同商店模式）

@tool
extends CanvasLayer

var _overlay: ColorRect = null
var _current_label: RichTextLabel = null
var _list: VBoxContainer = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_panel()

func _build_panel() -> void:
	if _overlay != null and is_instance_valid(_overlay):
		return
	_overlay = ColorRect.new()
	_overlay.name = "Overlay"
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.color = Color(0, 0, 0, 0.6)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	_overlay.visible = false
	add_child(_overlay)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UITheme.make_panel_texture_style(true))
	panel.custom_minimum_size = Vector2(360, 0)
	center.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	vbox.add_child(_make_rule())
	vbox.add_child(_make_label("招牌菜", 30, UITheme.COLOR_GOLD))
	vbox.add_child(_make_rule())

	_current_label = _make_label("", 18, UITheme.COLOR_TEXT_DIM, true)
	vbox.add_child(_current_label)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 8)
	vbox.add_child(_list)

	var back := Button.new()
	back.text = "返回"
	back.custom_minimum_size = Vector2(140, 40)
	back.add_theme_font_size_override("font_size", 20)
	var btn_styles := UITheme.make_button_styles()
	back.add_theme_stylebox_override("normal", btn_styles["normal"])
	back.add_theme_stylebox_override("hover", btn_styles["hover"])
	back.add_theme_stylebox_override("pressed", btn_styles["pressed"])
	back.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	back.add_theme_color_override("font_color", UITheme.COLOR_TEXT)
	UITheme.style_button_feedback(back)
	back.pressed.connect(_on_back_pressed)
	vbox.add_child(back)

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
	var btn_styles := UITheme.make_button_styles()
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

func _make_rule() -> ColorRect:
	var rule := ColorRect.new()
	rule.color = Color(UITheme.COLOR_GOLD_DARK, 0.8)
	rule.custom_minimum_size = Vector2(140, 2)
	rule.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rule

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
