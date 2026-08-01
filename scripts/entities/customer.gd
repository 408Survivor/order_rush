## 文件: scripts/entities/customer.gd
## 职责: 顾客实体：从入口走到指定槽位排队等待（Phase 1 简化版）
## 依赖: 由 CustomerManager 实例化并分配槽位
## 注意: 寻路保持简单（直线移动），顾客间碰撞由 CollisionShape2D 保证不重叠

@tool
extends CharacterBody2D

# ==================== 信号 ====================
## 到达自己的排队槽位时发出（供 CustomerManager 登记队列）
signal arrived

# ==================== 枚举 ====================
enum CustomerState {
	WALKING,  ## 走向槽位
	WAITING,  ## 已在槽位排队等待
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

# ==================== 状态变量 ====================
var state := CustomerState.WALKING

# ==================== 生命周期 ====================

func _ready() -> void:
	add_to_group("customer")
	print_rich("[color=green]Customer spawned at %s, heading to %s[/color]" % [str(global_position), str(queue_slot)])

func _physics_process(delta: float) -> void:
	if state != CustomerState.WALKING:
		return

	# 直线走向目标槽位（无需 A*，见 issue #3 上下文）
	var to_slot := queue_slot - global_position
	if to_slot.length() <= ARRIVE_DISTANCE:
		_arrive()
		return

	if Engine.is_editor_hint():
		# @tool：编辑器进程 PhysicsServer 不步进，move_and_slide 碰撞状态陈旧会传送；
		# 冒烟测试环境直接朝目标位移（不重叠由槽位间距 220 > 碰撞直径 200 保证，
		# 物理碰撞留给运行模式兜底）
		global_position = global_position.move_toward(queue_slot, move_speed * delta)
		return

	velocity = to_slot.normalized() * move_speed
	move_and_slide()

# ==================== 状态管理 ====================

## 到达槽位：停下并通知管理器
func _arrive() -> void:
	velocity = Vector2.ZERO
	state = CustomerState.WAITING
	print_rich("[color=cyan]Customer arrived at slot %s[/color]" % str(global_position))
	arrived.emit()

## 是否已就位排队
func is_waiting() -> bool:
	return state == CustomerState.WAITING
