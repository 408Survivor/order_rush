## 文件: scripts/ui/toast_manager.gd
## 职责: 操作反馈提示——左下角堆叠 Toast（新订单/交付成功/超时差评/加热完成），自动淡出（issue #26）
## 依赖: GameStateManager (autoload)；运行模式自动监听订单信号，测试/编辑器进程手动调 show_toast()
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
var _container: VBoxContainer = null

# ==================== 生命周期 ====================

func _ready() -> void:
	_build_container()
	if Engine.is_editor_hint():
		return
	# 监听订单信号 → 反馈提示（命名方法 + is_connected 防热重载/多实例重复连接）
	if not GameStateManager.order_state_changed.is_connected(_on_order_state_changed):
		GameStateManager.order_state_changed.connect(_on_order_state_changed)
	if not GameStateManager.order_completed.is_connected(_on_order_completed):
		GameStateManager.order_completed.connect(_on_order_completed)
	if not GameStateManager.order_failed.is_connected(_on_order_failed):
		GameStateManager.order_failed.connect(_on_order_failed)

func _on_order_completed(order_id: int, revenue: int) -> void:
	show_toast("交付成功  +%d" % revenue, Color(0.45, 1.0, 0.55))

func _on_order_failed(order_id: int) -> void:
	show_toast("订单超时！差评 -1", Color(1.0, 0.4, 0.4))

func _build_container() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	margin.offset_left = 16.0
	margin.offset_bottom = -16.0
	margin.offset_top = -140.0
	margin.offset_right = 360.0
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)

	_container = VBoxContainer.new()
	_container.add_theme_constant_override("separation", 6)
	margin.add_child(_container)

# ==================== Toast API ====================

## 显示一条提示（测试/编辑器进程可手动调用）
func show_toast(text: String, color: Color = Color.WHITE, duration: float = TOAST_DURATION) -> void:
	var bg := PanelContainer.new()
	bg.add_theme_stylebox_override("panel", _toast_stylebox())
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("outline_size", 5)
	bg.add_child(label)
	_container.add_child(bg)

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
	show_toast("新订单：%s" % GameStateManager.get_dish_display_name(str(order["dish_type"])), Color(0.55, 0.85, 1.0))

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

## 统一 Toast 样式：半透明深色 + 圆角
func _toast_stylebox() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.6)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(10)
	return sb
