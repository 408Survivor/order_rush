## 文件: scripts/main_scene.gd
## 职责: 主场景组装：按 LayoutManager 布局配置生成区域视觉（色块，#56 起无标签）、#51 场景陈设（墙/吧台/桌椅/装饰）、
##       #85 店外氛围带（草地/石板路/果树/灌木/路灯/栅栏，纯视觉）并摆放全部节点；
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

## 微波炉场景（P5：第二台升级后实例化）
const MICROWAVE_SCENE := preload("res://scenes/props/Microwave.tscn")
## 冰柜场景（#54：四格展示库存 + J/K/L/空格 取货）
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
## 反馈层脚本（#67：世界飘字 + 金币飞行，动态实例化 CanvasLayer）
const FLOATING_FEEDBACK_SCRIPT := preload("res://scripts/ui/floating_feedback.gd")
## 角色选择面板场景（P8，动态实例化 CanvasLayer；#48 起为 tscn）
const CHARACTER_SELECT_SCENE := preload("res://scenes/ui/CharacterSelect.tscn")

# ==================== #51 场景陈设素材（手绘 SVG，纯视觉） ====================
const WALL_TOP_TEX := preload("res://assets/art/props/wall_top.png")
const WALL_SIDE_TEX := preload("res://assets/art/props/wall_side.png")
const DOOR_TEX := preload("res://assets/art/props/door.png")
const FLOOR_MAT_TEX := preload("res://assets/art/props/floor_mat.png")
const COUNTER_BAR_TEX := preload("res://assets/art/props/counter_bar.png")
const CASHIER_TEX := preload("res://assets/art/props/cashier.png")
const TABLE_TEX := preload("res://assets/art/props/table.png")
const CHAIR_TEX := preload("res://assets/art/props/chair.png")
const PLANT_TEX := preload("res://assets/art/props/plant.png")
const TRASH_BIN_TEX := preload("res://assets/art/props/trash_bin.png")
const RUG_TEX := preload("res://assets/art/props/rug.png")
const FRIDGE_CABINET_TEX := preload("res://assets/art/props/fridge_cabinet.png")  ## #61 立式四层冷冻柜（#63 AI 素材）
const SHELF_WALL_TEX := preload("res://assets/art/props/shelf_wall.svg")          ## #93 靠墙置物架（手绘 SVG）
const DISPLAY_CASE_TEX := preload("res://assets/art/props/display_case.svg")      ## #93 玻璃展示柜（手绘 SVG）
const DEVICE_TABLE_SCENE := preload("res://scenes/props/DeviceTable.tscn")        ## #93 工作台（设备上桌底座）
## #93 靠墙置物架缩放（SVG 200x320 → 场景 150x240）
const SHELF_SCALE := Vector2(0.75, 0.75)
const CABINET_KEY_HINTS_SCRIPT := preload("res://scripts/props/cabinet_key_hints.gd")  ## #77 冷库柜四层键标
# ==================== #85 店外氛围带素材（手绘 SVG，纯视觉） ====================
const GRASS_TEX := preload("res://assets/art/props/grass.svg")
const STONE_PATH_TEX := preload("res://assets/art/props/stone_path.svg")
const FRUIT_TREE_TEX := preload("res://assets/art/props/fruit_tree.svg")
const BUSH_TEX := preload("res://assets/art/props/bush.svg")
const GARDEN_LAMP_TEX := preload("res://assets/art/props/garden_lamp.svg")
const FENCE_TEX := preload("res://assets/art/props/fence.svg")

# ==================== 区域定义（名称/标签/矩形/色值，顺序与 LayoutManager.ZONE_* 一致） ====================
var _zone_defs: Array = []

func _ready() -> void:
	_init_debug_screenshot()
	# #60 全场景 Y 排序：同 z 层内按 y 排绘制（靠南/靠前的后画，遮挡关系自动正确）。
	# 嵌套 y-sort 扁平化：MainScene + CustomerManager + Items 三处开，全场景统一排序；
	# 玩家/顾客子树不开——保护手持物（HeldItemPivot）与头顶订单标签的树内绘制顺序
	y_sort_enabled = true
	$CustomerManager.y_sort_enabled = true
	items_root.y_sort_enabled = true
	_zone_defs = [
		["ZoneStorage", LayoutManager.ZONE_STORAGE, Color(0.7, 0.85, 1, 0.06)],
		["ZoneKitchen", LayoutManager.ZONE_KITCHEN, Color(1, 0.95, 0.7, 0.06)],
		["ZoneFront", LayoutManager.ZONE_FRONT, Color(0.8, 1, 0.75, 0.06)],
		["ZoneDining", LayoutManager.ZONE_DINING, Color(1, 0.8, 0.6, 0.06)],
	]
	_build_zones()
	# #85 店外氛围带：草地垫底 + 石板路/果树/灌木/路灯/栅栏（纯视觉，先于店内陈设生成垫底）
	_build_outdoor()
	# #51 场景陈设：墙体/门/吧台/装饰先于功能道具生成（同 z 时功能道具后画在上层）
	_build_walls()
	_build_counter()
	_build_decorations()
	_build_tables()
	# #93：置物架 / 工作台（设备上桌底座）/ 展示柜
	_build_shelves()
	_build_device_tables()
	_build_display_cases()
	_build_freezer()
	_build_crate_stacks()
	_build_cabinet_key_hints()
	_build_takeout_counter()
	_build_takeaway_ui()
	_build_upgrade_shop()
	_build_card_draw()
	_build_specialty_panel()
	_build_character_select()
	_build_floating_feedback()
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

## 新一天重置：销毁手持/微波炉内/散落物品（#54：冰柜库存跨天保留，四格展示无需重建）
func _reset_shop_items() -> void:
	# 玩家手持物品销毁（跨天不保留）
	if player.has_method("discard_held_item"):
		player.discard_held_item()
	# 微波炉内物品清空（含加热中强制中止）——含 P5 第二台
	for mw: Node in [microwave, get_node_or_null("Microwave2")]:
		if mw != null and mw.has_method("clear_contents"):
			mw.clear_contents()
	# 清理散落物品（成品菜/货箱/Q 放下的料理包等全部清空；#54 起冰柜不再镜像台面包）
	for child in items_root.get_children():
		child.queue_free()
	# 玩家复位出生点
	player.global_position = LayoutManager.SPAWN_POINT

# ==================== 区域视觉 ====================

## 按配置生成区域色块（幂等：已存在则跳过，防编辑器热重载重复）
## #56：区域 Label 删除（陈设已定义分区），色块 alpha 降到 0.06 仅留极淡分区感
func _build_zones() -> void:
	for def in _zone_defs:
		var zone_name: String = def[0]
		if has_node(zone_name):
			continue
		var rect: Rect2 = def[1]
		var color: Color = def[2]

		var zone := ColorRect.new()
		zone.name = zone_name
		zone.position = rect.position
		zone.size = rect.size
		zone.color = color
		zone.z_index = -5
		add_child(zone)

# ==================== 餐桌 ====================

## 按配置生成餐桌（#51：圆桌 + 每桌左右两把圆凳；数量 = TABLE_SLOTS 全部，P4+ 直接加槽位即可）
## #75：桌/凳 PNG 已按世界尺寸重出（×0.85/×0.7 烘入），scale 恒为 1
func _build_tables() -> void:
	for i in LayoutManager.TABLE_SLOTS.size():
		var table_name := "Table%d" % (i + 1)
		var slot: Vector2 = LayoutManager.get_slot_position(LayoutManager.TABLE_SLOTS, i)
		_add_prop_sprite(table_name, TABLE_TEX, slot, Vector2.ONE)
		_add_prop_sprite(table_name + "ChairL", CHAIR_TEX, slot + Vector2(-110, 0), Vector2.ONE)
		_add_prop_sprite(table_name + "ChairR", CHAIR_TEX, slot + Vector2(110, 0), Vector2.ONE)

# ==================== #51 场景陈设（墙体/吧台/装饰，全部纯视觉无碰撞） ====================

## 通用陈设生成：Sprite2D 纯视觉（幂等：has_node 防编辑器热重载重复）
func _add_prop_sprite(prop_name: String, tex: Texture2D, pos: Vector2, prop_scale: Vector2, z: int = 0) -> Sprite2D:
	if has_node(prop_name):
		return get_node(prop_name)
	var sprite := Sprite2D.new()
	sprite.name = prop_name
	sprite.texture = tex
	sprite.position = pos
	sprite.scale = prop_scale
	sprite.z_index = z
	add_child(sprite)
	return sprite

## 墙体与门脸（z=-3）：顶墙平铺、左右侧墙平铺（段数 = LayoutManager 槽位数组长度）；入口盖门 + 门内地垫（z=-9）
## #75：点位收编 LayoutManager；门/地毯 PNG 已按世界尺寸重出，scale 恒为 1
## #90：段数随店内尺寸扩容（顶 4→5、侧 2→3/边），循环按槽位数组驱动不再硬编码
func _build_walls() -> void:
	for i in LayoutManager.WALL_TOP_SLOTS.size():
		_add_prop_sprite("WallTop%d" % (i + 1), WALL_TOP_TEX, LayoutManager.WALL_TOP_SLOTS[i], Vector2.ONE, -3)
	for i in 3:
		_add_prop_sprite("WallSideL%d" % (i + 1), WALL_SIDE_TEX, LayoutManager.WALL_SIDE_SLOTS[i], Vector2.ONE, -3)
		_add_prop_sprite("WallSideR%d" % (i + 1), WALL_SIDE_TEX, LayoutManager.WALL_SIDE_SLOTS[3 + i], Vector2.ONE, -3)
	# 入口门脸盖左墙门洞位（与顾客入口 ENTRANCE_POINT 对齐；门在墙段之后生成，同 z 绘制在上层）
	_add_prop_sprite("Door", DOOR_TEX, LayoutManager.DOOR_POS, Vector2.ONE, -2)  # #63：新侧墙变宽，门 z 提高避免被盖
	# 门内地垫（z=-9 压地板、在区域色块之下）
	_add_prop_sprite("FloorMat", FLOOR_MAT_TEX, LayoutManager.FLOOR_MAT_POS, Vector2.ONE, -9)

## 前台吧台 + 收银机（#51 视觉；#58 加碰撞体——只挡玩家，顾客不受影响）
## #75：整吧台单图（1440×189 批次 021 v3 空台面），scale=1 单 sprite——左让入口通道、右让外卖口，不压顾客队列区
## #90：店内加宽只重摆（COUNTER_BAR_POS 跟随），图宽不变故碰撞体尺寸不变、位置按偏移跟随
func _build_counter() -> void:
	_add_prop_sprite("CounterBar", COUNTER_BAR_TEX, LayoutManager.COUNTER_BAR_POS, Vector2.ONE)
	_add_prop_sprite("Cashier", CASHIER_TEX, LayoutManager.COUNTER_POINT + LayoutManager.CASHIER_OFFSET, Vector2.ONE)
	# #58 吧台碰撞体：StaticBody2D(layer=1) 只挡玩家（顾客 mask 已去 World 层）；
	# 只覆盖正面厚度（柜点 y-20..y+12）——台面视觉可重叠，俯视角下头压桌面是正常观感；
	# 玩家（半径 117）北面停在柜点 y-137，距队列顾客 137px < 交互范围 160
	if not has_node("CounterBody"):
		var body := StaticBody2D.new()
		body.name = "CounterBody"
		body.collision_layer = 1
		body.collision_mask = 0
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(1440, 32)
		shape.shape = rect
		body.add_child(shape)
		add_child(body)
	# 位置每帧就绪都跟随布局（@tool 编辑器内热重载也要复位，不能只写在 has_node 分支里）
	$CounterBody.position = LayoutManager.COUNTER_BAR_POS + Vector2(60, 64)

## 装饰陈设：就餐区地毯（z=-9 垫桌下）+ 绿植 + 垃圾桶 + #61 立式冷冻柜（z=-1 作功能道具背景，不遮交互视觉）
## #75：点位收编 LayoutManager；地毯 PNG 已按世界尺寸重出，scale 恒为 1
func _build_decorations() -> void:
	_add_prop_sprite("Rug", RUG_TEX, LayoutManager.RUG_POS, Vector2.ONE, -9)
	_add_prop_sprite("Plant1", PLANT_TEX, LayoutManager.PLANT_SLOTS[0], Vector2.ONE)
	_add_prop_sprite("Plant2", PLANT_TEX, LayoutManager.PLANT_SLOTS[1], Vector2.ONE)
	_add_prop_sprite("TrashBin", TRASH_BIN_TEX, LayoutManager.TRASH_BIN_POS, Vector2.ONE)
	# #61：立式四层冷冻柜（货箱堆按 CRATE_SLOTS 上架）
	_add_prop_sprite("FridgeCabinet", FRIDGE_CABINET_TEX, LayoutManager.FRIDGE_CABINET_POS, Vector2.ONE, -1)

# ==================== #93 置物架 / 工作台 / 展示柜 ====================

## 靠墙置物架 ×3（z=-1 贴墙背景；顶墙下沿，冷库区与厨房区之间）
func _build_shelves() -> void:
	for i in LayoutManager.SHELF_SLOTS.size():
		_add_prop_sprite("ShelfWall%d" % (i + 1), SHELF_WALL_TEX,
			LayoutManager.get_slot_position(LayoutManager.SHELF_SLOTS, i), SHELF_SCALE, -1)

## 工作台 ×2（设备上桌底座；替换 #61 WORK_TABLE 单图。桌面 z=-1 由 device_table.gd 自设）
func _build_device_tables() -> void:
	for i in LayoutManager.DEVICE_TABLE_SLOTS.size():
		var table_name := "DeviceTable" if i == 0 else "DeviceTable%d" % (i + 1)
		if not has_node(table_name):
			var table: Node2D = DEVICE_TABLE_SCENE.instantiate()
			table.name = table_name
			table.set("table_index", i)  # 须在 add_child 前注入：_ready 即按序号摆槽位
			add_child(table)
		var table_node: Node2D = get_node(table_name)
		table_node.global_position = LayoutManager.get_slot_position(LayoutManager.DEVICE_TABLE_SLOTS, i)
		table_node.call("_sync_slots")  # 槽位按新全局位置重摆（编辑器热重载/布局调整时跟随）

## 玻璃展示柜 ×2（z=0 参与 y-sort 遮挡；前区下沿、收银台左侧）
func _build_display_cases() -> void:
	for i in LayoutManager.DISPLAY_SLOTS.size():
		_add_prop_sprite("DisplayCase%d" % (i + 1), DISPLAY_CASE_TEX,
			LayoutManager.get_slot_position(LayoutManager.DISPLAY_SLOTS, i), Vector2.ONE, 0)

# ==================== #85 店外氛围带（草地/石板路/果树/灌木/路灯/栅栏，全部纯视觉无碰撞） ====================

## 店外氛围带生成（幂等：has_node 防编辑器热重载重复；节点自身不开 y_sort——继承 MainScene 根排序即可）
## z 层：草地 -11（比店内地板 -10 更靠底）、石板路 -9（同门内地垫，压草地）；果树/灌木/路灯/栅栏 z=0
## 参与全场景 y-sort——玩家/顾客走进店外时遮挡自动正确（#60 扁平化排序覆盖世界全域）
func _build_outdoor() -> void:
	# 草地整图垫底（768x432 等比拉伸铺满世界）
	if not has_node("Grass"):
		var grass := Sprite2D.new()
		grass.name = "Grass"
		grass.texture = GRASS_TEX
		grass.position = LayoutManager.WORLD_ORIGIN + LayoutManager.WORLD_SIZE / 2.0
		grass.scale = LayoutManager.WORLD_SIZE / Vector2(GRASS_TEX.get_size())
		grass.z_index = -11
		add_child(grass)
	# 石板小路（左带，对齐顾客入口动线）
	_add_prop_sprite("StonePath", STONE_PATH_TEX, LayoutManager.STONE_PATH_POS, Vector2.ONE, -9)
	# 果树 ×4 / 灌木 ×6 / 路灯 ×2 / 栅栏 ×9（点位单一权威 = LayoutManager）
	for i in LayoutManager.TREE_SLOTS.size():
		_add_prop_sprite("FruitTree%d" % (i + 1), FRUIT_TREE_TEX, LayoutManager.get_slot_position(LayoutManager.TREE_SLOTS, i), Vector2.ONE)
	for i in LayoutManager.BUSH_SLOTS.size():
		_add_prop_sprite("Bush%d" % (i + 1), BUSH_TEX, LayoutManager.get_slot_position(LayoutManager.BUSH_SLOTS, i), Vector2.ONE)
	for i in LayoutManager.LAMP_SLOTS.size():
		_add_prop_sprite("GardenLamp%d" % (i + 1), GARDEN_LAMP_TEX, LayoutManager.get_slot_position(LayoutManager.LAMP_SLOTS, i), Vector2.ONE)
	for i in LayoutManager.FENCE_SLOTS.size():
		_add_prop_sprite("Fence%d" % (i + 1), FENCE_TEX, LayoutManager.get_slot_position(LayoutManager.FENCE_SLOTS, i), Vector2.ONE)

# ==================== 冰柜 + 货箱堆（#50 两段式补给；#54 四格取货） ====================

## 实例化冰柜并摆到布局槽位（动态生成幂等）
func _build_freezer() -> void:
	if not has_node("Freezer"):
		var freezer: Node2D = FREEZER_SCENE.instantiate()
		freezer.name = "Freezer"
		add_child(freezer)
	$Freezer.global_position = LayoutManager.FREEZER_SLOT

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

# ==================== 冷库柜四层键标（#77） ====================

## 生成 CabinetKeyHints（动态生成幂等）：[J]/[K]/[L]/[空格] 浮于对应层上方，靠近才显示。
## 层中心 = CRATE_SLOTS y（136/204/272）+ 第 4 层预留 (300,340)；标签放层左侧蓝色内壁区（层距 68 < 箱堆高 ≈90，上方无干净间隙）
func _build_cabinet_key_hints() -> void:
	if has_node("CabinetKeyHints"):
		return
	var hints := Node2D.new()
	hints.name = "CabinetKeyHints"
	hints.set_script(CABINET_KEY_HINTS_SCRIPT)
	add_child(hints)
	hints.global_position = LayoutManager.FRIDGE_CABINET_POS
	var tier_ys: Array[float] = [136.0, 204.0, 272.0, 340.0]
	var keys: Array[String] = ["[J]", "[K]", "[L]", "[空格]"]
	for i in 4:
		var label := Label.new()
		label.name = "Tier%d" % (i + 1)
		label.text = keys[i]
		label.add_theme_color_override("font_color", Color(0.35, 0.3, 0.25, 1))
		label.add_theme_color_override("font_outline_color", Color(1, 1, 1, 0.9))
		label.add_theme_constant_override("outline_size", 4)
		label.add_theme_font_size_override("font_size", 11)
		label.position = Vector2(-100, tier_ys[i] - LayoutManager.FRIDGE_CABINET_POS.y - 8.0)
		label.size = Vector2(50, 16)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hints.add_child(label)
	hints.visible = false

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

## 实例化反馈层（#67：世界飘字 + 金币飞行，动态生成幂等）
func _build_floating_feedback() -> void:
	if not has_node("FloatingFeedback"):
		var feedback: CanvasLayer = FLOATING_FEEDBACK_SCRIPT.new()
		feedback.name = "FloatingFeedback"
		add_child(feedback)

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

## 升级购买后：应用设备效果 + 重置物品（清场；冰柜库存不受升级影响）
func _on_upgrades_changed() -> void:
	_apply_upgrades()
	_reset_shop_items()

# ==================== 调试截图（#56） ====================

## 自动截图帧计数（-1 = 关闭；>=0 时每帧 +1，到 _debug_shot_target 截图并退出，供终端核验运行画面）
var _debug_shot_frame := -1
## 自动截图触发帧（默认 ~25s：顾客/订单/外卖骑手已上屏，画面最具代表性）
const DEBUG_SHOT_AT_FRAME := 1500
## 截图输出目录（已 gitignore）
const DEBUG_SHOT_DIR := "res://debug_shots"
## 自动截图目标帧（--debug-screenshot=N 指定；#84 修复 N > 1500 时计数从负值起步永不触发的问题）
var _debug_shot_target := DEBUG_SHOT_AT_FRAME

## 启动时检测 --debug-screenshot[=帧数] 用户参数：开启自动截图，并跳过角色选择面板（不落存档）
func _init_debug_screenshot() -> void:
	if Engine.is_editor_hint():
		return
	var frame := DEBUG_SHOT_AT_FRAME
	var found := false
	for arg in OS.get_cmdline_user_args():
		if arg == "--debug-screenshot":
			found = true
		elif arg.begins_with("--debug-screenshot="):
			found = true
			frame = int(arg.get_slice("=", 1))
	if not found:
		return
	_debug_shot_target = frame
	_debug_shot_frame = 0
	if not CharacterManager.has_selected():
		CharacterManager.current_character = "chef"
	# --debug-walk-down：持续按住下移（验证碰撞体阻挡效果，#58）
	if OS.get_cmdline_user_args().has("--debug-walk-down"):
		Input.action_press("move_down")

## F12 手动截图（运行模式）
func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F12:
		print("DEBUG_SHOT_SAVED %s" % save_debug_screenshot())

func _process(_delta: float) -> void:
	if _debug_shot_frame < 0:
		return
	_debug_shot_frame += 1
	if _debug_shot_frame == _debug_shot_target:
		print("DEBUG_SHOT_SAVED %s" % save_debug_screenshot())
		_dump_ui_tree()
		get_tree().quit()

## 保存当前视口为 PNG，返回绝对路径（macOS 下绕过 TCC 屏幕录制权限——Godot 已有完全磁盘访问）
func save_debug_screenshot() -> String:
	DirAccess.make_dir_recursive_absolute(DEBUG_SHOT_DIR)
	var file := "%s/shot_%s.png" % [DEBUG_SHOT_DIR, Time.get_datetime_string_from_system().replace(":", "-")]
	get_viewport().get_texture().get_image().save_png(file)
	return ProjectSettings.globalize_path(file)

## 打印可见 UI 树（定位莫名面板用；只列实际参与绘制的节点）
func _dump_ui_tree(node: Node = null, depth: int = 0) -> void:
	if node == null:
		node = get_tree().root
		if toast_manager != null:
			print("UI_DUMP toasts=%d" % toast_manager.get("_toasts").size())
			for t in toast_manager.get("_toasts"):
				print("UI_DUMP toast bg=%s text=%s" % [(t["bg"] as Control).get_global_rect(), (t["label"] as RichTextLabel).text])
	if node is Control:
		var ctl := node as Control
		if ctl.is_visible_in_tree():
			print("UI_DUMP %s%s grect=%s" % ["-".repeat(depth * 2), ctl.name, ctl.get_global_rect()])
	elif node is CanvasLayer:
		print("UI_DUMP %s[%s]" % ["-".repeat(depth * 2), node.name])
	for child in node.get_children():
		_dump_ui_tree(child, depth + 1)

# ==================== 节点摆放 ====================

## 按 LayoutManager 配置摆放全部功能节点（位置单一权威）
func _place_nodes() -> void:
	# 相机居中锁定（世界中心 = WORLD_ORIGIN + WORLD_SIZE/2）+ zoom 适配整世界（zoom = WINDOW/WORLD 动态换算）
	camera.position = LayoutManager.WORLD_ORIGIN + LayoutManager.WORLD_SIZE / 2.0
	camera.zoom = LayoutManager.WINDOW_SIZE / LayoutManager.WORLD_SIZE

	# 地板满铺店内（#60：z=-10 垫底；#85：店外由草地 -11 承接，地板仍只盖 SHOP_SIZE 店内范围）
	floor_sprite.z_index = -10
	floor_sprite.position = LayoutManager.SHOP_SIZE / 2.0
	if floor_sprite.texture != null:
		floor_sprite.scale = LayoutManager.SHOP_SIZE / floor_sprite.texture.get_size()

	# 关键点位（注意：SpawnPoint 节点 = 顾客生成入口，玩家出生点是 LayoutManager.SPAWN_POINT）
	spawn_point.global_position = LayoutManager.ENTRANCE_POINT
	counter_point.global_position = LayoutManager.COUNTER_POINT
	player.global_position = LayoutManager.SPAWN_POINT
