## 文件: scripts/ui/character_select.gd
## 职责: 角色选择界面（P8）——开店前（MainScene 载入且未选角色时）弹出，2 角色卡片选择
## 依赖: CharacterManager/UITheme (autoload)；选择后恢复暂停开始营业

@tool
extends CanvasLayer

var _overlay: ColorRect = null
var _list: HBoxContainer = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_panel()

func _build_panel() -> void:
	if _overlay != null and is_instance_valid(_overlay):
		return
	_overlay = ColorRect.new()
	_overlay.name = "Overlay"
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.color = Color(0, 0, 0, 0.5)
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
	panel.custom_minimum_size = Vector2(520, 0)
	center.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	# 标题 + 装饰
	vbox.add_child(_make_rule())
	vbox.add_child(_make_label("选择你的主厨", 30, UITheme.COLOR_GOLD))
	vbox.add_child(_make_label("不同主厨拥有不同技能，开店后生效", 16, UITheme.COLOR_TEXT_DIM))
	vbox.add_child(_make_rule())

	_list = HBoxContainer.new()
	_list.add_theme_constant_override("separation", 14)
	_list.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(_list)

# ==================== 展示 ====================

## 显示角色选择（未选角色时启动调用；暂停游戏直至选择）
func show_select() -> void:
	refresh()
	_overlay.visible = true
	get_tree().paused = true

func hide_select() -> void:
	_overlay.visible = false

## 刷新：全部角色卡片
func refresh() -> void:
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	for character_id: String in CharacterManager.CHARACTERS:
		_list.add_child(_make_card(character_id, CharacterManager.CHARACTERS[character_id]))

## 一张角色卡（名称/描述/技能说明 + 选择按钮）
func _make_card(character_id: String, def: Dictionary) -> Control:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _card_style())
	card.custom_minimum_size = Vector2(220, 180)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(vbox)

	var name_label := _make_label(def["name"], 24, UITheme.COLOR_TEXT)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(name_label)

	var desc := _make_label(def["desc"], 15, UITheme.COLOR_TEXT_DIM)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.custom_minimum_size = Vector2(180, 60)
	vbox.add_child(desc)

	var skill := _make_label("技能：制作时间 %d%%" % int(round(def["heat_multiplier"] * 100.0)), 16, UITheme.COLOR_GOLD)
	skill.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(skill)

	var btn := Button.new()
	btn.text = "选择"
	btn.custom_minimum_size = Vector2(120, 40)
	btn.add_theme_font_size_override("font_size", 20)
	var btn_styles := UITheme.make_button_styles()
	btn.add_theme_stylebox_override("normal", btn_styles["normal"])
	btn.add_theme_stylebox_override("hover", btn_styles["hover"])
	btn.add_theme_stylebox_override("pressed", btn_styles["pressed"])
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	btn.add_theme_color_override("font_color", UITheme.COLOR_TEXT)
	UITheme.style_button_feedback(btn)
	btn.pressed.connect(func() -> void: _on_select(character_id))
	vbox.add_child(btn)

	return card

func _on_select(character_id: String) -> void:
	if CharacterManager.select_character(character_id):
		hide_select()
		get_tree().paused = false
		# P9：开始营业播放 BGM（文件由 SunoAI 生成后生效，缺失静默）
		AudioManager.play_bgm("bgm_shop.ogg")

# ==================== 样式辅助 ====================

func _make_rule() -> ColorRect:
	var rule := ColorRect.new()
	rule.color = Color(UITheme.COLOR_GOLD_DARK, 0.8)
	rule.custom_minimum_size = Vector2(140, 2)
	rule.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rule

func _make_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.29, 0.22, 0.16, 0.85))
	label.add_theme_constant_override("outline_size", 4)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _card_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1.0, 0.97, 0.90, 0.95)
	sb.set_corner_radius_all(10)
	sb.set_border_width_all(2)
	sb.border_color = UITheme.COLOR_BORDER
	sb.set_content_margin_all(12)
	return sb
