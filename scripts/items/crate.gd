## 文件: scripts/items/crate.gd
## 职责: 货箱（#50 两段式补给）——从冷库区货箱堆取出，送入冰柜补充对应菜品库存
## 依赖: GameStateManager (autoload，菜品显示名)
## 注意: 挂在 Area2D 上；碰撞 layer 8 与料理包一致，可被 Q 放下再拾取；
##       微波炉只收 meal_package 组、顾客/外卖口只收 dish 组——货箱自然被拒，无需额外拦截

@tool
extends Area2D

# ==================== 导出变量 ====================
## 显示名称（用于交互提示）
@export var display_name := "货箱"
## 菜品类型（决定入库的菜品库存与名称色调）
@export var dish_type := "kungpao"

# ==================== 生命周期 ====================

func _ready() -> void:
	add_to_group("interactable")
	add_to_group("pickable")
	add_to_group("crate")
	apply_dish_visual()

## 按 dish_type 应用名称（占位视觉：素材复用料理包图 + 棕色调，正式素材见 issue #51）
func apply_dish_visual() -> void:
	display_name = "%s货箱" % GameStateManager.get_dish_display_name(dish_type)
	modulate = Color(0.72, 0.52, 0.34)
