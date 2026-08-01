## 文件: scripts/entities/customer.gd
## 职责: 顾客实体：从入口走到指定槽位排队等待，收菜后离开（Phase 1 简化版）
## 依赖: 由 CustomerManager 实例化并分配槽位；收菜信号供管理器结算
## 注意: 寻路保持简单（直线移动），顾客间碰撞由 CollisionShape2D 保证不重叠

@tool
extends CharacterBody2D

# ==================== 信号 ====================
## 到达自己的排队槽位时发出（供 CustomerManager 登记队列）
signal arrived
## 收到成品菜时发出（供 CustomerManager 结算订单）
signal served(dish: Node2D)

# ==================== 枚举 ====================
enum CustomerState {
	WALKING,  ## 走向槽位
	WAITING,  ## 已在槽位排队等待
	SERVED,   ## 已收菜，准备离开
}

# ==================== 常量 ====================
const ARRIVE_DISTANCE := 12.0  ## 到达判定阈值（像素）

# ==================== 导出变量 ====================
## 移动速度（像素/秒）
@export var move_speed := 160.0
## 排队槽位目标位置（由管理器分配）
@export var queue_slot: Vector2 = Vector2.ZERO

# ==================== 节点引用 ====================
@onready var sprite: Sprite2D = $Sprite2D
@onready var order_label: Label = $OrderLabel

# ==================== 状态变量 ====================
var state := CustomerState.WALKING
## 关联的订单 id（管理器下单时设置）
var order_id := -1

var _leaving := false

# ==================== 生命周期 ====================

func _ready() -> void:
	add_to_group("customer")
	print_rich("[color=green]Customer spawned at %s, heading to %s[/color]" % [str(global_position), str(queue_slot)])

func _physics_process(delta: float) -> void:
	if state != CustomerState.WALKING:
		return

	# 直线走向目标（槽位或出口，无需 A*，见 issue #3/#4 上下文）
	var to_target := queue_slot - global_position
	if to_target.length() <= ARRIVE_DISTANCE:
		_arrive()
		return

	if Engine.is_editor_hint():
		# @tool：编辑器进程 PhysicsServer 不步进，move_and_slide 碰撞状态陈旧会传送；
		# 冒烟测试环境直接朝目标位移（不重叠由槽位间距 220 > 碰撞直径 200 保证，
		# 物理碰撞留给运行模式兜底）
		global_position = global_position.move_toward(queue_slot, move_speed * delta)
		return

	velocity = to_target.normalized() * move_speed
	move_and_slide()

# ==================== 状态管理 ====================

## 到达目标：入队或离店
func _arrive() -> void:
	velocity = Vector2.ZERO
	if _leaving:
		print_rich("[color=gray]Customer left the store[/color]")
		queue_free()
		return
	state = CustomerState.WAITING
	print_rich("[color=cyan]Customer arrived at slot %s[/color]" % str(global_position))
	arrived.emit()

## 是否已就位排队
func is_waiting() -> bool:
	return state == CustomerState.WAITING

## 是否可接收成品菜（有订单且手持为成品菜）
func can_accept_dish(item: Node2D) -> bool:
	if state != CustomerState.WAITING:
		return false
	if order_id == -1:
		return false
	return item.is_in_group("dish")

## 接收成品菜：物品销毁，状态置 SERVED，发出 served 信号（管理器结算）
func receive_dish(dish: Node2D) -> void:
	state = CustomerState.SERVED
	clear_order_label()
	if dish.get_parent() != null:
		dish.get_parent().remove_child(dish)
	dish.queue_free()
	print_rich("[color=green]Customer received dish (order #%d)[/color]" % order_id)
	served.emit(dish)

## 显示订单标记（队首头顶，供玩家识别服务对象）
func set_order_label(text: String) -> void:
	order_label.text = text
	order_label.visible = true

func clear_order_label() -> void:
	order_label.visible = false

## 走向出口并离店（收菜后由管理器调用）
func leave(exit_pos: Vector2) -> void:
	_leaving = true
	queue_slot = exit_pos
	state = CustomerState.WALKING
	print_rich("[color=orange]Customer leaving towards %s[/color]" % str(exit_pos))

## 走向新槽位（队列补位时由管理器调用）
func walk_to(slot: Vector2) -> void:
	if _leaving:
		return
	queue_slot = slot
	state = CustomerState.WALKING
