## 文件: scripts/autoload/GameStateManager.gd
## 职责: 全局游戏状态管理，P2 维护订单队列（多单）、耐心值、评分与营业额
## 依赖: 无
## 注意: 后续阶段会扩展为包含经济、天数、角色等状态；@tool 使编辑器进程（冒烟测试）可访问
## P2: 耐心倒计时由本管理器驱动（tick_patience），编辑器进程拦截自动 tick（冒烟测试手动推进）

@tool
extends Node

# ==================== 信号 ====================
## 当订单状态变化时发出（供UI和调试面板监听）
signal order_state_changed(order_id: int, new_state: int)
## 订单完成结算时发出（交付成功即结算）
signal order_completed(order_id: int, revenue: int)
## 订单超时失败时发出（P2 新增，供 CustomerManager 让顾客离店）
signal order_failed(order_id: int)
## 营业额变化时发出（供 HUD 更新）
signal revenue_changed(total: int)
## 好评/差评数变化时发出（P2 评分，供 HUD 更新）
signal reviews_changed(good: int, bad: int)

# ==================== 常量 ====================
const MAX_CONCURRENT_ORDERS := 3  # P2: 最多同时 3 单（与 max_queue=3 对齐）
const DISH_PRICE := 20            ## 宫保鸡丁单价（P2 固定价）
## 菜品类型 → 显示名映射（头顶订单标记/HUD 用；P7 多菜品时扩展）
const DISH_NAMES := {
	"kungpao": "宫保鸡丁",
}

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
## 结构: [{ id: int, state: OrderState, customer_id: int, dish_type: String,
##         patience_left: float, patience_total: float }]
var active_orders: Array[Dictionary] = []

## 累计营业额（交付成功累加）
var revenue := 0

## 好评数（订单完成 +1）与差评数（订单超时 +1），P2 评分
var good_reviews := 0
var bad_reviews := 0

## 订单耐心时长（秒），运行时可调（调试/测试用）
var patience_time := 30.0

var _next_order_id := 1

# ==================== 订单管理 ====================

## 生成一个新订单（P2: 自动附带耐心倒计时）
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
		"patience_left": patience_time,
		"patience_total": patience_time,
		"created_at": Time.get_time_dict_from_system()
	}
	active_orders.append(order)
	order_state_changed.emit(order_id, OrderState.PENDING)
	
	print_rich("[color=green]Order %d created: %s (patience %.1fs)[/color]" % [order_id, dish_type, patience_time])
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

## 菜品类型 → 显示名（未知类型回退为类型 id，防御）
func get_dish_display_name(dish_type: String) -> String:
	return DISH_NAMES.get(dish_type, dish_type)


## 订单交付成功：计入营业额与好评并发出 order_completed（结算入口）
## 输入: order_id (int)
## 输出: bool（是否成功结算）
## 副作用: revenue 累加，好评 +1，订单移除，发出 order_completed / revenue_changed / reviews_changed
func complete_order(order_id: int) -> bool:
	for i in range(active_orders.size()):
		if active_orders[i]["id"] == order_id:
			active_orders.remove_at(i)
			revenue += DISH_PRICE
			good_reviews += 1
			order_completed.emit(order_id, DISH_PRICE)
			revenue_changed.emit(revenue)
			reviews_changed.emit(good_reviews, bad_reviews)
			print_rich("[color=green]Order %d completed! Revenue: %d (total %d), good review (+1)[/color]" % [order_id, DISH_PRICE, revenue])
			return true
	push_warning("complete_order: order %d not found" % order_id)
	return false

## 订单超时失败：差评 +1，订单移除（P2 超时/差评入口）
## 输入: order_id (int)
## 输出: bool（是否成功标记失败）
## 副作用: 差评 +1，订单移除，发出 order_failed / reviews_changed
func fail_order(order_id: int) -> bool:
	for i in range(active_orders.size()):
		if active_orders[i]["id"] == order_id:
			active_orders.remove_at(i)
			bad_reviews += 1
			order_failed.emit(order_id)
			reviews_changed.emit(good_reviews, bad_reviews)
			print_rich("[color=red]Order %d failed (patience expired)! Bad review (+1)[/color]" % order_id)
			return true
	push_warning("fail_order: order %d not found" % order_id)
	return false

# ==================== 耐心值（P2） ====================

## 每帧推进所有活跃订单的耐心倒计时（运行模式由 _process 调用，测试手动调用）
## 输入: delta (float) 秒
## 输出: int（本次超时的订单数）
## 副作用: 超时订单被 fail_order
## 注意: 在 _process 中调用（帧序晚于 _input 的交付栈），交付/超时不会同帧竞态；
##       若将来交互逻辑挪到 _physics_process，需重新评估时序
func tick_patience(delta: float) -> int:
	var failed := 0
	# 倒序遍历，避免 fail_order 移除元素影响索引
	for i in range(active_orders.size() - 1, -1, -1):
		var order := active_orders[i]
		# 防御：SERVED/COMPLETED 为未来订单状态机的预留（当前完成/失败直接移除订单，
		# 活跃订单的 state 实际始终为 PENDING）
		if order["state"] == OrderState.SERVED or order["state"] == OrderState.COMPLETED:
			continue
		order["patience_left"] = maxf(order["patience_left"] - delta, 0.0)
		if order["patience_left"] <= 0.0:
			if fail_order(order["id"]):
				failed += 1
	return failed

func _process(delta: float) -> void:
	# @tool：编辑器进程（冒烟测试）不自动推进耐心，测试手动 tick_patience 控制时序
	if Engine.is_editor_hint():
		return
	tick_patience(delta)


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
