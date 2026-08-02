## 文件: scripts/ui/takeaway_board.gd
## 职责: 外卖订单面板（P4）——屏幕右侧列出外卖订单：菜品 + 骑手 ETA 进度条（红黄绿蓝时间裕度）+ 打包状态
## 依赖: GameStateManager/UITheme (autoload)；运行模式 _process 每帧刷新，测试/编辑器进程手动调 refresh()
## 注意: @tool + 编辑器进程拦截自动刷新（冒烟测试手动 refresh 断言确定性），与 order_board 同模式

@tool
extends CanvasLayer

const BAR_WIDTH := 88.0   ## ETA 进度条宽度（像素）
const BAR_HEIGHT := 12.0

var _list: VBoxContainer = null

func _ready() -> void:
	_build_panel()

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	refresh()

## 构建右侧面板（纹理九宫格 + 标题 + 订单列表）
func _build_panel() -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UITheme.make_panel_texture_style())
	panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	panel.position = Vector2(-16 - 240, 118)  # 经营面板（右上）下方
	panel.custom_minimum_size = Vector2(240, 0)
	add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)

	var title := RichTextLabel.new()
	title.bbcode_enabled = true
	title.fit_content = true
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.add_theme_font_size_override("normal_font_size", 18)
	title.add_theme_color_override("default_color", UITheme.COLOR_GOLD)
	title.text = "外卖订单"
	vbox.add_child(title)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 4)
	vbox.add_child(_list)

## 与 GameStateManager.takeaway_orders 同步重建订单行（订单最多 3 单，重建成本可忽略）
func refresh() -> void:
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	var orders: Array[Dictionary] = GameStateManager.takeaway_orders
	if orders.is_empty():
		_list.add_child(_make_label("暂无外卖订单", UITheme.COLOR_TEXT_DIM, 15))
		return
	for order in orders:
		_list.add_child(_make_row(order))

## 一行订单：菜品图标+名 / ETA 进度条（四色）/ 剩余秒 / 打包状态
func _make_row(order: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)

	var dish := RichTextLabel.new()
	dish.bbcode_enabled = true
	dish.fit_content = true
	dish.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dish.add_theme_font_size_override("normal_font_size", 16)
	dish.add_theme_color_override("default_color", UITheme.COLOR_TEXT)
	dish.text = "%s %s" % [UITheme.icon(UITheme.ICON_PLATE, 16), GameStateManager.get_dish_display_name(order["dish_type"])]
	dish.custom_minimum_size = Vector2(86, 0)
	row.add_child(dish)

	var eta: float = order["eta_left"]
	var total: float = order["eta_total"]
	var ratio := 1.0 if total <= 0.0 else clampf(eta / total, 0.0, 1.0)

	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	bar.size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	bar.max_value = 100.0
	bar.value = ratio * 100.0
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_theme_stylebox_override("background", _bar_bg_style())
	bar.add_theme_stylebox_override("fill", _bar_fill_style(_eta_color(ratio)))
	row.add_child(bar)

	var seconds := _make_label("%ds" % int(ceil(eta)), UITheme.COLOR_TEXT, 14)
	seconds.custom_minimum_size = Vector2(30, 0)
	row.add_child(seconds)

	var packed: bool = order["packed"]
	var state := _make_label("待打包" if not packed else "已打包", UITheme.COLOR_YELLOW if not packed else UITheme.COLOR_GOLD, 14)
	row.add_child(state)

	return row

## 时间裕度四色（P4）：ETA 剩余比例 >75% 蓝 / >50% 绿 / >25% 黄 / ≤25% 红
func _eta_color(ratio: float) -> Color:
	if ratio > 0.75:
		return UITheme.COLOR_BLUE
	if ratio > 0.5:
		return UITheme.COLOR_GREEN
	if ratio > 0.25:
		return UITheme.COLOR_YELLOW
	return UITheme.COLOR_RED

## 简洁富文本标签
func _make_label(text: String, color: Color, font_size: int) -> RichTextLabel:
	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = text
	label.add_theme_font_size_override("normal_font_size", font_size)
	label.add_theme_color_override("default_color", color)
	return label

func _bar_bg_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.92, 0.88, 0.82, 0.9)
	sb.set_corner_radius_all(6)
	return sb

func _bar_fill_style(color: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(6)
	return sb
