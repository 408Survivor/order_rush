## 文件: scripts/ui/floating_feedback.gd
## 职责: 反馈层（#67）——世界坐标飘字（+N 金色收入 / 红色差评罚款）+ 金币飞向经营面板动画
## 依赖: GameStateManager/UITheme (autoload)；由 main_scene 动态实例化为 FloatingFeedback（CanvasLayer）
## 注意: @tool + 编辑器进程（冒烟测试）不连接信号/不跑 tween，手动调 show_gain/show_penalty 断言子节点；
##       飘字在屏幕空间渲染（世界坐标经 canvas_transform 换算；相机锁定全店可见，无跟拍滚动）

@tool
extends CanvasLayer

# ==================== 常量 ====================
const FLOAT_DISTANCE := 70.0     ## 飘字上移距离（px）
const FLOAT_DURATION := 0.9      ## 飘字总时长（秒）
const COIN_FLY_TIME := 0.65      ## 金币飞行时长（秒）
const COIN_COUNT := 3            ## 每次结算飞出的金币数
const FONT_SIZE := 30

# ==================== 生命周期 ====================

func _ready() -> void:
	layer = 8  # 低于 InteractionPrompt(10)，高于场景与 HUD 面板
	if Engine.is_editor_hint():
		return
	# 监听结算信号（命名方法 + is_connected 防热重载/多实例重复连接）
	if not GameStateManager.order_completed.is_connected(_on_order_completed):
		GameStateManager.order_completed.connect(_on_order_completed)
	if not GameStateManager.order_failed.is_connected(_on_order_failed):
		GameStateManager.order_failed.connect(_on_order_failed)
	if not GameStateManager.takeaway_completed.is_connected(_on_takeaway_completed):
		GameStateManager.takeaway_completed.connect(_on_takeaway_completed)
	if not GameStateManager.takeaway_failed.is_connected(_on_takeaway_failed):
		GameStateManager.takeaway_failed.connect(_on_takeaway_failed)

# ==================== 信号处理 ====================

func _on_order_completed(order_id: int, revenue: int) -> void:
	show_gain(_resolve_customer_pos(order_id), revenue)

func _on_order_failed(order_id: int) -> void:
	show_penalty(_resolve_customer_pos(order_id), "差评")

func _on_takeaway_completed(_order_id: int, revenue: int) -> void:
	show_gain(_resolve_takeout_pos(), revenue)

func _on_takeaway_failed(_order_id: int) -> void:
	show_penalty(_resolve_takeout_pos(), "-%d" % GameStateManager.TAKEOUT_FAIL_PENALTY)

# ==================== 位置解析 ====================

## 按订单 id 找持有该订单的顾客位置；找不到（已离店/已解绑）回退到柜台点
func _resolve_customer_pos(order_id: int) -> Vector2:
	var scene := get_tree().current_scene
	if scene != null and scene.has_node("CustomerManager"):
		for customer in scene.get_node("CustomerManager").get_children():
			if customer.is_in_group("customer") and customer.get("order_id") == order_id:
				return customer.global_position
	if scene != null and scene.has_node("CounterPoint"):
		return scene.get_node("CounterPoint").global_position
	return Vector2(960, 520)

## 外卖口位置（回退 LayoutManager.PICKUP_POINT）
func _resolve_takeout_pos() -> Vector2:
	var scene := get_tree().current_scene
	if scene != null and scene.has_node("TakeoutCounter"):
		return scene.get_node("TakeoutCounter").global_position
	return LayoutManager.PICKUP_POINT

# ==================== 飘字 / 金币 API（测试可直接调用） ====================

## 收入反馈：金色 +N 飘字 + 金币飞向经营面板
func show_gain(world_pos: Vector2, amount: int) -> void:
	_spawn_float_text(world_pos, "+%d" % amount, UITheme.COLOR_GOLD)
	_spawn_coin_flight(world_pos)

## 负反馈：红色文字飘字（差评 / -N 罚款）
func show_penalty(world_pos: Vector2, text: String) -> void:
	_spawn_float_text(world_pos, text, UITheme.COLOR_RED)

# ==================== 内部实现 ====================

func _world_to_screen(world_pos: Vector2) -> Vector2:
	return get_viewport().canvas_transform * world_pos

## 生成飘字 Label（编辑器进程：静止生成不跑动画，供冒烟断言）
func _spawn_float_text(world_pos: Vector2, text: String, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", FONT_SIZE)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("outline_size", 6)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	var screen_pos := _world_to_screen(world_pos) + Vector2(-label.size.x / 2.0 if label.size.x > 0 else -20, -110)
	label.position = screen_pos
	if Engine.is_editor_hint():
		return label
	# 弹入 → 上移 → 淡出
	label.pivot_offset = label.size / 2.0
	label.scale = Vector2(0.5, 0.5)
	var tween := create_tween()
	tween.tween_property(label, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(label, "position:y", screen_pos.y - FLOAT_DISTANCE, FLOAT_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.3)
	tween.tween_callback(label.queue_free)
	return label

## 金币从事件点飞向经营面板（右上角 RevenueHUD；编辑器进程跳过）
func _spawn_coin_flight(world_pos: Vector2) -> void:
	if Engine.is_editor_hint():
		return
	var start := _world_to_screen(world_pos)
	var target := _hud_target_pos()
	var coin_tex: Texture2D = load(UITheme.ICON_COIN)
	for i in COIN_COUNT:
		var coin := TextureRect.new()
		coin.texture = coin_tex
		coin.custom_minimum_size = Vector2(30, 30)
		coin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(coin)
		coin.position = start + Vector2(randf_range(-24, 24), randf_range(-24, 24))
		coin.modulate.a = 0.0
		var delay := i * 0.09
		var tween := create_tween()
		tween.tween_property(coin, "modulate:a", 1.0, 0.1).set_delay(delay)
		tween.parallel().tween_property(coin, "position", target, COIN_FLY_TIME).set_delay(delay + 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tween.parallel().tween_property(coin, "scale", Vector2(0.4, 0.4), COIN_FLY_TIME).set_delay(delay + 0.08)
		tween.tween_callback(coin.queue_free)

## 经营面板屏幕坐标（RevenueHUD 面板中心；回退右上角估算位）
func _hud_target_pos() -> Vector2:
	var scene := get_tree().current_scene
	if scene != null and scene.has_node("RevenueHUD/Panel"):
		var panel: Control = scene.get_node("RevenueHUD/Panel")
		return panel.get_global_rect().get_center()
	return Vector2(1700, 60)
