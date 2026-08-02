## 文件: scripts/props/takeout_counter.gd
## 职责: 外卖取餐口（P4）——玩家持成品菜在此打包外卖订单，骑手 ETA 归零后取餐
## 依赖: GameStateManager (autoload)
## 注意: 加入 interactable/takeout 组，由 player 交互分发（try_interact 的 takeout 分支）；
##       @tool 无副作用（不持有运行态）

@tool
extends Area2D

@export var display_name := "外卖口"

func _ready() -> void:
	add_to_group("interactable")
	add_to_group("takeout")

## 玩家调用：用一份成品菜打包一份待打包的外卖订单（无待打包单/物品不符则失败）
## 输出: bool（是否成功打包）
func pack_with(dish: Node2D) -> bool:
	if not is_instance_valid(dish):
		return false
	if not dish.is_in_group("dish"):
		return false
	var order := GameStateManager.get_pending_takeaway()
	if order.is_empty():
		return false
	return GameStateManager.pack_takeaway(order["id"])
