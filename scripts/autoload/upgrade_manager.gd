## 文件: scripts/autoload/upgrade_manager.gd
## 职责: 设备升级状态（P5）——第二微波炉 / 加热加速 / 冰柜扩容 + JSON 存档（user://save_p5.json），
##       把 P3 利润（金币）转化为可积累的产能成长
## 依赖: GameStateManager (autoload，作为购买货币)；无副作用 @tool（加载失败仅告警）

@tool
extends Node

## 存档路径（冒烟测试可注入替换，避免污染真实存档）
var save_path := "user://save_p5.json"

# ==================== 升级状态 ====================
var has_second_microwave := false
var heat_level := 0    ## 0=基础 3.0s，1=加速 2.2s
var freezer_level := 0 ## 0=每菜库存容量 4，1=8（#50 库存语义；料理包台面按库存镜像）
## #93 设备自定义摆放位置（key=设备名 "Microwave"/"Microwave2"，value=[x,y]；缺省空字典，旧存档兼容）
var device_positions: Dictionary = {}

## 升级项定义（id → 名称/描述/价格；可购项扩展在此追加）
const UPGRADES := {
	"second_microwave": {"name": "第二微波炉", "desc": "并行加热，产能翻倍", "price": 80},
	"heat_accel": {"name": "加热加速", "desc": "加热时长 3.0s → 2.2s", "price": 50},
	"freezer": {"name": "冰柜扩容", "desc": "每菜库存容量 4 → 8", "price": 60},
}

signal upgrades_changed

func _ready() -> void:
	load_upgrades()

## 是否已购（商店置灰/隐藏已购项用）
func is_owned(upgrade_id: String) -> bool:
	match upgrade_id:
		"second_microwave":
			return has_second_microwave
		"heat_accel":
			return heat_level >= 1
		"freezer":
			return freezer_level >= 1
	return false

## 尝试购买升级：金币足够且未购 → 扣金币 + 应用 + 存档 + 发 upgrades_changed
## 输出: bool（购买成功）
func buy_upgrade(upgrade_id: String) -> bool:
	if not UPGRADES.has(upgrade_id):
		return false
	if is_owned(upgrade_id):
		return false
	var price: int = UPGRADES[upgrade_id]["price"]
	if GameStateManager.money < price:
		return false
	GameStateManager.money -= price
	_apply_upgrade(upgrade_id)
	upgrades_changed.emit()
	save_upgrades()
	print_rich("[color=green]Upgrade bought: %s（- %d 金币，现有 %d）[/color]" % [UPGRADES[upgrade_id]["name"], price, GameStateManager.money])
	return true

func _apply_upgrade(upgrade_id: String) -> void:
	match upgrade_id:
		"second_microwave":
			has_second_microwave = true
		"heat_accel":
			heat_level = 1
		"freezer":
			freezer_level = 1

# ==================== #93 设备自定义摆放位置 ====================

## 记录设备摆放位置并写盘（放上工作台槽位 / Q 放地面时调用）
func set_device_position(device_name: String, pos: Vector2) -> void:
	device_positions[device_name] = [pos.x, pos.y]
	save_upgrades()

## 读取设备自定义位置（无记录返回 null → 调用方回退默认槽位）
func get_device_position(device_name: String) -> Variant:
	var raw: Variant = device_positions.get(device_name, null)
	if typeof(raw) == TYPE_ARRAY and raw.size() == 2:
		return Vector2(float(raw[0]), float(raw[1]))
	return null

# ==================== JSON 存档 ====================

## 保存升级状态（读-改-写合并：保留 #83 繁荣度/店铺星级等同文件外键；写失败仅告警——编辑器进程 TCC 限制下不阻塞逻辑）
func save_upgrades() -> void:
	var data := {}
	if FileAccess.file_exists(save_path):
		var read_file := FileAccess.open(save_path, FileAccess.READ)
		if read_file != null:
			var parsed: Variant = JSON.parse_string(read_file.get_as_text())
			read_file.close()
			if typeof(parsed) == TYPE_DICTIONARY:
				data = parsed
	data["has_second_microwave"] = has_second_microwave
	data["heat_level"] = heat_level
	data["freezer_level"] = freezer_level
	# #93：设备自定义摆放位置并入同一存档通道
	data["device_positions"] = device_positions
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		push_warning("UpgradeManager: 存档写入失败（%s, err=%d）" % [save_path, FileAccess.get_open_error()])
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()

## 加载升级状态（无存档/损坏时保持默认）
func load_upgrades() -> void:
	if not FileAccess.file_exists(save_path):
		return
	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var data: Dictionary = parsed
	has_second_microwave = bool(data.get("has_second_microwave", false))
	heat_level = int(data.get("heat_level", 0))
	freezer_level = int(data.get("freezer_level", 0))
	# #93：设备自定义位置（缺省空字典，旧存档兼容）
	var positions: Variant = data.get("device_positions", {})
	if typeof(positions) == TYPE_DICTIONARY:
		device_positions = positions
