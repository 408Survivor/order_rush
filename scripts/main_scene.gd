## 文件: scripts/main_scene.gd
## 职责: 主场景组装：按 LayoutManager 布局配置生成区域视觉（色块+标签）并摆放全部节点
## 依赖: LayoutManager (autoload)；场景节点结构见 MainScene.tscn（节点位置以本脚本为准）
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

# ==================== 区域定义（名称/标签/矩形/色值，顺序与 LayoutManager.ZONE_* 一致） ====================
var _zone_defs: Array = []

func _ready() -> void:
	_zone_defs = [
		["ZoneStorage", "仓库区", LayoutManager.ZONE_STORAGE, Color(0.7, 0.85, 1, 0.22)],
		["ZoneKitchen", "厨房区", LayoutManager.ZONE_KITCHEN, Color(1, 0.95, 0.7, 0.22)],
		["ZoneFront", "前台", LayoutManager.ZONE_FRONT, Color(0.8, 1, 0.75, 0.22)],
		["ZoneDining", "就餐区", LayoutManager.ZONE_DINING, Color(1, 0.8, 0.6, 0.22)],
	]
	_build_zones()
	_build_tables()
	_place_nodes()

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
		label.add_theme_color_override("font_outline_color", Color(0.1, 0.15, 0.2, 0.6))
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

# ==================== 节点摆放 ====================

## 按 LayoutManager 配置摆放全部功能节点（位置单一权威）
func _place_nodes() -> void:
	# 相机居中锁定（世界 = 窗口，整店可见不跟随）
	camera.position = LayoutManager.WORLD_SIZE / 2.0

	# 地板满铺世界
	floor_sprite.position = LayoutManager.WORLD_SIZE / 2.0
	if floor_sprite.texture != null:
		floor_sprite.scale = LayoutManager.WORLD_SIZE / floor_sprite.texture.get_size()

	# 微波炉 → 设备槽位 0（第 2 槽位 P5 解锁）
	microwave.global_position = LayoutManager.get_slot_position(LayoutManager.MICROWAVE_SLOTS, 0)

	# 料理包 → 货架前 3 位（P7 多菜品扩展）
	var meal_names := ["MealPackage", "MealPackage2", "MealPackage3"]
	for i in meal_names.size():
		var meal := items_root.get_node_or_null(meal_names[i])
		if meal != null:
			meal.global_position = LayoutManager.get_slot_position(LayoutManager.MEAL_SLOTS, i)

	# 关键点位（注意：SpawnPoint 节点 = 顾客生成入口，玩家出生点是 LayoutManager.SPAWN_POINT）
	spawn_point.global_position = LayoutManager.ENTRANCE_POINT
	counter_point.global_position = LayoutManager.COUNTER_POINT
	player.global_position = LayoutManager.SPAWN_POINT
