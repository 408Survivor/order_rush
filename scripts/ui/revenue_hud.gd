## 文件: scripts/ui/revenue_hud.gd
## 职责: 经营面板 HUD——右上角统一显示天数/营业倒计时/当日营业额/好评/差评（半透明圆角面板，issue #26；P3 扩展）
## 依赖: GameStateManager (autoload)
## 注意: 场景结构 RevenueHUD > Panel > Margin > VBox > DayTimeLabel/RevenueLabel/GoodLabel/BadLabel
##       @tool：编辑器进程（冒烟测试）不连接信号，手动 _update_all 断言（项目脚本统一约定）
## P3: 营业额/评分显示【当日】值；天数+营业倒计时实时刷新（最后 10s 红色警示）

@tool
extends CanvasLayer

@onready var day_time_label: Label = $Panel/Margin/VBox/DayTimeLabel
@onready var revenue_label: Label = $Panel/Margin/VBox/RevenueLabel
@onready var good_label: Label = $Panel/Margin/VBox/GoodLabel
@onready var bad_label: Label = $Panel/Margin/VBox/BadLabel

func _ready() -> void:
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

## 当日统计变化 → 刷新营业额/评分
func _on_day_stats_changed() -> void:
	revenue_label.text = "营业额：%d" % GameStateManager.day_revenue
	good_label.text = "好评：%d" % GameStateManager.day_good_reviews
	bad_label.text = "差评：%d" % GameStateManager.day_bad_reviews

## 营业倒计时更新 → 刷新天数行（最后 10s 红色警示；打烊后显示"已打烊"）
func _on_time_changed(time_left: float) -> void:
	var text: String
	if GameStateManager.is_shop_open:
		var left := int(ceil(time_left))
		text = "第 %d 天 ｜ 营业剩余 %ds" % [GameStateManager.day, left]
	else:
		text = "第 %d 天 ｜ 已打烊" % GameStateManager.day
	day_time_label.text = text
	if GameStateManager.is_shop_open and time_left <= 10.0:
		day_time_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.4))
	else:
		day_time_label.add_theme_color_override("font_color", Color(1, 0.95, 0.75))

## 进入下一天 → 刷新整面板（倒计时已在 time_changed 刷新）
func _on_day_started(_day: int) -> void:
	_update_all()

func _update_all() -> void:
	_on_day_stats_changed()
	_on_time_changed(GameStateManager.business_time_left)
