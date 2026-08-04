## 文件: scripts/items/finished_dish.gd
## 职责: 成品菜——微波炉加热产物，可拾取、可交付给顾客
## 依赖: GameStateManager (autoload，菜品显示名)
## 注意: 挂在 Area2D 上；交付判定看 is_in_group("dish")，菜品类型看 dish_type（P2 校验）；
##       #54 起按 dish_type 换带盘菜图标（dish_*.svg），不再整图 tint

@tool
extends Area2D

# ==================== 常量 ====================
## 各菜成品菜纹理（#54：带盘菜图标，替代占位 PNG + tint）
const DISH_TEXTURES := {
	"kungpao": preload("res://assets/art/items/dish_kungpao_plated.png"),
	"yuxiang": preload("res://assets/art/items/dish_yuxiang_plated.png"),
	"mapo": preload("res://assets/art/items/dish_mapo_plated.png"),
}

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

## P7/#54：按 dish_type 应用名称/纹理（带盘菜图标，不再整图 tint）
func apply_dish_visual() -> void:
	display_name = GameStateManager.get_dish_display_name(dish_type)
	modulate = Color.WHITE  # 防御：清除旧的整图 tint
	var tex: Texture2D = DISH_TEXTURES.get(dish_type)
	if tex != null:
		$Sprite2D.texture = tex
