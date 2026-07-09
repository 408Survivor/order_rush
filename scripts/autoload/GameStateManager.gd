## 文件: scripts/autoload/GameStateManager.gd
## 职责: 全局游戏状态管理，Phase 1 仅维护订单状态
## 依赖: 无
## 注意: 后续阶段会扩展为包含经济、天数、角色等状态

extends Node

# ==================== 信号 ====================
## 当订单状态变化时发出（供UI和调试面板监听）
signal order_state_changed(order_id: int, new_state: int)

# ==================== 常量 ====================
const MAX_CONCURRENT_ORDERS := 1  # Phase 1 只支持1单

# ==================== 枚举 ====================
enum OrderState {
	PENDING,    ## 等待制作
	COOKING,    ## 制作中
	READY,      ## 制作完成，等待送餐
	SERVED,     ## 已送达，顾客用餐中
	COMPLETED,  ## 顾客吃完，订单完成
	FAILED      ## 超时或失败（Phase 2启用）
}

# ==================== 状态变量 ====================
## 当前活跃订单列表
## 结构: [{ id: int, state: OrderState, customer_id: int, dish_type: String }]
var active_orders: Array[Dictionary] = []

var _next_order_id := 1

# ==================== 订单管理 ====================

## 生成一个新订单
## 输入: customer_id (int), dish_type (String)
## 输出: int (order_id)
## 副作用: 添加订单到 active_orders，发出 order_state_changed
func create_order(customer_id: int, dish_type: String) -> int:
	if active_orders.size() >= MAX_CONCURRENT_ORDERS:
		push_warning("Max concurrent orders reached, cannot create new order")
		return -1
	
	var order_id := _next_order_id
	_next_order_id += 1
	
	var order := {
		"id": order_id,
		"state": OrderState.PENDING,
		"customer_id": customer_id,
		"dish_type": dish_type,
		"created_at": Time.get_time_dict_from_system()
	}
	active_orders.append(order)
	order_state_changed.emit(order_id, OrderState.PENDING)
	
	print_rich("[color=green]Order %d created: %s[/color]" % [order_id, dish_type])
	return order_id


## 更新订单状态
## 输入: order_id (int), new_state (OrderState)
## 输出: bool (是否成功更新)
## 副作用: 修改订单状态，发出 order_state_changed
func update_order_state(order_id: int, new_state: int) -> bool:
	for order in active_orders:
		if order["id"] == order_id:
			var old_state := order["state"] as int
			order["state"] = new_state
			order_state_changed.emit(order_id, new_state)
			
			print_rich("[color=yellow]Order %d: %s -> %s[/color]" % [
				order_id, 
				OrderState.keys()[old_state],
				OrderState.keys()[new_state]
			])
			return true
	
	push_warning("Order %d not found" % order_id)
	return false


## 获取指定订单
## 输入: order_id (int)
## 输出: Dictionary (订单数据，找不到返回空字典)
func get_order(order_id: int) -> Dictionary:
	for order in active_orders:
		if order["id"] == order_id:
			return order
	return {}


## 移除已完成/失败的订单
## 输入: order_id (int)
## 输出: bool (是否成功移除)
func remove_order(order_id: int) -> bool:
	for i in range(active_orders.size()):
		if active_orders[i]["id"] == order_id:
			active_orders.remove_at(i)
			print_rich("[color=gray]Order %d removed[/color]" % order_id)
			return true
	return false


## 获取当前活跃订单数量
func get_active_order_count() -> int:
	return active_orders.size()


# ==================== 调试辅助 ====================

## 返回所有订单的可读状态字符串
func get_orders_debug_string() -> String:
	var result := "Active Orders: %d\n" % active_orders.size()
	for order in active_orders:
		result += "  #%d: %s (%s)\n" % [
			order["id"],
			OrderState.keys()[order["state"]],
			order["dish_type"]
		]
	return result
