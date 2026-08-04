## 文件: scripts/items/meal_package.gd
## 职责: 料理包——可被玩家拾取的可交互物品
## 依赖: GameStateManager (autoload，菜品显示名)
## 注意: 挂在 Area2D 上；拾取后由玩家持有（见 player_character.gd）；
##       #54 起按 dish_type 换独立分色 SVG（meal_pack_*.svg），不再整图 tint

@tool
extends Area2D

# ==================== 常量 ====================
## 各菜料理包纹理（#54：独立分色铝箔袋素材，替代占位 PNG + tint）
const DISH_TEXTURES := {
	"kungpao": preload("res://assets/art/items/meal_pack_kungpao.png"),
	"yuxiang": preload("res://assets/art/items/meal_pack_yuxiang.png"),
	"mapo": preload("res://assets/art/items/meal_pack_mapo.png"),
}

# ==================== 导出变量 ====================
## 显示名称（用于交互提示）
@export var display_name := "料理包"
## 菜品类型（P7 多菜品：决定名称/纹理；与订单 dish_type 匹配）
@export var dish_type := "kungpao"

# ==================== 生命周期 ====================

func _ready() -> void:
	add_to_group("interactable")
	add_to_group("pickable")
	add_to_group("meal_package")
	apply_dish_visual()

## P7/#54：按 dish_type 应用名称/纹理（独立分色素材，不再整图 tint）
func apply_dish_visual() -> void:
	display_name = "%s料理包" % GameStateManager.get_dish_display_name(dish_type)
	modulate = Color.WHITE  # 防御：清除旧的整图 tint
	var tex: Texture2D = DISH_TEXTURES.get(dish_type)
	if tex != null:
		$Sprite2D.texture = tex
