## 文件: scripts/ui/upgrade_shop.gd
## 职责: 设备升级商店（P5）——打烊后从日结算面板打开（暂停中可交互），用累计金币购买设备升级
##       （#48 tscn 化：静态结构移入 scenes/ui/UpgradeShop.tscn，按钮换立体纹理三态）
## 依赖: GameStateManager/UITheme/UpgradeManager (autoload)
## 注意: process_mode=ALWAYS（打烊暂停期间按钮仍可点，同日结算面板）；@tool 编辑器进程不自动刷新

@tool
extends CanvasLayer

@onready var _overlay: ColorRect = $Overlay
@onready var _panel: PanelContainer = $Overlay/CenterContainer/Panel
@onready var _money_label: RichTextLabel = $Overlay/CenterContainer/Panel/Margin/VBox/MoneyLabel
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
	# #48：购买按钮立体纹理三态
	var btn_styles := UITheme.make_button_texture_styles()
	buy.add_theme_stylebox_override("normal", btn_styles["normal"])
	buy.add_theme_stylebox_override("hover", btn_styles["hover"])
	buy.add_theme_stylebox_override("pressed", btn_styles["pressed"])
	buy.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	buy.add_theme_stylebox_override("disabled", _disabled_style())
	buy.add_theme_color_override("font_color", UITheme.COLOR_TEXT)
	buy.add_theme_color_override("font_disabled_color", UITheme.COLOR_TEXT_DIM)
	buy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	UITheme.style_button_feedback(buy)
	buy.pressed.connect(func() -> void: _on_buy_pressed(id))
	hbox.add_child(buy)
	return row

func _on_buy_pressed(upgrade_id: String) -> void:
	if UpgradeManager.buy_upgrade(upgrade_id):
		refresh()

# ==================== 样式辅助 ====================

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
