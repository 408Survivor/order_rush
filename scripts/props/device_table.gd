## 文件: scripts/props/device_table.gd
## 职责: 工作台（#93）——「设备上桌」的桌面底座：2 个 device_slot 槽位（Marker2D，不碰撞不挡人），
##       设备（微波炉类 device 组）被玩家搬起后可吸附摆放到本桌空槽位
## 依赖: LayoutManager (autoload)；槽位全局位置单一权威 = LayoutManager.DEVICE_SLOTS
## 注意: 桌子本体 z=-1 纯视觉不加碰撞——延续 Session 16 经验（操作桌加碰撞会打断 160 交互距离）；
##       槽位占用为派生态（按 device 组节点的实际位置判定），不做簿记，放下/搬起/读档天然一致

@tool
extends Node2D

# ==================== 常量 ====================
## 判定设备占据槽位的贴合距离（像素）
const SLOT_SNAP_DISTANCE := 30.0

# ==================== 节点引用 ====================
@onready var _slots: Array[Marker2D] = [$SlotL, $SlotR]

# ==================== 状态变量 ====================
## 本桌在 LayoutManager.DEVICE_TABLE_SLOTS 中的序号（main_scene 实例化后注入）
var table_index := -1

# ==================== 初始化 ====================

func _ready() -> void:
	add_to_group("device_table")
	z_index = -1  # 桌面垫在设备之下（设备 z=0 参与 y-sort，读作「摆上桌」）
	for slot in _slots:
		slot.add_to_group("device_slot")
	_sync_slots()

## 槽位按 LayoutManager.DEVICE_SLOTS 摆位（单一权威，不手抄坐标；桌子移动后需重调）
func _sync_slots() -> void:
	if table_index < 0:
		return
	for i in _slots.size():
		var slot_pos := LayoutManager.get_slot_position(LayoutManager.DEVICE_SLOTS, table_index * _slots.size() + i)
		_slots[i].position = slot_pos - global_position

# ==================== 槽位接口 ====================

## 全部槽位标记
func get_slots() -> Array[Marker2D]:
	return _slots

## 槽位是否空闲（派生态：无任何 device 组节点贴在槽位上）
## 注意：设备查找限定与本桌同一场景分支——编辑器进程可能开着 MainScene 页签（同组多台设备）
func is_slot_free(slot: Marker2D) -> bool:
	var home := get_parent()
	for node in get_tree().get_nodes_in_group("device"):
		if not (node is Node2D):
			continue
		if home != null and not home.is_ancestor_of(node):
			continue
		if node.global_position.distance_to(slot.global_position) <= SLOT_SNAP_DISTANCE:
			return false
	return true

## 第一个空槽位（无则返回 null）
func get_free_slot() -> Marker2D:
	for slot in _slots:
		if is_slot_free(slot):
			return slot
	return null

## 把设备吸附摆放到指定槽位：设备挂回 MainScene 根（z=0 参与 y-sort 遮挡）、恢复设备碰撞层
## 输出: bool（是否摆放成功；槽位被占则失败）
## 副作用: 设备位置吸附到槽位、碰撞层恢复为 5（World+Interactables）、自定义位置写存档
func place_device(slot: Marker2D, device: Node2D) -> bool:
	if slot == null or device == null:
		return false
	if not is_slot_free(slot):
		return false
	if device.get_parent() != null:
		device.get_parent().remove_child(device)
	var home := get_parent()
	if home == null:
		return false
	home.add_child(device)
	device.global_position = slot.global_position
	if device is Area2D:
		device.collision_layer = 5  ## 设备碰撞层（World+Interactables；与 Microwave.tscn 场景初始值一致）
		device.collision_mask = 0
	# 自定义摆放位置写存档（重启后按存档复位，见 main_scene._apply_upgrades）
	UpgradeManager.set_device_position(device.name, device.global_position)
	print_rich("[color=cyan]DeviceTable: %s 放上槽位 %s[/color]" % [device.name, str(slot.global_position)])
	return true
