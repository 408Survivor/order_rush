## 文件: scripts/systems/customer_manager.gd
## 职责: 顾客系统管理器（#103 窗口店双队列）：点单队列（下单，上限 max_queue）→ 取餐队列（等餐，不限额）
##       按固定间隔生成顾客、分配两套槽位、维护队列索引；交付在取餐台完成后由 on_order_served 驱动离店
## 依赖: Customer.tscn（scripts/entities/customer.gd）；槽位几何单一权威 = LayoutManager
##       （ORDER_QUEUE_FRONT 左延 / PICKUP_QUEUE_FRONT 右延 / SPAWN_POINT 店外左缘刷出）
## 注意: 生成闸门 = 点单队列未满（与 MAX_CONCURRENT_ORDERS 对齐，控制屏上顾客总量）

@tool
extends Node2D

# ==================== 常量 ====================
const ParticleFX := preload("res://scripts/systems/particle_fx.gd")
const CUSTOMER_SCENE := preload("res://scenes/entities/Customer.tscn")

# ==================== 导出变量 ====================
## 生成间隔（秒）
@export var spawn_interval := 3.0
## 排队槽位间距（像素），默认取 LayoutManager.QUEUE_SPACING（200 > 顾客碰撞直径 130）
@export var queue_spacing := LayoutManager.QUEUE_SPACING
## 点单队列上限（= MAX_CONCURRENT_ORDERS 对齐；取餐队列不限额）
@export var max_queue := 3

# ==================== 节点引用 ====================
@onready var spawn_timer: Timer = $SpawnTimer

# ==================== 状态变量 ====================
## 点单队列（走向/已到点单槽位的顾客；spawn 即入队防撞槽）
var _order_queue: Array[Node] = []
## 取餐队列（已下单、走向/已在取餐槽位等餐的顾客）
var _pickup_queue: Array[Node] = []

## 在场顾客数（已生成未移除；打烊清场等统计用）
var _active_count := 0

# ==================== 生命周期 ====================

func _ready() -> void:
	add_to_group("customer_manager")
	spawn_timer.wait_time = get_effective_interval()
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	# P2：订单超时 → 对应顾客离店（防重复连接：脚本重载/编辑器进程会多次 _ready；
	# 注意：is_connected 防护在多 CustomerManager 实例下仅首个实例订阅，本项目单实例无碍）
	if not GameStateManager.order_failed.is_connected(_on_order_failed):
		GameStateManager.order_failed.connect(_on_order_failed)
	# P6：客流高峰卡生效后即时刷新生成间隔
	if not CardManager.cards_changed.is_connected(_on_cards_changed):
		CardManager.cards_changed.connect(_on_cards_changed)
	# @tool：编辑器进程（含编辑器内部检查实例化）不启动定时生成，仅测试/运行时手动触发
	if Engine.is_editor_hint():
		spawn_timer.stop()
	else:
		spawn_timer.start()
	print_rich("[color=green]CustomerManager ready (interval=%.1fs, max_queue=%d)[/color]" % [get_effective_interval(), max_queue])

## 实际生成间隔（P6：客流高峰卡 -25%；P7：难度递增）
func get_effective_interval() -> float:
	return spawn_interval * CardManager.get_multiplier("spawn_multiplier") * GameStateManager.get_difficulty()["spawn"]

## P6：卡牌变化 → 刷新生成间隔（定时器在下次启动时生效）
func _on_cards_changed() -> void:
	spawn_timer.wait_time = get_effective_interval()

# ==================== 生成 ====================

## 生成一名顾客并分配点单槽位（spawn 即入点单队列，行走中与已排队的顾客互不撞槽）
func spawn_customer() -> Node2D:
	# P3：已打烊不再接客（防手动/时序生成）
	if not GameStateManager.is_shop_open:
		print_rich("[color=orange]CustomerManager: 已打烊，拒绝生成顾客[/color]")
		return null
	# #103：生成闸门 = 点单队列未满（取餐队列不限额——已下单顾客必须能等餐）
	if _order_queue.size() >= max_queue:
		print_rich("[color=orange]CustomerManager: 点单队列已满（%d/%d），暂不生成[/color]" % [_order_queue.size(), max_queue])
		return null

	var customer: CharacterBody2D = CUSTOMER_SCENE.instantiate()
	customer.queue_slot = _get_order_slot(_order_queue.size())
	customer.global_position = LayoutManager.SPAWN_POINT
	add_child(customer)
	customer.arrived.connect(_on_customer_arrived.bind(customer))
	customer.tree_exited.connect(_on_customer_left.bind(customer))
	_order_queue.append(customer)
	_active_count += 1
	print_rich("[color=cyan]Customer spawned (order queue: %d, pickup queue: %d)[/color]" % [_order_queue.size(), _pickup_queue.size()])
	return customer

## 点单槽位：队首 = ORDER_QUEUE_FRONT，队伍沿人行道向左延伸
func _get_order_slot(index: int) -> Vector2:
	return LayoutManager.ORDER_QUEUE_FRONT - Vector2(index * queue_spacing, 0)

## 取餐槽位：队首 = PICKUP_QUEUE_FRONT，队伍沿人行道向右延伸
func _get_pickup_slot(index: int) -> Vector2:
	return LayoutManager.PICKUP_QUEUE_FRONT + Vector2(index * queue_spacing, 0)

# ==================== 队列管理 ====================

## 顾客到达槽位：phase 0（点单槽位）→ 下单并转取餐队列；phase 1（取餐槽位）→ 就位等餐
func _on_customer_arrived(customer: Node2D) -> void:
	if customer.get("phase") == 0:
		_create_order_for_customer(customer)
		# 下单完成 → 转取餐队列（点单槽位让出，补位前移）
		_order_queue.erase(customer)
		_pickup_queue.append(customer)
		customer.call("walk_to_pickup", _get_pickup_slot(_pickup_queue.size() - 1))
		_shift_order_queue()
		print_rich("[color=green]Customer ordered, moving to pickup queue (total %d)[/color]" % _pickup_queue.size())
	# phase 1 到达 = 就位等餐（状态已由 customer._arrive 置 WAITING，无需额外登记）

## 为单个顾客生成订单（到达点单槽位即下单；已有订单则跳过）
## 注意: 前置条件 max_queue <= MAX_CONCURRENT_ORDERS（当前 3==3），下单失败仅作防御日志
func _create_order_for_customer(customer: Node2D) -> void:
	if customer.get("order_id") != -1:
		return
	var order_id := GameStateManager.create_order(customer.get_instance_id(), GameStateManager.get_random_dish())
	if order_id != -1:
		customer.order_id = order_id
		customer.set_order_label("宫保鸡丁")
		print_rich("[color=cyan]Order #%d bound to customer %s[/color]" % [order_id, customer.name])
	else:
		push_warning("CustomerManager: 下单失败（并发订单已满），顾客 %s 将无单等待" % customer.name)

## 点单队列队首（当前点单服务对象），空队返回 null
func get_front_customer() -> Node2D:
	if _order_queue.is_empty():
		return null
	return _order_queue[0]

## 点单/取餐队列人数
func get_order_queue_count() -> int:
	return _order_queue.size()

func get_pickup_queue_count() -> int:
	return _pickup_queue.size()

## 总在场排队人数（兼容旧接口）
func get_queue_count() -> int:
	return _order_queue.size() + _pickup_queue.size()

## 移除顾客（离店/清场时调用）
func remove_customer(customer: Node2D) -> void:
	_order_queue.erase(customer)
	_pickup_queue.erase(customer)

## 取餐台交付完成（PickupCounter.serve_with 调用）：对应顾客（无论走位中还是等餐中）收菜离店
## 注意：订单已由 complete_order 结算（经济/好评/繁荣度），此处只做顾客侧清理
func on_order_served(order_id: int) -> void:
	var customer := _find_customer_by_order(order_id)
	if customer == null:
		return
	customer.order_id = -1
	customer.call("mark_served")
	_pickup_queue.erase(customer)
	customer.leave(LayoutManager.SPAWN_POINT)
	_shift_pickup_queue()
	print_rich("[color=green]Customer served via pickup counter, leaving[/color]")

## 订单超时失败：找到对应顾客 → 离店 → 补位（P2 差评路径；#103 覆盖双队列）
func _on_order_failed(order_id: int) -> void:
	var customer := _find_customer_by_order(order_id)
	if customer == null:
		return
	customer.order_id = -1
	customer.clear_order_label()
	_order_queue.erase(customer)
	_pickup_queue.erase(customer)
	customer.leave(LayoutManager.SPAWN_POINT)
	# P9：超时警示粒子
	ParticleFX.burst(customer, Vector2(0, -50), Color(1.0, 0.35, 0.3), 8, Vector2(0, -200), 160.0, 0.5)
	_shift_order_queue()
	_shift_pickup_queue()
	print_rich("[color=red]Customer %s left due to failed order #%d[/color]" % [customer.name, order_id])

## 按订单 id 找在场顾客（双队列 + 子节点兜底——覆盖走位中的顾客）
func _find_customer_by_order(order_id: int) -> Node2D:
	for customer in get_children():
		if customer.is_in_group("customer") and customer.get("order_id") == order_id:
			return customer
	return null

## 队列补位：_order_queue[i] 走向点单槽位 i（队首 = 点单台）
func _shift_order_queue() -> void:
	for i in range(_order_queue.size()):
		_order_queue[i].walk_to(_get_order_slot(i))

## 队列补位：_pickup_queue[j] 走向取餐槽位 j（队首 = 取餐台）
func _shift_pickup_queue() -> void:
	for j in range(_pickup_queue.size()):
		_pickup_queue[j].walk_to(_get_pickup_slot(j))

## 顾客节点离开场景树时回收在场计数并清理队列（防悬空引用）
func _on_customer_left(customer: Node2D) -> void:
	_active_count = maxi(_active_count - 1, 0)
	_order_queue.erase(customer)
	_pickup_queue.erase(customer)

# ==================== 内部 ====================

func _on_spawn_timer_timeout() -> void:
	spawn_customer()

# ==================== 日循环清场（P3） ====================

## 打烊清场：停止接客并移除全部在场顾客（含排队与行走中）
## 副作用: spawn_timer 停止、双队列/计数清零；顾客节点 queue_free（tree_exited 会走 _on_customer_left 防御回收）
func clear_customers() -> void:
	spawn_timer.stop()
	var all_customers := get_children().filter(func(c: Node) -> bool: return c.is_in_group("customer"))
	_order_queue.clear()
	_pickup_queue.clear()
	_active_count = 0
	for customer in all_customers:
		customer.queue_free()
	print_rich("[color=yellow]CustomerManager: 打烊清场，移除 %d 名顾客[/color]" % all_customers.size())

## 新一天开始接客（由 main_scene 监听 day_started 调用；编辑器进程不自动启动，冒烟测试手动触发）
func start_serving() -> void:
	if Engine.is_editor_hint():
		return
	spawn_timer.start()
	print_rich("[color=green]CustomerManager: 开始接客（%.1fs 间隔）[/color]" % spawn_interval)
