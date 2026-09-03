## 文件: scripts/props/cabinet_key_hints.gd
## 职责: 冷库柜四层键标（#77）——玩家进入取箱距离（TAKE_DISTANCE，无朝向要求）时
##       显示 [J]/[K]/[L]/[空格]（浮于对应层上方），离开隐藏；与取货冰柜层键标（#71）同一交互语言
## 依赖: 无（玩家经 player 组查找）
## 注意: 挂 Node2D（置于冷库柜中心 FRIDGE_CABINET_POS）；整节点显隐即四层键标显隐；
##       编辑器内不自动跑（is_editor_hint 惯例），距离判定抽成 update_key_hints() 供冒烟直调

@tool
extends Node2D

# ==================== 常量 ====================
## 取箱键标显示半径（与 player_character.gd #54 FREEZER_TAKE_DISTANCE 一致）
const TAKE_DISTANCE := 340.0

# ==================== 生命周期 ====================

func _ready() -> void:
	visible = false  # 默认隐藏，靠近才显示

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	update_key_hints()

# ==================== 显隐 ====================

## 按玩家距离刷新键标可见性（public，冒烟可直调）
## 注意：玩家限定与自身同一场景分支——编辑器进程可能开着场景页签（组内多个玩家），
##       不加过滤会拿到页签里的玩家（距离判定对不上，同 freezer.gd #71 修复）
func update_key_hints() -> void:
	var tree := get_tree()
	if tree == null:
		return
	var home := get_parent()
	for player in tree.get_nodes_in_group("player"):
		if home != null and home.is_ancestor_of(player):
			visible = global_position.distance_to(player.global_position) <= TAKE_DISTANCE
			return
