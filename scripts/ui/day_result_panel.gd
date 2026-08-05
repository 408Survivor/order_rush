## 文件: scripts/ui/day_result_panel.gd
## 职责: 日结算面板——打烊后居中显示当日收入/成本明细/利润/评分/累计金币，按钮进入下一天（P3）
##       （#30 弹出动画/按钮三态/统一调色板；#48 tscn 化：静态结构移入 scenes/ui/DayResultPanel.tscn，
##        标题 44 号、主按钮立体纹理三态、次按钮描边样式写入 tscn）
## 依赖: GameStateManager/UITheme (autoload)；运行模式监听 shop_closed 自动弹出并暂停游戏
## 注意: 场景结构 DayResultPanel(CanvasLayer) > Overlay(ColorRect) > CenterContainer > Panel > Margin > VBox
##       （成本 5 行 Label 命名 cost_ingredients/cost_consumables/cost_utilities/cost_penalty/cost_rent，
##        _ready 按名收集进 _cost_labels）
##       @tool：编辑器进程（冒烟测试）不连接信号/不暂停/无动画，手动 show_result() 断言文本（项目统一约定）
## #30: Overlay 及子树 process_mode=ALWAYS——打烊暂停后弹出动画仍推进（tween 归属本节点）

@tool
extends CanvasLayer

# ==================== 节点引用（tscn 绑定，变量名冒烟测试依赖） ====================
@onready var _overlay: ColorRect = $Overlay
@onready var _panel: PanelContainer = $Overlay/CenterContainer/Panel
@onready var _title_label: Label = $Overlay/CenterContainer/Panel/Margin/VBox/TitleLabel
@onready var _revenue_label: RichTextLabel = $Overlay/CenterContainer/Panel/Margin/VBox/RevenueLabel
var _cost_labels: Dictionary = {}   # key -> Label（食材/耗材/水电/罚款/房租，_ready 按名收集）
@onready var _cost_total_label: Label = $Overlay/CenterContainer/Panel/Margin/VBox/CostPanel/Margin/VBox/CostTotalLabel
@onready var _profit_label: Label = $Overlay/CenterContainer/Panel/Margin/VBox/ProfitLabel
@onready var _review_label: Label = $Overlay/CenterContainer/Panel/Margin/VBox/ReviewLabel
@onready var _money_label: RichTextLabel = $Overlay/CenterContainer/Panel/Margin/VBox/MoneyLabel
@onready var _next_day_button: Button = $Overlay/CenterContainer/Panel/Margin/VBox/NextDayButton
@onready var _shop_button: Button = $Overlay/CenterContainer/Panel/Margin/VBox/ShopButton
@onready var _draw_button: Button = $Overlay/CenterContainer/Panel/Margin/VBox/DrawButton
@onready var _specialty_button: Button = $Overlay/CenterContainer/Panel/Margin/VBox/SpecialtyButton

## 按钮信号/反馈只接一次（@tool 热重载幂等）
var _wired := false

# ==================== 生命周期 ====================

func _ready() -> void:
	# #30：本面板在打烊暂停（get_tree().paused）期间仍需推进弹出动画（tween 归属本节点，
	#       process_mode=ALWAYS 使暂停下 tween 继续；进入下一天按钮由 Control 输入驱动不受暂停影响）
	process_mode = Node.PROCESS_MODE_ALWAYS
	# 纹理面板样式（奶黄金边；@tool 下同样生效，纯视觉无副作用）
	_panel.add_theme_stylebox_override("panel", UITheme.make_panel_texture_style(true))
	# 成本明细标签按名收集（tscn 静态节点）
	var cost_box: VBoxContainer = $Overlay/CenterContainer/Panel/Margin/VBox/CostPanel/Margin/VBox
	for key in ["cost_ingredients", "cost_consumables", "cost_utilities", "cost_penalty", "cost_rent"]:
		_cost_labels[key] = cost_box.get_node(key)
	# #48：主按钮三态换立体纹理（normal/hover/pressed）
	var btn_styles := UITheme.make_button_texture_styles()
	_next_day_button.add_theme_stylebox_override("normal", btn_styles["normal"])
	_next_day_button.add_theme_stylebox_override("hover", btn_styles["hover"])
	_next_day_button.add_theme_stylebox_override("pressed", btn_styles["pressed"])
	_next_day_button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	# 按钮信号与反馈（热重载防重；编辑器进程连接无副作用，按下不会触发）
	if not _wired:
		_wired = true
		UITheme.style_button_feedback(_next_day_button)
		UITheme.style_button_feedback(_shop_button)
		UITheme.style_button_feedback(_draw_button)
		UITheme.style_button_feedback(_specialty_button)
		_next_day_button.pressed.connect(_on_next_day_pressed)
		_shop_button.pressed.connect(_on_shop_pressed)
		_draw_button.pressed.connect(_on_draw_pressed)
		_specialty_button.pressed.connect(_on_specialty_pressed)
	if Engine.is_editor_hint():
		return
	# 防重复连接（热重载/多实例 _ready）
	if not GameStateManager.shop_closed.is_connected(_on_shop_closed):
		GameStateManager.shop_closed.connect(_on_shop_closed)

## 打烊 → 弹出结算面板并暂停游戏（运行模式）
func _on_shop_closed(result: Dictionary) -> void:
	show_result(result)
	get_tree().paused = true

# ==================== 展示与交互 ====================

## 显示结算结果（测试/编辑器进程可手动调用；运行模式由 shop_closed 触发）
func show_result(result: Dictionary) -> void:
	if result.is_empty():
		push_warning("DayResultPanel: 结算结果为空，不显示")
		return
	_title_label.text = "第 %d 天 结算" % result.get("day", 0)
	_revenue_label.text = "%s 总收入：%d" % [UITheme.icon(UITheme.ICON_COIN), result.get("revenue", 0)]
	for key in _cost_labels:
		_cost_labels[key].text = "%s：%d" % [_cost_labels[key].text.split("：")[0], result.get(key, 0)]
	_cost_total_label.text = "成本合计：%d" % result.get("cost_total", 0)

	var profit: int = result.get("profit", 0)
	_profit_label.text = "今日利润：%d" % profit
	_profit_label.add_theme_color_override("font_color", UITheme.COLOR_GREEN if profit >= 0 else UITheme.COLOR_RED)

	_review_label.text = "好评 %d ｜ 差评 %d" % [result.get("good_reviews", 0), result.get("bad_reviews", 0)]
	_money_label.text = "%s 现有资金：%d" % [UITheme.icon(UITheme.ICON_COIN), result.get("money", 0)]
	_overlay.visible = true

	# #30：弹出动画（编辑器进程直接显示，保证冒烟断言确定性）
	if Engine.is_editor_hint():
		_overlay.modulate.a = 1.0
		_panel.scale = Vector2.ONE
		_panel.modulate.a = 1.0
		return
	_overlay.modulate.a = 0.0
	_panel.pivot_offset = _panel.size / 2.0
	_panel.scale = Vector2(0.7, 0.7)
	_panel.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(_overlay, "modulate:a", 1.0, 0.2)
	tween.parallel().tween_property(_panel, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(_panel, "modulate:a", 1.0, 0.2)

	# #67：金额 count-up（依次滚动出现；编辑器进程在上方已 return，不会执行到这里）
	_count_up(_revenue_label, "%s 总收入：" % UITheme.icon(UITheme.ICON_COIN), result.get("revenue", 0), 0.15)
	_count_up(_cost_total_label, "成本合计：", result.get("cost_total", 0), 0.3)
	_count_up(_profit_label, "今日利润：", profit, 0.45)
	_count_up(_money_label, "%s 现有资金：" % UITheme.icon(UITheme.ICON_COIN), result.get("money", 0), 0.6)

## #67：数字从 0 滚动到终值（0.55s + 延迟依次出现；终值为 0 时保持静态文本）
func _count_up(label: Control, prefix: String, final: int, delay: float) -> void:
	if final == 0:
		return
	label.text = "%s0" % prefix
	var tween := create_tween()
	tween.tween_method(func(v: float) -> void: label.text = "%s%d" % [prefix, int(v)], 0.0, float(final), 0.55).set_delay(delay)

## 点击进入下一天：恢复暂停 → 推进天数（清场由 main_scene 监听 day_started 处理）→ 隐藏面板
func _on_next_day_pressed() -> void:
	if Engine.is_editor_hint():
		return
	get_tree().paused = false
	GameStateManager.start_next_day()
	hide_panel()

## 打开设备升级商店（P5；商店为 main_scene 动态实例化的 UpgradeShop，打烊暂停中可交互）
func _on_shop_pressed() -> void:
	if Engine.is_editor_hint():
		return
	var shop := get_tree().current_scene.get_node_or_null("UpgradeShop")
	if shop != null and shop.has_method("show_shop"):
		shop.show_shop()

## 打开口碑抽卡（P6；抽卡面板为 main_scene 动态实例化的 CardDraw，打烊暂停中可交互）
func _on_draw_pressed() -> void:
	if Engine.is_editor_hint():
		return
	var draw := get_tree().current_scene.get_node_or_null("CardDraw")
	if draw != null and draw.has_method("show_draw"):
		draw.show_draw()

## 打开招牌菜选择（P7；面板为 main_scene 动态实例化的 SpecialtyPanel，打烊暂停中可交互）
func _on_specialty_pressed() -> void:
	if Engine.is_editor_hint():
		return
	var panel := get_tree().current_scene.get_node_or_null("SpecialtyPanel")
	if panel != null and panel.has_method("show_panel"):
		panel.show_panel()

## 隐藏面板（新一天开始后由按钮触发；防御重复调用）
func hide_panel() -> void:
	if _overlay != null:
		_overlay.visible = false
