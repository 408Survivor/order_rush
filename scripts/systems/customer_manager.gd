## 文件: scripts/systems/customer_manager.gd
## 职责: 顾客系统管理器：按固定间隔生成顾客、分配排队槽位、维护队列索引
## 依赖: Customer.tscn（scripts/entities/customer.gd）
## 注意: 队列队首 = 当前服务对象（供订单系统索引，见 issue #3 验收）

@tool
extends Node2D

# ==================== 常量 ====================
const CUSTOMER_SCENE := preload("res://scenes/entities/Customer.tscn")

# ==================== 导出变量 ====================
## 生成间隔（秒）
@export var spawn_interval := 3.0
## 排队槽位间距（像素），需大于顾客碰撞直径 200
@export var queue_spacing := 220.0
## 最大在场顾客数（超出不再生成；3 人 = 槽位 0-2 均在屏幕内）
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

	spawn_timer.wait_time = spawn_interval
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	# @tool：编辑器进程（含编辑器内部检查实例化）不启动定时生成，仅测试/运行时手动触发
	if Engine.is_editor_hint():
		spawn_timer.stop()
	else:
		spawn_timer.start()
	print_rich("[color=green]CustomerManager ready (interval=%.1fs, max_queue=%d)[/color]" % [spawn_interval, max_queue])

# ==================== 生成 ====================

## 生成一名顾客并分配槽位（槽位按在场数分配，行走中与已排队的顾客互不撞槽）
func spawn_customer() -> Node2D:
	if _spawn_point == null or _counter_point == null:
		return null
	if _active_count >= max_queue:
		print_rich("[color=orange]CustomerManager: 队伍已满（%d/%d），暂不生成[/color]" % [_active_count, max_queue])
		return null

	var customer: CharacterBody2D = CUSTOMER_SCENE.instantiate()
	customer.queue_slot = _get_slot_position(_active_count)
	customer.global_position = _spawn_point.global_position
	add_child(customer)
	customer.arrived.connect(_on_customer_arrived.bind(customer))
	customer.tree_exited.connect(_on_customer_left.bind(customer))
	_active_count += 1
	print_rich("[color=cyan]Customer spawned (queue before: %d, active: %d)[/color]" % [queue.size(), _active_count])
	return customer

## 计算第 index 位顾客的槽位（队首在柜台，队伍沿柜台反向延伸）
func _get_slot_position(index: int) -> Vector2:
	return _counter_point.global_position - Vector2(index * queue_spacing, 0)

# ==================== 队列管理 ====================

## 顾客到达槽位后登记入队
func _on_customer_arrived(customer: Node2D) -> void:
	if customer in queue:
		return
	queue.append(customer)
	print_rich("[color=green]Customer queued: #%d (total %d)[/color]" % [queue.size() - 1, queue.size()])

## 队首顾客（当前服务对象），空队返回 null
func get_front_customer() -> Node2D:
	if queue.is_empty():
		return null
	return queue[0]

## 当前排队人数
func get_queue_count() -> int:
	return queue.size()

## 移除顾客（服务完成/离开时调用，issue #4 使用）
func remove_customer(customer: Node2D) -> void:
	var idx := queue.find(customer)
	if idx != -1:
		queue.remove_at(idx)
	print_rich("[color=yellow]Customer removed (left in queue: %d)[/color]" % queue.size())

## 顾客节点离开场景树时回收在场计数并清理队列（防悬空引用）
func _on_customer_left(customer: Node2D) -> void:
	_active_count = maxi(_active_count - 1, 0)
	var idx := queue.find(customer)
	if idx != -1:
		queue.remove_at(idx)

# ==================== 内部 ====================

func _on_spawn_timer_timeout() -> void:
	spawn_customer()
