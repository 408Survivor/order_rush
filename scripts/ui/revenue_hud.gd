## 文件: scripts/ui/revenue_hud.gd
## 职责: 顶部 HUD：营业额 + 好评/差评（P2 评分），监听 GameStateManager 信号
## 依赖: GameStateManager (autoload)

extends CanvasLayer

@onready var revenue_label: Label = $RevenueLabel
@onready var review_label: Label = $ReviewLabel

func _ready() -> void:
	# 防重复连接（热重载/编辑器进程多次 _ready 时避免双回调）
	if not GameStateManager.revenue_changed.is_connected(_on_revenue_changed):
		GameStateManager.revenue_changed.connect(_on_revenue_changed)
	if not GameStateManager.reviews_changed.is_connected(_on_reviews_changed):
		GameStateManager.reviews_changed.connect(_on_reviews_changed)
	revenue_label.text = "营业额: %d" % GameStateManager.revenue
	review_label.text = _review_text()

func _on_revenue_changed(total: int) -> void:
	revenue_label.text = "营业额: %d" % total

func _on_reviews_changed(good: int, bad: int) -> void:
	review_label.text = _review_text()

func _review_text() -> String:
	return "好评: %d  差评: %d" % [GameStateManager.good_reviews, GameStateManager.bad_reviews]
