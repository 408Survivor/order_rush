## 文件: scripts/ui/revenue_hud.gd
## 职责: 经营面板 HUD——右上角显示天数/营业倒计时/当日营业额/好评/差评（issue #26；#30 升级：图标化/数字滚动/倒计时脉冲）
## 依赖: GameStateManager/UITheme (autoload)
## 注意: 场景结构 RevenueHUD > Panel > Margin > VBox > DayTimeLabel/RevenueLabel/GoodLabel/BadLabel（节点路径保持兼容）
##       @tool：编辑器进程（冒烟测试）不连接信号/不启用动画，手动 _update_all 断言（项目统一约定）
## #30: 营业额数字滚动、倒计时最后 10s 红色脉冲仅运行模式生效；文本带 emoji 图标（系统 fallback 渲染）

@tool
extends CanvasLayer

@onready var panel: PanelContainer = $Panel
@onready var day_time_label: RichTextLabel = $Panel/Margin/VBox/DayTimeLabel
@onready var revenue_label: RichTextLabel = $Panel/Margin/VBox/RevenueLabel
@onready var good_label: RichTextLabel = $Panel/Margin/VBox/GoodLabel
@onready var bad_label: RichTextLabel = $Panel/Margin/VBox/BadLabel

## 已显示的营业额（数字滚动动画起点）
var _displayed_revenue := -1
var _revenue_tween: Tween = null
## 倒计时脉冲动画（最后 10s 启用）
var _pulse_tween: Tween = null

func _ready() -> void:
	# #30：统一面板样式（代码覆盖 tscn 占位 stylebox；@tool 下同样生效，纯视觉无副作用）
	panel.add_theme_stylebox_override("panel", UITheme.make_panel_style(12))
	# @tool：编辑器进程不连接信号/刷新（冒烟测试手动 _update_all 断言），与 toast/order_board 拦截模式一致
	if Engine.is_editor_hint():
		return
	# 防重复连接（热重载/多实例 _ready 时避免双回调）
	if not GameStateManager.day_stats_changed.is_connected(_on_day_stats_changed):
		GameStateManager.day_stats_changed.connect(_on_day_stats_changed)
	if not GameStateManager.time_changed.is_connected(_on_time_changed):
		GameStateManager.time_changed.connect(_on_time_changed)
	if not GameStateManager.day_started.is_connected(_on_day_started):
		GameStateManager.day_started.connect(_on_day_started)
	_update_all()

## 当日统计变化 → 营业额数字滚动 + 评分刷新
func _on_day_stats_changed() -> void:
	_animate_revenue(GameStateManager.day_revenue)
	good_label.text = "%s 好评 %d" % [UITheme.icon(UITheme.ICON_GOOD), GameStateManager.day_good_reviews]
	bad_label.text = "%s 差评 %d" % [UITheme.icon(UITheme.ICON_BAD), GameStateManager.day_bad_reviews]

## 营业倒计时更新 → 刷新天数行（最后 10s 红色脉冲警示；打烊后显示"已打烊"）
func _on_time_changed(time_left: float) -> void:
	var text: String
	var urgent := false
	if GameStateManager.is_shop_open:
		var left := int(ceil(time_left))
		text = "%s 第 %d 天　%s 营业剩余 %ds" % [UITheme.icon(UITheme.ICON_CALENDAR), GameStateManager.day, UITheme.icon(UITheme.ICON_TIMER), left]
		urgent = left <= 10
	else:
		text = "%s 第 %d 天　%s 已打烊" % [UITheme.icon(UITheme.ICON_CALENDAR), GameStateManager.day, UITheme.icon(UITheme.ICON_CLOSED)]
	day_time_label.text = text
	day_time_label.add_theme_color_override("default_color", UITheme.COLOR_RED if urgent else UITheme.COLOR_GOLD)
	_update_pulse(urgent)

## 进入下一天 → 刷新整面板（倒计时已在 time_changed 刷新）
func _on_day_started(_day: int) -> void:
	_update_all()

func _update_all() -> void:
	_displayed_revenue = -1
	_on_day_stats_changed()
	_on_time_changed(GameStateManager.business_time_left)

## 营业额数字滚动（运行模式 tween 0.4s；编辑器进程/首刷直接设置，保证冒烟断言确定性）
func _animate_revenue(target: int) -> void:
	if Engine.is_editor_hint():
		_displayed_revenue = target
		revenue_label.text = "%s 营业额 %d" % [UITheme.icon(UITheme.ICON_COIN), target]
		return
	if _displayed_revenue < 0:
		_displayed_revenue = target
	if _revenue_tween != null and _revenue_tween.is_valid():
		_revenue_tween.kill()
	revenue_label.text = "%s 营业额 %d" % [UITheme.icon(UITheme.ICON_COIN), _displayed_revenue]
	if _displayed_revenue == target:
		return
	_revenue_tween = create_tween()
	_revenue_tween.tween_method(_set_revenue_text, float(_displayed_revenue), float(target), 0.4)
	_displayed_revenue = target

func _set_revenue_text(value: float) -> void:
	revenue_label.text = "%s 营业额 %d" % [UITheme.icon(UITheme.ICON_COIN), int(round(value))]

## 倒计时脉冲：最后 10s 缩放 1.0↔1.08 循环；非紧急/打烊停止并复位
func _update_pulse(urgent: bool) -> void:
	if Engine.is_editor_hint():
		return
	if urgent and (_pulse_tween == null or not _pulse_tween.is_valid()):
		# 每次用当前 size 设 pivot（首帧布局后 size 才稳定）
		day_time_label.pivot_offset = day_time_label.size / 2.0
		_pulse_tween = create_tween().set_loops()
		_pulse_tween.tween_property(day_time_label, "scale", Vector2(1.08, 1.08), 0.45)
		_pulse_tween.tween_property(day_time_label, "scale", Vector2.ONE, 0.45)
	elif not urgent:
		if _pulse_tween != null and _pulse_tween.is_valid():
			_pulse_tween.kill()
			_pulse_tween = null
		day_time_label.scale = Vector2.ONE
