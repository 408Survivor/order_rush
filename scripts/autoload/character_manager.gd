## 文件: scripts/autoload/character_manager.gd
## 职责: 角色系统（P8）——角色定义/选择 + JSON 存档 + 技能乘数查询（Modifier 式），形成角色差异化玩法
## 依赖: 无（autoload）；技能通过 get_*_multiplier 查询，各系统（微波炉加热等）接入
## 注意: 与 UpgradeManager 同存档模式（user://save_p8.json，写失败仅告警）

@tool
extends Node

## 存档路径（冒烟测试可注入替换）
var save_path := "user://save_p8.json"

# ==================== 角色定义 ====================
## id → 名称/描述/技能数值（技能字段与卡牌同模式：multiplier 乘数）
const CHARACTERS := {
	"chef": {"name": "主厨", "desc": "均衡型，无加成", "heat_multiplier": 1.0},
	"fast_chef": {"name": "快手主厨", "desc": "制作时间 -15%（加热加速）", "heat_multiplier": 0.85},
}

signal character_changed(character_id: String)

## 当前角色（空 = 未选择，启动时弹选择界面）
var current_character := ""

func _ready() -> void:
	load_character()

## 是否已选角色
func has_selected() -> bool:
	return current_character != "" and CHARACTERS.has(current_character)

## 选择角色：校验合法 → 存档 → 发信号
## 输出: bool
func select_character(character_id: String) -> bool:
	if not CHARACTERS.has(character_id):
		return false
	current_character = character_id
	character_changed.emit(character_id)
	save_character()
	print_rich("[color=green]Character selected: %s（%s）[/color]" % [character_id, CHARACTERS[character_id]["name"]])
	return true

## 技能乘数查询（无角色/非法返回 1.0；与卡牌/升级乘数在消费端连乘）
func get_heat_multiplier() -> float:
	if not has_selected():
		return 1.0
	return CHARACTERS[current_character].get("heat_multiplier", 1.0)

# ==================== JSON 存档 ====================

func save_character() -> void:
	var data := {"character": current_character}
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		push_warning("CharacterManager: 存档写入失败（%s, err=%d）" % [save_path, FileAccess.get_open_error()])
		return
	file.store_string(JSON.stringify(data))
	file.close()

func load_character() -> void:
	if not FileAccess.file_exists(save_path):
		return
	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var character_id: String = str(parsed.get("character", ""))
	if CHARACTERS.has(character_id):
		current_character = character_id
