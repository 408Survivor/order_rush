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
@onready var order_label: RichTextLabel = $OrderLabel

# ==================== 状态变量 ====================
var state := CustomerState.WALKING
## 关联的订单 id（管理器下单时设置）
var order_id := -1

var _leaving := false

## 上次应用的耐心颜色（避免每帧 add_theme_color_override 分配开销）
var _last_label_color := Color(-1, -1, -1, -1)

# ==================== 生命周期 ====================

func _ready() -> void:
	add_to_group("interactable")
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
		# 冒烟测试环境直接朝目标位移（不重叠由槽位间距 150 > 碰撞直径 130 保证，
		# 物理碰撞留给运行模式兜底）
		global_position = global_position.move_toward(queue_slot, move_speed * delta)
		return

	velocity = to_target.normalized() * move_speed
	move_and_slide()

func _process(_delta: float) -> void:
	# 每帧刷新头顶订单显示（菜品 + 耐心剩余秒数 + 颜色），无副作用
	_update_order_display()

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

## 是否可接收成品菜（有订单、菜品匹配且手持为成品菜；P2 校验菜品类型）
func can_accept_dish(item: Node2D) -> bool:
	if state != CustomerState.WAITING:
		return false
	if order_id == -1:
		return false
	if not item.is_in_group("dish"):
		return false
	var order := GameStateManager.get_order(order_id)
	if order.is_empty():
		return false  # 订单已移除（超时等），不可交付
	return str(item.get("dish_type")) == str(order["dish_type"])

## 接收成品菜：物品销毁，状态置 SERVED，发出 served 信号（管理器结算）
func receive_dish(dish: Node2D) -> void:
	state = CustomerState.SERVED
	clear_order_label()
	if dish.get_parent() != null:
		dish.get_parent().remove_child(dish)
	dish.queue_free()
	print_rich("[color=green]Customer received dish (order #%d)[/color]" % order_id)
	served.emit(dish)

## 显示订单标记（头顶，供玩家识别服务对象；文本与耐心倒计时由 _process 每帧刷新）
func set_order_label(text: String) -> void:
	order_label.text = text
	order_label.visible = true

func clear_order_label() -> void:
	order_label.visible = false

# ==================== 耐心显示（P2） ====================

## 每帧刷新头顶订单显示：菜品名 + 剩余秒数，颜色随耐心（>50% 绿 / >20% 黄 / 否则红）
func _update_order_display() -> void:
	if order_id == -1 or not order_label.visible:
		return
	var order := GameStateManager.get_order(order_id)
	if order.is_empty():
		return  # 订单已移除（如超时后等待离店），保持现状
	var total: float = order["patience_total"]
	var left: float = order["patience_left"]
	var ratio := 1.0 if total <= 0.0 else left / total
	order_label.text = "%s %s %ds" % [UITheme.icon(UITheme.ICON_PLATE, 18), GameStateManager.get_dish_display_name(str(order["dish_type"])), int(ceil(left))]
	var color := UITheme.COLOR_GREEN  # >50% 绿
	if ratio <= 0.5 and ratio > 0.2:
		color = UITheme.COLOR_YELLOW  # ≤50% 黄
	elif ratio <= 0.2:
		color = UITheme.COLOR_RED     # ≤20% 红
	if color != _last_label_color:
		order_label.add_theme_color_override("default_color", color)
		_last_label_color = color

## 走向出口并离店（收菜后由管理器调用；离店时禁用碰撞，避免与补位顾客迎面卡住）
func leave(exit_pos: Vector2) -> void:
	_leaving = true
	queue_slot = exit_pos
	state = CustomerState.WALKING
	collision_layer = 0
	collision_mask = 0
	print_rich("[color=orange]Customer leaving towards %s[/color]" % str(exit_pos))

## 走向新槽位（队列补位时由管理器调用）
func walk_to(slot: Vector2) -> void:
	if _leaving:
		return
	queue_slot = slot
	state = CustomerState.WALKING
