## 文件: scripts/main_scene.gd
## 职责: 主场景组装：按 LayoutManager 布局配置生成区域视觉（色块+标签）并摆放全部节点；
##       P3 日循环清场（打烊清顾客/新一天重置物品与玩家）
## 依赖: LayoutManager/GameStateManager (autoload)；场景节点结构见 MainScene.tscn（节点位置以本脚本为准）
## 注意: @tool 使编辑器进程打开场景即按配置摆放（位置单一权威 = LayoutManager，issue #24）

@tool
extends Node2D

# ==================== 节点引用 ====================
@onready var floor_sprite: Sprite2D = $Floor
@onready var camera: Camera2D = $Camera2D
@onready var items_root: Node2D = $Items
@onready var microwave: Node2D = $Microwave
@onready var spawn_point: Marker2D = $SpawnPoint
@onready var counter_point: Marker2D = $CounterPoint
@onready var player: Node2D = $PlayerCharacter
@onready var order_board: CanvasLayer = $OrderBoard
@onready var toast_manager: CanvasLayer = $ToastManager

## 料理包台面的单一权威 = Freezer.sync_packages（#50，本脚本不再直接摆料理包）
## 微波炉场景（P5：第二台升级后实例化）
const MICROWAVE_SCENE := preload("res://scenes/props/Microwave.tscn")
## 冰柜场景（#50 两段式补给：库存 + 台面料理包镜像）
const FREEZER_SCENE := preload("res://scenes/props/Freezer.tscn")
## 货箱堆场景（#50：冷库区批发仓，按 CRATE_SLOTS 生成 3 个）
const CRATE_STACK_SCENE := preload("res://scenes/props/CrateStack.tscn")
## 外卖口场景（P4，动态实例化）
const TAKEOUT_COUNTER_SCENE := preload("res://scenes/props/TakeoutCounter.tscn")
## 外卖订单面板场景（P4，动态实例化 CanvasLayer；#48 起为 tscn）
const TAKEAWAY_BOARD_SCENE := preload("res://scenes/ui/TakeawayBoard.tscn")
## 骑手视觉管理器脚本（P4）
const TAKEOUT_RIDER_SCRIPT := preload("res://scripts/systems/takeaway_rider.gd")
## 升级商店场景（P5，动态实例化 CanvasLayer；#48 起为 tscn）
const UPGRADE_SHOP_SCENE := preload("res://scenes/ui/UpgradeShop.tscn")
## 抽卡面板场景（P6，动态实例化 CanvasLayer；#48 起为 tscn）
const CARD_DRAW_SCENE := preload("res://scenes/ui/CardDraw.tscn")
## 招牌菜面板场景（P7，动态实例化 CanvasLayer；#48 起为 tscn）
const SPECIALTY_PANEL_SCENE := preload("res://scenes/ui/SpecialtyPanel.tscn")
## 角色选择面板场景（P8，动态实例化 CanvasLayer；#48 起为 tscn）
const CHARACTER_SELECT_SCENE := preload("res://scenes/ui/CharacterSelect.tscn")

# ==================== 区域定义（名称/标签/矩形/色值，顺序与 LayoutManager.ZONE_* 一致） ====================
var _zone_defs: Array = []

func _ready() -> void:
	_zone_defs = [
		["ZoneStorage", "冷库区", LayoutManager.ZONE_STORAGE, Color(0.7, 0.85, 1, 0.22)],
		["ZoneKitchen", "厨房区", LayoutManager.ZONE_KITCHEN, Color(1, 0.95, 0.7, 0.22)],
		["ZoneFront", "前台", LayoutManager.ZONE_FRONT, Color(0.8, 1, 0.75, 0.22)],
		["ZoneDining", "就餐区", LayoutManager.ZONE_DINING, Color(1, 0.8, 0.6, 0.22)],
	]
	_build_zones()
	_build_tables()
	_build_freezer()
	_build_crate_stacks()
	_build_takeout_counter()
	_build_takeaway_ui()
	_build_upgrade_shop()
	_build_card_draw()
	_build_specialty_panel()
	_build_character_select()
	_apply_upgrades()
	_place_nodes()
	# P3 日循环：打烊清场 / 新一天重置（is_connected 防热重载/多实例重复连接）
	if not GameStateManager.shop_closed.is_connected(_on_shop_closed):
		GameStateManager.shop_closed.connect(_on_shop_closed)
	if not GameStateManager.day_started.is_connected(_on_day_started):
		GameStateManager.day_started.connect(_on_day_started)
	# P5 升级：购买后应用（第二微波炉/冰柜扩容即时生效）
	if not UpgradeManager.upgrades_changed.is_connected(_on_upgrades_changed):
		UpgradeManager.upgrades_changed.connect(_on_upgrades_changed)

# ==================== P3 日循环 ====================

## 打烊：清空顾客、刷新订单面板（未完成订单已由 close_shop 作废）
func _on_shop_closed(result: Dictionary) -> void:
	var customer_manager := get_node_or_null("CustomerManager")
	if customer_manager != null and customer_manager.has_method("clear_customers"):
		customer_manager.clear_customers()
	if order_board != null and order_board.has_method("refresh"):
		order_board.refresh()
	# 注意：不在此处弹 Toast——结算面板已暂停游戏并全屏遮罩，Toast 不可见（由面板本身承担反馈）

## 新一天：顾客重新接客 + 物品/玩家复位
func _on_day_started(_day: int) -> void:
	var customer_manager := get_node_or_null("CustomerManager")
	if customer_manager != null and customer_manager.has_method("start_serving"):
		customer_manager.start_serving()
	_reset_shop_items()

## 新一天重置：销毁手持/微波炉内/散落物品，台面料理包由冰柜按库存重摆（#50：库存跨天保留，不再每天免费刷新）
func _reset_shop_items() -> void:
	# 玩家手持物品销毁（跨天不保留）
	if player.has_method("discard_held_item"):
		player.discard_held_item()
	# 微波炉内物品清空（含加热中强制中止）——含 P5 第二台
	for mw: Node in [microwave, get_node_or_null("Microwave2")]:
		if mw != null and mw.has_method("clear_contents"):
			mw.clear_contents()
	# 清理散落物品（成品菜/货箱/Q 放下的残留）；台面在架的料理包保留，由下方 sync 按库存统一重摆
	var freezer := get_node_or_null("Freezer")
	var counter_packages: Array = []
	if freezer != null:
		counter_packages = freezer.get("_packages").values()
	for child in items_root.get_children():
		if child not in counter_packages:
			child.queue_free()
	# 冰柜按库存同步台面料理包（有货补摆/缺货撤下/重摆取包位）
	if freezer != null and freezer.has_method("sync_packages"):
		freezer.sync_packages()
	# 玩家复位出生点
	player.global_position = LayoutManager.SPAWN_POINT

# ==================== 区域视觉 ====================

## 按配置生成区域色块 + 标签（幂等：已存在则跳过，防编辑器热重载重复）
func _build_zones() -> void:
	for def in _zone_defs:
		var zone_name: String = def[0]
		if has_node(zone_name):
			continue
		var label_text: String = def[1]
		var rect: Rect2 = def[2]
		var color: Color = def[3]

		var zone := ColorRect.new()
		zone.name = zone_name
		zone.position = rect.position
		zone.size = rect.size
		zone.color = color
		zone.z_index = -5
		add_child(zone)

		var label := Label.new()
		label.name = zone_name + "Label"
		label.position = rect.position + Vector2(12, 8)
		label.z_index = -4
		label.add_theme_color_override("font_color", color.lightened(0.55))
		label.add_theme_color_override("font_outline_color", Color(0.12, 0.08, 0.05, 0.6))
		label.add_theme_constant_override("outline_size", 4)
		label.add_theme_font_size_override("font_size", 22)
		label.text = label_text
		add_child(label)

# ==================== 餐桌 ====================

## 按配置生成餐桌（就餐区装饰；数量 = TABLE_SLOTS 全部，P4+ 直接加槽位即可）
func _build_tables() -> void:
	for i in LayoutManager.TABLE_SLOTS.size():
		var table_name := "Table%d" % (i + 1)
		if has_node(table_name):
			continue
		var table := ColorRect.new()
		table.name = table_name
		table.position = LayoutManager.get_slot_position(LayoutManager.TABLE_SLOTS, i)
		table.size = Vector2(100, 50)
		table.color = Color(1, 1, 1, 0.35)
		table.z_index = -4
		add_child(table)

# ==================== 冰柜 + 货箱堆（#50 两段式补给） ====================

## 实例化冰柜并摆到布局槽位（动态生成幂等）；初始台面 sync 在此显式调用（不依赖 freezer._ready 的父节点时序）
func _build_freezer() -> void:
	if not has_node("Freezer"):
		var freezer: Node2D = FREEZER_SCENE.instantiate()
		freezer.name = "Freezer"
		add_child(freezer)
	$Freezer.global_position = LayoutManager.FREEZER_SLOT
	if $Freezer.has_method("sync_packages"):
		$Freezer.sync_packages()

## 按 CRATE_SLOTS + L1_DISHES 生成 3 个货箱堆（冷库区批发仓，动态生成幂等）
func _build_crate_stacks() -> void:
	for i in GameStateManager.L1_DISHES.size():
		var stack_name := "CrateStack" if i == 0 else "CrateStack%d" % (i + 1)
		if has_node(stack_name):
			get_node(stack_name).global_position = LayoutManager.get_slot_position(LayoutManager.CRATE_SLOTS, i)
			continue
		var stack: Node2D = CRATE_STACK_SCENE.instantiate()
		stack.name = stack_name
		add_child(stack)
		stack.set("dish_type", GameStateManager.L1_DISHES[i])
		if stack.has_method("apply_dish_visual"):
			stack.apply_dish_visual()
		stack.global_position = LayoutManager.get_slot_position(LayoutManager.CRATE_SLOTS, i)

# ==================== 外卖口（P4） ====================

## 实例化外卖取餐口并摆到布局点位（动态生成幂等：has_node 防编辑器热重载重复 _ready）
func _build_takeout_counter() -> void:
	if has_node("TakeoutCounter"):
		$TakeoutCounter.global_position = LayoutManager.PICKUP_POINT
		return
	var counter: Node2D = TAKEOUT_COUNTER_SCENE.instantiate()
	counter.name = "TakeoutCounter"
	add_child(counter)
	counter.global_position = LayoutManager.PICKUP_POINT

## 实例化外卖 UI：订单面板 + 骑手视觉（动态生成幂等）
func _build_takeaway_ui() -> void:
	if not has_node("TakeawayBoard"):
		var board: CanvasLayer = TAKEAWAY_BOARD_SCENE.instantiate()
		board.name = "TakeawayBoard"
		add_child(board)
	if not has_node("TakeawayRider"):
		var rider: Node2D = TAKEOUT_RIDER_SCRIPT.new()
		rider.name = "TakeawayRider"
		add_child(rider)

## 实例化升级商店（P5；打烊暂停中由日结算面板按钮打开，动态生成幂等）
func _build_upgrade_shop() -> void:
	if not has_node("UpgradeShop"):
		var shop: CanvasLayer = UPGRADE_SHOP_SCENE.instantiate()
		shop.name = "UpgradeShop"
		add_child(shop)

## 实例化抽卡面板（P6；打烊暂停中由日结算面板按钮打开，动态生成幂等）
func _build_card_draw() -> void:
	if not has_node("CardDraw"):
		var draw: CanvasLayer = CARD_DRAW_SCENE.instantiate()
		draw.name = "CardDraw"
		add_child(draw)

## 实例化招牌菜面板（P7；打烊暂停中由日结算面板按钮打开，动态生成幂等）
func _build_specialty_panel() -> void:
	if not has_node("SpecialtyPanel"):
		var panel: CanvasLayer = SPECIALTY_PANEL_SCENE.instantiate()
		panel.name = "SpecialtyPanel"
		add_child(panel)

## 实例化角色选择面板（P8；未选角色时启动弹出，动态生成幂等）
func _build_character_select() -> void:
	if not has_node("CharacterSelect"):
		var select: CanvasLayer = CHARACTER_SELECT_SCENE.instantiate()
		select.name = "CharacterSelect"
		add_child(select)
	# 未选角色 → 开店前弹出选择（暂停中；选择后恢复开始营业）
	if not CharacterManager.has_selected():
		get_node("CharacterSelect").call("show_select")

# ==================== P5 设备升级应用 ====================

## 应用升级状态（P5）：微波炉摆位 + 第二台实例化；冰柜扩容语义 = 每菜库存容量（Freezer.capacity，#50）
func _apply_upgrades() -> void:
	microwave.global_position = LayoutManager.get_slot_position(LayoutManager.MICROWAVE_SLOTS, 0)
	if not UpgradeManager.has_second_microwave:
		if has_node("Microwave2"):
			$Microwave2.queue_free()
		return
	if not has_node("Microwave2"):
		var mw2: Node2D = MICROWAVE_SCENE.instantiate()
		mw2.name = "Microwave2"
		add_child(mw2)
	$Microwave2.global_position = LayoutManager.get_slot_position(LayoutManager.MICROWAVE_SLOTS, 1)

## 升级购买后：应用设备效果 + 重置物品（清场后冰柜按库存重摆台面）
func _on_upgrades_changed() -> void:
	_apply_upgrades()
	_reset_shop_items()

# ==================== 节点摆放 ====================

## 按 LayoutManager 配置摆放全部功能节点（位置单一权威）
func _place_nodes() -> void:
	# 相机居中锁定（世界 = 窗口，整店可见不跟随）
	camera.position = LayoutManager.WORLD_SIZE / 2.0

	# 地板满铺世界
	floor_sprite.position = LayoutManager.WORLD_SIZE / 2.0
	if floor_sprite.texture != null:
		floor_sprite.scale = LayoutManager.WORLD_SIZE / floor_sprite.texture.get_size()

	# 关键点位（注意：SpawnPoint 节点 = 顾客生成入口，玩家出生点是 LayoutManager.SPAWN_POINT）
	spawn_point.global_position = LayoutManager.ENTRANCE_POINT
	counter_point.global_position = LayoutManager.COUNTER_POINT
	player.global_position = LayoutManager.SPAWN_POINT
