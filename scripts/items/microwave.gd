## 文件: scripts/items/microwave.gd
## 职责: 微波炉设备：接收料理包 → 加热（带进度条）→ 产出成品菜
## 依赖: FinishedDish.tscn（加热完成后创建）
## 注意: 加热进度表现见 issue #4 验收；Timer 由脚本管理

@tool
extends Area2D

# ==================== 信号 ====================
## 物品放入时发出
signal item_inserted(item: Node2D)
## 加热开始时发出
signal heating_started()
## 加热完成时发出
signal heating_finished()
## 物品取出时发出
signal item_removed(item: Node2D)

# ==================== 枚举 ====================
enum MicrowaveState {
	IDLE,      ## 空闲，等待放入
	HEATING,   ## 加热中
	DONE,      ## 加热完成，等待取出
}

# ==================== 常量 ====================
const FINISHED_DISH_SCENE := preload("res://scenes/items/FinishedDish.tscn")
const HEAT_TIME := 3.0  ## 加热时长（秒）

# ==================== 导出变量 ====================
## 显示名称（用于交互提示）
@export var display_name := "微波炉"

# ==================== 节点引用 ====================
@onready var sprite: Sprite2D = $Sprite2D
@onready var indicator: ColorRect = $Indicator
@onready var progress_fill: ColorRect = $ProgressBar/ProgressFill
@onready var heat_timer: Timer = $HeatTimer

# ==================== 状态变量 ====================
var current_state := MicrowaveState.IDLE
var contained_item: Node2D = null  ## 内部物品（料理包或成品菜）

var _progress_max_width := 120.0

# ==================== 生命周期 ====================

func _ready() -> void:
	add_to_group("interactable")
	add_to_group("appliance")
	heat_timer.wait_time = HEAT_TIME
	heat_timer.one_shot = true
	heat_timer.timeout.connect(_on_heat_timer_timeout)
	_progress_max_width = progress_fill.size.x
	_update_indicator()
	_update_progress(0.0)

func _process(_delta: float) -> void:
	# 加热中实时刷新进度条
	if current_state == MicrowaveState.HEATING:
		_update_progress(1.0 - heat_timer.time_left / HEAT_TIME)

# ==================== 交互接口 ====================

## 检查是否可以接受某物品（仅空闲且为料理包）
func can_accept_item(item: Node2D) -> bool:
	if current_state != MicrowaveState.IDLE:
		return false
	return item.is_in_group("meal_package")

## 是否内部有物品（供交互提示判断，无副作用）
func is_occupied() -> bool:
	return contained_item != null

## 是否加热完成待取出
func is_done() -> bool:
	return current_state == MicrowaveState.DONE

## 放入料理包并开始加热
## 输入: item (Node2D) - 料理包
## 输出: bool（是否成功放入）
## 副作用: 状态置 HEATING，启动加热计时
func accept_item(item: Node2D) -> bool:
	if not can_accept_item(item):
		return false

	contained_item = item
	current_state = MicrowaveState.HEATING

	if item.get_parent() != null:
		item.get_parent().remove_child(item)
	add_child(item)
	item.position = Vector2.ZERO
	item.visible = false  # 加热中隐藏

	_update_indicator()
	_update_progress(0.0)
	item_inserted.emit(item)
	heat_timer.start()
	heating_started.emit()
	print_rich("[color=cyan]Microwave: heating started (%s)[/color]" % item.name)
	return true

## 取出物品（仅 IDLE/DONE 可取出；加热中禁止，防止取消加热）
## 输出: Node2D（取出的物品，空则返回 null）
## 副作用: 状态恢复 IDLE
func give_item() -> Node2D:
	if current_state == MicrowaveState.HEATING:
		return null
	if contained_item == null:
		return null

	var item := contained_item
	contained_item = null
	current_state = MicrowaveState.IDLE

	if item.get_parent() != null:
		item.get_parent().remove_child(item)
	item.visible = true
	item.scale = Vector2.ONE

	_update_indicator()
	_update_progress(0.0)
	item_removed.emit(item)
	print_rich("[color=cyan]Microwave: item removed (%s)[/color]" % item.name)
	return item

# ==================== 加热逻辑 ====================

## 加热完成：料理包替换为成品菜，状态置 DONE
func _on_heat_timer_timeout() -> void:
	if current_state != MicrowaveState.HEATING:
		return

	# 销毁料理包，生成成品菜
	if contained_item != null:
		contained_item.queue_free()
	var dish: Node2D = FINISHED_DISH_SCENE.instantiate()
	add_child(dish)
	dish.position = Vector2.ZERO
	contained_item = dish

	current_state = MicrowaveState.DONE
	_update_indicator()
	_update_progress(1.0)
	heating_finished.emit()
	print_rich("[color=green]Microwave: heating finished![/color]")

# ==================== 视觉辅助 ====================

## 指示灯：IDLE 绿 / HEATING 黄 / DONE 红
func _update_indicator() -> void:
	match current_state:
		MicrowaveState.HEATING:
			indicator.color = Color(0.95, 0.76, 0.20)  # 黄
		MicrowaveState.DONE:
			indicator.color = Color(0.90, 0.22, 0.21)  # 红
		_:
			indicator.color = Color(0.30, 0.69, 0.31)  # 绿

## 进度条填充宽度（0.0-1.0）
func _update_progress(ratio: float) -> void:
	progress_fill.size.x = _progress_max_width * clampf(ratio, 0.0, 1.0)
