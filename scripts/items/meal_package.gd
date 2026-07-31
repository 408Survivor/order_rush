## 文件: scripts/items/meal_package.gd
## 职责: 料理包——可被玩家拾取的可交互物品
## 依赖: 无
## 注意: 挂在 Area2D 上；拾取后由玩家持有（见 player_character.gd）

@tool
extends Area2D

# ==================== 导出变量 ====================
## 显示名称（用于交互提示）
@export var display_name := "料理包"

# ==================== 生命周期 ====================

func _ready() -> void:
	add_to_group("interactable")
	add_to_group("pickable")
	add_to_group("meal_package")
