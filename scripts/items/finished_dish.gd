## 文件: scripts/items/finished_dish.gd
## 职责: 成品菜（宫保鸡丁）——微波炉加热产物，可拾取、可交付给顾客
## 依赖: 无
## 注意: 挂在 Area2D 上；交付判定看 is_in_group("dish")，菜品类型看 dish_type（P2 校验）

@tool
extends Area2D

# ==================== 导出变量 ====================
## 显示名称（用于交互提示）
@export var display_name := "宫保鸡丁"
## 菜品类型（与订单 dish_type 匹配校验，P2；多菜品阶段扩展为枚举）
@export var dish_type := "kungpao"

# ==================== 生命周期 ====================

func _ready() -> void:
	add_to_group("interactable")
	add_to_group("pickable")
	add_to_group("dish")
	apply_dish_visual()

## P7：按 dish_type 应用名称/色调（占位视觉——现有素材着色区分，AI 素材 013 批次后替换）
func apply_dish_visual() -> void:
	display_name = GameStateManager.get_dish_display_name(dish_type)
	modulate = GameStateManager.get_dish_tint(dish_type)
