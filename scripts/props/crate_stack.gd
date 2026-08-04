## 文件: scripts/props/crate_stack.gd
## 职责: 货箱堆（#50 两段式补给）——冷库区批发仓，空手按 E 无限取出对应菜品货箱
## 依赖: GameStateManager (autoload，菜品显示名/色调)；Crate.tscn（取箱时实例化）
## 注意: 挂在 Area2D 上；批发仓无限库存，堆本身不消耗；
##       占位视觉 = 两张错位叠加的料理包图（菜品色调），正式素材见 issue #51

@tool
extends Area2D

# ==================== 常量 ====================
const CRATE_SCENE := preload("res://scenes/items/Crate.tscn")

# ==================== 导出变量 ====================
## 显示名称（用于交互提示）
@export var display_name := "货箱堆"
## 菜品类型（决定给出货箱的菜品与堆体色调）
@export var dish_type := "kungpao"

# ==================== 生命周期 ====================

func _ready() -> void:
	add_to_group("interactable")
	add_to_group("crate_stack")
	apply_dish_visual()

## 按 dish_type 应用名称/色调（整堆 modulate，两张叠加 Sprite 一起着色）
func apply_dish_visual() -> void:
	display_name = "%s货箱堆" % GameStateManager.get_dish_display_name(dish_type)
	modulate = GameStateManager.get_dish_tint(dish_type)

# ==================== 交互接口 ====================

## 给出一个货箱（玩家空手按 E 时由 _interact_with_crate_stack 调用）
## 输出: Node2D（新实例化的货箱，尚未入树；调用方负责挂接）
func give_crate() -> Node2D:
	var crate: Node2D = CRATE_SCENE.instantiate()
	crate.set("dish_type", dish_type)
	return crate
