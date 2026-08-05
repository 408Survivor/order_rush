## 文件: scripts/props/freezer.gd
## 职责: 冰柜（#54 四格取货；#71 立式四层货架）——按菜管理料理包库存：收货箱补库存（每箱 CRATE_SIZE），
##       四层货架展示各菜库存（图标 + 计数），玩家按 J/K/L/空格 直接取包（取货扣库存）；
##       层键标默认隐藏，玩家进入取货距离（TAKE_DISTANCE，无朝向要求）时浮于对应层上方显示
## 依赖: GameStateManager/UpgradeManager (autoload)；MealPackage.tscn（取货实例化）
## 注意: 挂 Area2D，加入 appliance 组复用玩家设备交互分支（can_accept_item/accept_item/give_item/is_done）；
##       加入 freezer 组供玩家 J/K/L/空格 取货查找；SLOT_DISHES 第 4 层为预留空位

@tool
extends Area2D

# ==================== 常量 ====================
const MEAL_PACKAGE_SCENE := preload("res://scenes/items/MealPackage.tscn")
const INITIAL_STOCK := 0  ## 各菜初始库存（#54：冰柜初始空，全靠货箱补给）
const CRATE_SIZE := 4     ## 每个货箱补充的库存数
## 取货距离（与 player_character.gd #54 FREEZER_TAKE_DISTANCE 一致；#71 兼作层键标显示半径）
const TAKE_DISTANCE := 340.0
## 四层菜品（竖排摆于立式货架；层 4 预留空）
const SLOT_DISHES: Array[String] = ["kungpao", "yuxiang", "mapo", ""]
## 四层按键提示（与 project.godot take_slot_1..4 对应：J/K/L/空格）
const SLOT_KEY_HINTS: Array[String] = ["[J]", "[K]", "[L]", "[空格]"]
## 四层短菜名（取货提示用）
const SLOT_SHORT_NAMES: Array[String] = ["宫保", "鱼香", "麻婆", "预留"]

# ==================== 导出变量 ====================
## 显示名称（用于交互提示）
@export var display_name := "冰柜"

# ==================== 节点引用 ====================
@onready var _slots: Array[Node2D] = [$Slots/Slot1, $Slots/Slot2, $Slots/Slot3, $Slots/Slot4]

# ==================== 状态变量 ====================
## 各菜料理包库存（跨天保留，不再每天免费刷新；#50 起由货箱补充，#54 起初始为空）
var stock := {"kungpao": INITIAL_STOCK, "yuxiang": INITIAL_STOCK, "mapo": INITIAL_STOCK}

# ==================== 生命周期 ====================

func _ready() -> void:
	add_to_group("interactable")
	add_to_group("appliance")
	add_to_group("freezer")  # 玩家 J/K/L/空格 取货按组查找（#54）
	_refresh_slots()
	set_key_hints_visible(false)  # #71：层键标默认隐藏，靠近才显示

## #71：玩家进入取货距离 → 对应层键标（J/K/L/空格）显示；离开隐藏。
## 无朝向要求（与 try_take_from_freezer 的判定一致：只看距离）。
## 编辑器内不自动跑（is_editor_hint 惯例）；距离判定抽成 update_key_hints() 供冒烟直接调用
func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	update_key_hints()

## 按玩家距离刷新层键标可见性（public，冒烟可直调；玩家经 player 组查找）
func update_key_hints() -> void:
	var tree := get_tree()
	if tree == null:
		return
	var player := tree.get_first_node_in_group("player")
	if player == null:
		return
	set_key_hints_visible(global_position.distance_to(player.global_position) <= TAKE_DISTANCE)

# ==================== 库存 ====================

## 每菜库存容量（P5 冰柜扩容：4 → 8）
func capacity() -> int:
	return 4 + 4 * UpgradeManager.freezer_level

# ==================== appliance 交互接口 ====================

## 是否可接受物品：仅货箱（crate 组）且对应菜品库存未满
func can_accept_item(item: Node2D) -> bool:
	if not item.is_in_group("crate"):
		return false
	return int(stock.get(str(item.get("dish_type")), 0)) < capacity()

## 收入货箱：对应菜品库存 +CRATE_SIZE（不超容量），货箱消耗，刷新四格
func accept_item(item: Node2D) -> bool:
	if not can_accept_item(item):
		return false
	var dish: String = str(item.get("dish_type"))
	stock[dish] = mini(capacity(), int(stock.get(dish, 0)) + CRATE_SIZE)
	item.queue_free()
	_refresh_slots()
	print_rich("[color=cyan]Freezer: crate stored (%s → %d)[/color]" % [dish, stock[dish]])
	return true

## 空手按 E 无操作（料理包经 J/K/L/空格 四格取货，不经由此接口）
func give_item() -> Node2D:
	return null

## appliance 组约定接口（玩家提示代码会调用）：冰柜无"完成"态
func is_done() -> bool:
	return false

# ==================== 四格取货（#54） ====================

## 从指定格取货：slot_index 0..3；预留空位/无库存 → 返回 null；
## 否则库存 -1、实例化料理包（设好 dish_type 与视觉）并返回（不挂场景，调用方接手）
func take_from_slot(slot_index: int) -> Node2D:
	if slot_index < 0 or slot_index >= SLOT_DISHES.size():
		return null
	var dish: String = SLOT_DISHES[slot_index]
	if dish == "" or int(stock.get(dish, 0)) <= 0:
		return null
	stock[dish] = int(stock[dish]) - 1
	var pkg: Node2D = MEAL_PACKAGE_SCENE.instantiate()
	pkg.set("dish_type", dish)
	if pkg.has_method("apply_dish_visual"):
		pkg.apply_dish_visual()
	_refresh_slots()
	print_rich("[color=cyan]Freezer: slot %d taken (%s → %d)[/color]" % [slot_index + 1, dish, stock[dish]])
	return pkg

## 玩家空手面对冰柜时的取货提示："[J]宫保×N [K]鱼香×N [L]麻婆×N [空格]预留"
func take_hint() -> String:
	var parts: Array[String] = []
	for i in SLOT_DISHES.size():
		var dish: String = SLOT_DISHES[i]
		if dish == "":
			parts.append("%s%s" % [SLOT_KEY_HINTS[i], SLOT_SHORT_NAMES[i]])
		else:
			parts.append("%s%s×%d" % [SLOT_KEY_HINTS[i], SLOT_SHORT_NAMES[i], int(stock.get(dish, 0))])
	return " ".join(parts)

# ==================== 视觉辅助 ====================

## #71：设置四层键标（KeyLabel）可见性（public，冒烟测试可直接调用）
func set_key_hints_visible(v: bool) -> void:
	if _slots == null:
		return
	for slot in _slots:
		if slot == null:
			continue
		var key_label: Label = slot.get_node_or_null("KeyLabel")
		if key_label != null:
			key_label.visible = v

## 刷新四层展示：库存 >0 → 图标显示、计数 ×N；=0 → 图标隐藏、计数 ×0 调暗；预留层只显示按键提示
func _refresh_slots() -> void:
	if _slots == null:
		return
	for i in SLOT_DISHES.size():
		var slot := _slots[i]
		if slot == null:
			continue
		var dish: String = SLOT_DISHES[i]
		var icon: Sprite2D = slot.get_node_or_null("Icon")
		var count_label: Label = slot.get_node_or_null("CountLabel")
		if dish == "":
			if icon != null:
				icon.visible = false
			if count_label != null:
				count_label.text = ""
			continue
		var count := int(stock.get(dish, 0))
		if icon != null:
			icon.visible = count > 0
		if count_label != null:
			count_label.text = "×%d" % count
			count_label.modulate = Color(1, 1, 1, 1) if count > 0 else Color(1, 1, 1, 0.4)
