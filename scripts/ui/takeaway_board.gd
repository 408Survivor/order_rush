## 文件: scripts/ui/takeaway_board.gd
## 职责: 外卖订单面板（P4）——屏幕右侧列出外卖订单：菜品图标 + 骑手 ETA 进度条（红黄绿蓝时间裕度）+ 打包状态
##       （#48 tscn 化：静态面板结构移入 scenes/ui/TakeawayBoard.tscn，菜品/打包图标 + bar 纹理）
## 依赖: GameStateManager/UITheme (autoload)；运行模式 _process 每帧刷新，测试/编辑器进程手动调 refresh()
## 注意: @tool + 编辑器进程拦截自动刷新（冒烟测试手动 refresh 断言确定性），与 order_board 同模式；
##       _list 绑定 tscn 的 Panel/Margin/VBox/List（变量名保留，冒烟测试依赖）

@tool
extends CanvasLayer

# ==================== 节点引用 ====================
@onready var _panel: PanelContainer = $Panel
@onready var _list: VBoxContainer = $Panel/Margin/VBox/List

func _ready() -> void:
	# 纹理九宫格面板样式（@tool 下同样生效，纯视觉无副作用）
	_panel.add_theme_stylebox_override("panel", UITheme.make_panel_texture_style())

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	refresh()

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
	# #48：菜品贴纸图标（替换原通用餐盘）
	dish.text = "%s %s" % [UITheme.icon(UITheme.dish_icon_path(str(order["dish_type"])), 20), GameStateManager.get_dish_display_name(str(order["dish_type"]))]
	dish.custom_minimum_size = Vector2(86, 0)
	row.add_child(dish)

	var eta: float = order["eta_left"]
	var total: float = order["eta_total"]
	var ratio := 1.0 if total <= 0.0 else clampf(eta / total, 0.0, 1.0)

	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(88, 12)
	bar.max_value = 100.0
	bar.value = ratio * 100.0
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# #48：bar 纹理（轨道 + 四色高光填充）
	bar.add_theme_stylebox_override("background", UITheme.make_bar_bg_style())
	bar.add_theme_stylebox_override("fill", UITheme.make_bar_fill_style(_eta_color(ratio)))
	row.add_child(bar)

	var seconds := _make_label("%ds" % int(ceil(eta)), UITheme.COLOR_TEXT, 14)
	seconds.custom_minimum_size = Vector2(30, 0)
	row.add_child(seconds)

	var packed: bool = order["packed"]
	# #48：打包状态前内联打包图标
	var state_text := "%s %s" % [UITheme.icon(UITheme.ICON_PACK, 14), "已打包" if packed else "待打包"]
	var state := _make_label(state_text, UITheme.COLOR_GOLD if packed else UITheme.COLOR_YELLOW, 14)
	row.add_child(state)

	return row

## 时间裕度四色（P4）：ETA 剩余比例 >75% 蓝 / >50% 绿 / >25% 黄 / ≤25% 红（#48 返回颜色名供 bar 纹理）
func _eta_color(ratio: float) -> String:
	if ratio > 0.75:
		return "blue"
	if ratio > 0.5:
		return "green"
	if ratio > 0.25:
		return "yellow"
	return "red"

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
