## 文件: scripts/ui/order_board.gd
## 职责: 订单队列面板——屏幕顶部集中显示所有活跃订单（菜品 + 耐心进度条 + 剩余秒数），
##       随订单创建/完成/超时实时增删（issue #26）
## 依赖: GameStateManager (autoload)；运行模式 _process 每帧刷新，测试/编辑器进程手动调 refresh()
## 注意: @tool + 编辑器进程拦截自动刷新（与 tick_patience 同模式）；面板为纯显示无副作用

@tool
extends CanvasLayer

# ==================== 常量 ====================
const BAR_WIDTH := 120.0   ## 耐心进度条宽度（像素）
const BAR_HEIGHT := 12.0
const MAX_CARDS := 6       ## 面板最大卡片数（布局队列容量 5 + 余量）

# ==================== 节点引用 ====================
var _container: HBoxContainer = null

# ==================== 状态变量 ====================
## order_id -> { panel, name_label, bar_fill, seconds_label }
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
	card["name_label"].text = dish_name

	var total: float = order["patience_total"]
	var left: float = order["patience_left"]
	var ratio := 1.0 if total <= 0.0 else clampf(left / total, 0.0, 1.0)
	var fill: ColorRect = card["bar_fill"]
	fill.size.x = BAR_WIDTH * ratio
	# 耐心颜色：>50% 绿 / >20% 黄 / 否则红（与顾客头顶一致）
	var color := Color(0.4, 0.9, 0.45)
	if ratio <= 0.5 and ratio > 0.2:
		color = Color(0.95, 0.8, 0.25)
	elif ratio <= 0.2:
		color = Color(0.95, 0.3, 0.3)
	fill.color = color
	card["seconds_label"].text = "%ds" % int(ceil(left))

## 创建一张卡片（PanelContainer > Margin > VBox: 菜名 + HBox(进度条 + 秒)）
func _create_card(order_id: int) -> Dictionary:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _card_stylebox())

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 8)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	margin.add_child(vbox)

	var name_label := Label.new()
	name_label.add_theme_font_size_override("font_size", 22)
	name_label.add_theme_color_override("font_color", Color(1, 0.92, 0.6))
	name_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	name_label.add_theme_constant_override("outline_size", 4)
	vbox.add_child(name_label)

	var bar_row := HBoxContainer.new()
	bar_row.add_theme_constant_override("separation", 6)
	vbox.add_child(bar_row)

	# 进度条：背景 + 前景填充
	var bar_bg := ColorRect.new()
	bar_bg.color = Color(0.15, 0.15, 0.15, 0.8)
	bar_bg.custom_minimum_size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	bar_bg.size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_row.add_child(bar_bg)

	var bar_fill := ColorRect.new()
	bar_fill.color = Color(0.4, 0.9, 0.45)
	bar_fill.size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	bar_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_bg.add_child(bar_fill)

	var seconds_label := Label.new()
	seconds_label.add_theme_font_size_override("font_size", 16)
	seconds_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
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
		"bar_fill": bar_fill,
		"seconds_label": seconds_label,
	}
	_cards[order_id] = card
	return card

func _remove_card(order_id: int) -> void:
	if not _cards.has(order_id):
		return
	var card: Dictionary = _cards[order_id]
	card["panel"].queue_free()
	_cards.erase(order_id)

## 统一卡片样式：半透明深色 + 圆角
func _card_stylebox() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.55)
	sb.set_corner_radius_all(10)
	sb.set_border_width_all(2)
	sb.border_color = Color(0.9, 0.85, 0.6, 0.35)
	return sb
