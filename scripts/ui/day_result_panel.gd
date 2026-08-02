## 文件: scripts/ui/day_result_panel.gd
## 职责: 日结算面板——打烊后居中显示当日收入/成本明细/利润/评分/累计金币，按钮进入下一天（P3）
## 依赖: GameStateManager (autoload)；运行模式监听 shop_closed 自动弹出并暂停游戏
## 注意: 结构全代码构建（DayResultPanel(CanvasLayer) > Overlay(ColorRect) > Center > Panel > Margin > VBox）
##       @tool：编辑器进程（冒烟测试）不连接信号/不暂停，手动 show_result() 断言文本（项目统一约定）
## P3: 暂停恢复由本面板负责（close_shop 不暂停，见 GameStateManager.close_shop 注释——编辑器进程安全）

@tool
extends CanvasLayer

# ==================== 节点引用 ====================
var _overlay: ColorRect = null
var _title_label: Label = null
var _revenue_label: Label = null
var _cost_labels: Dictionary = {}   # key -> Label（食材/耗材/水电/房租）
var _cost_total_label: Label = null
var _profit_label: Label = null
var _review_label: Label = null
var _money_label: Label = null
var _next_day_button: Button = null

# ==================== 生命周期 ====================

func _ready() -> void:
	_build_panel()
	if Engine.is_editor_hint():
		return
	# 防重复连接（热重载/多实例 _ready）
	if not GameStateManager.shop_closed.is_connected(_on_shop_closed):
		GameStateManager.shop_closed.connect(_on_shop_closed)

## 打烊 → 弹出结算面板并暂停游戏（运行模式）
func _on_shop_closed(result: Dictionary) -> void:
	show_result(result)
	get_tree().paused = true

# ==================== 面板构建 ====================

func _build_panel() -> void:
	# @tool 热重载幂等：变量在热重载时保留，已构建过则跳过（对比 main_scene._build_zones 的 has_node 防护）
	if _overlay != null and is_instance_valid(_overlay):
		return
	# 全屏半透明遮罩（拦截点击，防止结算时操作场景）
	_overlay = ColorRect.new()
	_overlay.name = "Overlay"
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.color = Color(0, 0, 0, 0.55)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.visible = false
	add_child(_overlay)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_stylebox())
	center.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(vbox)

	_title_label = _make_label("", 40, Color(1, 0.92, 0.55))
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_title_label)

	# 分隔线
	var divider := HSeparator.new()
	vbox.add_child(divider)

	_revenue_label = _make_label("总收入：0", 24, Color(1, 0.9, 0.4))
	_revenue_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_revenue_label)

	# 成本明细（4 行）
	var cost_specs := [
		["cost_ingredients", "食材成本"],
		["cost_consumables", "耗材成本"],
		["cost_utilities", "水电成本"],
		["cost_rent", "房租"],
	]
	for spec in cost_specs:
		var label := _make_label("", 20, Color(1, 1, 1, 0.9))
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(label)
		_cost_labels[spec[0]] = label

	_cost_total_label = _make_label("成本合计：0", 22, Color(1, 0.85, 0.7))
	_cost_total_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_cost_total_label)

	_profit_label = _make_label("今日利润：0", 30, Color(0.6, 1, 0.65))
	_profit_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_profit_label)

	_review_label = _make_label("好评 0 ｜ 差评 0", 20, Color(0.85, 0.95, 1))
	_review_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_review_label)

	_money_label = _make_label("现有资金：0", 22, Color(1, 0.95, 0.75))
	_money_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_money_label)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 6)
	vbox.add_child(spacer)

	_next_day_button = Button.new()
	_next_day_button.text = "进入下一天"
	_next_day_button.custom_minimum_size = Vector2(220, 52)
	_next_day_button.add_theme_font_size_override("font_size", 26)
	_next_day_button.add_theme_stylebox_override("normal", _button_stylebox())
	_next_day_button.add_theme_stylebox_override("hover", _button_stylebox())
	_next_day_button.add_theme_stylebox_override("pressed", _button_stylebox())
	_next_day_button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_next_day_button.pressed.connect(_on_next_day_pressed)
	vbox.add_child(_next_day_button)

# ==================== 展示与交互 ====================

## 显示结算结果（测试/编辑器进程可手动调用；运行模式由 shop_closed 触发）
func show_result(result: Dictionary) -> void:
	if result.is_empty():
		push_warning("DayResultPanel: 结算结果为空，不显示")
		return
	_title_label.text = "第 %d 天 结算" % result.get("day", 0)
	_revenue_label.text = "总收入：%d" % result.get("revenue", 0)
	for key in _cost_labels:
		_cost_labels[key].text = "%s：%d" % [_cost_labels[key].text.split("：")[0], result.get(key, 0)]
	_cost_total_label.text = "成本合计：%d" % result.get("cost_total", 0)

	var profit: int = result.get("profit", 0)
	_profit_label.text = "今日利润：%d" % profit
	_profit_label.add_theme_color_override("font_color", Color(0.6, 1, 0.65) if profit >= 0 else Color(1.0, 0.45, 0.45))

	_review_label.text = "好评 %d ｜ 差评 %d" % [result.get("good_reviews", 0), result.get("bad_reviews", 0)]
	_money_label.text = "现有资金：%d" % result.get("money", 0)
	_overlay.visible = true

## 点击进入下一天：恢复暂停 → 推进天数（清场由 main_scene 监听 day_started 处理）→ 隐藏面板
func _on_next_day_pressed() -> void:
	if Engine.is_editor_hint():
		return
	get_tree().paused = false
	GameStateManager.start_next_day()
	hide_panel()

## 隐藏面板（新一天开始后由按钮触发；防御重复调用）
func hide_panel() -> void:
	if _overlay != null:
		_overlay.visible = false

# ==================== 样式辅助 ====================

func _make_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("outline_size", 5)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

## 结算面板样式：半透明深色 + 圆角 + 描边
func _panel_stylebox() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.09, 0.12, 0.96)
	sb.set_corner_radius_all(16)
	sb.set_border_width_all(3)
	sb.border_color = Color(1, 0.9, 0.55, 0.5)
	return sb

## 按钮样式：暖金色
func _button_stylebox() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.85, 0.62, 0.2, 1)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(10)
	return sb
