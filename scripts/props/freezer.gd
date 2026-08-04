## 文件: scripts/props/freezer.gd
## 职责: 冰柜（#50 两段式补给核心）——按菜管理料理包库存：收货箱补库存（每箱 CRATE_SIZE），
##       台面料理包镜像库存（有货则摆到冰柜前取包位，被拾取扣库存并自动补下一个）
## 依赖: GameStateManager/UpgradeManager/LayoutManager (autoload)；MealPackage.tscn（台面镜像实例化）
## 注意: 挂 Area2D，加入 appliance 组复用玩家设备交互分支（can_accept_item/accept_item/give_item/is_done）；
##       命名保持 legacy：kungpao="MealPackage"、yuxiang="MealPackage2"、mapo="MealPackage3"（冒烟测试路径依赖）；
##       编辑器进程也连接玩家 item_picked_up（冒烟测试在编辑器进程验证扣库存）

@tool
extends Area2D

# ==================== 常量 ====================
const MEAL_PACKAGE_SCENE := preload("res://scenes/items/MealPackage.tscn")
const INITIAL_STOCK := 3  ## 各菜初始库存（冒烟测试全流程每菜消耗 ≤2，留 1 余量保证跨天台面有包）
const CRATE_SIZE := 4     ## 每个货箱补充的库存数
## 台面包 legacy 命名（与冒烟测试 Items/MealPackage(2/3) 路径绑定，顺序对应 L1_DISHES）
const PACKAGE_NAMES := {
	"kungpao": "MealPackage",
	"yuxiang": "MealPackage2",
	"mapo": "MealPackage3",
}

# ==================== 导出变量 ====================
## 显示名称（用于交互提示）
@export var display_name := "冰柜"

# ==================== 节点引用 ====================
@onready var stock_label: Label = $StockLabel

# ==================== 状态变量 ====================
## 各菜料理包库存（跨天保留，不再每天免费刷新；#50 起由货箱补充）
var stock := {"kungpao": INITIAL_STOCK, "yuxiang": INITIAL_STOCK, "mapo": INITIAL_STOCK}
## 台面料理包镜像：dish_type → 台面上的包节点（被手持/消耗时为 null）
var _packages: Dictionary = {}

# ==================== 生命周期 ====================

func _ready() -> void:
	add_to_group("interactable")
	add_to_group("appliance")
	_update_stock_label()
	# 监听玩家拾取：台面包被拿走 → 扣库存并补下一个（编辑器进程也连，冒烟测试依赖）
	var player := get_parent().get_node_or_null("PlayerCharacter")
	if player != null and player.has_signal("item_picked_up"):
		if not player.item_picked_up.is_connected(_on_player_item_picked_up):
			player.item_picked_up.connect(_on_player_item_picked_up)

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

## 收入货箱：对应菜品库存 +CRATE_SIZE（不超容量），货箱消耗，刷新台面
func accept_item(item: Node2D) -> bool:
	if not can_accept_item(item):
		return false
	var dish: String = str(item.get("dish_type"))
	stock[dish] = mini(capacity(), int(stock.get(dish, 0)) + CRATE_SIZE)
	item.queue_free()
	sync_packages()
	_update_stock_label()
	print_rich("[color=cyan]Freezer: crate stored (%s → %d)[/color]" % [dish, stock[dish]])
	return true

## 空手按 E 无操作（料理包从台面直接拾取，不经由此接口）
func give_item() -> Node2D:
	return null

## appliance 组约定接口（玩家提示代码会调用）：冰柜无"完成"态
func is_done() -> bool:
	return false

# ==================== 台面料理包镜像 ====================

## 按库存同步台面料理包：有货且无包 → 摆到冰柜前取包位；无货且包在台面（未被手持）→ 撤下
## 幂等：可被 main_scene 初始摆放/日循环清场/入库/拾取后重复调用
func sync_packages() -> void:
	var items := get_parent().get_node_or_null("Items")
	if items == null:
		return
	for i in GameStateManager.L1_DISHES.size():
		var dish: String = GameStateManager.L1_DISHES[i]
		var pkg_name: String = PACKAGE_NAMES.get(dish, "MealPackage")
		var pkg: Node2D = _packages.get(dish)
		if pkg == null or not is_instance_valid(pkg) or pkg.is_queued_for_deletion():
			pkg = null
		if pkg == null:
			# 回收同名节点（Q 放下回 Items 的台面包），避免同帧重名冲突
			var found := items.get_node_or_null(pkg_name)
			if found != null and not found.is_queued_for_deletion():
				pkg = found
		if int(stock.get(dish, 0)) > 0:
			if pkg == null:
				pkg = MEAL_PACKAGE_SCENE.instantiate()
				pkg.name = pkg_name
				items.add_child(pkg)
			pkg.set("dish_type", dish)
			if pkg.has_method("apply_dish_visual"):
				pkg.apply_dish_visual()
			pkg.global_position = LayoutManager.get_slot_position(LayoutManager.MEAL_SLOTS, i)
			_packages[dish] = pkg
		else:
			if pkg != null and pkg.get_parent() == items:
				pkg.queue_free()
			_packages[dish] = null

# ==================== 信号响应 ====================

## 台面包被拾取 → 对应菜品库存 -1，补下一个上台面（deferred，等拾取重挂完成后同步）
func _on_player_item_picked_up(item: Node2D) -> void:
	for dish in _packages:
		if _packages[dish] == item:
			stock[dish] = maxi(0, int(stock.get(dish, 0)) - 1)
			_packages[dish] = null
			_update_stock_label()
			call_deferred("sync_packages")
			return

# ==================== 视觉辅助 ====================

## 机身库存标签（占位可视化，正式素材见 issue #51）
func _update_stock_label() -> void:
	if stock_label == null:
		return
	var parts: Array[String] = []
	for dish in GameStateManager.L1_DISHES:
		parts.append("%s×%d" % [GameStateManager.get_dish_display_name(dish), int(stock.get(dish, 0))])
	stock_label.text = "\n".join(parts)
