## 文件: scripts/autoload/GameStateManager.gd
## 职责: 全局游戏状态管理：P2 订单队列（多单）/耐心值/评分，P3 经济（收入/成本/日结算/天数）
## 依赖: 无
## 注意: @tool 使编辑器进程（冒烟测试）可访问；P2/P3 的自动 tick（耐心/营业倒计时）
##       在编辑器进程被拦截（冒烟测试手动推进）；打烊暂停由结算面板负责（编辑器进程安全）
## P3: 收入=基础价（堂食阶段；打包费/平台扣点 P4 外卖启用），成本=食材+房租+水电+耗材

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
## 当日统计变化时发出（P3：当日收入/评分/成本变化，供 HUD 刷新；不携带参数，读取状态即可）
signal day_stats_changed()
## 营业倒计时更新时发出（P3，供 HUD 显示剩余时间）
signal time_changed(time_left: float)
## 打烊结算时发出（P3，参数为结算结果字典，供日结算面板显示）
signal shop_closed(result: Dictionary)
## 进入下一天时发出（P3，供场景清场/重启营业）
signal day_started(day: int)

# ==================== 常量 ====================
const MAX_CONCURRENT_ORDERS := 3  # P2: 最多同时 3 单（与 max_queue=3 对齐）
const DISH_PRICE := 20            ## 宫保鸡丁基础价（P2 固定价，P3 经济收入侧）

# ===== P3 经济常量（可调，P5 设备/卡牌效果会引用） =====
const INGREDIENT_COST_PER_ORDER := 6   ## 食材成本（按售出量计，每单）
const CONSUMABLE_COST_PER_ORDER := 2   ## 耗材成本（按售出量计，每单：餐具/餐盒）
const RENT_COST_PER_DAY := 30          ## 固定房租（每天）
const UTILITY_COST_PER_HEAT := 1       ## 水电燃气（按设备使用次数计，每次加热）
const BUSINESS_TIME_PER_DAY := 90.0    ## 每天营业时长（秒），到点自动打烊
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

## 累计营业额（跨天累加，交付成功累加；P3 保留作历史统计/兼容）
var revenue := 0

## 累计好评数（订单完成 +1）与差评数（订单超时 +1），P2 评分（跨天累加）
var good_reviews := 0
var bad_reviews := 0

# ===== P3 经济状态 =====
## 当前天数（第 1 天起）
var day := 1
## 累计金币（= 累计净利润；打烊结算时累加，P5 设备升级购买用）
var money := 0
## 当日收入（交付成功累加）
var day_revenue := 0
## 当日成本明细（食材/耗材按单计，水电按加热次数计；房租为常量 RENT_COST_PER_DAY）
var day_cost_ingredients := 0
var day_cost_consumables := 0
var day_cost_utilities := 0
## 当日好评/差评（结算面板用；累计值见 good_reviews/bad_reviews）
var day_good_reviews := 0
var day_bad_reviews := 0
## 营业倒计时（剩余秒数），营业中递减，到 0 自动打烊
var business_time_left := BUSINESS_TIME_PER_DAY
## 是否营业中（false = 已打烊，等待进入下一天）
var is_shop_open := true
## 最近一次打烊结算结果（close_shop 写入；调试/结算面板/测试读取）
var last_settlement: Dictionary = {}

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


## 订单交付成功：计入当日收入与成本、好评，并发出 order_completed（结算入口）
## 输入: order_id (int)
## 输出: bool（是否成功结算）
## 副作用: 当日收入 + 菜品价、食材/耗材成本累加、好评 +1；累计 revenue/good_reviews 同步；
##         发出 order_completed / revenue_changed / reviews_changed / day_stats_changed
func complete_order(order_id: int) -> bool:
	for i in range(active_orders.size()):
		if active_orders[i]["id"] == order_id:
			active_orders.remove_at(i)
			var price := get_dish_price()
			revenue += price
			good_reviews += 1
			# P3：当日经济统计
			day_revenue += price
			day_cost_ingredients += INGREDIENT_COST_PER_ORDER
			day_cost_consumables += CONSUMABLE_COST_PER_ORDER
			day_good_reviews += 1
			order_completed.emit(order_id, price)
			revenue_changed.emit(revenue)
			reviews_changed.emit(good_reviews, bad_reviews)
			day_stats_changed.emit()
			print_rich("[color=green]Order %d completed! Revenue: %d (day %d, total %d)[/color]" % [order_id, price, day_revenue, revenue])
			return true
	push_warning("complete_order: order %d not found" % order_id)
	return false

## 订单超时失败：差评 +1，订单移除（P2 超时/差评入口）
## 输入: order_id (int)
## 输出: bool（是否成功标记失败）
## 副作用: 差评 +1（累计与当日），订单移除，发出 order_failed / reviews_changed / day_stats_changed
func fail_order(order_id: int) -> bool:
	for i in range(active_orders.size()):
		if active_orders[i]["id"] == order_id:
			active_orders.remove_at(i)
			bad_reviews += 1
			day_bad_reviews += 1
			order_failed.emit(order_id)
			reviews_changed.emit(good_reviews, bad_reviews)
			day_stats_changed.emit()
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
	# @tool：编辑器进程（冒烟测试）不自动推进，测试手动 tick_patience / tick_business_time 控制时序
	if Engine.is_editor_hint():
		return
	# 打烊后（等待结算）不再推进耐心/倒计时，订单已在 close_shop 清空
	if not is_shop_open:
		return
	tick_patience(delta)
	tick_business_time(delta)


# ==================== P3 经济系统 ====================

## 每单收入（P3 堂食阶段 = 菜品基础价；P4 外卖扩展：基础价 + 打包费 + 平台补贴 − 平台扣点）
func get_dish_price() -> int:
	return DISH_PRICE

## 当日总成本（食材 + 耗材 + 水电 + 房租）
func get_day_total_cost() -> int:
	return day_cost_ingredients + day_cost_consumables + day_cost_utilities + RENT_COST_PER_DAY

## 当日利润（收入 − 成本）
func get_day_profit() -> int:
	return day_revenue - get_day_total_cost()

## 记录一次设备加热（微波炉加热完成时调用），计入水电成本（P3）
func record_heat() -> void:
	day_cost_utilities += UTILITY_COST_PER_HEAT
	day_stats_changed.emit()

## 推进营业倒计时（运行模式由 _process 调用，测试手动调用）
## 输入: delta (float) 秒
## 输出: bool（是否触发打烊）
## 副作用: 倒计时归零时调用 close_shop() 并发出 time_changed
func tick_business_time(delta: float) -> bool:
	if not is_shop_open:
		return false
	business_time_left = maxf(business_time_left - delta, 0.0)
	time_changed.emit(business_time_left)
	if business_time_left <= 0.0:
		close_shop()
		return true
	return false

## 打烊结算：停止营业、作废未完成订单、计算利润并入累计金币，发出 shop_closed
## 输出: Dictionary（结算结果：day/收入/成本明细/利润/评分/累计金币；重复调用返回空字典）
## 注意: 不在此处暂停场景树（编辑器进程/冒烟测试安全）——运行模式由日结算面板监听
##       shop_closed 后自行暂停；顾客/物品清场由 main_scene 监听 shop_closed 处理
func close_shop() -> Dictionary:
	if not is_shop_open:
		push_warning("close_shop: 已打烊，忽略重复结算")
		return {}
	is_shop_open = false
	business_time_left = 0.0
	# 打烊作废全部未完成订单（不发 order_failed——不属超时差评，结算只统计当日已发生）
	active_orders.clear()

	var profit := get_day_profit()
	money += profit
	var result := {
		"day": day,
		"revenue": day_revenue,
		"cost_ingredients": day_cost_ingredients,
		"cost_consumables": day_cost_consumables,
		"cost_utilities": day_cost_utilities,
		"cost_rent": RENT_COST_PER_DAY,
		"cost_total": get_day_total_cost(),
		"profit": profit,
		"good_reviews": day_good_reviews,
		"bad_reviews": day_bad_reviews,
		"money": money,
	}
	last_settlement = result
	shop_closed.emit(result)
	time_changed.emit(0.0)
	print_rich("[color=orange]Day %d 打烊！收入 %d − 成本 %d = 利润 %d（累计金币 %d）[/color]" % [day, day_revenue, get_day_total_cost(), profit, money])
	return result

## 进入下一天：天数 +1、当日统计清零、恢复营业（累计 revenue/评分/金币保留）
## 注意: 场景清场（顾客/物品/玩家复位）由 main_scene 监听 day_started 处理；
##       暂停恢复由日结算面板负责（先恢复再进入下一天）
func start_next_day() -> void:
	if is_shop_open:
		push_warning("start_next_day: 尚未打烊，无法进入下一天")
		return
	day += 1
	_reset_day_stats()
	is_shop_open = true
	business_time_left = BUSINESS_TIME_PER_DAY
	day_started.emit(day)
	day_stats_changed.emit()
	time_changed.emit(business_time_left)
	print_rich("[color=green]Day %d 开始！营业时间 %.0fs[/color]" % [day, BUSINESS_TIME_PER_DAY])

## 当日统计清零（进入下一天时调用；累计 revenue/good_reviews/bad_reviews/money 保留）
func _reset_day_stats() -> void:
	day_revenue = 0
	day_cost_ingredients = 0
	day_cost_consumables = 0
	day_cost_utilities = 0
	day_good_reviews = 0
	day_bad_reviews = 0


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
