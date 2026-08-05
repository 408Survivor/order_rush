## 文件: scripts/autoload/layout_manager.gd
## 职责: 店内布局的单一权威配置：世界尺寸、区域矩形、关键点位、设备/货架/餐桌槽位、队列参数
## 依赖: 无
## 注意: 所有布局坐标集中于此——MainScene 按此生成区域视觉并摆放节点，
##       CustomerManager 按此计算队列槽位。新增设备/区域/货位只改本文件（issue #24）。
##       #50 布局动线重构：冷库区放货箱堆（CRATE_SLOTS），冰柜移至厨房区微波炉左侧，外卖口右移至柜台旁；
##       #54 冰柜四格取货：台面前取包位（MEAL_SLOTS）删除，料理包经 J/K/L/空格 从冰柜直接取货；
##       #75 tile 化一期：TILE_SIZE=64 网格建立 + 纯视觉装饰点位收编（main_scene 硬编码 → 本文件常量）。

@tool
extends Node

# ==================== 世界 ====================
## 世界尺寸（= 窗口 1920x1080，整店可见）
const WORLD_SIZE := Vector2(1920, 1080)

# ==================== Tile 网格（#75 美术规格 Step2 一期） ====================
## 1 tile = 64px 世界单位（Art Bible v0.1，#65）；世界 1920x1080 = 30 x 16.875 tile
## 一期：仅建立网格常量/换算函数 + 收编装饰点位；gameplay 点位数值不动
## （tile 坐标注释标注，~ 表示非整格），Step 3 设备节点化时再统一取整
const TILE_SIZE := 64

## tile 坐标 → 世界坐标（允许小数格，如 tile(16.6, 2.8)）
static func tile(tx: float, ty: float) -> Vector2:
	return Vector2(tx, ty) * TILE_SIZE

# ==================== 区域（Rect2，含 20px 边距） ====================
const ZONE_STORAGE := Rect2(60, 60, 520, 320)      ## 冷库区（左上：货箱堆/批发仓）
const ZONE_KITCHEN := Rect2(620, 60, 1240, 320)    ## 厨房区（右上：加热设备）
const ZONE_FRONT := Rect2(60, 420, 1800, 220)      ## 前台（中部横贯：柜台/队伍/外卖口）
const ZONE_DINING := Rect2(60, 680, 1800, 260)     ## 就餐区（下部：餐桌）

# ==================== 关键点位 ====================
const SPAWN_POINT := Vector2(960, 300)       ## 玩家出生点（厨房区下缘中央，#50 微调避开冰柜）｜tile(15, ~4.7)
const ENTRANCE_POINT := Vector2(80, 520)     ## 顾客入口（前台左端）｜tile(~1.3, ~8.1)
const COUNTER_POINT := Vector2(1350, 520)    ## 柜台服务点（前台偏右，队伍向左延伸）｜tile(~21.1, ~8.1)
const PICKUP_POINT := Vector2(1640, 520)     ## 外卖取餐口（#50 右移至柜台旁；入口/柜台不变，顾客行走时间不受影响）｜tile(~25.6, ~8.1)

# ==================== 顾客队列 ====================
## 队列间距（像素），需大于顾客碰撞直径 130
const QUEUE_SPACING := 200.0
## 队列容量（布局预留 5 人空间；当前玩法 max_queue=3，见 customer_manager.gd）
const QUEUE_CAPACITY := 5

# ==================== 设备/货架/餐桌槽位 ====================
## 微波炉位（第 1 位当前使用，第 2 位 P5 设备升级解锁；间距 190 > 矩形碰撞 250 在 x 向投影）
## #61：整排左移腾出右缘——原 (1700,180) 被右上经营面板（x≥1620）遮住，现设备排右缘 ≤1610
const MICROWAVE_SLOTS: Array[Vector2] = [Vector2(1500, 180), Vector2(1310, 180)]  ## tile(~23.4/~20.5, ~2.8)
## 冰柜位（#50：移至厨房区、微波炉左侧抱团；#54：四格展示库存，J/K/L/空格 取货；#61 随设备排左移）
const FREEZER_SLOT := Vector2(1065, 180)  ## tile(~16.6, ~2.8)
## 货箱堆位（#50：冷库区 3 堆，对应 L1_DISHES 3 道菜；批发仓无限库存）
## #61：货箱上架立式冷冻柜——竖排 3 层（柜体层中心 136/204/272），第 4 层 (300,340) 预留 L2
const CRATE_SLOTS: Array[Vector2] = [Vector2(300, 136), Vector2(300, 204), Vector2(300, 272)]  ## tile(~4.7, ~2.1/3.2/4.25)
## 餐桌位（当前使用前 2 位，P4+ 扩展至 4）
const TABLE_SLOTS: Array[Vector2] = [
	Vector2(450, 800), Vector2(800, 800), Vector2(1150, 800), Vector2(1500, 800),  ## tile(~7/12.5/18/23.4, 12.5)
]

# ==================== 纯视觉装饰点位（#75 收编自 main_scene；z 序留在 main_scene 调用处） ====================
## 顶墙 4 段平铺（480 宽/段，y=60）
const WALL_TOP_SLOTS: Array[Vector2] = [Vector2(240, 60), Vector2(720, 60), Vector2(1200, 60), Vector2(1680, 60)]
## 侧墙左右各 2 段
const WALL_SIDE_SLOTS: Array[Vector2] = [Vector2(60, 300), Vector2(60, 780), Vector2(1860, 300), Vector2(1860, 780)]
## 入口门脸（盖左墙门洞位，与 ENTRANCE_POINT 对齐）
const DOOR_POS := Vector2(66, 520)
## 门内地垫
const FLOOR_MAT_POS := Vector2(200, 520)
## 整吧台单图中心（#75：1440 宽，x 180..1620——左让入口通道、右让外卖口）
const COUNTER_BAR_POS := Vector2(900, 452)
## 收银机相对 COUNTER_POINT 的偏移（#75：-150 坐上整吧台后沿台面——木台面 y≈357..442，机底没入台沿读作置于台面）
const CASHIER_OFFSET := Vector2(0, -150)
## 就餐区地毯（垫桌下）
const RUG_POS := Vector2(975, 810)
## 绿植 ×2
const PLANT_SLOTS: Array[Vector2] = [Vector2(140, 960), Vector2(1790, 700)]
## 垃圾桶
const TRASH_BIN_POS := Vector2(1790, 560)
## 冷库区立式四层冷冻柜（货箱堆按 CRATE_SLOTS 上架）
const FRIDGE_CABINET_POS := Vector2(300, 218)
## 厨房操作长桌（垫冰柜/微波炉一排之下）
const WORK_TABLE_POS := Vector2(1300, 190)

# ==================== 访问函数 ====================

## 取槽位坐标（越界报错并回退 ZERO，防节点静默落原点）
static func get_slot_position(slots: Array[Vector2], index: int) -> Vector2:
	if index < 0 or index >= slots.size():
		push_error("LayoutManager: slot index %d out of range (size %d)" % [index, slots.size()])
		return Vector2.ZERO
	return slots[index]
