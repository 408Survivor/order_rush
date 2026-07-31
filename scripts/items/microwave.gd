## 文件: scripts/items/microwave.gd
## 职责: 微波炉设备：接收料理包、暂存物品
## 依赖: 无
## 注意: 加热进度表现属于 issue #4；本期仅实现放入/取出（交互闭环）

@tool
extends Area2D

# ==================== 信号 ====================
## 物品放入时发出
signal item_inserted(item: Node2D)
## 物品取出时发出
signal item_removed(item: Node2D)

# ==================== 枚举 ====================
enum MicrowaveState {
	IDLE,      ## 空闲，等待放入
	OCCUPIED,  ## 内部有物品
}

# ==================== 导出变量 ====================
## 显示名称（用于交互提示）
@export var display_name := "微波炉"

# ==================== 节点引用 ====================
@onready var sprite: Sprite2D = $Sprite2D
@onready var indicator: ColorRect = $Indicator

# ==================== 状态变量 ====================
var current_state := MicrowaveState.IDLE
var contained_item: Node2D = null  ## 当前内部的物品

# ==================== 生命周期 ====================

func _ready() -> void:
	add_to_group("interactable")
	add_to_group("appliance")
	_update_indicator()

# ==================== 交互接口 ====================

## 检查是否可以接受某物品
## 输入: item (Node2D)
## 输出: bool
## 规则: 仅空闲时、且物品为料理包（组 meal_package）
func can_accept_item(item: Node2D) -> bool:
	if current_state != MicrowaveState.IDLE:
		return false
	return item.is_in_group("meal_package")

## 是否内部有物品（供交互提示判断，无副作用）
func is_occupied() -> bool:
	return contained_item != null

## 放入物品
## 输入: item (Node2D)
## 输出: bool（是否成功放入）
## 副作用: 物品收纳为微波炉子节点并隐藏，状态置 OCCUPIED
func accept_item(item: Node2D) -> bool:
	if not can_accept_item(item):
		return false

	contained_item = item
	current_state = MicrowaveState.OCCUPIED

	if item.get_parent() != null:
		item.get_parent().remove_child(item)
	add_child(item)
	item.position = Vector2.ZERO
	item.scale = Vector2.ONE * 0.15
	item.visible = false  # 本期放入即收纳（加热中的视觉归 #4）

	_update_indicator()
	item_inserted.emit(item)
	print_rich("[color=cyan]Microwave: item inserted (%s)[/color]" % item.name)
	return true

## 取出物品（交给调用方——玩家会挂到手上）
## 输出: Node2D（取出的物品，空则返回 null）
## 副作用: 状态恢复 IDLE
func give_item() -> Node2D:
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
	item_removed.emit(item)
	print_rich("[color=cyan]Microwave: item removed[/color]")
	return item

# ==================== 视觉辅助 ====================

## 指示灯：IDLE 绿色，OCCUPIED 红色
func _update_indicator() -> void:
	if current_state == MicrowaveState.OCCUPIED:
		indicator.color = Color(0.898, 0.224, 0.208)  # 红
	else:
		indicator.color = Color(0.298, 0.686, 0.314)  # 绿
