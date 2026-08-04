## 文件: scripts/systems/customer_manager.gd
## 职责: 顾客系统管理器：按固定间隔生成顾客、分配排队槽位、维护队列索引
## 依赖: Customer.tscn（scripts/entities/customer.gd）
## 注意: 队列队首 = 当前服务对象（供订单系统索引，见 issue #3 验收）

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
## 最大在场顾客数（玩法参数；布局空间按 LayoutManager.QUEUE_CAPACITY=5 预留）
@export var max_queue := 3

# ==================== 节点引用 ====================
@onready var spawn_timer: Timer = $SpawnTimer

# ==================== 状态变量 ====================
## 已就位的顾客队列（队首 index 0）
var queue: Array[Node] = []

## 在场顾客数（已生成未移除；槽位按它分配，避免与行走中的顾客撞槽）
var _active_count := 0

var _spawn_point: Node2D = null
var _counter_point: Node2D = null

# ==================== 生命周期 ====================

func _ready() -> void:
	add_to_group("customer_manager")
	# 场景提供入口与柜台标记（MainScene 中配置，均为 MainScene 直接子节点）
	_spawn_point = get_node_or_null("../SpawnPoint")
	_counter_point = get_node_or_null("../CounterPoint")
	if _spawn_point == null or _counter_point == null:
		push_warning("CustomerManager: SpawnPoint/CounterPoint 未找到（应为 MainScene 的直接子节点）")

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

## 生成一名顾客并分配槽位（槽位按在场数分配，行走中与已排队的顾客互不撞槽）
func spawn_customer() -> Node2D:
	if _spawn_point == null or _counter_point == null:
		return null
	# P3：已打烊不再接客（防手动/时序生成）
	if not GameStateManager.is_shop_open:
		print_rich("[color=orange]CustomerManager: 已打烊，拒绝生成顾客[/color]")
		return null
	if _active_count >= max_queue:
		print_rich("[color=orange]CustomerManager: 队伍已满（%d/%d），暂不生成[/color]" % [_active_count, max_queue])
		return null

	var customer: CharacterBody2D = CUSTOMER_SCENE.instantiate()
	customer.queue_slot = _get_slot_position(_active_count)
	customer.global_position = _spawn_point.global_position
	add_child(customer)
	customer.arrived.connect(_on_customer_arrived.bind(customer))
	customer.served.connect(_on_customer_served.bind(customer))
	customer.tree_exited.connect(_on_customer_left.bind(customer))
	_active_count += 1
	print_rich("[color=cyan]Customer spawned (queue before: %d, active: %d)[/color]" % [queue.size(), _active_count])
	return customer

## 计算第 index 位顾客的槽位（队首在柜台，队伍沿柜台反向延伸）
func _get_slot_position(index: int) -> Vector2:
	return _counter_point.global_position - Vector2(index * queue_spacing, 0)

# ==================== 队列管理 ====================

## 顾客到达槽位后登记入队；每位顾客到达即生成订单（P2 多单并发，不再仅队首）
func _on_customer_arrived(customer: Node2D) -> void:
	if customer in queue:
		return
	queue.append(customer)
	print_rich("[color=green]Customer queued: #%d (total %d)[/color]" % [queue.size() - 1, queue.size()])
	_create_order_for_customer(customer)

## 为单个顾客生成订单（到达即下单；已有订单则跳过）
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

## 队首顾客（当前服务对象），空队返回 null
func get_front_customer() -> Node2D:
	if queue.is_empty():
		return null
	return queue[0]

## 当前排队人数
func get_queue_count() -> int:
	return queue.size()

## 移除顾客（服务完成/离开时调用）
func remove_customer(customer: Node2D) -> void:
	var idx := queue.find(customer)
	if idx != -1:
		queue.remove_at(idx)
	print_rich("[color=yellow]Customer removed (left in queue: %d)[/color]" % queue.size())

## 顾客收菜后：结算订单（好评）→ 顾客离店 → 队列补位
## 注意：served 信号带 (dish) 参数 + bind(customer) → 回调签名 (dish, customer)
## P2：每位顾客到达即下单，补位顾客已有订单，无需重建
func _on_customer_served(_dish: Node2D, customer: Node2D) -> void:
	if customer.order_id != -1:
		GameStateManager.complete_order(customer.order_id)
		customer.order_id = -1
	# 从队列移除（交付后离店，无需区分是否队首）
	remove_customer(customer)
	# 顾客走向出口离店
	customer.leave(_spawn_point.global_position)
	# 队列补位：剩余顾客前移一格（新队首已有订单）
	_shift_queue()

## 订单超时失败：找到对应顾客 → 离店 → 补位（P2 差评路径）
func _on_order_failed(order_id: int) -> void:
	for customer in queue:
		if customer.get("order_id") == order_id:
			customer.order_id = -1
			customer.clear_order_label()
			remove_customer(customer)
			customer.leave(_spawn_point.global_position)
			# P9：超时警示粒子
			ParticleFX.burst(customer, Vector2(0, -50), Color(1.0, 0.35, 0.3), 8, Vector2(0, -200), 160.0, 0.5)
			_shift_queue()
			print_rich("[color=red]Customer %s left due to failed order #%d[/color]" % [customer.name, order_id])
			return

## 队列补位：queue[i] 走向槽位 i（队首 = 柜台）
func _shift_queue() -> void:
	for i in range(queue.size()):
		var customer: Node2D = queue[i]
		customer.walk_to(_get_slot_position(i))
	print_rich("[color=cyan]Queue shifted: %d customer(s) move up[/color]" % queue.size())

## 顾客节点离开场景树时回收在场计数并清理队列（防悬空引用）
func _on_customer_left(customer: Node2D) -> void:
	_active_count = maxi(_active_count - 1, 0)
	var idx := queue.find(customer)
	if idx != -1:
		queue.remove_at(idx)

# ==================== 内部 ====================

func _on_spawn_timer_timeout() -> void:
	spawn_customer()

# ==================== 日循环清场（P3） ====================

## 打烊清场：停止接客并移除全部在场顾客（含排队与行走中）
## 副作用: spawn_timer 停止、队列/计数清零；顾客节点 queue_free（tree_exited 会走 _on_customer_left 防御回收）
func clear_customers() -> void:
	spawn_timer.stop()
	var all_customers := get_children().filter(func(c: Node) -> bool: return c.is_in_group("customer"))
	queue.clear()
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
