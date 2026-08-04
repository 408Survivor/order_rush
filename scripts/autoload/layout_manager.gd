## 文件: scripts/autoload/layout_manager.gd
## 职责: 店内布局的单一权威配置：世界尺寸、区域矩形、关键点位、设备/货架/餐桌槽位、队列参数
## 依赖: 无
## 注意: 所有布局坐标集中于此——MainScene 按此生成区域视觉并摆放节点，
##       CustomerManager 按此计算队列槽位。新增设备/区域/货位只改本文件（issue #24）。
##       #50 布局动线重构：冷库区放货箱堆（CRATE_SLOTS），冰柜移至厨房区微波炉左侧，外卖口右移至柜台旁；
##       #54 冰柜四格取货：台面前取包位（MEAL_SLOTS）删除，料理包经 J/K/L/空格 从冰柜直接取货。

@tool
extends Node

# ==================== 世界 ====================
## 世界尺寸（= 窗口 1920x1080，整店可见）
const WORLD_SIZE := Vector2(1920, 1080)

# ==================== 区域（Rect2，含 20px 边距） ====================
const ZONE_STORAGE := Rect2(60, 60, 520, 320)      ## 冷库区（左上：货箱堆/批发仓）
const ZONE_KITCHEN := Rect2(620, 60, 1240, 320)    ## 厨房区（右上：加热设备）
const ZONE_FRONT := Rect2(60, 420, 1800, 220)      ## 前台（中部横贯：柜台/队伍/外卖口）
const ZONE_DINING := Rect2(60, 680, 1800, 260)     ## 就餐区（下部：餐桌）

# ==================== 关键点位 ====================
const SPAWN_POINT := Vector2(960, 300)       ## 玩家出生点（厨房区下缘中央，#50 微调避开冰柜）
const ENTRANCE_POINT := Vector2(80, 520)     ## 顾客入口（前台左端）
const COUNTER_POINT := Vector2(1350, 520)    ## 柜台服务点（前台偏右，队伍向左延伸）
const PICKUP_POINT := Vector2(1640, 520)     ## 外卖取餐口（#50 右移至柜台旁；入口/柜台不变，顾客行走时间不受影响）

# ==================== 顾客队列 ====================
## 队列间距（像素），需大于顾客碰撞直径 130
const QUEUE_SPACING := 200.0
## 队列容量（布局预留 5 人空间；当前玩法 max_queue=3，见 customer_manager.gd）
const QUEUE_CAPACITY := 5

# ==================== 设备/货架/餐桌槽位 ====================
## 微波炉位（第 1 位当前使用，第 2 位 P5 设备升级解锁；间距 260 > 矩形碰撞 250）
const MICROWAVE_SLOTS: Array[Vector2] = [Vector2(1700, 180), Vector2(1440, 180)]
## 冰柜位（#50：移至厨房区、微波炉左侧抱团；#54：四格展示库存，J/K/L/空格 取货）
const FREEZER_SLOT := Vector2(1150, 180)
## 货箱堆位（#50：冷库区 3 堆，对应 L1_DISHES 3 道菜；批发仓无限库存）
const CRATE_SLOTS: Array[Vector2] = [Vector2(150, 200), Vector2(320, 200), Vector2(490, 200)]
## 餐桌位（当前使用前 2 位，P4+ 扩展至 4）
const TABLE_SLOTS: Array[Vector2] = [
	Vector2(450, 800), Vector2(800, 800), Vector2(1150, 800), Vector2(1500, 800),
]

# ==================== 访问函数 ====================

## 取槽位坐标（越界报错并回退 ZERO，防节点静默落原点）
static func get_slot_position(slots: Array[Vector2], index: int) -> Vector2:
	if index < 0 or index >= slots.size():
		push_error("LayoutManager: slot index %d out of range (size %d)" % [index, slots.size()])
		return Vector2.ZERO
	return slots[index]
