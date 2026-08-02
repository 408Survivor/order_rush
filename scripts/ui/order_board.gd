## 文件: scripts/ui/order_board.gd
## 职责: 订单队列面板——屏幕顶部集中显示所有活跃订单（菜品 + 耐心进度条 + 剩余秒数），
##       随订单创建/完成/超时实时增删（issue #26；#30 升级：卡片质感/ProgressBar/增删动画）
## 依赖: GameStateManager/UITheme (autoload)；运行模式 _process 每帧刷新，测试/编辑器进程手动调 refresh()
## 注意: @tool + 编辑器进程拦截自动刷新与动画（冒烟测试手动 refresh 断言确定性）；
##       _cards 结构 { panel, name_label, bar_fill(ProgressBar), seconds_label, bar_color }

@tool
extends CanvasLayer

# ==================== 常量 ====================
const BAR_WIDTH := 120.0   ## 耐心进度条宽度（像素）
const BAR_HEIGHT := 14.0
const MAX_CARDS := 6       ## 面板最大卡片数（布局队列容量 5 + 余量）
const CARD_WIDTH := 170.0  ## 卡片最小宽度（#30 统一）

# ==================== 节点引用 ====================
var _container: HBoxContainer = null

# ==================== 状态变量 ====================
## order_id -> { panel, name_label, bar_fill, seconds_label, bar_color }
var _cards: Dictionary = {}

# ==================== 生命周期 ====================

func _ready() -> void:
	_build_container()

func _process(_delta: float) -> void:
	# @tool：编辑器进程不自动刷新（冒烟测试手动调 refresh()）
	if Engine.is_editor_hint():
		return
	refresh()

# ==================== 面板构建 ====================

func _build_container() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_TOP_WIDE)
	margin.offset_top = 12.0
	margin.offset_bottom = 100.0
	margin.offset_left = 16.0
	margin.offset_right = -16.0
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)

	_container = HBoxContainer.new()
	_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_container.add_theme_constant_override("separation", 12)
	margin.add_child(_container)

# ==================== 刷新 ====================

## 同步卡片与 GameStateManager.active_orders（创建/更新/删除）
## 编辑器进程（冒烟测试）可手动调用
func refresh() -> void:
	var orders: Array[Dictionary] = GameStateManager.active_orders
	# 1) 移除已不在活跃列表的卡片（订单完成/超时）
	var active_ids := {}
	for order in orders:
		active_ids[order["id"]] = true
	for order_id in _cards.keys():
		if not active_ids.has(order_id):
			_remove_card(order_id)
	# 2) 更新/创建
	for order in orders:
		_update_card(order)

## 创建或更新一张订单卡片
func _update_card(order: Dictionary) -> void:
	var order_id: int = order["id"]
	var card: Dictionary
	if not _cards.has(order_id):
		card = _create_card(order_id)
	else:
		card = _cards[order_id]

	var dish_name: String = GameStateManager.get_dish_display_name(str(order["dish_type"]))
	card["name_label"].text = "%s %s" % [UITheme.icon(UITheme.ICON_PLATE), dish_name]

	var total: float = order["patience_total"]
	var left: float = order["patience_left"]
	var ratio := 1.0 if total <= 0.0 else clampf(left / total, 0.0, 1.0)
	var bar: ProgressBar = card["bar_fill"]
	bar.value = ratio * 100.0
	# 耐心颜色：>50% 绿 / >20% 黄 / 否则红（与顾客头顶一致）
	var color := UITheme.COLOR_GREEN
	if ratio <= 0.5 and ratio > 0.2:
		color = UITheme.COLOR_YELLOW
	elif ratio <= 0.2:
		color = UITheme.COLOR_RED
	if card["bar_color"] != color:
		card["bar_color"] = color
		bar.add_theme_stylebox_override("fill", _bar_fill_style(color))
	card["seconds_label"].text = "%ds" % int(ceil(left))

## 创建一张卡片（PanelContainer > Margin > VBox: 菜名 + HBox(进度条 + 秒)）
func _create_card(order_id: int) -> Dictionary:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UITheme.make_panel_style(10, UITheme.COLOR_PANEL, Color(0.9, 0.85, 0.6, 0.4)))
	panel.custom_minimum_size = Vector2(CARD_WIDTH, 0)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 8)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	margin.add_child(vbox)

	var name_label := RichTextLabel.new()
	name_label.bbcode_enabled = true
	name_label.fit_content = true
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.add_theme_font_size_override("normal_font_size", 22)
	name_label.add_theme_color_override("default_color", UITheme.COLOR_GOLD)
	name_label.add_theme_color_override("outline_color", Color(0, 0, 0, 0.8))
	name_label.add_theme_constant_override("outline_size", 4)
	vbox.add_child(name_label)

	var bar_row := HBoxContainer.new()
	bar_row.add_theme_constant_override("separation", 6)
	vbox.add_child(bar_row)

	# #30：ColorRect → ProgressBar（圆角轨道 + 填充，耐心三色）
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	bar.size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	bar.max_value = 100.0
	bar.value = 100.0
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_theme_stylebox_override("background", _bar_bg_style())
	bar.add_theme_stylebox_override("fill", _bar_fill_style(UITheme.COLOR_GREEN))
	bar_row.add_child(bar)

	var seconds_label := Label.new()
	seconds_label.add_theme_font_size_override("font_size", 16)
	seconds_label.add_theme_color_override("font_color", UITheme.COLOR_TEXT)
	seconds_label.custom_minimum_size = Vector2(44, 0)
	bar_row.add_child(seconds_label)

	if _cards.size() < MAX_CARDS:
		_container.add_child(panel)
	else:
		# 超出上限：不显示但仍记录（防御）
		panel.visible = false
		_container.add_child(panel)

	var card := {
		"panel": panel,
		"name_label": name_label,
		"bar_fill": bar,
		"seconds_label": seconds_label,
		"bar_color": UITheme.COLOR_GREEN,
	}
	_cards[order_id] = card
	# #30：新卡片弹入动画（运行模式）
	if not Engine.is_editor_hint():
		panel.pivot_offset = panel.size / 2.0
		panel.scale = Vector2(0.8, 0.8)
		panel.modulate.a = 0.0
		var tween := create_tween()
		tween.tween_property(panel, "scale", Vector2.ONE, 0.18)
		tween.parallel().tween_property(panel, "modulate:a", 1.0, 0.18)
	return card

## 移除卡片（运行模式先淡出再释放；编辑器进程直接释放保证断言确定性）
func _remove_card(order_id: int) -> void:
	if not _cards.has(order_id):
		return
	var card: Dictionary = _cards[order_id]
	_cards.erase(order_id)
	var panel: PanelContainer = card["panel"]
	if Engine.is_editor_hint():
		panel.queue_free()
		return
	var tween := create_tween()
	tween.tween_property(panel, "modulate:a", 0.0, 0.15)
	tween.tween_callback(func() -> void:
		if is_instance_valid(panel):
			panel.queue_free()
	)

# ==================== 样式 ====================

## 进度条轨道样式（暖深棕圆角）
func _bar_bg_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.13, 0.10, 0.07, 0.9)
	sb.set_corner_radius_all(7)
	return sb

## 进度条填充样式（耐心三色，圆角）
func _bar_fill_style(color: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(7)
	return sb
