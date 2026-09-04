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
##       #93 整店重排（对标烘焙糕手）：靠墙置物架 ×3 + 工作台 ×2（设备上桌：DEVICE_SLOTS）+
##       前区玻璃展示柜 ×2；微波炉默认摆桌面槽位，冰柜上桌面 2 左槽。
##       #103 窗口店模式（对标杯杯倒满）：店内纵向压缩 2304×1296 → 2304×1040（南氛围带 108→364 成店前人行道），
##       柜台南移贴南墙（临街开窗），顾客全程店外；点单/取餐双点（ORDER_POINT/PICKUP_POINT），
##       外卖口独立 RIDER_POINT；餐桌/地毯移除；顾客导航改店外 L 形。

@tool
extends Node

# ==================== 世界 ====================
## 窗口尺寸（= project.godot viewport 2560x1440，相机 zoom 换算用；#89 从 1920x1080 提升，店内元素视觉放大）
const WINDOW_SIZE := Vector2(2560, 1440)
## 店内范围（#90 扩容 1920x1080 → 2304x1296：地板/墙体/gameplay 全部在此内；
## #103 窗口店：纵向压缩 1296 → 1040，省出的 256px 给南侧氛围带（108→364）作店前人行道承载顾客流）
const SHOP_SIZE := Vector2(2304, 1040)
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
## #103：前区压缩为柜台带（窗口店：柜台贴南墙，顾客在店外）；就餐区删除（顾客不进店）
const ZONE_COUNTER := Rect2(60, 860, 2184, 160)     ## 柜台带（南部横贯：吧台/点单台/取餐台/外卖窗口）

# ==================== 关键点位（#103 窗口店重排） ====================
const SPAWN_POINT_PLAYER := Vector2(1152, 700)  ## 玩家出生点（店内中央大走道）｜tile(18, ~10.9)
const SPAWN_POINT := Vector2(-61, 1150)         ## 顾客刷出/离店点（左缘店外，对齐石板路动线）｜tile(~−1, 18)
const ORDER_POINT := Vector2(700, 960)          ## 点单台（柜台西段，收银机摆这；顾客到点单槽位自动下单）｜tile(~10.9, 15)
const PICKUP_POINT := Vector2(1500, 960)        ## 取餐台（柜台东段；#103 复用原外卖口常量名——堂食交付点）｜tile(~23.4, 15)
const RIDER_POINT := Vector2(1930, 960)         ## 外卖窗口（吧台东端外侧；右缘收在外卖面板屏幕 x≥2204 左侧）｜tile(~30.2, 15)
## 点单队列首（店外人行道，队伍向左延 QUEUE_SPACING）
const ORDER_QUEUE_FRONT := Vector2(700, 1150)   ## tile(~10.9, ~18.0)
## 取餐队列首（店外人行道，队伍向右延 QUEUE_SPACING）
const PICKUP_QUEUE_FRONT := Vector2(1500, 1150) ## tile(~23.4, ~18.0)

# ==================== 顾客队列 ====================
## 队列间距（像素），需大于顾客碰撞直径 130
const QUEUE_SPACING := 200.0
## 队列容量（布局预留 5 人空间；当前玩法 max_queue=3，见 customer_manager.gd）
const QUEUE_CAPACITY := 5

# ==================== #103 顾客导航带（店外 L 形：左竖带 ∪ 南横带，顾客全程店外） ====================
## 左竖带（刷出点南接人行道）
const NAV_BAND_LEFT := Rect2(-160, 600, 170, 700)
## 南横带（店前人行道：点单/取餐队列、顾客动线全在这条带上；栅栏 y=1350 在带外）
const NAV_BAND_SOUTH := Rect2(-160, 1040, 2656, 260)

# ==================== 设备/货架/餐桌槽位 ====================
## 微波炉位（第 1 位当前使用，第 2 位 P5 设备升级解锁；槽位间距 270 > 矩形碰撞 250，不相邻重叠）
## #93：设备上桌——默认值 = DEVICE_SLOTS 前两个桌面槽位（数值必须与 DEVICE_SLOTS[0]/[1] 保持一致，
## const 数组无法互引，冒烟断言两者相等防漂移）；桌面右缘 ≤2003，避开右上经营/外卖面板（屏幕 x≥2204）
const MICROWAVE_SLOTS: Array[Vector2] = [Vector2(1050, 230), Vector2(1320, 230)]  ## tile(~16.4/~20.6, ~3.6)
## 冰柜位（#50：移至厨房区、微波炉左侧抱团；#54：四格展示库存，J/K/L/空格 取货；#93：上桌面 2 左槽）
const FREEZER_SLOT := Vector2(1590, 230)  ## tile(~24.8, ~3.6)
## #93 设备槽位 ×4（桌面1左/右, 桌面2左/右；设备可搬起后吸附摆放到这些槽位，见 device_table.gd）
## 均匀间距 270（微波炉碰撞 250 不重叠）；玩家摆放只认这些槽位或自由落地面
const DEVICE_SLOTS: Array[Vector2] = [
	Vector2(1050, 230), Vector2(1320, 230), Vector2(1590, 230), Vector2(1860, 230),  ## tile(~16.4/20.6/24.8/29.1, ~3.6)
]
## #93 工作台 ×2（每张托 2 个设备槽位；中心 = 两槽位中点下移 15，替换 #61 WORK_TABLE_POS 单图）
const DEVICE_TABLE_SLOTS: Array[Vector2] = [Vector2(1185, 245), Vector2(1725, 245)]  ## tile(~18.5/~27.0, ~3.8)
## 货箱堆位（#50：冷库区 3 堆，对应 L1_DISHES 3 道菜；批发仓无限库存）
## #61：货箱上架立式冷冻柜——竖排 3 层（柜体层中心 136/204/272 与柜图美术层绑定，#90 不动），第 4 层 (300,340) 预留 L2
const CRATE_SLOTS: Array[Vector2] = [Vector2(300, 136), Vector2(300, 204), Vector2(300, 272)]  ## tile(~4.7, ~2.1/3.2/4.25)
## #93 靠墙置物架 ×3（梯子式三层架，顶墙下沿 y=150，冷库区与厨房区之间排布；场景内 scale=0.75，纯视觉 z=-1）
const SHELF_SLOTS: Array[Vector2] = [Vector2(540, 150), Vector2(720, 150), Vector2(900, 150)]  ## tile(~8.4/11.3/14.1, ~2.3)
## #93 玻璃展示柜 ×2；#103 移到柜台两翼店内侧（隔窗可见；z=0 参与 y-sort 遮挡）
const DISPLAY_SLOTS: Array[Vector2] = [Vector2(480, 860), Vector2(1830, 860)]  ## tile(7.5/28.6, ~13.4)

# ==================== 纯视觉装饰点位（#75 收编自 main_scene；z 序留在 main_scene 调用处） ====================
## 顶墙 5 段平铺（480 宽/段，y=60；#90 店内 2304 宽 → 4 段 → 5 段，末段探出右缘 96px 无碍）
const WALL_TOP_SLOTS: Array[Vector2] = [Vector2(240, 60), Vector2(720, 60), Vector2(1200, 60), Vector2(1680, 60), Vector2(2160, 60)]
## 侧墙左右各 3 段（480 高/段；#103 店内高 1296→1040：第 3 段上移收在 y=1000 盖到南缘，探入底带无碍）
const WALL_SIDE_SLOTS: Array[Vector2] = [
	Vector2(60, 240), Vector2(60, 720), Vector2(60, 1000),
	Vector2(2244, 240), Vector2(2244, 720), Vector2(2244, 1000),
]
## #103 南墙段（临街：y=1040 店界；复用顶墙图，吧台/外卖窗口处留窗口缺口——两侧各一段）
const WALL_BOTTOM_SLOTS: Array[Vector2] = [Vector2(240, 1040), Vector2(2064, 1040)]
## 入口门脸（#103 起纯装饰——玩家不出门、顾客不进店；仍盖左墙门洞位）
const DOOR_POS := Vector2(66, 680)
## 门内地垫（纯装饰，同上）
const FLOOR_MAT_POS := Vector2(200, 680)
## 整吧台单图中心（#75：1440 宽；#103 南移贴南墙临街开窗——x 432..1872，店内 y 895..1085 压店界线）
const COUNTER_BAR_POS := Vector2(1152, 990)
## 收银机相对 ORDER_POINT 的偏移（#103：从 COUNTER_POINT 改挂点单台；-70 坐上吧台前沿台面）
const CASHIER_OFFSET := Vector2(0, -70)
## 绿植 ×2（#103：1 号移出人行道到栅栏边；2 号留店内东侧）
const PLANT_SLOTS: Array[Vector2] = [Vector2(150, 1295), Vector2(2140, 820)]
## 垃圾桶
const TRASH_BIN_POS := Vector2(2140, 640)
## 冷库区立式四层冷冻柜（货箱堆按 CRATE_SLOTS 上架；#90 不动——层中心与柜图美术绑定）
const FRIDGE_CABINET_POS := Vector2(300, 218)

# ==================== 店外氛围带（#85，纯视觉无碰撞；#90 随新世界边界平移；z 序留在 main_scene 调用处） ====================
## 石板路横向段 ×9（#103：顾客动线改到店前人行道 y=1150，石板路平铺整排；264 宽/段，首段中心 x=-61 对齐刷出点）
const STONE_PATH_SLOTS: Array[Vector2] = [
	Vector2(-61, 1150), Vector2(203, 1150), Vector2(467, 1150), Vector2(731, 1150), Vector2(995, 1150),
	Vector2(1259, 1150), Vector2(1523, 1150), Vector2(1787, 1150), Vector2(2051, 1150),
]
## 果树 ×4（左带上/中各一 + 右带上/中各一；190x240；#103 左中树上移出顾客动线带，避让店外 L 形导航）
const TREE_SLOTS: Array[Vector2] = [Vector2(-90, 220), Vector2(-90, 620), Vector2(2394, 60), Vector2(2394, 880)]
## 灌木 ×6（顶带横排 4 + 右带 2；#90 顶带按新世界宽 2688 拉开）
const BUSH_SLOTS: Array[Vector2] = [
	Vector2(300, -52), Vector2(1000, -52), Vector2(1700, -52), Vector2(2350, -52),
	Vector2(2404, 500), Vector2(2414, 1160),
]
## 路灯 ×2（左带石板路两侧交错，对标烘焙糕手路边灯；#103 随人行道 y=1150 平移两翼）
const LAMP_SLOTS: Array[Vector2] = [Vector2(-140, 1060), Vector2(-45, 1260)]
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
