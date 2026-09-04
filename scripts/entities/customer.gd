## 文件: scripts/entities/customer.gd
## 职责: 顾客实体（#103 窗口店）：店外刷出 → 点单槽位下单（ORDERING）→ 取餐槽位等餐（WAITING）→ 离店
## 依赖: 由 CustomerManager 实例化并分配槽位；交付在取餐台（PickupCounter）完成，不经顾客本体
## 注意: #93 寻路改 NavigationAgent2D——MainScene 的 NavRegion 导航网格（#103 店外 L 形）绕行不卡不穿模；
##       顾客间碰撞由 CollisionShape2D 保证不重叠（mask=16 不变，家具靠寻路绕行而非碰撞）；
##       #103 起顾客不在 interactable 组——窗口店顾客与玩家无直接交互

@tool
extends CharacterBody2D

# ==================== 信号 ====================
## 到达当前阶段槽位时发出（phase 0=点单槽位 / 1=取餐槽位，供 CustomerManager 登记双队列）
signal arrived

# ==================== 枚举 ====================
enum CustomerState {
	WALKING,   ## 走向槽位（点单或取餐）
	ORDERING,  ## 已到点单槽位（下单即刻转取餐走位，此态为到达瞬间语义）
	WAITING,   ## 已在取餐槽位等餐
	SERVED,    ## 已收菜，准备离开
}

# ==================== 常量 ====================
const ARRIVE_DISTANCE := 12.0  ## 到达判定阈值（像素）
const ParticleFX := preload("res://scripts/systems/particle_fx.gd")  ## P9 粒子工具

# ==================== 导出变量 ====================
## 移动速度（像素/秒）
@export var move_speed := 160.0
## 排队槽位目标位置（由管理器分配）
@export var queue_slot: Vector2 = Vector2.ZERO

# ==================== 节点引用 ====================
@onready var sprite: Sprite2D = $Sprite2D
@onready var order_label: RichTextLabel = $OrderLabel
@onready var nav_agent: NavigationAgent2D = $NavigationAgent2D  ## #93 寻路（NavRegion 由 MainScene 生成）

# ==================== 状态变量 ====================
var state := CustomerState.WALKING
## 关联的订单 id（管理器下单时设置）
var order_id := -1
## 走位阶段（#103：0=走向点单槽位，1=走向取餐槽位）
var phase := 0

var _leaving := false

## 上次应用的耐心颜色（避免每帧 add_theme_color_override 分配开销）
var _last_label_color := Color(-1, -1, -1, -1)

# ==================== 生命周期 ====================

func _ready() -> void:
	add_to_group("customer")
	_sync_nav_target()
	print_rich("[color=green]Customer spawned at %s, heading to %s[/color]" % [str(global_position), str(queue_slot)])

## 导航目标跟随 queue_slot（#93；目标只在 _ready/walk_to/leave 变化时重设，不逐帧刷）
func _sync_nav_target() -> void:
	if nav_agent != null:
		nav_agent.target_position = queue_slot

func _physics_process(delta: float) -> void:
	if state != CustomerState.WALKING:
		return

	if global_position.distance_to(queue_slot) <= ARRIVE_DISTANCE:
		_arrive()
		return

	if Engine.is_editor_hint():
		# @tool：编辑器进程 PhysicsServer 不步进，NavigationAgent2D 路径不刷新；
		# 冒烟测试环境改用 NavigationServer 同步路径查询 + 直接位移
		# （不重叠由槽位间距 200 > 碰撞直径 130 保证，物理碰撞留给运行模式兜底）
		var nav_map := get_world_2d().navigation_map
		NavigationServer2D.map_force_update(nav_map)
		var path := NavigationServer2D.map_get_path(nav_map, global_position, queue_slot, true)
		var next := queue_slot
		if path.size() > 1:
			next = path[1]
		elif path.size() == 1:
			next = path[0]
		global_position = global_position.move_toward(next, move_speed * delta)
		return

	# #93：NavigationAgent2D 寻路跟随（目标在 _ready/walk_to/leave 时设置，不逐帧重设）
	var next_pos := nav_agent.get_next_path_position()
	if next_pos == global_position:
		return  # 路径尚未就绪（导航地图未同步），本帧不动
	velocity = (next_pos - global_position).normalized() * move_speed
	move_and_slide()

func _process(_delta: float) -> void:
	# 每帧刷新头顶订单显示（菜品 + 耐心剩余秒数 + 颜色），无副作用
	_update_order_display()

# ==================== 状态管理 ====================

## 到达目标：按阶段入队（点单→ORDERING / 取餐→WAITING）或离店
func _arrive() -> void:
	velocity = Vector2.ZERO
	if _leaving:
		print_rich("[color=gray]Customer left the store[/color]")
		queue_free()
		return
	if phase == 0:
		state = CustomerState.ORDERING
	else:
		state = CustomerState.WAITING
	print_rich("[color=cyan]Customer arrived at slot %s (phase %d)[/color]" % [str(global_position), phase])
	arrived.emit()

## 是否已在取餐槽位等餐
func is_waiting() -> bool:
	return state == CustomerState.WAITING

## 是否可接收成品菜（有订单、菜品匹配且已在取餐槽位等餐；P2 校验菜品类型）
## #103：不再被玩家直接调用（交付在取餐台），保留供管理器/测试校验
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

## 订单在取餐台被交付（#103：交付动作发生在取餐台，不经顾客本体）：
## 清订单标记 + 金币粒子 + 状态置 SERVED（离店由管理器 leave 驱动）
func mark_served() -> void:
	state = CustomerState.SERVED
	clear_order_label()
	# P9：交付成功金币粒子反馈
	ParticleFX.burst(self, Vector2(0, -60), Color(1.0, 0.78, 0.3), 14, Vector2(0, -350), 200.0, 0.7)
	print_rich("[color=green]Customer served via pickup counter (order #%d)[/color]" % order_id)

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
	_sync_nav_target()
	print_rich("[color=orange]Customer leaving towards %s[/color]" % str(exit_pos))

## 走向新槽位（队列补位时由管理器调用）
func walk_to(slot: Vector2) -> void:
	if _leaving:
		return
	queue_slot = slot
	state = CustomerState.WALKING
	_sync_nav_target()

## 走向取餐槽位（#103：点单完成 → 转取餐队列走位，phase 0→1）
func walk_to_pickup(slot: Vector2) -> void:
	if _leaving:
		return
	phase = 1
	walk_to(slot)
