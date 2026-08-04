## 文件: scripts/ui/card_draw.gd
## 职责: 卡牌抽卡界面（P6）——打烊后 3 选 1 抽卡（消耗口碑），选中卡入构筑影响次日经营
##       （#48 tscn 化：静态结构移入 scenes/ui/CardDraw.tscn，返回按钮换立体纹理三态）
## 依赖: GameStateManager/UITheme/CardManager (autoload)
## 注意: process_mode=ALWAYS（打烊暂停期间可交互，同升级商店）；@tool 编辑器进程不自动刷新

@tool
extends CanvasLayer

@onready var _overlay: ColorRect = $Overlay
@onready var _panel: PanelContainer = $Overlay/CenterContainer/Panel
@onready var _reputation_label: RichTextLabel = $Overlay/CenterContainer/Panel/Margin/VBox/ReputationLabel
@onready var _cards_row: HBoxContainer = $Overlay/CenterContainer/Panel/Margin/VBox/CardsRow
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

func show_draw() -> void:
	refresh()
	_overlay.visible = true

func hide_draw() -> void:
	_overlay.visible = false

func _on_back_pressed() -> void:
	hide_draw()

## 刷新：口碑行 + 3 张候选卡
func refresh() -> void:
	_reputation_label.text = "%s 口碑：%d（抽卡消耗 %d）" % [UITheme.icon(UITheme.ICON_GOOD), CardManager.get_reputation(), CardManager.REPUTATION_COST_PER_DRAW]
	for child in _cards_row.get_children():
		_cards_row.remove_child(child)
		child.queue_free()
	for card_id: String in CardManager.draw_offer():
		_cards_row.add_child(_make_card(card_id, CardManager.CARDS[card_id]))

## 一张候选卡（名称/描述/口碑成本；点击抽卡）
func _make_card(card_id: String, def: Dictionary) -> Control:
	var can_afford := CardManager.get_reputation() >= CardManager.REPUTATION_COST_PER_DRAW
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _card_style(can_afford))
	card.custom_minimum_size = Vector2(150, 170)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	if can_afford:
		card.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				_on_card_pressed(card_id)
		)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(vbox)

	var name_label := _make_label(def["name"], 22, UITheme.COLOR_GOLD)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(name_label)

	var desc := _make_label(def["desc"], 16, UITheme.COLOR_TEXT)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.custom_minimum_size = Vector2(130, 60)
	vbox.add_child(desc)

	var cost := _make_label("%s %d" % [UITheme.icon(UITheme.ICON_GOOD, 16), CardManager.REPUTATION_COST_PER_DRAW], 16, UITheme.COLOR_YELLOW if can_afford else UITheme.COLOR_TEXT_DIM, true)
	cost.alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(cost)

	return card

func _on_card_pressed(card_id: String) -> void:
	if CardManager.pick_card(card_id):
		hide_draw()

# ==================== 样式辅助 ====================

## 文本标签（rich=true 支持 [img] 内联图标；居中由调用处设置）
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

## 卡片底（可抽奶油白+深金描边 / 口碑不足浅灰）
func _card_style(affordable: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1.0, 0.97, 0.90, 0.95) if affordable else Color(0.9, 0.88, 0.82, 0.7)
	sb.set_corner_radius_all(10)
	sb.set_border_width_all(2)
	sb.border_color = UITheme.COLOR_GOLD if affordable else Color(0.6, 0.55, 0.45, 0.6)
	sb.set_content_margin_all(10)
	return sb
