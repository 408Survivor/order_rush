## 文件: scripts/items/finished_dish.gd
## 职责: 成品菜（宫保鸡丁）——微波炉加热产物，可拾取、可交付给顾客
## 依赖: 无
## 注意: 挂在 Area2D 上；交付判定看 is_in_group("dish")

@tool
extends Area2D

# ==================== 导出变量 ====================
## 显示名称（用于交互提示）
@export var display_name := "宫保鸡丁"

# ==================== 生命周期 ====================

func _ready() -> void:
	add_to_group("interactable")
	add_to_group("pickable")
	add_to_group("dish")
