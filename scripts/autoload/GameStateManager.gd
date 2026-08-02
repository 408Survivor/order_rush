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
## P4 外卖信号：创建 / 状态变化（打包等）/ 完成取餐 / 超时罚款
signal takeaway_created(order_id: int)
signal takeaway_state_changed(order_id: int, new_state: int)
signal takeaway_completed(order_id: int, revenue: int)
signal takeaway_failed(order_id: int)
## P7 特殊事件信号：开始（Toast/微波炉提示用）
signal event_started(event_type: int)

# ==================== 常量 ====================
const MAX_CONCURRENT_ORDERS := 3  # P2: 最多同时 3 单（与 max_queue=3 对齐）
const DISH_PRICE := 20            ## 宫保鸡丁基础价（P2 固定价，P3 经济收入侧）

# ===== P3 经济常量（可调，P5 设备/卡牌效果会引用） =====
const INGREDIENT_COST_PER_ORDER := 6   ## 食材成本（按售出量计，每单）
const CONSUMABLE_COST_PER_ORDER := 2   ## 耗材成本（按售出量计，每单：餐具/餐盒）
const RENT_COST_PER_DAY := 30          ## 固定房租（每天）
const UTILITY_COST_PER_HEAT := 1       ## 水电燃气（按设备使用次数计，每次加热）
const BUSINESS_TIME_PER_DAY := 90.0    ## 每天营业时长（秒），到点自动打烊

# ===== P4 外卖常量（可调） =====
const TAKEOUT_MAX_CONCURRENT := 3       ## 外卖订单并发上限（与堂食 3 单并行）
const TAKEOUT_ORDER_INTERVAL := 25.0    ## 外卖订单生成间隔（秒）
const TAKEOUT_ETA := 40.0               ## 骑手 ETA（秒）——外卖时间压力核心
const PACKING_FEE := 2                  ## 打包费（外卖收入加成）
const PLATFORM_SUBSIDY := 3             ## 平台补贴（外卖收入加成）
const PLATFORM_CUT_RATE := 0.10         ## 平台扣点比例（外卖收入扣减）
const TAKEOUT_FAIL_PENALTY := 5         ## 外卖超时罚款（计入当日成本）

# ===== P7 多菜品 + 难度 + 招牌菜 + 特殊事件 =====
## 菜品配置（id → 名称/等级/基础价；L2/L3 槽位预留，二期接入炒锅/现做流程）
const DISHES := {
	"kungpao": {"name": "宫保鸡丁", "level": 1, "price": 20},
	"yuxiang": {"name": "鱼香肉丝", "level": 1, "price": 22},
	"mapo": {"name": "麻婆豆腐", "level": 1, "price": 18},
}
const L1_DISHES: Array[String] = ["kungpao", "yuxiang", "mapo"]  ## 当前可点菜品池（L1）
const SPECIALTY_PROF_PER_LEVEL := 3   ## 招牌菜熟练度升级档位（每 N 次售出 +1 档）
const SPECIALTY_PRICE_BONUS := 0.20   ## 招牌菜基础价格加成
const SPECIALTY_PROF_BONUS := 0.10    ## 招牌菜每档熟练度价格加成（上限 3 档）
const SPECIALTY_PROF_MAX_LEVEL := 3   ## 熟练度档位上限
## 7 天难度表（倍率作用于顾客间隔/耐心/外卖 ETA；第 7 天后封顶）
const DIFFICULTY_TABLE: Array[Dictionary] = [
	{"spawn": 1.00, "patience": 1.00, "eta": 1.00},
	{"spawn": 0.92, "patience": 0.95, "eta": 0.96},
	{"spawn": 0.85, "patience": 0.90, "eta": 0.92},
	{"spawn": 0.78, "patience": 0.85, "eta": 0.88},
	{"spawn": 0.72, "patience": 0.80, "eta": 0.84},
	{"spawn": 0.66, "patience": 0.75, "eta": 0.80},
	{"spawn": 0.60, "patience": 0.70, "eta": 0.76},
]
## 特殊事件类型（P7 简化：设备故障 / 恶劣天气）
enum SpecialEvent { NONE, EQUIPMENT_BREAK, BAD_WEATHER }
const EVENT_DURATION := {0: 0.0, 1: 8.0, 2: 15.0}  ## 事件时长（秒）
const EVENT_TRIGGER_INTERVAL := 30.0  ## 事件判定间隔（秒）
const EVENT_TRIGGER_CHANCE := 0.15    ## 每次判定触发概率

## 菜品类型 → 显示名映射（头顶订单标记/HUD 用；P7 由 DISHES 驱动）
const DISH_NAMES := {
	"kungpao": "宫保鸡丁",
	"yuxiang": "鱼香肉丝",
	"mapo": "麻婆豆腐",
}
## 菜品视觉占位色调（P7：现有素材着色区分；AI 素材 013 批次后替换为真实纹理）
const DISH_TINT := {
	"kungpao": Color.WHITE,
	"yuxiang": Color(0.95, 0.55, 0.50),
	"mapo": Color(0.95, 0.72, 0.35),
}

## 菜品占位色调（未知菜品回退白色）
func get_dish_tint(dish_type: String) -> Color:
	return DISH_TINT.get(dish_type, Color.WHITE)

# ==================== 枚举 ====================
enum OrderState {
	PENDING,    ## 等待制作
	COOKING,    ## 制作中
	READY,      ## 制作完成，等待送餐
	SERVED,     ## 已送达，顾客用餐中
	COMPLETED,  ## 顾客吃完，订单完成
	FAILED      ## 超时或失败（Phase 2启用）
}

## 外卖订单状态（P4）
enum TakeoutState {
	PACKING,  ## 待打包（玩家需加热并到外卖口打包）
	READY,    ## 已打包待取餐（骑手 ETA 归零后取走）
}

# ==================== 状态变量 ====================
## 当前活跃订单列表
## 结构: [{ id: int, state: OrderState, customer_id: int, dish_type: String,
##         patience_left: float, patience_total: float }]
var active_orders: Array[Dictionary] = []

## P4 外卖订单（独立队列，与堂食并行）
## 结构: [{ id: int, state: TakeoutState, dish_type: String, eta_left: float, eta_total: float, packed: bool }]
var takeaway_orders: Array[Dictionary] = []
var _takeaway_spawn_timer := TAKEOUT_ORDER_INTERVAL  ## 距离下一单外卖生成（秒）

# ===== P7 多菜品/难度/招牌菜/事件状态 =====
var specialty_dish := ""            ## 当日招牌菜（P7；打烊时可选，跨天保留至改选）
var dish_proficiency := {}          ## dish_type → 累计售出数（招牌菜熟练度）
var active_event := SpecialEvent.NONE  ## 当前特殊事件
var _event_time_left := 0.0         ## 事件剩余时长
var _event_timer := EVENT_TRIGGER_INTERVAL  ## 距下次事件判定
var _dish_override := ""            ## 随机菜测试钩子（空 = 真随机）

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
var day_cost_penalty := 0                ## 当日超时罚款（P4 外卖超时，计入成本）
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
		"patience_left": get_patience_time(),
		"patience_total": get_patience_time(),
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

## 顾客耐心（P6：慢工出细活卡牌 +15s；P7：难度递减）
func get_patience_time() -> float:
	return (patience_time + CardManager.get_value("patience_bonus")) * get_difficulty()["patience"]

## 每单好评数（P6：会员日卡牌 2）
func get_review_gain() -> int:
	return 2 if CardManager.has_flag("double_review") else 1

## 外卖骑手 ETA（P6：闪送合作卡牌 +15s；P7：难度递减）
func get_takeout_eta() -> float:
	return (TAKEOUT_ETA + CardManager.get_value("takeout_eta_bonus")) * get_difficulty()["eta"]

## 外卖超时罚款（P6：员工关怀卡牌减半）
func get_fail_penalty() -> int:
	return int(round(TAKEOUT_FAIL_PENALTY * CardManager.get_multiplier("penalty_multiplier")))


## 订单交付成功：计入当日收入与成本、好评，并发出 order_completed（结算入口）
## 输入: order_id (int)
## 输出: bool（是否成功结算）
## 副作用: 当日收入 + 菜品价、食材/耗材成本累加、好评 +1；累计 revenue/good_reviews 同步；
##         发出 order_completed / revenue_changed / reviews_changed / day_stats_changed
func complete_order(order_id: int) -> bool:
	for i in range(active_orders.size()):
		if active_orders[i]["id"] == order_id:
			var served_dish: String = active_orders[i]["dish_type"]
			active_orders.remove_at(i)
			var price := get_dish_price(false, served_dish)
			var gain := get_review_gain()
			revenue += price
			good_reviews += gain
			# P3：当日经济统计
			day_revenue += price
			day_cost_ingredients += INGREDIENT_COST_PER_ORDER
			day_cost_consumables += CONSUMABLE_COST_PER_ORDER
			day_good_reviews += gain
			# P7：招牌菜熟练度
			record_dish_served(served_dish)
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

# ==================== P4 外卖系统 ====================

## 生成一个外卖订单（独立队列，运行模式由 tick_takeaway 定时触发，测试可手动）
## 输出: int (order_id；打烊/达并发上限返回 -1)
func create_takeaway_order() -> int:
	if not is_shop_open:
		return -1
	# P7：恶劣天气外卖暂停（骑手不出车）
	if active_event == SpecialEvent.BAD_WEATHER:
		return -1
	if takeaway_orders.size() >= TAKEOUT_MAX_CONCURRENT:
		return -1
	var order_id := _next_order_id
	_next_order_id += 1
	var eta := get_takeout_eta()
	var order := {
		"id": order_id,
		"state": TakeoutState.PACKING,
		"dish_type": get_random_dish(),
		"eta_left": eta,
		"eta_total": eta,
		"packed": false,
	}
	takeaway_orders.append(order)
	takeaway_created.emit(order_id)
	print_rich("[color=cyan]Takeaway %d created (ETA %.1fs)[/color]" % [order_id, TAKEOUT_ETA])
	return order_id

## 每帧推进外卖：生成计时 + 全部订单 ETA；ETA 归零结算（已打包→骑手取餐完成 / 未打包→超时罚款）
func tick_takeaway(delta: float) -> void:
	if not is_shop_open:
		return
	_takeaway_spawn_timer -= delta
	if _takeaway_spawn_timer <= 0.0:
		_takeaway_spawn_timer = TAKEOUT_ORDER_INTERVAL
		create_takeaway_order()
	var finished: Array[int] = []
	for order in takeaway_orders:
		order["eta_left"] = maxf(order["eta_left"] - delta, 0.0)
		takeaway_state_changed.emit(order["id"], order["state"])
		if order["eta_left"] <= 0.0:
			finished.append(order["id"])
	for order_id in finished:
		if order_is_packed(order_id):
			complete_takeaway(order_id)
		else:
			fail_takeaway(order_id)

## 获取外卖订单（找不到返回空字典）
func get_takeaway(order_id: int) -> Dictionary:
	for order in takeaway_orders:
		if order["id"] == order_id:
			return order
	return {}

## 取一个待打包的外卖订单（外卖口打包入口；返回空字典表示无待打包单）
func get_pending_takeaway() -> Dictionary:
	for order in takeaway_orders:
		if not order["packed"]:
			return order
	return {}

## 判断外卖订单是否已打包
func order_is_packed(order_id: int) -> bool:
	var order := get_takeaway(order_id)
	return not order.is_empty() and order["packed"]

## 打包一份外卖（玩家在外卖口交付成品菜时调用；PACKING → READY）
## 输出: bool（是否成功打包）
func pack_takeaway(order_id: int) -> bool:
	for order in takeaway_orders:
		if order["id"] == order_id:
			if order["packed"]:
				return false
			order["packed"] = true
			order["state"] = TakeoutState.READY
			takeaway_state_changed.emit(order_id, TakeoutState.READY)
			print_rich("[color=yellow]Takeaway %d packed, rider arriving[/color]" % order_id)
			return true
	return false

## 移除外卖订单（完成/失败后清理）
func remove_takeaway(order_id: int) -> bool:
	for i in range(takeaway_orders.size()):
		if takeaway_orders[i]["id"] == order_id:
			takeaway_orders.remove_at(i)
			return true
	return false

## 外卖完成（已打包 + ETA 归零 → 骑手取餐）：收入=外卖价、好评+1、食材/耗材成本
## 输出: bool
func complete_takeaway(order_id: int) -> bool:
	var order := get_takeaway(order_id)
	if order.is_empty():
		return false
	var price := get_dish_price(true, order["dish_type"])
	var gain := get_review_gain()
	revenue += price
	good_reviews += gain
	day_revenue += price
	day_cost_ingredients += INGREDIENT_COST_PER_ORDER
	day_cost_consumables += CONSUMABLE_COST_PER_ORDER
	day_good_reviews += gain
	# P7：招牌菜熟练度
	record_dish_served(order["dish_type"])
	remove_takeaway(order_id)
	takeaway_completed.emit(order_id, price)
	revenue_changed.emit(revenue)
	reviews_changed.emit(good_reviews, bad_reviews)
	day_stats_changed.emit()
	print_rich("[color=green]Takeaway %d delivered! Revenue: %d (day %d)[/color]" % [order_id, price, day_revenue])
	return true

## 外卖超时（未打包 + ETA 归零 → 骑手空手离开）：罚款计入当日成本、差评 +1
## 输出: bool
func fail_takeaway(order_id: int) -> bool:
	var order := get_takeaway(order_id)
	if order.is_empty():
		return false
	bad_reviews += 1
	day_bad_reviews += 1
	var penalty := get_fail_penalty()
	day_cost_penalty += penalty
	remove_takeaway(order_id)
	takeaway_failed.emit(order_id)
	reviews_changed.emit(good_reviews, bad_reviews)
	day_stats_changed.emit()
	print_rich("[color=red]Takeaway %d timed out! Penalty %d (day %d)[/color]" % [order_id, penalty, day_cost_penalty])
	return true

## 打烊作废全部未完成外卖订单（不发 takeaway_failed——不属超时差评，同堂食作废处理）
func clear_takeaways() -> void:
	takeaway_orders.clear()
	_takeaway_spawn_timer = TAKEOUT_ORDER_INTERVAL

# ==================== P7 特殊事件 ====================

## 推进特殊事件（运行模式由 _process 调用）：事件倒计时结束清除；空闲到点判定随机触发
func tick_event(delta: float) -> void:
	if active_event != SpecialEvent.NONE:
		_event_time_left -= delta
		if _event_time_left <= 0.0:
			var ended := active_event
			active_event = SpecialEvent.NONE
			print_rich("[color=orange]Event ended: %s[/color]" % SpecialEvent.keys()[ended])
		return
	_event_timer -= delta
	if _event_timer <= 0.0:
		_event_timer = EVENT_TRIGGER_INTERVAL
		if randf() < EVENT_TRIGGER_CHANCE:
			_trigger_event()

func _trigger_event() -> void:
	var event_type := SpecialEvent.EQUIPMENT_BREAK if randi() % 2 == 0 else SpecialEvent.BAD_WEATHER
	active_event = event_type
	_event_time_left = EVENT_DURATION[event_type]
	event_started.emit(event_type)
	print_rich("[color=red]Event started: %s（%.0fs）[/color]" % [SpecialEvent.keys()[event_type], _event_time_left])

## 手动触发事件（测试用；真实触发走 tick_event 随机判定）
func force_event(event_type: int) -> void:
	active_event = event_type
	_event_time_left = EVENT_DURATION[event_type]
	event_started.emit(event_type)

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
	tick_takeaway(delta)
	tick_event(delta)
	tick_business_time(delta)


# ==================== P3 经济系统 ====================

## 每单收入：堂食 = 基础价；外卖 = 基础价 + 打包费 + 平台补贴 − 平台扣点（P4）
## P6 卡牌：platform_subsidy 外卖额外 +N；premium_price 全部价格 +X%
## P7：按菜品基础价（DISHES）；招牌菜价格加成（基础 20% + 熟练度每档 10%，上限 3 档）
func get_dish_price(is_takeout: bool = false, dish_type: String = "kungpao") -> int:
	var base: int = DISHES.get(dish_type, DISHES["kungpao"])["price"]
	if is_takeout:
		base = base + PACKING_FEE + PLATFORM_SUBSIDY - int(round(base * PLATFORM_CUT_RATE))
		base += int(CardManager.get_value("takeout_extra"))
	base = int(round(base * (1.0 + CardManager.get_value("price_modifier"))))
	if dish_type == specialty_dish and specialty_dish != "":
		var prof_level := get_specialty_prof_level(dish_type)
		base = int(round(base * (1.0 + SPECIALTY_PRICE_BONUS + SPECIALTY_PROF_BONUS * prof_level)))
	return base

## 随机一道可点菜（堂食/外卖下单用；P7 多菜品）
## _dish_override 为测试钩子（冒烟测试固定菜品保证确定性；空串 = 真随机）
func get_random_dish() -> String:
	if _dish_override != "":
		return _dish_override
	return L1_DISHES[randi() % L1_DISHES.size()]

## 当前难度档（按天数，第 7 天后封顶）
func get_difficulty() -> Dictionary:
	return DIFFICULTY_TABLE[clampi(day - 1, 0, DIFFICULTY_TABLE.size() - 1)]

## 招牌菜熟练度档位（每 SPECIALTY_PROF_PER_LEVEL 次售出 +1 档，上限封顶）
func get_specialty_prof_level(dish_type: String) -> int:
	return mini(int(dish_proficiency.get(dish_type, 0)) / SPECIALTY_PROF_PER_LEVEL, SPECIALTY_PROF_MAX_LEVEL)

## 记录菜品售出（招牌菜熟练度 +1；P7）
func record_dish_served(dish_type: String) -> void:
	dish_proficiency[dish_type] = int(dish_proficiency.get(dish_type, 0)) + 1

## 设置当日招牌菜（打烊时选择次日生效；非法菜品置空）
func set_specialty_dish(dish_type: String) -> void:
	specialty_dish = dish_type if DISHES.has(dish_type) else ""

## 特殊事件是否生效（微波炉/外卖系统查询）
func is_event_active(event_type: int) -> bool:
	return active_event == event_type

## 当日房租（P6：房东豁免卡牌减半）
func get_day_rent() -> int:
	return int(round(RENT_COST_PER_DAY * CardManager.get_multiplier("rent_multiplier")))

## 当日总成本（食材 + 耗材 + 水电 + 超时罚款 + 房租）
func get_day_total_cost() -> int:
	return day_cost_ingredients + day_cost_consumables + day_cost_utilities + day_cost_penalty + get_day_rent()

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
	# P4：外卖订单同堂食作废
	clear_takeaways()

	# P6：利润加成卡（仅正利润放大，避免亏本被营销费放大）
	var raw_profit := get_day_profit()
	var profit := int(round(raw_profit * CardManager.get_multiplier("profit_multiplier"))) if raw_profit > 0 else raw_profit
	money += profit
	var result := {
		"day": day,
		"revenue": day_revenue,
		"cost_ingredients": day_cost_ingredients,
		"cost_consumables": day_cost_consumables,
		"cost_utilities": day_cost_utilities,
		"cost_penalty": day_cost_penalty,
		"cost_rent": get_day_rent(),
		"cost_total": get_day_total_cost(),
		"profit": profit,
		"good_reviews": day_good_reviews,
		"bad_reviews": day_bad_reviews,
		"money": money,
	}
	last_settlement = result
	# P6：结算数据定格后再清空卡牌构筑（每日重新抽卡；不影响本日结算数值）
	CardManager.reset_cards()
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
	day_cost_penalty = 0
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
