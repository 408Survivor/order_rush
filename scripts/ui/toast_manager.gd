## 文件: scripts/ui/toast_manager.gd
## 职责: 操作反馈提示——左下角堆叠 Toast（新订单/交付成功/超时差评/加热完成），自动淡出
##       （issue #26；#30 左侧类型色带 + 图标；#48 tscn 化 + 卡片样式 + 弹入动画）
## 依赖: GameStateManager/UITheme (autoload)；容器结构在 scenes/ui/ToastManager.tscn；
##       运行模式自动监听订单信号，测试/编辑器进程手动调 show_toast()
## 注意: @tool + 编辑器进程不连接信号（测试手动触发）；纯显示无副作用

@tool
extends CanvasLayer

# ==================== 常量 ====================
const MAX_TOASTS := 3
const TOAST_DURATION := 2.2  ## 显示时长（秒）
const FADE_TIME := 0.4       ## 淡出时长（秒）

# ==================== 状态变量 ====================
## { label: Label, bg: PanelContainer }
var _toasts: Array[Dictionary] = []
@onready var _container: VBoxContainer = $Margin/List

# ==================== 生命周期 ====================

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	# 监听订单信号 → 反馈提示（命名方法 + is_connected 防热重载/多实例重复连接）
	if not GameStateManager.order_state_changed.is_connected(_on_order_state_changed):
		GameStateManager.order_state_changed.connect(_on_order_state_changed)
	if not GameStateManager.order_completed.is_connected(_on_order_completed):
		GameStateManager.order_completed.connect(_on_order_completed)
	if not GameStateManager.order_failed.is_connected(_on_order_failed):
		GameStateManager.order_failed.connect(_on_order_failed)
	# P4 外卖反馈：新订单 / 骑手取餐 / 超时罚款
	if not GameStateManager.takeaway_created.is_connected(_on_takeaway_created):
		GameStateManager.takeaway_created.connect(_on_takeaway_created)
	if not GameStateManager.takeaway_completed.is_connected(_on_takeaway_completed):
		GameStateManager.takeaway_completed.connect(_on_takeaway_completed)
	if not GameStateManager.takeaway_failed.is_connected(_on_takeaway_failed):
		GameStateManager.takeaway_failed.connect(_on_takeaway_failed)
	# P7 特殊事件提示（设备故障/恶劣天气）
	if not GameStateManager.event_started.is_connected(_on_event_started):
		GameStateManager.event_started.connect(_on_event_started)
	# #83 店铺升星反馈
	if not GameStateManager.shop_star_upgraded.is_connected(_on_shop_star_upgraded):
		GameStateManager.shop_star_upgraded.connect(_on_shop_star_upgraded)

## #83：升星 Toast（金色，多停留 1s 强化里程碑感）
func _on_shop_star_upgraded(new_star: int) -> void:
	show_toast("%s 店铺升星！当前 %d 星" % [UITheme.icon(UITheme.ICON_STAR), new_star], UITheme.COLOR_GOLD, TOAST_DURATION + 1.0)

func _on_order_completed(order_id: int, revenue: int) -> void:
	show_toast("%s 交付成功  +%d" % [UITheme.icon(UITheme.ICON_CHECK), revenue], UITheme.COLOR_GREEN)

func _on_order_failed(order_id: int) -> void:
	show_toast("%s 订单超时！差评 -1" % UITheme.icon(UITheme.ICON_CROSS), UITheme.COLOR_RED)

# ==================== Toast API ====================

## 显示一条提示（测试/编辑器进程可手动调用）
## #30: 左侧类型色带（color 指示）+ 文字描边；icon 由调用方拼入文本
func show_toast(text: String, color: Color = Color.WHITE, duration: float = TOAST_DURATION) -> void:
	var bg := PanelContainer.new()
	bg.add_theme_stylebox_override("panel", _toast_stylebox())
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	bg.add_child(row)

	# 左侧类型色带（竖条，类型色）
	var stripe := ColorRect.new()
	stripe.color = color
	stripe.custom_minimum_size = Vector2(5, 0)
	stripe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(stripe)

	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	# #56：关闭自动换行——容器内 fit_content 最小宽度塌缩为 1 字宽会把文本竖排成虚线状高条
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = text
	label.add_theme_font_size_override("normal_font_size", 20)
	label.add_theme_color_override("default_color", color)
	label.add_theme_color_override("outline_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("outline_size", 5)
	row.add_child(label)
	_container.add_child(bg)

	# #48：弹入动画（运行模式：0.8→1 回弹；编辑器进程跳过保证断言确定性）
	if not Engine.is_editor_hint():
		bg.pivot_offset = bg.size / 2.0
		bg.scale = Vector2(0.8, 0.8)
		var pop := create_tween()
		pop.tween_property(bg, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	var entry := {"bg": bg, "label": label, "fade": false}
	_toasts.append(entry)
	# 超出上限：移除最旧
	while _toasts.size() > MAX_TOASTS:
		_destroy_toast(_toasts[0])
	# 倒计时后淡出
	var timer := get_tree().create_timer(duration)
	timer.timeout.connect(func() -> void: _begin_fade(entry))

## 新订单反馈（PENDING 状态创建时；订单 id 从信号参数读取，避免依赖 append 顺序）
func _on_order_state_changed(order_id: int, new_state: int) -> void:
	if new_state != GameStateManager.OrderState.PENDING:
		return
	var order := GameStateManager.get_order(order_id)
	if order.is_empty():
		return
	show_toast("%s 新订单：%s" % [UITheme.icon(UITheme.ICON_ORDER), GameStateManager.get_dish_display_name(str(order["dish_type"]))], UITheme.COLOR_BLUE)

## P4 外卖反馈：新外卖订单（骑手已接单，注意打包）
func _on_takeaway_created(order_id: int) -> void:
	var order := GameStateManager.get_takeaway(order_id)
	if order.is_empty():
		return
	show_toast("%s 新外卖：%s 骑手 %.0fs 后到" % [UITheme.icon(UITheme.ICON_ORDER), GameStateManager.get_dish_display_name(str(order["dish_type"])), order["eta_total"]], UITheme.COLOR_BLUE)

## P4 外卖反馈：骑手取餐成功
func _on_takeaway_completed(_order_id: int, revenue: int) -> void:
	show_toast("%s 骑手取餐 +%d" % [UITheme.icon(UITheme.ICON_CHECK), revenue], UITheme.COLOR_GREEN)

## P4 外卖反馈：超时罚款
func _on_takeaway_failed(_order_id: int) -> void:
	show_toast("%s 外卖超时！罚款 %d" % [UITheme.icon(UITheme.ICON_CROSS), GameStateManager.TAKEOUT_FAIL_PENALTY], UITheme.COLOR_RED)

## P7 特殊事件提示（设备故障 / 恶劣天气；#82 主厨慌乱——心率爆表危机）
func _on_event_started(event_type: int) -> void:
	if event_type == GameStateManager.SpecialEvent.EQUIPMENT_BREAK:
		show_toast("⚠ 设备故障！微波炉停用 8s", UITheme.COLOR_RED)
	elif event_type == GameStateManager.SpecialEvent.BAD_WEATHER:
		show_toast("⚠ 恶劣天气！外卖暂停 15s", UITheme.COLOR_YELLOW)
	elif event_type == GameStateManager.SpecialEvent.CHEF_PANIC:
		show_toast("%s 心率爆表！主厨慌乱：加热 ×%.1f（%.0fs）" % [
			UITheme.icon(UITheme.ICON_HEART),
			GameStateManager.STRESS_CRISIS_HEAT_MULTIPLIER,
			GameStateManager.EVENT_DURATION[GameStateManager.SpecialEvent.CHEF_PANIC]], UITheme.COLOR_RED)

## 淡出并移除（防御：节点可能已被超限移除提前释放）
func _begin_fade(entry: Dictionary) -> void:
	if entry["fade"] or not is_instance_valid(entry["bg"]):
		return
	entry["fade"] = true
	var bg: PanelContainer = entry["bg"]
	var tween := create_tween()
	tween.tween_property(bg, "modulate:a", 0.0, FADE_TIME)
	tween.tween_callback(func() -> void: _destroy_toast(entry))

func _destroy_toast(entry: Dictionary) -> void:
	if is_instance_valid(entry["bg"]):
		entry["bg"].queue_free()
	_toasts.erase(entry)

## 统一 Toast 样式：紧凑卡片纹理（#48 九宫格卡片，取代通用面板纹理）
func _toast_stylebox() -> StyleBoxTexture:
	return UITheme.make_card_style()
