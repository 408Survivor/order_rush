## 文件: scripts/ui/upgrade_shop.gd
## 职责: 设备升级商店（P5）——打烊后从日结算面板打开（暂停中可交互），用累计金币购买设备升级
## 依赖: GameStateManager/UITheme/UpgradeManager (autoload)
## 注意: process_mode=ALWAYS（打烊暂停期间按钮仍可点，同日结算面板）；@tool 编辑器进程不自动刷新

@tool
extends CanvasLayer

var _overlay: ColorRect = null
var _money_label: RichTextLabel = null
var _list: VBoxContainer = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_panel()

func _build_panel() -> void:
	if _overlay != null and is_instance_valid(_overlay):
		return
	# 全屏遮罩（拦截点击，防止商店打开时操作场景）
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
	panel.custom_minimum_size = Vector2(420, 0)
	center.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	# 标题 + 上下金线装饰
	vbox.add_child(_make_rule())
	var title := _make_label("设备升级商店", 32, UITheme.COLOR_GOLD)
	vbox.add_child(title)
	vbox.add_child(_make_rule())

	_money_label = _make_label("", 20, UITheme.COLOR_GOLD, true)
	vbox.add_child(_money_label)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 8)
	vbox.add_child(_list)

	# 返回按钮
	var back := Button.new()
	back.text = "返回"
	back.custom_minimum_size = Vector2(160, 44)
	back.add_theme_font_size_override("font_size", 22)
	var btn_styles := UITheme.make_button_styles()
	back.add_theme_stylebox_override("normal", btn_styles["normal"])
	back.add_theme_stylebox_override("hover", btn_styles["hover"])
	back.add_theme_stylebox_override("pressed", btn_styles["pressed"])
	back.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	back.add_theme_color_override("font_color", UITheme.COLOR_TEXT)
	back.pressed.connect(_on_back_pressed)
	vbox.add_child(back)

# ==================== 展示 ====================

## 显示商店（打烊暂停中由结算面板按钮调用）
func show_shop() -> void:
	refresh()
	_overlay.visible = true

func hide_shop() -> void:
	_overlay.visible = false

func _on_back_pressed() -> void:
	hide_shop()

## 刷新：金币行 + 全部可购项（已购显示"已拥有"，金币不足置灰）
func refresh() -> void:
	_money_label.text = "%s 现有金币：%d" % [UITheme.icon(UITheme.ICON_COIN), GameStateManager.money]
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	for id: String in UpgradeManager.UPGRADES:
		_list.add_child(_make_upgrade_row(id, UpgradeManager.UPGRADES[id]))

## 一行升级项：名称/描述 + 购买按钮（或"已拥有"）
func _make_upgrade_row(id: String, def: Dictionary) -> Control:
	var row := PanelContainer.new()
	row.add_theme_stylebox_override("panel", _row_style())
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	row.add_child(hbox)

	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 2)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(info)
	info.add_child(_make_label(def["name"], 22, UITheme.COLOR_TEXT))
	info.add_child(_make_label(def["desc"], 15, UITheme.COLOR_TEXT_DIM))

	if UpgradeManager.is_owned(id):
		var owned := _make_label("已拥有", 18, UITheme.COLOR_GOLD)
		owned.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hbox.add_child(owned)
		return row

	var buy := Button.new()
	buy.text = "%s %d" % [UITheme.icon(UITheme.ICON_COIN, 16), def["price"]]
	buy.disabled = GameStateManager.money < def["price"]
	buy.custom_minimum_size = Vector2(110, 40)
	buy.add_theme_font_size_override("font_size", 18)
	var btn_styles := UITheme.make_button_styles()
	buy.add_theme_stylebox_override("normal", btn_styles["normal"])
	buy.add_theme_stylebox_override("hover", btn_styles["hover"])
	buy.add_theme_stylebox_override("pressed", btn_styles["pressed"])
	buy.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	buy.add_theme_stylebox_override("disabled", _disabled_style())
	buy.add_theme_color_override("font_color", UITheme.COLOR_TEXT)
	buy.add_theme_color_override("font_disabled_color", UITheme.COLOR_TEXT_DIM)
	buy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	buy.pressed.connect(func() -> void: _on_buy_pressed(id))
	hbox.add_child(buy)
	return row

func _on_buy_pressed(upgrade_id: String) -> void:
	if UpgradeManager.buy_upgrade(upgrade_id):
		refresh()

# ==================== 样式辅助 ====================

func _make_rule() -> ColorRect:
	var rule := ColorRect.new()
	rule.color = Color(UITheme.COLOR_GOLD_DARK, 0.8)
	rule.custom_minimum_size = Vector2(140, 2)
	rule.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rule

## 文本标签（统一居中；rich=true 支持 [img] 内联图标）
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
		rl.set("alignment", HorizontalAlignment.HORIZONTAL_ALIGNMENT_CENTER)  # typed enum 需 set()
		return rl
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override("outline_size", 4)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

## 升级行底（浅棕内嵌区块，奶油白面板上清晰）
func _row_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.93, 0.88, 0.80, 0.45)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(10)
	return sb

## 按钮禁用态（浅灰）
func _disabled_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.9, 0.88, 0.82, 0.8)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(10)
	return sb
