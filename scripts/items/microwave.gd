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
const ParticleFX := preload("res://scripts/systems/particle_fx.gd")
const FINISHED_DISH_SCENE := preload("res://scenes/items/FinishedDish.tscn")
const HEAT_TIME := 3.0    ## 基础加热时长（秒）
const HEAT_TIME_UPGRADED := 2.2  ## 加热加速后时长（P5 升级 heat_level>=1）

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
## 实际加热时长（P5：按 UpgradeManager.heat_level 取基础 3.0s 或加速 2.2s）
var heat_time := HEAT_TIME

var _progress_max_width := 120.0

# ==================== 生命周期 ====================

func _ready() -> void:
	add_to_group("interactable")
	add_to_group("appliance")
	_refresh_heat_time()
	heat_timer.one_shot = true
	heat_timer.timeout.connect(_on_heat_timer_timeout)
	_progress_max_width = progress_fill.size.x
	_update_indicator()
	_update_progress(0.0)
	# P5/P6/P8：购买加热加速/卡牌/角色技能生效后即时刷新（无需重启场景）
	if not UpgradeManager.upgrades_changed.is_connected(_on_upgrades_changed):
		UpgradeManager.upgrades_changed.connect(_on_upgrades_changed)
	if not CardManager.cards_changed.is_connected(_on_upgrades_changed):
		CardManager.cards_changed.connect(_on_upgrades_changed)
	if not CharacterManager.character_changed.is_connected(_on_upgrades_changed):
		CharacterManager.character_changed.connect(_on_upgrades_changed)

## 统一重算加热时长 = 基础（P5 加速可选）× 卡牌乘数（P6 工业烤箱）× 角色技能（P8 快手主厨）；即时生效
func _refresh_heat_time() -> void:
	var base := HEAT_TIME_UPGRADED if UpgradeManager.heat_level >= 1 else HEAT_TIME
	var new_time := base * CardManager.get_multiplier("heat_multiplier") * CharacterManager.get_heat_multiplier()
	if heat_time != new_time:
		heat_time = new_time
		heat_timer.wait_time = heat_time

## P5/P6/P8 升级/卡牌/角色变化 → 重算加热时长（商店/抽卡/角色选择在打烊或营业前，仅空闲态）
## 注意: 带默认参数以兼容 character_changed(1 参) 与 upgrades/cards_changed(0 参) 两类信号（Godot 4.6 参数数不匹配会报错）
func _on_upgrades_changed(_extra: Variant = null) -> void:
	_refresh_heat_time()

func _process(_delta: float) -> void:
	# 加热中实时刷新进度条
	if current_state == MicrowaveState.HEATING:
		_update_progress(1.0 - heat_timer.time_left / heat_time)

# ==================== 交互接口 ====================

## 检查是否可以接受某物品（仅空闲且为料理包；P7：设备故障期间拒绝放入）
func can_accept_item(item: Node2D) -> bool:
	if is_broken():
		return false
	if current_state != MicrowaveState.IDLE:
		return false
	return item.is_in_group("meal_package")

## P7：设备故障事件中（特殊事件 EQUIPMENT_BREAK）
func is_broken() -> bool:
	return GameStateManager.is_event_active(GameStateManager.SpecialEvent.EQUIPMENT_BREAK)

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

## 打烊清场：清空内部物品（含加热中强制中止）并复位状态（P3 日循环）
## 副作用: 内部物品销毁、计时停止、状态回 IDLE
func clear_contents() -> void:
	heat_timer.stop()
	if contained_item != null:
		var item := contained_item
		contained_item = null
		if is_instance_valid(item):
			item.queue_free()
	current_state = MicrowaveState.IDLE
	_update_indicator()
	_update_progress(0.0)
	print_rich("[color=yellow]Microwave: contents cleared (打烊清场)[/color]")

# ==================== 加热逻辑 ====================

## 加热完成：料理包替换为成品菜，状态置 DONE，并计入一次水电成本（P3 经济）
func _on_heat_timer_timeout() -> void:
	if current_state != MicrowaveState.HEATING:
		return
	# P9：加热完成蒸汽粒子 + 音效
	ParticleFX.burst(self, Vector2(0, -60), Color(0.95, 0.95, 0.9, 0.8), 10, Vector2(0, -200), 120.0, 0.8)
	AudioManager.play_sfx("heat_done")

	# 销毁料理包，生成成品菜（P7：成品菜继承料理包的 dish_type）
	if contained_item != null:
		var meal_dish_type: String = str(contained_item.get("dish_type"))
		contained_item.queue_free()
		var dish: Node2D = FINISHED_DISH_SCENE.instantiate()
		dish.set("dish_type", meal_dish_type)
		add_child(dish)
		dish.position = Vector2.ZERO
		if dish.has_method("apply_dish_visual"):
			dish.apply_dish_visual()
		contained_item = dish

	current_state = MicrowaveState.DONE
	_update_indicator()
	_update_progress(1.0)
	# P3：每次加热完成计入一次水电成本（GameStateManager 为 autoload，编辑器进程可安全调用）
	GameStateManager.record_heat()
	heating_finished.emit()
	print_rich("[color=green]Microwave: heating finished![/color]")

# ==================== 视觉辅助 ====================

## 指示灯：IDLE 绿 / HEATING 黄 / DONE 红（#32 统一引用 UITheme 功能色，与耐心三色一致）
func _update_indicator() -> void:
	match current_state:
		MicrowaveState.HEATING:
			indicator.color = UITheme.COLOR_YELLOW
		MicrowaveState.DONE:
			indicator.color = UITheme.COLOR_RED
		_:
			indicator.color = UITheme.COLOR_GREEN

## 进度条填充宽度（0.0-1.0）；#30 按状态着色（加热中黄 / 完成红 / 空闲绿）
func _update_progress(ratio: float) -> void:
	progress_fill.size.x = _progress_max_width * clampf(ratio, 0.0, 1.0)
	var color := UITheme.COLOR_GREEN
	match current_state:
		MicrowaveState.HEATING:
			color = UITheme.COLOR_YELLOW
		MicrowaveState.DONE:
			color = UITheme.COLOR_RED
	progress_fill.color = color
