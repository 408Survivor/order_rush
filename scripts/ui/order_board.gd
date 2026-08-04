## 文件: scripts/ui/order_board.gd
## 职责: 订单队列面板——屏幕顶部集中显示所有活跃订单（菜品图标 + 菜名 + 耐心进度条 + 剩余秒数 + 耐心表情），
##       随订单创建/完成/超时实时增删（issue #26；#30 卡片质感/ProgressBar/增删动画；#48 tscn 化 + 菜品/表情图标）
## 依赖: GameStateManager/UITheme (autoload)；容器结构在 scenes/ui/OrderBoard.tscn，
##       卡片实例化 scenes/ui/OrderCard.tscn；运行模式 _process 每帧刷新，测试/编辑器进程手动调 refresh()
## 注意: @tool + 编辑器进程拦截自动刷新与动画（冒烟测试手动 refresh 断言确定性）；
##       _cards 结构 { panel, name_label, bar_fill(ProgressBar), seconds_label, bar_color(颜色名字符串),
##                     dish_icon, mood_icon, dish_type, mood_path, pulse_tween }
## #48: bar_color 键改为颜色名字符串 "green"/"yellow"/"red"（原 Color）；低耐心（≤20%）卡片红色调脉冲（运行模式）

@tool
extends CanvasLayer

# ==================== 常量 ====================
const MAX_CARDS := 6  ## 面板最大卡片数（布局队列容量 5 + 余量）

## 订单卡片场景（#48：静态结构 tscn 化，脚本只绑定节点与刷新数据）
const ORDER_CARD_SCENE := preload("res://scenes/ui/OrderCard.tscn")

# ==================== 节点引用 ====================
@onready var _container: HBoxContainer = $Margin/Cards

# ==================== 状态变量 ====================
## order_id -> { panel, name_label, bar_fill, seconds_label, bar_color, dish_icon, mood_icon, dish_type, mood_path, pulse_tween }
var _cards: Dictionary = {}

# ==================== 生命周期 ====================

func _process(_delta: float) -> void:
	# @tool：编辑器进程不自动刷新（冒烟测试手动调 refresh()）
	if Engine.is_editor_hint():
		return
	refresh()

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

	# #48：菜名纯文本（图标独立为 DishIcon 贴纸，仅菜品变化时重设纹理）
	var dish_type := str(order["dish_type"])
	card["name_label"].text = GameStateManager.get_dish_display_name(dish_type)
	if card["dish_type"] != dish_type:
		card["dish_type"] = dish_type
		card["dish_icon"].texture = load(UITheme.dish_icon_path(dish_type))

	var total: float = order["patience_total"]
	var left: float = order["patience_left"]
	var ratio := 1.0 if total <= 0.0 else clampf(left / total, 0.0, 1.0)
	var bar: ProgressBar = card["bar_fill"]
	bar.value = ratio * 100.0
	# 耐心颜色：>50% 绿 / >20% 黄 / 否则红（与顾客头顶一致）；#48 存颜色名，仅变化时重设填充纹理
	var color_name := "green"
	if ratio <= 0.5 and ratio > 0.2:
		color_name = "yellow"
	elif ratio <= 0.2:
		color_name = "red"
	if card["bar_color"] != color_name:
		card["bar_color"] = color_name
		bar.add_theme_stylebox_override("fill", UITheme.make_bar_fill_style(color_name))
	# #48：耐心表情图标（仅档位变化时重设纹理）
	var mood_path := UITheme.mood_icon_path(ratio)
	if card["mood_path"] != mood_path:
		card["mood_path"] = mood_path
		card["mood_icon"].texture = load(mood_path)
	card["seconds_label"].text = "%ds" % int(ceil(left))
	# #48：低耐心警示——卡片红色调脉冲（运行模式 tween 循环；编辑器进程跳过保证断言确定性）
	_update_low_patience_pulse(card, ratio <= 0.2)

## 实例化一张卡片（OrderCard.tscn）并绑定节点引用
func _create_card(order_id: int) -> Dictionary:
	var panel: PanelContainer = ORDER_CARD_SCENE.instantiate()
	# #48：卡片样式（紧凑圆角卡片纹理，脚本设置与旧版一致）
	panel.add_theme_stylebox_override("panel", UITheme.make_card_style())

	var name_label: RichTextLabel = panel.get_node("Margin/HBox/Right/TopRow/NameLabel")
	var dish_icon: TextureRect = panel.get_node("Margin/HBox/DishIcon")
	var bar: ProgressBar = panel.get_node("Margin/HBox/Right/BottomRow/Bar")
	var seconds_label: Label = panel.get_node("Margin/HBox/Right/BottomRow/SecondsLabel")
	var mood_icon: TextureRect = panel.get_node("Margin/HBox/Right/BottomRow/MoodIcon")
	# #48：进度条轨道纹理（填充色随耐心三色切换，见 _update_card）
	bar.add_theme_stylebox_override("background", UITheme.make_bar_bg_style())
	bar.add_theme_stylebox_override("fill", UITheme.make_bar_fill_style("green"))

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
		"bar_color": "green",
		"dish_icon": dish_icon,
		"mood_icon": mood_icon,
		"dish_type": "",
		"mood_path": "",
		"pulse_tween": null,
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
	if card["pulse_tween"] != null:
		card["pulse_tween"].kill()
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

## 低耐心红色调脉冲（#48）：≤20% 启动循环脉冲，恢复时复位 modulate
func _update_low_patience_pulse(card: Dictionary, low: bool) -> void:
	if Engine.is_editor_hint():
		return
	var panel: PanelContainer = card["panel"]
	if low and card["pulse_tween"] == null:
		var tween := create_tween().set_loops()
		tween.tween_property(panel, "modulate", Color(1.0, 0.55, 0.55), 0.4)
		tween.tween_property(panel, "modulate", Color.WHITE, 0.4)
		card["pulse_tween"] = tween
	elif not low and card["pulse_tween"] != null:
		card["pulse_tween"].kill()
		card["pulse_tween"] = null
		panel.modulate = Color.WHITE
