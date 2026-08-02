## 文件: scripts/items/meal_package.gd
## 职责: 料理包——可被玩家拾取的可交互物品
## 依赖: 无
## 注意: 挂在 Area2D 上；拾取后由玩家持有（见 player_character.gd）

@tool
extends Area2D

# ==================== 导出变量 ====================
## 显示名称（用于交互提示）
@export var display_name := "料理包"
## 菜品类型（P7 多菜品：决定名称/色调；与订单 dish_type 匹配）
@export var dish_type := "kungpao"

# ==================== 生命周期 ====================

func _ready() -> void:
	add_to_group("interactable")
	add_to_group("pickable")
	add_to_group("meal_package")
	apply_dish_visual()

## P7：按 dish_type 应用名称/色调（占位视觉——现有素材着色区分，AI 素材 013 批次后替换）
func apply_dish_visual() -> void:
	display_name = "%s料理包" % GameStateManager.get_dish_display_name(dish_type)
	modulate = GameStateManager.get_dish_tint(dish_type)
