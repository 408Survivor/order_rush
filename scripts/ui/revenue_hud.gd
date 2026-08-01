## 文件: scripts/ui/revenue_hud.gd
## 职责: 经营面板 HUD——右上角统一显示营业额/好评/差评（半透明圆角面板，issue #26）
## 依赖: GameStateManager (autoload)
## 注意: 场景结构 RevenueHUD > Panel > Margin > VBox > RevenueLabel/GoodLabel/BadLabel
##       @tool：编辑器进程（冒烟测试）可调用方法断言，符合项目脚本统一约定

@tool
extends CanvasLayer

@onready var revenue_label: Label = $Panel/Margin/VBox/RevenueLabel
@onready var good_label: Label = $Panel/Margin/VBox/GoodLabel
@onready var bad_label: Label = $Panel/Margin/VBox/BadLabel

func _ready() -> void:
	# @tool：编辑器进程不连接信号/刷新（冒烟测试手动 _update_all 断言），与 toast/order_board 拦截模式一致
	if Engine.is_editor_hint():
		return
	# 防重复连接（热重载/多实例 _ready 时避免双回调）
	if not GameStateManager.revenue_changed.is_connected(_on_revenue_changed):
		GameStateManager.revenue_changed.connect(_on_revenue_changed)
	if not GameStateManager.reviews_changed.is_connected(_on_reviews_changed):
		GameStateManager.reviews_changed.connect(_on_reviews_changed)
	_update_all()

func _on_revenue_changed(total: int) -> void:
	revenue_label.text = "营业额：%d" % total

func _on_reviews_changed(good: int, bad: int) -> void:
	good_label.text = "好评：%d" % good
	bad_label.text = "差评：%d" % bad

func _update_all() -> void:
	_on_revenue_changed(GameStateManager.revenue)
	_on_reviews_changed(GameStateManager.good_reviews, GameStateManager.bad_reviews)
