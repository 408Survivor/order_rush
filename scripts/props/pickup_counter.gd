## 文件: scripts/props/pickup_counter.gd
## 职责: 取餐台（#103 点单/取餐分离）——玩家持成品菜在此交付堂食订单：
##       在队订单按菜品匹配 → complete_order 结算 → 对应顾客（无论走位/等餐）转离店
## 依赖: GameStateManager (autoload)；CustomerManager（on_order_served 通知离店，同场景分支查找）
## 注意: 加入 interactable/pickup_counter 组，由 player 交互分发（try_interact 的 pickup_counter 分支）；
##       @tool 无副作用（不持有运行态）

@tool
extends Area2D

@export var display_name := "取餐台"

func _ready() -> void:
	add_to_group("interactable")
	add_to_group("pickup_counter")

## 玩家调用：用一份成品菜交付一份菜品匹配的堂食订单（无匹配则失败，物品不消耗）
## 输出: bool（是否成功交付）
## 副作用: 订单结算（经济/好评/繁荣度经 complete_order 原链路）、对应顾客转离店
func serve_with(dish: Node2D) -> bool:
	if not is_instance_valid(dish):
		return false
	if not dish.is_in_group("dish"):
		return false
	var order_id := GameStateManager.find_order_by_dish(str(dish.get("dish_type")))
	if order_id == -1:
		return false
	# 先结算（order_completed 信号同步发出，飘字此时还能按 customer.order_id 定位顾客位置）
	GameStateManager.complete_order(order_id)
	var mgr := _find_customer_manager()
	if mgr != null:
		mgr.call("on_order_served", order_id)
	return true

## 是否有菜品匹配的在队订单（交互提示用，无副作用）
func can_serve(dish: Node2D) -> bool:
	if dish == null or not dish.is_in_group("dish"):
		return false
	return GameStateManager.find_order_by_dish(str(dish.get("dish_type"))) != -1

## 找同场景分支的 CustomerManager（编辑器进程可能开着 MainScene 页签，同组多个）
func _find_customer_manager() -> Node:
	var home := get_parent()
	for node in get_tree().get_nodes_in_group("customer_manager"):
		if home != null and home.is_ancestor_of(node):
			return node
	return null
