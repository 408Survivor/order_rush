## 文件: scripts/ui/revenue_hud.gd
## 职责: 营业额 HUD：监听 GameStateManager.revenue_changed 显示当前营业额
## 依赖: GameStateManager (autoload)

extends CanvasLayer

@onready var revenue_label: Label = $RevenueLabel

func _ready() -> void:
	GameStateManager.revenue_changed.connect(_on_revenue_changed)
	revenue_label.text = "营业额: %d" % GameStateManager.revenue

func _on_revenue_changed(total: int) -> void:
	revenue_label.text = "营业额: %d" % total
