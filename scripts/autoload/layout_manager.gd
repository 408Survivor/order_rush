## 文件: scripts/autoload/layout_manager.gd
## 职责: 店内布局的单一权威配置：世界尺寸、区域矩形、关键点位、设备/货架/餐桌槽位、队列参数
## 依赖: 无
## 注意: 所有布局坐标集中于此——MainScene 按此生成区域视觉并摆放节点，
##       CustomerManager 按此计算队列槽位。新增设备/区域/货位只改本文件（issue #24）。
##       #50 布局动线重构：冷库区放货箱堆（CRATE_SLOTS），冰柜移至厨房区微波炉左侧，外卖口右移至柜台旁；
##       #54 冰柜四格取货：台面前取包位（MEAL_SLOTS）删除，料理包经 J/K/L/空格 从冰柜直接取货；
##       #75 tile 化一期：TILE_SIZE=64 网格建立 + 纯视觉装饰点位收编（main_scene 硬编码 → 本文件常量）；
##       #85 店外氛围带：世界四周外扩（左右 192 / 上下 108，保持 16:9），店内 SHOP_SIZE 与全部 gameplay 点位数值不变；
##       #90 店堂内部扩容：SHOP_SIZE 1920x1080 → 2304x1296（+20% 线性），拓扑不变只拉间距——
##       设备排/柜台/餐桌区/冷库区之间走道加宽；世界 = 店内 + 氛围带边距 → 2688x1512（仍 16:9）。

@tool
extends Node

# ==================== 世界 ====================
## 窗口尺寸（= project.godot viewport 2560x1440，相机 zoom 换算用；#89 从 1920x1080 提升，店内元素视觉放大）
const WINDOW_SIZE := Vector2(2560, 1440)
## 店内范围（#90 扩容 1920x1080 → 2304x1296：地板/墙体/gameplay 全部在此内；+20% 线性，走道整体拉宽）
const SHOP_SIZE := Vector2(2304, 1296)
## 世界左上角（#85 店外氛围带边距：左右 192 = 3 tile、上下 108；世界 = 店内 + 四周氛围带，#90 边距不变）
const WORLD_ORIGIN := Vector2(-192, -108)
## 世界尺寸（#90：2688x1512 = 2304+2×192 / 1296+2×108，仍 16:9；相机 zoom = WINDOW/WORLD ≈ 0.952 整世界可见）
const WORLD_SIZE := Vector2(2688, 1512)

# ==================== Tile 网格（#75 美术规格 Step2 一期） ====================
## 1 tile = 64px 世界单位（Art Bible v0.1，#65）；世界 2688x1512 = 42 x 23.625 tile（#90，店内 36 x 20.25）
## 一期：仅建立网格常量/换算函数 + 收编装饰点位；gameplay 点位数值不动
## （tile 坐标注释标注，~ 表示非整格），Step 3 设备节点化时再统一取整
const TILE_SIZE := 64

## tile 坐标 → 世界坐标（允许小数格，如 tile(16.6, 2.8)）
static func tile(tx: float, ty: float) -> Vector2:
	return Vector2(tx, ty) * TILE_SIZE

# ==================== 区域（Rect2，含 20px 边距） ====================
const ZONE_STORAGE := Rect2(60, 60, 560, 380)       ## 冷库区（左上：货箱堆/批发仓）
const ZONE_KITCHEN := Rect2(660, 60, 1560, 380)     ## 厨房区（右上：加热设备）
const ZONE_FRONT := Rect2(60, 560, 2184, 240)       ## 前台（中部横贯：柜台/队伍/外卖口）
const ZONE_DINING := Rect2(60, 860, 2184, 340)      ## 就餐区（下部：餐桌）

# ==================== 关键点位（#90 扩容重排：拓扑不变，间距拉开） ====================
const SPAWN_POINT := Vector2(1152, 460)      ## 玩家出生点（店内横向中央、设备排与柜台之间走道）｜tile(18, ~7.2)
const ENTRANCE_POINT := Vector2(80, 680)     ## 顾客入口（前台左端，左墙中部）｜tile(~1.3, ~10.6)
const COUNTER_POINT := Vector2(1560, 680)    ## 柜台服务点（前台偏右，队伍向左延伸）｜tile(~24.4, ~10.6)
const PICKUP_POINT := Vector2(1850, 680)     ## 外卖取餐口（柜台右侧，吧台右缘 +20）｜tile(~28.9, ~10.6)

# ==================== 顾客队列 ====================
## 队列间距（像素），需大于顾客碰撞直径 130
const QUEUE_SPACING := 200.0
## 队列容量（布局预留 5 人空间；当前玩法 max_queue=3，见 customer_manager.gd）
const QUEUE_CAPACITY := 5

# ==================== 设备/货架/餐桌槽位 ====================
## 微波炉位（第 1 位当前使用，第 2 位 P5 设备升级解锁；#90 间距 190 → 270 > 矩形碰撞 250，不再相邻重叠）
## #90：设备排整体拉开——右缘 ≤1815，仍避开右上经营面板/外卖面板（屏幕 x≥2204）
const MICROWAVE_SLOTS: Array[Vector2] = [Vector2(1690, 230), Vector2(1420, 230)]  ## tile(~26.4/~22.2, ~3.6)
## 冰柜位（#50：移至厨房区、微波炉左侧抱团；#54：四格展示库存，J/K/L/空格 取货；#90 随设备排拉开）
const FREEZER_SLOT := Vector2(1150, 230)  ## tile(~18.0, ~3.6)
## 货箱堆位（#50：冷库区 3 堆，对应 L1_DISHES 3 道菜；批发仓无限库存）
## #61：货箱上架立式冷冻柜——竖排 3 层（柜体层中心 136/204/272 与柜图美术层绑定，#90 不动），第 4 层 (300,340) 预留 L2
const CRATE_SLOTS: Array[Vector2] = [Vector2(300, 136), Vector2(300, 204), Vector2(300, 272)]  ## tile(~4.7, ~2.1/3.2/4.25)
## 餐桌位（当前使用前 2 位，P4+ 扩展至 4；#90 间距 350 → 480，y 800 → 1020 让出柜台后走道）
const TABLE_SLOTS: Array[Vector2] = [
	Vector2(520, 1020), Vector2(1000, 1020), Vector2(1480, 1020), Vector2(1960, 1020),  ## tile(~8.1/15.6/23.1/30.6, ~15.9)
]

# ==================== 纯视觉装饰点位（#75 收编自 main_scene；z 序留在 main_scene 调用处） ====================
## 顶墙 5 段平铺（480 宽/段，y=60；#90 店内 2304 宽 → 4 段 → 5 段，末段探出右缘 96px 无碍）
const WALL_TOP_SLOTS: Array[Vector2] = [Vector2(240, 60), Vector2(720, 60), Vector2(1200, 60), Vector2(1680, 60), Vector2(2160, 60)]
## 侧墙左右各 3 段（480 高/段；#90 店内 1296 高 → 2 段 → 3 段，末段探入底带 144px 盖草地无碍）
const WALL_SIDE_SLOTS: Array[Vector2] = [
	Vector2(60, 240), Vector2(60, 720), Vector2(60, 1200),
	Vector2(2244, 240), Vector2(2244, 720), Vector2(2244, 1200),
]
## 入口门脸（盖左墙门洞位，与 ENTRANCE_POINT 对齐）
const DOOR_POS := Vector2(66, 680)
## 门内地垫
const FLOOR_MAT_POS := Vector2(200, 680)
## 整吧台单图中心（#75：1440 宽；#90 店内加宽只重摆不重出图——x 390..1830：左让入口通道、右让外卖口）
const COUNTER_BAR_POS := Vector2(1110, 612)
## 收银机相对 COUNTER_POINT 的偏移（#75：-150 坐上整吧台后沿台面——木台面没入台沿读作置于台面）
const CASHIER_OFFSET := Vector2(0, -150)
## 就餐区地毯（垫中间两桌下）
const RUG_POS := Vector2(1240, 1020)
## 绿植 ×2
const PLANT_SLOTS: Array[Vector2] = [Vector2(170, 1180), Vector2(2140, 820)]
## 垃圾桶
const TRASH_BIN_POS := Vector2(2140, 640)
## 冷库区立式四层冷冻柜（货箱堆按 CRATE_SLOTS 上架；#90 不动——层中心与柜图美术绑定）
const FRIDGE_CABINET_POS := Vector2(300, 218)
## 厨房操作长桌（垫冰柜/微波炉一排之下）
const WORK_TABLE_POS := Vector2(1420, 240)

# ==================== 店外氛围带（#85，纯视觉无碰撞；#90 随新世界边界平移；z 序留在 main_scene 调用处） ====================
## 石板小路中心（左氛围带，y=680 对齐顾客入口动线 ENTRANCE_POINT，东端抵门脸 DOOR_POS）
const STONE_PATH_POS := Vector2(-61, 680)
## 果树 ×4（左带上下各一 + 右带上/中各一；190x240，全部收在氛围带内；右带随店右缘 2304 平移）
const TREE_SLOTS: Array[Vector2] = [Vector2(-90, 220), Vector2(-90, 1060), Vector2(2394, 60), Vector2(2394, 880)]
## 灌木 ×6（顶带横排 4 + 右带 2；#90 顶带按新世界宽 2688 拉开）
const BUSH_SLOTS: Array[Vector2] = [
	Vector2(300, -52), Vector2(1000, -52), Vector2(1700, -52), Vector2(2350, -52),
	Vector2(2404, 500), Vector2(2414, 1160),
]
## 路灯 ×2（左带石板路两侧交错，对标烘焙糕手路边灯；#90 随石板路 y=680 平移）
const LAMP_SLOTS: Array[Vector2] = [Vector2(-140, 555), Vector2(-45, 815)]
## 栅栏段 ×11（底带横向平铺：256 宽/段 × 11 = 2816 ≥ 世界 2688 满宽，首段中心 x=-64 步进 256，末段探出右缘无碍；
## #90 世界底缘 1296+108 → y=1350 底带中央）
const FENCE_SLOTS: Array[Vector2] = [
	Vector2(-64, 1350), Vector2(192, 1350), Vector2(448, 1350), Vector2(704, 1350), Vector2(960, 1350),
	Vector2(1216, 1350), Vector2(1472, 1350), Vector2(1728, 1350), Vector2(1984, 1350), Vector2(2240, 1350),
	Vector2(2496, 1350),
]

# ==================== 访问函数 ====================

## 取槽位坐标（越界报错并回退 ZERO，防节点静默落原点）
static func get_slot_position(slots: Array[Vector2], index: int) -> Vector2:
	if index < 0 or index >= slots.size():
		push_error("LayoutManager: slot index %d out of range (size %d)" % [index, slots.size()])
		return Vector2.ZERO
	return slots[index]
