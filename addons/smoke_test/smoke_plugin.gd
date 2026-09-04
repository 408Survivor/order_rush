## 文件: tests/plugin/smoke_plugin.gd
## 职责: 冒烟测试（EditorPlugin 方式）：交互闭环（#2）+ 顾客排队（#3）+ 订单循环（#4）
##       + P2 订单队列/耐心值/超时差评（#20）
## 运行: 在 project.godot [editor_plugins] 注册 "res://addons/smoke_test/plugin.cfg" 后，
##       Godot --path . --editor --quit-after N 会自动执行并输出 PASS/FAIL
## 注意: 编辑器进程会运行 @tool 节点的 _physics_process（玩家/顾客脚本含 is_editor_hint 分支）；
##       顾客在编辑器进程用直接位移（物理不步进），运行模式走 move_and_slide 真实碰撞
## P2: GameStateManager._process 在编辑器进程被拦截，耐心倒计时由测试手动 tick_patience 推进
## #54: 世界不再常备台面料理包——测试直接设 freezer.stock 并瞬移玩家到冰柜旁，
##       经 player.try_take_from_freezer(N)（J/K/L/空格 格位）确定性取包

@tool
extends EditorPlugin

var _fail_count := 0
var _picked_up_count := 0
var _placed_count := 0

func _enter_tree() -> void:
	print("SMOKE: plugin entered, running tests...")
	_run.call_deferred()

func _exit_tree() -> void:
	pass

func _run() -> void:
	# 等编辑器稳定几帧（脚本编译已完成，但给场景树一点余量）
	for i in 5:
		await get_tree().process_frame

	var scene: Node2D = (load("res://scenes/MainScene.tscn") as PackedScene).instantiate()
	# P8 测试钩子：预选主厨角色，避免启动角色选择弹窗暂停干扰测试（真实启动由选择面板处理）
	var character_manager = get_tree().root.get_node_or_null("CharacterManager")
	if character_manager != null:
		character_manager.set("current_character", "chef")
	# #93 测试钩子：清空设备自定义位置（真实存档若含 device_positions 会让微波炉不落默认槽位）
	UpgradeManager.device_positions = {}
	get_tree().root.add_child(scene)
	await get_tree().process_frame
	await get_tree().process_frame

	var player = scene.get_node("PlayerCharacter")
	var microwave = scene.get_node("Microwave")
	var freezer = scene.get_node("Freezer")

	# P7 测试钩子：固定随机菜为宫保鸡丁（保证既有断言确定性；P7 段再解除验证随机）
	scene.get_node("/root/GameStateManager").set("_dish_override", "kungpao")

	# 监听信号（验收标准：信号命名规范 item_picked_up / item_placed）
	# 注意：编辑器进程中对非 @tool 脚本的成员访问需用动态 API
	player.connect("item_picked_up", func(_item): _picked_up_count += 1)
	player.connect("item_placed", func(_item): _placed_count += 1)

	# ===== 场景要素就位 =====
	_check(player != null, "PlayerCharacter 存在于 MainScene")
	_check(microwave != null, "Microwave 存在于 MainScene")
	_check(freezer != null, "Freezer 存在于 MainScene（#54）")
	# #54：冰柜初始空 + 取货输入注册 + freezer 组
	_check(int(freezer.stock["kungpao"]) == 0 and int(freezer.stock["yuxiang"]) == 0 \
		and int(freezer.stock["mapo"]) == 0, "冰柜初始库存全 0（#54）")
	# 注意：编辑器进程 InputMap 只含内建 ui_*，项目自定义 action 用 ProjectSettings 断言
	_check(ProjectSettings.has_setting("input/take_slot_1") and ProjectSettings.has_setting("input/take_slot_2") \
		and ProjectSettings.has_setting("input/take_slot_3") and ProjectSettings.has_setting("input/take_slot_4"), "take_slot_1..4 输入已注册（#54）")
	_check(freezer.is_in_group("freezer"), "冰柜在 freezer 组（玩家取货查找，#54）")

	# ===== 0.5 布局系统（issue #24）：LayoutManager 配置驱动摆放 =====
	# 放在交互测试之前：此时节点未被移动/销毁，可断言初始摆放
	var layout = scene.get_node("/root/LayoutManager")
	var manager = scene.get_node("CustomerManager")
	var counter = scene.get_node("CounterPoint")
	_check(layout != null, "LayoutManager (autoload) 可访问")
	_check(manager != null, "CustomerManager 存在于 MainScene")
	_check(counter != null, "CounterPoint 存在于 MainScene")
	_check(layout.WORLD_SIZE == Vector2(2688, 1512), "世界尺寸 2688x1512（#90 店堂扩容 + #85 氛围带边距，16:9 保持）")
	_check(layout.SHOP_SIZE == Vector2(2304, 1296) and layout.WORLD_ORIGIN == Vector2(-192, -108),
		"店内范围 2304x1296（#90 扩容 +20%）+ 氛围带边距 192/108 不变（#85）")
	_check(scene.get_node("ZoneStorage") != null and scene.get_node("ZoneFront") != null \
		and scene.get_node("ZoneKitchen") != null and scene.get_node("ZoneDining") != null,
		"四区色块由布局配置生成")
	_check(player.global_position == layout.SPAWN_POINT, "玩家出生点位于布局配置点位")
	_check(counter.global_position == layout.COUNTER_POINT, "柜台位于布局配置点位")
	_check(scene.get_node("SpawnPoint").global_position == layout.ENTRANCE_POINT, "顾客入口位于布局配置点位")
	_check(microwave.global_position == layout.get_slot_position(layout.MICROWAVE_SLOTS, 0), "微波炉位于设备槽位 0")
	_check(freezer.global_position == layout.FREEZER_SLOT, "冰柜位于 FREEZER_SLOT（#54）")
	_check(scene.get_node("Table1").position == layout.TABLE_SLOTS[0], "餐桌位于就餐区槽位 0")
	_check(layout.QUEUE_SPACING == 200.0 and manager.get("queue_spacing") == 200.0, "队列间距接入布局系统（200）")
	# #58 吧台碰撞体：StaticBody2D(layer=1) 挡玩家；顾客 mask 去 World 层不受影响
	var counter_body = scene.get_node_or_null("CounterBody")
	_check(counter_body != null and counter_body is StaticBody2D and counter_body.collision_layer == 1,
		"吧台碰撞体存在（StaticBody2D layer=1，#58）")
	# #90：吧台碰撞体跟随整吧台重摆（图宽不变 → 碰撞尺寸不变，位置 = 吧台中心 + 固定偏移）
	_check(counter_body != null and counter_body.position == layout.COUNTER_BAR_POS + Vector2(60, 64),
		"吧台碰撞体跟随吧台新位置（#90）")
	var customer_scene: PackedScene = load("res://scenes/entities/Customer.tscn")
	var probe: CharacterBody2D = customer_scene.instantiate()
	_check(probe.collision_mask == 16, "顾客 mask=16（不撞吧台碰撞体，#58）")
	probe.free()
	# #60 全场景 Y 排序：根节点开启 + 地板 z=-10 垫底（不参与排序遮挡）
	_check(scene.y_sort_enabled and scene.get_node("CustomerManager").y_sort_enabled, "全场景 Y 排序已开启（#60）")
	_check(scene.get_node("Floor").z_index == -10, "地板 z=-10 垫底（#60）")

	# ===== #85 店外氛围带：草地/石板路/果树/灌木/路灯/栅栏（纯视觉） =====
	var grass: Sprite2D = scene.get_node_or_null("Grass")
	_check(grass != null, "店外草地节点存在（#85）")
	_check(grass != null and grass.z_index == -11, "草地 z=-11（比店内地板 -10 更靠底，#85）")
	_check(grass != null and grass.position == layout.WORLD_ORIGIN + layout.WORLD_SIZE / 2.0, "草地满铺整世界（#85）")
	var floor_sprite: Sprite2D = scene.get_node("Floor")
	_check(floor_sprite.position == layout.SHOP_SIZE / 2.0, "地板仍只盖店内 2304x1296（#90）")
	var stone_path: Sprite2D = scene.get_node_or_null("StonePath")
	_check(stone_path != null and stone_path.position == layout.STONE_PATH_POS, "石板路位于布局点位（#85）")
	_check(stone_path != null and absf(stone_path.position.y - layout.ENTRANCE_POINT.y) < 1.0, "石板路与顾客入口动线 y=680 对齐（#90）")
	_check(stone_path != null and stone_path.z_index == -9, "石板路 z=-9 压草地（#85）")
	var outdoor_counts_ok := true
	for i in 4:
		if scene.get_node_or_null("FruitTree%d" % (i + 1)) == null:
			outdoor_counts_ok = false
	for i in 6:
		if scene.get_node_or_null("Bush%d" % (i + 1)) == null:
			outdoor_counts_ok = false
	for i in 2:
		if scene.get_node_or_null("GardenLamp%d" % (i + 1)) == null:
			outdoor_counts_ok = false
	for i in 11:
		if scene.get_node_or_null("Fence%d" % (i + 1)) == null:
			outdoor_counts_ok = false
	_check(outdoor_counts_ok, "果树×4/灌木×6/路灯×2/栅栏×11 全部上屏（#85/#90 栅栏随世界宽 2688 增至 11 段）")
	_check(scene.get_node("FruitTree1").position == layout.TREE_SLOTS[0] \
		and scene.get_node("Fence11").position == layout.FENCE_SLOTS[10], "氛围带点位接入 LayoutManager（#85/#90）")
	# 相机：中心 = 世界中心 (1152,648)，zoom = 窗口/世界 适配扩容后整世界可见
	_check(scene.get_node("Camera2D").position == Vector2(1152, 648), "相机中心 = 新世界中心（#90）")
	_check(scene.get_node("Camera2D").zoom.is_equal_approx(layout.WINDOW_SIZE / layout.WORLD_SIZE), "相机 zoom 适配世界扩容（#90）")
	# gameplay 点位数值（#90 扩容重排：拓扑不变、间距拉开）
	_check(layout.ENTRANCE_POINT == Vector2(80, 680) and layout.COUNTER_POINT == Vector2(1560, 680) \
		and layout.PICKUP_POINT == Vector2(1850, 680) and layout.SPAWN_POINT == Vector2(1152, 460), "gameplay 点位数值（#90）")

	# ===== 0.7 界面系统（issue #26）：订单面板 / Toast / 经营面板 =====
	var board = scene.get_node("OrderBoard")
	var toast = scene.get_node("ToastManager")
	_check(board != null, "OrderBoard 存在")
	_check(toast != null, "ToastManager 存在")
	_check(scene.get_node("RevenueHUD/Panel/Margin/VBox/RevenueLabel") != null, "经营面板节点结构就位")

	# ===== 1. 冰柜四格取货（#54）：设库存 → 瞬移冰柜旁 → 格 1（J）取包 =====
	freezer.stock["kungpao"] = 5
	player.global_position = freezer.global_position + Vector2(0, 150)
	_check(player.call("try_take_from_freezer", 1), "冰柜旁按格取货成功（#54）")
	var meal = player.get("held_item")
	_check(meal != null and meal.is_in_group("meal_package"), "取到的是料理包（#54）")
	_check(meal.get("dish_type") == "kungpao", "格 1 料理包为宫保（#54）")
	_check(_picked_up_count == 1, "item_picked_up 信号应发出 1 次")
	_check(meal.get_parent() == player.get_node("HeldItemPivot"), "料理包应挂到 HeldItemPivot 下")
	_check(int(freezer.stock["kungpao"]) == 4, "取货扣库存 5 → 4（#54）")
	_check(str(meal.get_node("Sprite2D").texture.resource_path).contains("meal_pack_kungpao.png"), "料理包纹理按 dish_type 区分（#54/#63）")
	_check(str(freezer.call("take_hint")) != "", "冰柜取货提示文本非空（#54）")
	_check(freezer.call("take_from_slot", 3) == null, "格 4 预留位取货返回 null（#54）")
	# 取货边界：距离 >340 失败；手持时失败
	player.global_position = freezer.global_position + Vector2(0, 500)
	_check(player.call("try_take_from_freezer", 1) == false, "距离 >340 取货失败（#54）")
	player.global_position = freezer.global_position + Vector2(0, 150)
	_check(player.call("try_take_from_freezer", 1) == false, "手持时取货失败（#54）")
	# #71：层键标随取货距离显示/隐藏（无朝向要求；update_key_hints 供编辑器内冒烟直调）
	var key_label1: Label = freezer.get_node("Slots/Slot1/KeyLabel")
	var key_label4: Label = freezer.get_node("Slots/Slot4/KeyLabel")
	freezer.call("update_key_hints")
	_check(key_label1.visible and key_label4.visible, "玩家在取货距离内 → 四层键标显示（#71）")
	player.global_position = freezer.global_position + Vector2(0, 500)
	freezer.call("update_key_hints")
	_check(not key_label1.visible and not key_label4.visible, "玩家离开取货距离 → 四层键标隐藏（#71）")
	freezer.call("set_key_hints_visible", true)
	_check(key_label1.visible, "set_key_hints_visible(true) 直接生效（#71）")
	freezer.call("set_key_hints_visible", false)
	_check(not key_label1.visible, "set_key_hints_visible(false) 直接生效（#71）")
	player.global_position = freezer.global_position + Vector2(0, 150)

	# ===== #77 冷库柜四层键标 + J/K/L 按键取箱 =====
	var cab_hints: Node2D = scene.get_node_or_null("CabinetKeyHints")
	_check(cab_hints != null, "冷库柜键标节点 CabinetKeyHints 存在（#77）")
	_check(cab_hints != null and not cab_hints.visible, "冷库柜键标默认隐藏（#77）")
	player.global_position = layout.FRIDGE_CABINET_POS + Vector2(0, 150)
	cab_hints.call("update_key_hints")
	_check(cab_hints.visible, "玩家靠近冷库柜 → 四层键标显示（#77）")
	player.global_position = layout.FRIDGE_CABINET_POS + Vector2(0, 500)
	cab_hints.call("update_key_hints")
	_check(not cab_hints.visible, "玩家远离冷库柜 → 四层键标隐藏（#77）")
	# 手持时按键取箱失败（玩家此时手持料理包）
	player.global_position = layout.FRIDGE_CABINET_POS + Vector2(0, 150)
	_check(player.call("try_take_crate", 1) == false, "手持时按键取箱失败（#77）")
	player.global_position = freezer.global_position + Vector2(0, 150)

	# ===== 1.5 中途放下（issue #22）：Q 放下 → 恢复可拾取 → 再拾取 =====
	_check(player.call("drop_held_item"), "手持时按 Q 放下应成功")
	_check(player.get("held_item") == null, "放下后玩家空手")
	_check(meal.get_parent() == scene.get_node("Items"), "料理包挂回场景 Items 容器")
	_check(abs(meal.global_position.distance_to(player.global_position) - 50.0) < 1.0, "放下位置为玩家身前约 50px")
	_check(meal.collision_layer == 8 and meal.collision_mask == 0, "放下后恢复可拾取碰撞（layer=8）")
	# #77：空手按键取箱——层 4 预留/距离外失败，层 2 成功；收尾放下货箱并回到料理包旁
	player.global_position = layout.FRIDGE_CABINET_POS + Vector2(0, 150)
	_check(player.call("try_take_crate", 4) == false, "第 4 层预留位按键取箱返回 false（#77）")
	player.global_position = layout.get_slot_position(layout.CRATE_SLOTS, 1) + Vector2(0, 500)
	_check(player.call("try_take_crate", 2) == false, "距离 >340 按键取箱失败（#77）")
	player.global_position = layout.get_slot_position(layout.CRATE_SLOTS, 1) + Vector2(0, 120)
	_check(player.call("try_take_crate", 2), "冷库柜旁按键取箱成功（#77）")
	var crate_taken: Node2D = player.get("held_item")
	_check(crate_taken != null and crate_taken.is_in_group("crate"), "取到的是货箱（#77）")
	_check(str(crate_taken.get("dish_type")) == "yuxiang", "第 2 层货箱为鱼香（#77）")
	_check(player.call("drop_held_item"), "放下货箱收尾（#77）")
	player.global_position = meal.global_position + Vector2(0, 100)
	# 编辑器进程物理不步进：物品重挂场景后需等一帧注册到物理服务器，射线查询才命中
	await get_tree().process_frame
	_face_and_ray(player, meal, Vector2.UP)
	_check(player.call("try_interact"), "放下后可再次拾取")
	_check(player.get("held_item") == meal, "再拾取后 held_item 应为该料理包")

	# ===== 2. 手持料理包靠近微波炉 → 放入 =====
	_face_and_ray(player, microwave, Vector2.UP)
	_check(player.call("try_interact"), "手持料理包面对微波炉按 E 应成功放入")
	_check(player.get("held_item") == null, "放入后玩家应空手")
	_check(microwave.call("is_occupied"), "微波炉内部应有物品")
	_check(_placed_count == 1, "item_placed 信号应发出 1 次")

	# ===== 3. 空手靠近微波炉：加热中禁止取出 → 加热完成后取出成品菜 =====
	_face_and_ray(player, microwave, Vector2.UP)
	_check(player.call("try_interact") == false, "加热中取出被拒绝（不能取消加热）")
	await get_tree().create_timer(3.5).timeout
	_check(player.call("try_interact"), "加热完成后按 E 取出成品菜")
	_check(player.get("held_item") != null and player.get("held_item").is_in_group("dish"), "取出的是成品菜（dish 组）")

	# ===== 4. 顾客系统：生成 → 排队 → 队首索引 =====
	_check(manager != null, "CustomerManager 存在于 MainScene")
	_check(counter != null, "CounterPoint 存在于 MainScene")

	# 顾客生成时序（#90 按新动线重算，#24 经验：距离变 → 时序按距离/160px/s 重算）：
	# 入口(80,680)→柜台(1560,680) 距离 1480px / 160 = 9.25s；槽位 1 = 1280px = 8.0s；槽位 2 = 1080px = 6.75s
	# 槽位按在场数分配（c2 不与行走中的 c1 撞槽）
	var c1 = manager.call("spawn_customer")
	await get_tree().create_timer(10.0).timeout
	var c2 = manager.call("spawn_customer")
	await get_tree().create_timer(8.7).timeout
	var c3 = manager.call("spawn_customer")
	await get_tree().create_timer(7.4).timeout

	_check(c1 != null and c2 != null and c3 != null, "顾客按间隔连续生成成功")
	_check(c2.get("queue_slot") == counter.global_position - Vector2(200.0, 0.0), "c2 分配槽位 1（不与行走中的 c1 撞槽）")
	_check(c3.get("queue_slot") == counter.global_position - Vector2(400.0, 0.0), "c3 分配槽位 2")
	_check(manager.call("get_queue_count") == 3, "3 名顾客应全部入队")
	_check(manager.call("get_front_customer") == c1, "队首应为第一名顾客（c1）")
	_check(c1.call("is_waiting") and c2.call("is_waiting") and c3.call("is_waiting"), "顾客到达槽位后处于 WAITING")

	# 槽位不重叠（间距 200 > 碰撞直径 130，留容差按 >120 断言）
	var gap_ok: bool = c1.global_position.distance_to(c2.global_position) > 120.0 \
		and c2.global_position.distance_to(c3.global_position) > 120.0
	_check(gap_ok, "相邻顾客间距充足（不重叠）")

	# 队首位于柜台服务点（供订单系统索引）
	_check(c1.global_position.distance_to(counter.global_position) < 100.0, "队首位于柜台服务点")

	# 队列满时不再生成（max_queue=3，布局空间预留 5 人）
	_check(manager.call("spawn_customer") == null, "队伍满（3/3）时生成被拒绝")

	# ===== 5. P2 订单队列：多单并发 + 交付/好评 =====
	# 注意：编辑器进程物理不步进，RayCast2D 查询结果不稳定，
	# 本段直接调用内部交互方法（_interact_with_*）验证逻辑，射线路径由游戏运行模式保证
	# 玩家此时已手持第 3 段产出的成品菜（dish）
	var gsm = scene.get_node("/root/GameStateManager")
	_check(gsm != null, "GameStateManager (autoload) 可访问")
	# #83：存档路径注入 /tmp，避免后续打烊/升星落档污染真实存档（user://save_p5.json）
	gsm.set("save_path", "/tmp/test_save_p5.json")

	# P2：每位顾客到达即下单 → 3 名顾客 = 3 个并发订单
	_check(gsm.get_active_order_count() == 3, "3 名顾客就位后订单队列应有 3 单（P2 多单并发）")
	board.call("refresh")
	_check(board.get("_cards").size() == 3, "订单面板显示 3 张卡片")
	# #48：订单卡片图标——菜品贴纸 + 满耐心笑脸（第一张卡 = c1，dish_override=kungpao）
	var first_card: Dictionary = board.get("_cards").values()[0]
	_check(str(first_card["dish_icon"].texture.resource_path).contains("dish_kungpao.svg"), "订单卡片菜品图标为宫保鸡丁贴纸（#48）")
	_check(str(first_card["mood_icon"].texture.resource_path).contains("mood_happy.svg"), "满耐心表情为笑脸（#48）")
	# #69：卡片菜名前显示 #订单号 + 容器子节点按订单号升序
	_check(str(first_card["name_label"].text).begins_with("#"), "订单卡片显示 #订单号（#69）")
	var id_by_panel := {}
	for oid in board.get("_cards"):
		id_by_panel[board.get("_cards")[oid]["panel"]] = oid
	var last_id := -1
	var sorted_ok := true
	for child in board.get_node("Margin/Cards").get_children():
		var oid: int = id_by_panel.get(child, -1)
		if oid <= last_id:
			sorted_ok = false
		last_id = oid
	_check(sorted_ok, "订单卡片按订单号升序排列（#69）")
	_check(c1.get("order_id") != -1 and c2.get("order_id") != -1 and c3.get("order_id") != -1, "每名顾客均绑定订单 id")
	var order1: Dictionary = gsm.get_order(c1.get("order_id"))
	_check(not order1.is_empty() and order1["dish_type"] == "kungpao", "订单菜品为宫保鸡丁")
	_check(order1["patience_total"] == gsm.patience_time, "订单带耐心倒计时（patience_total）")
	_check(c1.get_node("OrderLabel").visible, "顾客头顶显示订单标记")
	_check(str(c1.get_node("OrderLabel").text).contains("宫保鸡丁"), "订单标记含菜品名")
	_check(player.get("held_item") != null and player.get("held_item").is_in_group("dish"), "玩家手持成品菜（第 3 段产出）")

	# 耐心推进：tick 5s 后耐心减少但订单未超时
	gsm.tick_patience(5.0)
	_check(gsm.get_order(c1.get("order_id"))["patience_left"] < gsm.patience_time, "耐心倒计时随 tick 递减")
	_check(gsm.get_active_order_count() == 3, "耐心未耗尽，订单仍在队列")

	# #48：低耐心（剩余 ≤20% 但未超时：30 → 5.5s，ratio≈0.18）→ 表情切换怒脸
	gsm.tick_patience(19.5)
	board.call("refresh")
	var low_card: Dictionary = board.get("_cards").values()[0]
	_check(str(low_card["mood_icon"].texture.resource_path).contains("mood_angry.svg"), "低耐心表情切换为怒脸（#48）")

	# 第一轮交付：手持成品菜交付 c1 → 好评 +1
	_check(player.call("_interact_with_customer", c1), "手持成品菜交付 c1 成功")
	_check(gsm.revenue == 20, "交付后营业额 +20")
	_check(gsm.good_reviews == 1 and gsm.bad_reviews == 0, "交付成功 → 好评 +1（差评 0）")
	_check(gsm.get_active_order_count() == 2, "c1 订单结算，队列剩 2 单（c2/c3）")
	_check(manager.call("get_queue_count") == 2, "c1 离店，队列剩 2 人")

	# 界面联动：订单面板移除已结算卡片、Toast 交付反馈、经营面板营业额更新
	board.call("refresh")
	_check(board.get("_cards").size() == 2, "交付后订单面板剩 2 张卡片")
	toast.call("show_toast", "交付成功  +20", Color(0.45, 1, 0.55))
	_check(toast.get("_toasts").size() == 1, "Toast 显示交付反馈")
	scene.get_node("RevenueHUD").call("_update_all")
	_check(scene.get_node("RevenueHUD/Panel/Margin/VBox/RevenueLabel").text.contains("营业额 20"), "经营面板营业额更新（图标化）")
	_check(scene.get_node("RevenueHUD/Panel/Margin/VBox/RevenueLabel").text.contains("coin.svg"), "经营面板用 SVG 图标内联（#32 图标集）")

	# 补位：c2 前移到柜台（已有订单，无需重建）
	await get_tree().create_timer(2.0).timeout
	_check(manager.call("get_front_customer") == c2, "补位后队首为 c2")
	_check(gsm.get_active_order_count() == 2, "补位顾客已有订单，不重复下单（count=2）")

	# 第二轮：冰柜取包 → 加热 → 交付 c2 → 好评 +2（#54：格 1 取宫保包，库存 4 → 3）
	player.global_position = freezer.global_position + Vector2(0, 150)
	_check(player.call("try_take_from_freezer", 1), "第二轮取包成功（#54）")
	player.call("_interact_with_appliance", microwave)
	await get_tree().create_timer(3.5).timeout
	player.call("_interact_with_appliance", microwave)
	_check(player.get("held_item") != null and player.get("held_item").is_in_group("dish"), "第二轮取出成品菜")
	_check(str(player.get("held_item").get_node("Sprite2D").texture.resource_path).contains("dish_kungpao_plated.png"), "成品菜纹理按 dish_type 区分（#54/#63）")
	_check(player.call("_interact_with_customer", c2), "第二轮交付 c2 成功")
	_check(gsm.revenue == 40, "营业额累加至 40")
	_check(gsm.good_reviews == 2, "好评累加至 2")
	await get_tree().create_timer(2.0).timeout
	_check(manager.call("get_front_customer") == c3, "补位后队首为 c3")

	# 第三轮：冰柜取包 → 加热 → 交付 c3 → 队列清空 → 无状态残留（#54：库存 3 → 2）
	player.global_position = freezer.global_position + Vector2(0, 150)
	_check(player.call("try_take_from_freezer", 1), "第三轮取包成功（#54）")
	player.call("_interact_with_appliance", microwave)
	await get_tree().create_timer(3.5).timeout
	player.call("_interact_with_appliance", microwave)
	_check(player.call("_interact_with_customer", c3), "第三轮交付 c3 成功")
	_check(gsm.revenue == 60, "营业额累加至 60")
	_check(gsm.good_reviews == 3, "好评累加至 3")
	_check(gsm.get_active_order_count() == 0, "无残留订单")
	_check(manager.call("get_queue_count") == 0, "队列已清空")
	_check(player.get("held_item") == null, "玩家空手（无残留物品）")

	# ===== 6. P2 超时/差评：耐心耗尽 → 订单失败 → 顾客离店 =====
	# 等待上一批顾客全部离店（柜台→入口 1480px / 160 = 9.25s，#90 重算）后生成新一批
	await get_tree().create_timer(10.0).timeout
	var c4 = manager.call("spawn_customer")
	await get_tree().create_timer(10.0).timeout
	var c5 = manager.call("spawn_customer")
	await get_tree().create_timer(8.7).timeout
	var c6 = manager.call("spawn_customer")
	await get_tree().create_timer(7.4).timeout
	_check(c4 != null and c5 != null and c6 != null, "超时测试顾客生成成功")
	_check(gsm.get_active_order_count() == 3, "新一批 3 单就位")

	# 耐心耗尽 → 3 单全部超时失败（差评）
	var failed: int = gsm.tick_patience(99999.0)
	_check(failed == 3, "tick 大 delta 触发 3 单超时")
	_check(gsm.bad_reviews == 3, "超时 → 差评 +3")
	_check(gsm.get_active_order_count() == 0, "超时订单已全部移除")
	board.call("refresh")
	_check(board.get("_cards").size() == 0, "超时后订单面板清空")
	_check(manager.call("get_queue_count") == 0, "超时顾客离店，队列清空")
	_check(c4.get("order_id") == -1 and c5.get("order_id") == -1 and c6.get("order_id") == -1, "超时顾客订单已解绑")

	# ===== 7. P3 经济系统：收入/成本/日结算/日循环（issue #28） =====
	# #30 UI 主题：autoload + 中文字体已加载
	var ui_theme = scene.get_node("/root/UITheme")
	_check(ui_theme != null and ui_theme.font != null, "UITheme autoload 与中文字体已加载")
	# 前序数据：3 单交付（revenue=60、加热 3 次）+ 3 单超时差评 → 当日收入 60、食材 18、耗材 6、水电 3、房租 30
	var day_result_panel = scene.get_node("DayResultPanel")
	_check(day_result_panel != null, "DayResultPanel 存在")
	_check(gsm.day == 1, "初始为第 1 天")
	_check(gsm.day_revenue == 60, "当日收入 = 3 单 × 20 = 60")
	_check(gsm.day_cost_ingredients == 18, "食材成本 = 3 单 × 6 = 18")
	_check(gsm.day_cost_consumables == 6, "耗材成本 = 3 单 × 2 = 6")
	_check(gsm.day_cost_utilities == 3, "水电成本 = 3 次加热 × 1 = 3")
	_check(gsm.get_day_total_cost() == 57, "当日总成本 = 18+6+3+30 = 57")
	_check(gsm.day_good_reviews == 3 and gsm.day_bad_reviews == 3, "当日好评 3 / 差评 3")
	_check(gsm.get_dish_price() == 20, "每单收入 = 菜品基础价 20")
	_check(gsm.is_shop_open, "当前营业中")
	_check(absf(gsm.business_time_left - gsm.BUSINESS_TIME_PER_DAY) < 0.01, "营业倒计时初始为满")

	# HUD 拆行（#32 第③步）：DayTimeLabel 天数行 + TimeLabel 倒计时行（#84 移入 TopRow/TopLabels，与饼图时钟并排）
	scene.get_node("RevenueHUD").call("_update_all")
	var day_text: String = scene.get_node("RevenueHUD/Panel/Margin/VBox/TopRow/TopLabels/DayTimeLabel").text
	var time_text: String = scene.get_node("RevenueHUD/Panel/Margin/VBox/TopRow/TopLabels/TimeLabel").text
	_check(day_text.contains("第 1/7 天") and day_text.contains("calendar.svg"), "HUD 天数行（图标化 + Day N/7 标注，#84）")
	_check(time_text.contains("营业剩余 90s") and time_text.contains("timer.svg"), "HUD 倒计时行（图标化）")
	# #84 饼图时钟：节点就位 + 满时指针指向 12 点（-PI/2）
	var clock: Control = scene.get_node_or_null("RevenueHUD/Panel/Margin/VBox/TopRow/BusinessClock")
	_check(clock != null, "HUD 饼图时钟节点存在（#84，替换 #48 线性 TimeBar）")
	var angle_start: float = clock.get("hand_angle")
	_check(absf(angle_start - (-PI / 2.0)) < 0.01, "时钟满时指针指向 12 点（#84）")

	# 倒计时推进（未到点不触发打烊）
	gsm.tick_business_time(10.0)
	_check(absf(gsm.business_time_left - (gsm.BUSINESS_TIME_PER_DAY - 10.0)) < 0.01, "营业倒计时随 tick 递减")
	_check(gsm.is_shop_open, "未到点仍营业")
	scene.get_node("RevenueHUD").call("_update_all")
	var angle_after: float = clock.get("hand_angle")
	_check(absf(angle_after - angle_start - TAU / 9.0) < 0.01, "时钟指针随 tick 顺时针转动（#84）")
	_check(not clock.get("urgent"), "非末段时钟无紧急脉冲（#84）")

	# #84 末段（最后 10s）：进入紧急态 + 红色脉冲相位推进
	gsm.tick_business_time(71.0)
	_check(absf(gsm.business_time_left - 9.0) < 0.01, "营业倒计时推进至末段（剩 9s）")
	scene.get_node("RevenueHUD").call("_update_all")
	_check(clock.get("urgent"), "最后 10s 时钟进入紧急脉冲态（#84）")
	var alpha0: float = clock.call("pulse_alpha")
	clock.call("_tick_pulse", 0.35)
	_check(absf(clock.call("pulse_alpha") - alpha0) > 0.01, "末段红色脉冲相位随时间推进（#84）")

	# 倒计时耗尽 → 自动打烊：停止营业、作废订单、结算利润
	# 打烊前造一笔未完成订单（P2 超时段已把订单清空），真实覆盖“打烊作废订单”分支
	gsm.create_order(999, "kungpao")
	_check(gsm.get_active_order_count() == 1, "打烊前存在未完成订单")
	var closed: bool = gsm.tick_business_time(99999.0)
	_check(closed, "倒计时耗尽触发打烊")
	_check(not gsm.is_shop_open, "打烊后停止营业")
	_check(gsm.get_active_order_count() == 0, "打烊作废全部未完成订单")
	_check(gsm.get_day_profit() == 3, "当日利润 = 收入60 − 成本57 = 3")
	_check(gsm.money == 3, "利润并入累计金币（3）")
	_check(gsm.close_shop().is_empty(), "重复打烊被拒绝（防御）")

	# 结算面板展示
	var settlement: Dictionary = gsm.last_settlement
	_check(not settlement.is_empty() and settlement["day"] == 1, "结算结果已生成（含天数）")
	day_result_panel.call("show_result", settlement)
	_check(day_result_panel.get("_overlay").visible, "结算面板弹出")
	_check(day_result_panel.get("_next_day_button") != null, "结算面板主按钮已绑定（#48）")
	_check(day_result_panel.get("_title_label").text == "第 1 天 结算", "结算面板标题含天数")
	_check(day_result_panel.get("_revenue_label").text.contains("总收入：60"), "结算面板收入正确（图标化）")
	_check(day_result_panel.get("_cost_total_label").text == "成本合计：57", "结算面板成本合计正确")
	_check(day_result_panel.get("_profit_label").text == "今日利润：3", "结算面板利润正确")
	_check(day_result_panel.get("_money_label").text.contains("现有资金：3"), "结算面板累计金币正确（图标化）")

	# 进入下一天：天数 +1、当日清零、累计保留、场景清场重建
	var stock_before := int(freezer.stock["kungpao"])  # #54：清场前记录冰柜库存，验证跨天保留
	gsm.start_next_day()
	_check(gsm.day == 2, "天数 +1 → 第 2 天")
	_check(gsm.is_shop_open, "新一天恢复营业")
	_check(gsm.day_revenue == 0 and gsm.day_cost_ingredients == 0 \
		and gsm.day_cost_consumables == 0 and gsm.day_cost_utilities == 0, "当日收入/成本清零")
	_check(gsm.day_good_reviews == 0 and gsm.day_bad_reviews == 0, "当日评分清零")
	_check(gsm.money == 3, "累计金币跨天保留")
	_check(absf(gsm.business_time_left - gsm.BUSINESS_TIME_PER_DAY) < 0.01, "营业倒计时重置")
	_check(gsm.revenue == 60 and gsm.good_reviews == 3 and gsm.bad_reviews == 3, "累计营业额/评分跨天保留")

	# 场景清场（main_scene 监听 day_started）：顾客清空、玩家复位；#54 起冰柜库存跨天保留、四格计数刷新
	_check(manager.call("get_queue_count") == 0, "新一天顾客队列清空")
	_check(int(freezer.stock["kungpao"]) == stock_before, "冰柜库存跨天保留（#54）")
	_check(freezer.get_node("Slots/Slot1/CountLabel").text == "×%d" % stock_before, "四格计数随库存刷新（#54）")
	_check(player.global_position == layout.SPAWN_POINT, "玩家复位出生点")

	# ===== P4 外卖系统（第 2 天营业中） =====
	_check(gsm.get_dish_price() == 20 and gsm.get_dish_price(true) == 23, "外卖定价 = 基础价+打包费+平台补贴−扣点（堂食 20 vs 外卖 23）")
	gsm.set("_takeaway_spawn_timer", 99999.0)  # 禁用自动生成，测试手动控制时序
	var takeout_id: int = gsm.create_takeaway_order()
	_check(takeout_id > 0, "外卖订单创建成功")
	_check(gsm.takeaway_orders.size() == 1, "外卖独立队列 1 单（与堂食并行）")
	_check(gsm.get_takeaway(takeout_id)["state"] == gsm.TakeoutState.PACKING, "外卖初始待打包")
	_check(absf(gsm.get_takeaway(takeout_id)["eta_left"] - gsm.get_takeout_eta()) < 0.01, "骑手 ETA 初始满")

	var takeaway_board: CanvasLayer = scene.get_node("TakeawayBoard")
	takeaway_board.call("refresh")
	_check(takeaway_board.get("_list").get_child_count() == 1, "外卖面板显示 1 行订单")
	_check(takeaway_board.get_node_or_null("Panel/Margin/VBox/Title") != null, "外卖面板标题节点存在（#48）")

	_check(gsm.pack_takeaway(takeout_id), "打包外卖成功（PACKING→READY）")
	_check(gsm.order_is_packed(takeout_id), "打包后标记已打包")

	var revenue_before: int = gsm.day_revenue
	gsm.tick_takeaway(gsm.TAKEOUT_ETA + 1.0)
	_check(gsm.takeaway_orders.is_empty(), "骑手取餐后外卖队列清空")
	_check(gsm.day_revenue == revenue_before + 23, "外卖完成收入 +23（打包费+补贴−扣点）")
	_check(gsm.day_good_reviews == 1, "外卖完成好评 +1")

	var takeout2: int = gsm.create_takeaway_order()
	_check(takeout2 > 0, "第二单外卖创建")
	var bad_before: int = gsm.day_bad_reviews
	gsm.tick_takeaway(gsm.TAKEOUT_ETA + 1.0)
	_check(gsm.takeaway_orders.is_empty(), "超时单已移除")
	_check(gsm.day_cost_penalty == gsm.TAKEOUT_FAIL_PENALTY, "超时罚款计入成本（%d）" % gsm.TAKEOUT_FAIL_PENALTY)
	_check(gsm.day_bad_reviews == bad_before + 1, "外卖超时差评 +1")

	var takeout_counter = scene.get_node_or_null("TakeoutCounter")
	_check(takeout_counter != null, "外卖口已实例化")
	_check(takeout_counter.global_position == layout.PICKUP_POINT, "外卖口位于布局点位")

	# ===== P5 设备升级（内存态，避免污染开发者真实存档） =====
	UpgradeManager.has_second_microwave = false
	UpgradeManager.heat_level = 0
	UpgradeManager.freezer_level = 0
	UpgradeManager.save_path = "/tmp/test_save_p5.json"
	_check(not UpgradeManager.is_owned("second_microwave"), "初始无第二微波炉")

	# 金币不足 → 购买失败不扣钱
	gsm.money = 10
	_check(not UpgradeManager.buy_upgrade("second_microwave"), "金币不足购买失败")
	_check(gsm.money == 10, "购买失败不扣金币")

	# 金币足够 → 购买成功扣钱
	gsm.money = 200
	_check(UpgradeManager.buy_upgrade("second_microwave"), "购买第二微波炉成功")
	_check(gsm.money == 120, "购买第二微波炉扣 80 金币")
	_check(not UpgradeManager.buy_upgrade("second_microwave"), "已购不可重复购买")
	_check(UpgradeManager.buy_upgrade("heat_accel"), "购买加热加速成功")
	_check(UpgradeManager.buy_upgrade("freezer"), "购买冰柜扩容成功")
	_check(gsm.money == 10, "三项共扣 190（200−80−50−60）")

	# 效果应用（buy_upgrade 发 upgrades_changed，main_scene/微波炉同步响应）
	_check(scene.get_node_or_null("Microwave2") != null, "第二微波炉已实例化")
	_check(scene.get_node("Microwave2").global_position == layout.get_slot_position(layout.MICROWAVE_SLOTS, 1), "第二微波炉位于槽位 2")
	_check(microwave.heat_time == 2.2, "微波炉加热加速生效（3.0→2.2）")
	# #50：冰柜扩容语义 = 每菜库存容量（旧"料理包 3→5 个"断言废弃，库存由货箱补充）
	_check(scene.get_node("Freezer").call("capacity") == 8, "冰柜扩容后每菜库存容量 4 → 8（#50）")
	_check(UpgradeManager.is_owned("freezer"), "冰柜升级状态已记录")

	# ===== P6 卡牌系统 =====
	CardManager.active_cards.clear()
	_check(CardManager.active_cards.is_empty(), "初始构筑为空")
	_check(CardManager.get_reputation() == gsm.good_reviews, "口碑 = 累计好评数")

	# 抽卡：3 选 1 + 口碑消耗
	var offer: Array[String] = CardManager.draw_offer()
	_check(offer.size() == 3, "抽卡 3 选 1")
	var reviews_before: int = gsm.good_reviews
	_check(CardManager.pick_card(offer[0]), "抽卡成功（消耗口碑）")
	_check(gsm.good_reviews == reviews_before - 3, "抽卡消耗 3 口碑")
	_check(CardManager.has(offer[0]), "选中卡入构筑")
	_check(not CardManager.pick_card(offer[0]), "已持有的卡不可重复抽")

	# 口碑不足 → 失败
	var reviews_low: int = gsm.good_reviews
	gsm.good_reviews = 1
	_check(not CardManager.pick_card("premium_price"), "口碑不足抽卡失败")
	gsm.good_reviews = reviews_low

	# 显式构筑效果卡 → 数值断言（口碑充值 100；跳过已抽到的 held，其余全部入构筑）
	gsm.good_reviews = 100
	var held: String = offer[0]
	var cards_to_pick := ["premium_price", "double_review", "patient_guests", "fast_rider", "industrial_oven", "traffic_peak", "rent_waiver", "platform_subsidy", "penalty_waiver", "profit_bonus"]
	cards_to_pick.erase(held)
	for card_id: String in cards_to_pick:
		_check(CardManager.pick_card(card_id), "选%s" % CardManager.CARDS[card_id]["name"])
	_check(CardManager.active_cards.size() == 10, "构筑 10 张卡（全流派叠加）")
	_check(gsm.get_dish_price() == 26, "招牌溢价：堂食 20 → 26（+30%）")
	_check(gsm.get_dish_price(true) == 36, "平台补贴+招牌溢价：外卖 (23+5) ×1.3 = 36")
	_check(gsm.get_review_gain() == 2, "会员日：每单好评 +2")
	_check(absf(gsm.get_patience_time() - (45.0 * gsm.get_difficulty()["patience"])) < 0.01, "慢工出细活：耐心 30 → 45s（含难度递减）")
	_check(absf(gsm.get_takeout_eta() - (55.0 * gsm.get_difficulty()["eta"])) < 0.01, "闪送合作：外卖 ETA 40 → 55s（含难度递减）")
	_check(absf(microwave.heat_time - 1.65) < 0.01, "工业烤箱：加热 ×0.75（P5 加速 2.2 → 1.65s）")
	_check(absf(manager.get_effective_interval() - (2.25 * gsm.get_difficulty()["spawn"])) < 0.01, "客流高峰：顾客间隔 3.0 → 2.25s（含难度递减）")
	_check(gsm.get_day_rent() == 15, "房东豁免：房租 30 → 15")
	_check(gsm.get_fail_penalty() == 3, "员工关怀：罚款 5 → 2.5 → 3")
	_check(CardManager.get_multiplier("profit_multiplier") > 1.0, "口碑营销：利润乘数 >1")

	# 打烊：房租减半入结算 + 构筑清空（每日重抽）
	var close_result: Dictionary = gsm.close_shop()
	_check(close_result["cost_rent"] == 15, "结算房租减半生效")
	_check(CardManager.active_cards.is_empty(), "打烊清空构筑（每日重新抽卡）")

	# ===== P7 多菜品 + 难度 + 招牌菜 + 特殊事件（进入第 3 天） =====
	gsm.start_next_day()  # P6 已打烊 → 恢复营业进第 3 天
	_check(gsm.day == 3, "进入第 3 天")
	_check(GameStateManager.DISHES.size() == 3, "菜品配置 3 种 L1（宫保鸡丁/鱼香肉丝/麻婆豆腐）")
	# 解除随机菜钩子 → 随机菜来自菜品池
	gsm.set("_dish_override", "")
	var random_dish: String = gsm.get_random_dish()
	_check(random_dish in GameStateManager.L1_DISHES, "随机菜来自菜品池（%s）" % random_dish)
	gsm.set("_dish_override", "kungpao")

	# 7 天难度：天数越高倍率越低
	_check(gsm.get_difficulty()["patience"] < 1.0, "第 %d 天难度递增（耐心倍率 <1）" % gsm.day)
	_check(absf(gsm.get_patience_time() - (gsm.patience_time * gsm.get_difficulty()["patience"])) < 0.01, "耐心随难度递减")
	_check(gsm.get_difficulty()["spawn"] < 1.0, "顾客间隔难度递减")

	# 招牌菜：价格加成 + 熟练度档位
	_check(gsm.get_dish_price(false, "yuxiang") == 22, "非招牌菜基础价 22")
	gsm.set_specialty_dish("yuxiang")
	_check(gsm.get_dish_price(false, "yuxiang") == 26, "招牌菜价格加成 +20%（22 → 26）")
	gsm.record_dish_served("yuxiang")
	gsm.record_dish_served("yuxiang")
	gsm.record_dish_served("yuxiang")
	_check(gsm.get_specialty_prof_level("yuxiang") == 1, "熟练度 3 次售出升 1 档")
	_check(gsm.get_dish_price(false, "yuxiang") == 29, "招牌菜熟练度档加成（26 → 29，+10%）")
	_check(gsm.get_dish_price(false, "kungpao") == 20, "非招牌菜不受加成")

	# 特殊事件：设备故障 → 微波炉停用；恶劣天气 → 外卖暂停
	# #54：世界里不再常备台面料理包，直接构造料理包验证故障拒收
	var meal_rebuilt: Node2D = (load("res://scenes/items/MealPackage.tscn") as PackedScene).instantiate()
	gsm.force_event(GameStateManager.SpecialEvent.EQUIPMENT_BREAK)
	_check(microwave.is_broken(), "设备故障事件中微波炉停用")
	_check(not microwave.can_accept_item(meal_rebuilt), "故障期间拒绝放入料理包")
	meal_rebuilt.free()
	gsm.tick_event(100.0)
	_check(not microwave.is_broken(), "事件结束微波炉恢复")
	gsm.force_event(GameStateManager.SpecialEvent.BAD_WEATHER)
	_check(gsm.is_event_active(GameStateManager.SpecialEvent.BAD_WEATHER), "恶劣天气事件激活")
	_check(gsm.create_takeaway_order() == -1, "恶劣天气外卖暂停生成")
	gsm.tick_event(100.0)
	_check(gsm.active_event == GameStateManager.SpecialEvent.NONE, "天气事件结束清除")

	# ===== #82 心率值：全局营业压力机制 =====
	# 第 3 天开工心率已重置为安全值；此时堂食/外卖队列均空
	var heart_panel: CanvasLayer = scene.get_node_or_null("HeartRatePanel")
	_check(heart_panel != null, "心率面板存在于 MainScene（#82）")
	_check(absf(gsm.heart_rate - gsm.STRESS_INITIAL) < 0.01, "心率每日开工初始为安全值 %d（#82）" % int(gsm.STRESS_INITIAL))
	var hr_signal_count := [0]
	gsm.heart_rate_changed.connect(func(_v: float) -> void: hr_signal_count[0] += 1)

	# 缓解路径 1：空闲（无在队订单/外卖）持续 −X/s
	gsm.tick_stress(5.0)
	var hr_expect: float = gsm.STRESS_INITIAL - gsm.STRESS_IDLE_RATE * 5.0
	_check(absf(gsm.heart_rate - hr_expect) < 0.01, "空闲 5s 心率回落 −%.0f/s（#82）" % gsm.STRESS_IDLE_RATE)

	# 累积路径 1：在队订单 ≥3 持续 +X/s
	var stress_ids: Array[int] = []
	for i in 3:
		stress_ids.append(gsm.create_order(900 + i, "kungpao"))
	gsm.tick_stress(2.0)
	hr_expect += gsm.STRESS_QUEUE_RATE * 2.0
	_check(absf(gsm.heart_rate - hr_expect) < 0.01, "在队 3 单 2s 心率持续 +%.0f/s（#82）" % gsm.STRESS_QUEUE_RATE)
	# HUD 同步（编辑器进程手动 refresh）
	heart_panel.call("refresh")
	var hr_bar: ProgressBar = heart_panel.get_node("Panel/Margin/HBox/Bar")
	_check(heart_panel.get_node("Panel/Margin/HBox/Value").text == "%d" % int(round(gsm.heart_rate)), "心率面板数值同步（#82）")
	_check(absf(hr_bar.value - gsm.heart_rate) < 0.01, "心率条填充同步（#82）")
	_check(hr_bar.max_value == gsm.STRESS_MAX, "心率条量程 = STRESS_MAX（#82）")

	# 缓解路径 2：成功交付 −X
	gsm.complete_order(stress_ids[0])
	hr_expect -= gsm.STRESS_ON_DELIVERY
	_check(absf(gsm.heart_rate - hr_expect) < 0.01, "成功交付心率 −%.0f（#82）" % gsm.STRESS_ON_DELIVERY)

	# 累积路径 2/3：堂食订单超时 +X、外卖超时差评 +X
	gsm.fail_order(stress_ids[1])
	var stress_takeout: int = gsm.create_takeaway_order()
	gsm.fail_takeaway(stress_takeout)
	hr_expect += gsm.STRESS_ON_TIMEOUT + gsm.STRESS_ON_BAD_REVIEW
	_check(absf(gsm.heart_rate - hr_expect) < 0.01, "订单超时 +%.0f / 差评 +%.0f（#82）" % [gsm.STRESS_ON_TIMEOUT, gsm.STRESS_ON_BAD_REVIEW])
	_check(hr_signal_count[0] > 0, "heart_rate_changed 信号随压力事件发出（#82）")

	# 爆表路径：≥100 触发危机事件（主厨慌乱，复用 P7 事件框架）并回落安全值
	gsm.remove_order(stress_ids[2])
	gsm.add_stress(gsm.STRESS_MAX)
	_check(gsm.active_event == GameStateManager.SpecialEvent.CHEF_PANIC, "爆表触发危机事件：主厨慌乱（#82）")
	_check(absf(gsm.heart_rate - gsm.STRESS_SAFE_AFTER_CRISIS) < 0.01, "爆表后心率回落安全值 %d（#82）" % int(gsm.STRESS_SAFE_AFTER_CRISIS))
	microwave._refresh_heat_time()
	_check(absf(microwave.heat_time - 2.2 * gsm.STRESS_CRISIS_HEAT_MULTIPLIER) < 0.01, "主厨慌乱加热耗时 ×%.1f（2.2 → %.2f，#82）" % [gsm.STRESS_CRISIS_HEAT_MULTIPLIER, 2.2 * gsm.STRESS_CRISIS_HEAT_MULTIPLIER])
	gsm.tick_event(100.0)
	_check(gsm.active_event == GameStateManager.SpecialEvent.NONE, "危机事件结束清除（#82）")
	microwave._refresh_heat_time()
	_check(absf(microwave.heat_time - 2.2) < 0.01, "危机结束加热耗时恢复（#82）")

	# 跨天语义：每日开工心率重置（day 3 → 4；P8 段起不再依赖天数/心率）
	gsm.close_shop()
	gsm.start_next_day()
	_check(absf(gsm.heart_rate - gsm.STRESS_INITIAL) < 0.01, "新一天心率重置为安全值（#82）")

	# ===== #83 繁荣度/店铺星级 =====
	# 测试钩子：隔离前序段累计值，从确定状态起测（当前第 4 天营业中，队列均空）
	gsm.set("prosperity", 0)
	gsm.set("shop_stars", 1)
	_check(gsm.STAR_THRESHOLDS.size() == 5 and gsm.STAR_THRESHOLDS[0] == 0 and gsm.STAR_MAX == 5,
		"五档星级阈值表（初始 1 星，#83）")

	# 差评扣减：繁荣度 50 时订单超时差评 −PROSPERITY_BAD_WEIGHT
	gsm.set("prosperity", 50)
	var star_order: int = gsm.create_order(950, "kungpao")
	gsm.fail_order(star_order)
	_check(gsm.get("prosperity") == 50 - gsm.PROSPERITY_BAD_WEIGHT, "差评扣减繁荣度 −%d（#83）" % gsm.PROSPERITY_BAD_WEIGHT)
	# 触底钳制：繁荣度低于扣减值时再差评 → 0（不为负）
	gsm.set("prosperity", 10)
	var star_order2: int = gsm.create_order(951, "kungpao")
	gsm.fail_order(star_order2)
	_check(gsm.get("prosperity") == 0, "繁荣度扣减触底钳制为 0（#83）")

	# 阈值升星：距 2 星（阈值 320）一步之遥时交付 → 升星 + 信号
	var star_signal_count := [0]
	gsm.shop_star_upgraded.connect(func(_s: int) -> void: star_signal_count[0] += 1)
	gsm.set("prosperity", gsm.STAR_THRESHOLDS[1] - 30)
	var star_order3: int = gsm.create_order(952, "kungpao")
	gsm.complete_order(star_order3)  # +20 菜价 +15 好评 = +35 → 325 ≥ 320
	_check(gsm.get("prosperity") == gsm.STAR_THRESHOLDS[1] + 5, "交付营收+好评计入繁荣度（#83）")
	_check(gsm.get("shop_stars") == 2, "达阈值升 2 星（#83）")
	_check(star_signal_count[0] == 1, "shop_star_upgraded 信号发出一次（#83）")

	# 星级只升不降：升星后差评扣减，星级保持
	var star_order4: int = gsm.create_order(953, "kungpao")
	gsm.fail_order(star_order4)
	_check(gsm.get("shop_stars") == 2, "差评扣减后星级不回降（#83）")

	# 跨天保留：打烊 → 下一天，繁荣度/星级不清零
	var prosperity_before_close: int = gsm.get("prosperity")
	gsm.close_shop()
	gsm.start_next_day()
	_check(gsm.get("prosperity") == prosperity_before_close and gsm.get("shop_stars") == 2,
		"繁荣度/星级跨天保留（#83）")

	# HUD 星级常显行：图标 + 文字（编辑器进程手动刷新，与既有 HUD 断言同约定）
	scene.get_node("RevenueHUD").call("_update_all")
	var star_hud_text: String = scene.get_node("RevenueHUD/Panel/Margin/VBox/StarLabel").text
	_check(star_hud_text.contains("店铺 2 星") and star_hud_text.contains("star.svg"),
		"HUD 星级常显行（图标 + 文字，#83）")
	_check(star_hud_text.contains("star_empty.svg"), "HUD 未达成档位显示空星图标（#83）")

	# 结算面板：星级行 + 距下一星进度
	day_result_panel.call("show_result", gsm.last_settlement)
	_check(day_result_panel.get("_star_label").text.contains("店铺星级：2 星"),
		"结算面板显示当前星级（#83）")
	var progress: Dictionary = gsm.get_star_progress()
	_check(progress["floor"] == gsm.STAR_THRESHOLDS[1] and progress["next_threshold"] == gsm.STAR_THRESHOLDS[2]
		and not progress["maxed"], "星级进度快照（本档起点/下一档阈值，#83）")
	_check(day_result_panel.get("_star_progress_label").text.contains("距 3 星"),
		"结算面板显示距下一星进度（#83）")
	var star_bar: ProgressBar = day_result_panel.get("_star_progress_bar")
	_check(star_bar.max_value == gsm.STAR_THRESHOLDS[2] - gsm.STAR_THRESHOLDS[1]
		and int(star_bar.value) == maxi(gsm.get("prosperity") - gsm.STAR_THRESHOLDS[1], 0),
		"结算面板星级进度条填充（#83）")

	# 存档并入 #36 既有通道（user://save_p5.json 合并键）：与升级键共存不互覆
	gsm.call("save_prosperity")
	var saved_prosperity: int = gsm.get("prosperity")
	var saved_stars: int = gsm.get("shop_stars")
	gsm.set("prosperity", 0)
	gsm.set("shop_stars", 1)
	gsm.call("load_prosperity")
	_check(gsm.get("prosperity") == saved_prosperity and gsm.get("shop_stars") == saved_stars,
		"繁荣度/星级存档读写恢复（#83）")
	var save_file := FileAccess.open("/tmp/test_save_p5.json", FileAccess.READ)
	var save_data: Variant = JSON.parse_string(save_file.get_as_text())
	save_file.close()
	_check(typeof(save_data) == TYPE_DICTIONARY and save_data.has("prosperity") and save_data.has("shop_stars")
		and save_data.has("heat_level"), "星级并入 save_p5.json 与升级键共存（#83）")
	# 满星快照边界（纯函数断言，不动状态）
	gsm.set("prosperity", gsm.STAR_THRESHOLDS[4] + 100)
	gsm.set("shop_stars", gsm.STAR_MAX)
	var maxed_progress: Dictionary = gsm.get_star_progress()
	_check(maxed_progress["maxed"] and maxed_progress["next_threshold"] == -1, "满星进度快照 maxed（#83）")
	gsm.set("prosperity", saved_prosperity)
	gsm.set("shop_stars", saved_stars)

	# ===== P8 角色系统 =====
	CharacterManager.save_path = "/tmp/test_save_p8.json"
	CharacterManager.current_character = ""
	_check(CharacterManager.CHARACTERS.size() == 2, "角色配置 2 个（主厨/快手主厨）")
	_check(not CharacterManager.has_selected(), "重置后未选角色")

	_check(CharacterManager.select_character("chef"), "选择主厨成功")
	_check(CharacterManager.get_heat_multiplier() == 1.0, "主厨无加热加成")
	_check(not CharacterManager.select_character("invalid"), "非法角色拒绝")
	_check(not CharacterManager.select_character(""), "空角色拒绝")

	_check(CharacterManager.select_character("fast_chef"), "选择快手主厨")
	_check(absf(CharacterManager.get_heat_multiplier() - 0.85) < 0.01, "快手主厨加热乘数 ×0.85")
	# 微波炉即时生效：P5 加热加速(2.2s) × 卡牌(无，已重置) × 快手主厨(0.85) = 1.87
	_check(absf(microwave.heat_time - (2.2 * 0.85)) < 0.01, "微波炉加热角色技能生效（2.2 → 1.87s）")

	# ===== #93 设备搬运：搬起 → 摆上桌槽 → 加热全链路 → Q 放地面 → 存档读回 → 清场保留 =====
	# 存档通道已在 P5 段替换为 /tmp/test_save_p5.json，设备位置写盘不污染真实存档
	UpgradeManager.device_positions = {}
	_check(microwave.is_in_group("device") and bool(microwave.get("is_device")), "微波炉在 device 组（#93）")
	_check(bool(microwave.call("can_be_picked_up")), "IDLE 空载微波炉可搬起（#93）")
	var table2: Node2D = scene.get_node("DeviceTable2")
	var mw2_node: Node2D = scene.get_node("Microwave2")

	# 搬起：空手对空闲微波炉按 E → 设备上手（碰撞清零、挂 HeldItemPivot）
	player.call("discard_held_item")  # 防御：确保空手
	_face_and_ray(player, microwave, Vector2.UP)
	_check(player.call("try_interact"), "空手对空闲微波炉按 E 搬起设备（#93）")
	_check(player.get("held_item") == microwave, "手持物为微波炉（#93）")
	_check(microwave.collision_layer == 0 and microwave.get_parent() == player.get_node("HeldItemPivot"),
		"搬起后碰撞清零并挂手持点（#93）")

	# 不可套娃：手持设备对另一台设备交互 → 拒绝
	_face_and_ray(player, mw2_node, Vector2.UP)
	_check(player.call("try_interact") == false and player.get("held_item") == microwave, "设备不能叠放（#93）")

	# 摆上桌槽：面对桌面 2 右槽（DEVICE_SLOTS[3]，此时空槽）按 E → 吸附放置
	player.global_position = layout.DEVICE_SLOTS[3] + Vector2(0, 250)
	player.set("facing_direction", Vector2.UP)
	player.get_node("InteractionRay").target_position = Vector2.UP * 280.0
	player.set("_interaction_cooldown", 0.0)
	_check(player.call("_find_free_device_slot") == table2.get_node("SlotR"), "身前扫到桌面 2 右槽空槽位（#93）")
	_check(player.call("try_interact"), "手持设备对空槽位按 E 放上工作台（#93）")
	_check(microwave.global_position == layout.DEVICE_SLOTS[3], "微波炉吸附到槽位（#93）")
	_check(microwave.collision_layer == 5 and microwave.get_parent() == scene, "放上桌后恢复设备碰撞层并挂回场景根（#93）")
	_check(not bool(table2.call("is_slot_free", table2.get_node("SlotR"))), "槽位被占（派生占用，#93）")
	_check(UpgradeManager.get_device_position("Microwave") == layout.DEVICE_SLOTS[3], "放置写自定义位置存档（#93）")
	# 设备重挂场景根后需等一帧注册到物理服务器，射线查询才命中（Session 8/12 经验）
	await get_tree().process_frame

	# 加热全链路（新位置功能照常）：取包 → 放入 → 加热中不可搬/不可取 → 完成取出
	player.global_position = freezer.global_position + Vector2(0, 150)
	_check(player.call("try_take_from_freezer", 1), "桌面槽位上就位后取包（#93）")
	_face_and_ray(player, microwave, Vector2.UP)
	_check(player.call("try_interact"), "料理包放入槽位上的微波炉（#93）")
	_check(microwave.call("is_occupied"), "槽位上的微波炉加热中（#93）")
	_face_and_ray(player, microwave, Vector2.UP)
	_check(player.call("try_interact") == false and player.get("held_item") == null \
		and microwave.get_parent() == scene, "加热中不可搬起也不可取出（#93）")
	await get_tree().create_timer(3.5).timeout
	_face_and_ray(player, microwave, Vector2.UP)
	_check(player.call("try_interact") and player.get("held_item") != null \
		and player.get("held_item").is_in_group("dish"), "槽位上加热完成取出成品菜（#93）")
	player.call("discard_held_item")

	# Q 放地面：恢复 layer=5、挂 Items、位置写存档
	_face_and_ray(player, microwave, Vector2.UP)
	_check(player.call("try_interact") and player.get("held_item") == microwave, "从桌槽搬回设备（#93）")
	player.global_position = Vector2(1152, 460)
	player.set("facing_direction", Vector2.UP)
	_check(player.call("drop_held_item"), "Q 放下设备到地面（#93）")
	_check(microwave.get_parent() == scene.get_node("Items") and microwave.collision_layer == 5,
		"设备落地面挂 Items 且恢复 layer=5（#93）")
	_check(microwave.global_position == Vector2(1152, 410), "设备落在身前 50px（#93）")
	_check(UpgradeManager.get_device_position("Microwave") == Vector2(1152, 410), "落地面位置写存档（#93）")

	# 存档读回：_apply_upgrades 优先用自定义位置；清档后回退默认槽位
	microwave.global_position = Vector2(500, 900)
	scene.call("_apply_upgrades")
	_check(microwave.global_position == Vector2(1152, 410), "重摆时按存档读回自定义位置（#93）")
	UpgradeManager.device_positions.clear()
	scene.call("_apply_upgrades")
	_check(microwave.global_position == layout.MICROWAVE_SLOTS[0], "无存档回退默认桌面槽位（#93）")
	# 派生占用（device 组实际位置判定）：桌面 1 两槽被两台微波炉占满，桌面 2 左槽被冰柜占、右槽空
	var table1: Node2D = scene.get_node("DeviceTable")
	_check(table1.call("get_free_slot") == null, "桌面 1 两槽被微波炉占满（派生占用，#93）")
	_check(table2.call("get_free_slot") == table2.get_node("SlotR"), "桌面 2 右槽空闲（冰柜占左槽，#93）")

	# 清场保留：设备（device 组）跨天不被 queue_free，普通物品照清
	player.global_position = freezer.global_position + Vector2(0, 150)
	player.call("try_take_from_freezer", 1)
	var pkg_drop: Node2D = player.get("held_item")
	player.call("drop_held_item")  # 普通物品落入 Items 作对照组
	gsm.close_shop()
	gsm.start_next_day()  # 触发 _reset_shop_items（day_started 信号）
	await get_tree().process_frame
	_check(is_instance_valid(microwave) and microwave.is_inside_tree(), "清场后设备仍在（#93）")
	_check(not is_instance_valid(pkg_drop), "普通物品仍被清场（#93）")

	# ===== P9 Polish =====
	_check(load("res://assets/audio/sfx/deliver.wav") != null, "交付音效文件存在")
	_check(load("res://assets/audio/sfx/timeout.wav") != null, "超时音效文件存在")
	_check(load("res://assets/audio/sfx/new_order.wav") != null, "新订单音效文件存在")
	_check(load("res://assets/audio/sfx/pickup.wav") != null, "拾取音效文件存在")
	var audio_mgr = scene.get_node_or_null("/root/AudioManager")
	_check(audio_mgr != null, "AudioManager autoload 可访问")
	audio_mgr.call("play_sfx", "click")
	_check(load("res://scripts/systems/particle_fx.gd") != null, "ParticleFX 工具脚本存在")
	_check(FileAccess.file_exists("res://docs/发布指南.md"), "发布指南文档存在")

	# ===== #50 两段式补给（货箱 → 冰柜） =====
	# 本段直接操作 freezer.stock 保证确定性，不依赖前面流程的消耗账
	_check(freezer != null, "冰柜已实例化（#50）")
	_check(freezer.global_position == layout.FREEZER_SLOT, "冰柜位于厨房区 FREEZER_SLOT（#50）")
	var stacks: Array = []
	for i in 3:
		var stack = scene.get_node_or_null("CrateStack" if i == 0 else "CrateStack%d" % (i + 1))
		stacks.append(stack)
		_check(stack != null, "货箱堆 %d 已实例化（#50）" % (i + 1))
		_check(stack != null and stack.global_position == layout.get_slot_position(layout.CRATE_SLOTS, i), "货箱堆 %d 位于 CRATE_SLOTS（#50）" % (i + 1))
	_check(layout.PICKUP_POINT == Vector2(1850, 680), "外卖口点位（#90：吧台右缘 +20，随柜台右移）")
	_check(layout.SPAWN_POINT == Vector2(1152, 460), "玩家出生点位（#90）")

	# 空手从货箱堆拿货箱 → 手持 crate 组物品
	player.call("discard_held_item")  # 防御：确保空手，避免影响后续断言
	var stack0 = stacks[0]  # kungpao 货箱堆
	_check(player.call("_interact_with_crate_stack", stack0), "空手对货箱堆交互成功（#50）")
	_check(player.get("held_item") != null and player.get("held_item").is_in_group("crate"), "拿到的是货箱（crate 组，#50）")

	# 手持货箱放入冰柜 → 库存 +CRATE_SIZE（不超容量；P5 已购扩容，容量 8）
	freezer.stock["kungpao"] = 1
	var cap: int = freezer.call("capacity")
	_check(player.call("_interact_with_appliance", freezer), "手持货箱对冰柜交互成功（#50）")
	_check(freezer.stock["kungpao"] == mini(1 + freezer.CRATE_SIZE, cap), "货箱入库：库存 +%d（不超容量，#50）" % freezer.CRATE_SIZE)
	_check(player.get("held_item") == null, "入库后玩家空手（#50）")

	# 满仓拒收
	player.call("_interact_with_crate_stack", stack0)
	freezer.stock["kungpao"] = cap
	_check(not freezer.call("can_accept_item", player.get("held_item")), "满仓时冰柜拒收货箱（#50）")
	player.call("discard_held_item")

	# 四格展示（#54）：库存 0 → 格图标隐藏/计数 ×0；库存 >0 → 图标显示/计数 ×N
	var slot2_icon: Sprite2D = freezer.get_node("Slots/Slot2/Icon")
	var slot2_count: Label = freezer.get_node("Slots/Slot2/CountLabel")
	freezer.stock["yuxiang"] = 0
	freezer.call("_refresh_slots")
	_check(not slot2_icon.visible, "鱼香库存 0 → 格 2 图标隐藏（#54）")
	_check(slot2_count.text == "×0", "鱼香库存 0 → 格 2 计数 ×0（#54）")
	freezer.stock["yuxiang"] = 2
	freezer.call("_refresh_slots")
	_check(slot2_icon.visible, "鱼香补货 → 格 2 图标显示（#54）")
	_check(slot2_count.text == "×2", "鱼香补货 → 格 2 计数 ×2（#54）")

	# take_from_slot 扣库存（#54）：格 3 取麻婆包 3 → 2
	freezer.stock["mapo"] = 3
	var pkg_taken: Node2D = freezer.call("take_from_slot", 2)
	_check(pkg_taken != null and pkg_taken.get("dish_type") == "mapo", "格 3 取货返回麻婆料理包（#54）")
	_check(int(freezer.stock["mapo"]) == 2, "take_from_slot 扣库存 3 → 2（#54）")
	pkg_taken.free()

	# ===== #51 场景陈设素材（手绘 SVG 换肤 + 纯视觉陈设） =====
	_check(load("res://assets/art/props/microwave.png") != null, "微波炉素材文件存在（#51/#63）")
	_check(load("res://assets/art/props/freezer.png") != null, "冰柜素材文件存在（#51/#63）")
	_check(load("res://assets/art/props/table.png") != null, "餐桌素材文件存在（#51/#63）")
	_check(load("res://assets/art/props/counter_bar.png") != null, "吧台素材文件存在（#51/#63）")
	_check(load("res://assets/art/props/wall_top.png") != null, "墙体素材文件存在（#51/#63）")
	var mw_sprite: Sprite2D = microwave.get_node_or_null("Sprite2D")
	_check(mw_sprite != null and mw_sprite.texture != null \
		and str(mw_sprite.texture.resource_path).contains("props/microwave.png"), "微波炉 Sprite2D 换用 AI 素材（#51/#63）")
	var tables_ok := true
	for i in 4:
		var t: Node = scene.get_node_or_null("Table%d" % (i + 1))
		if t == null or not (t is Sprite2D):
			tables_ok = false
	_check(tables_ok, "餐桌 Table1..Table4 存在且为 Sprite2D（#51）")
	_check(scene.get_node_or_null("CounterBar") != null and scene.get_node_or_null("CounterBar1") == null \
		and scene.get_node_or_null("Cashier") != null, "整吧台单图单 sprite + 收银机已陈设（#75）")
	_check(scene.get_node_or_null("Door") != null and scene.get_node_or_null("FloorMat") != null, "店门与门内地垫已陈设（#51）")

	# ===== #93 布局重排：靠墙置物架 + 工作台（设备上桌）+ 展示柜 =====
	_check(load("res://assets/art/props/shelf_wall.svg") != null, "置物架素材存在（#93）")
	_check(load("res://assets/art/props/display_case.svg") != null, "展示柜素材存在（#93）")
	var shelves_ok := true
	for i in 3:
		var s: Node = scene.get_node_or_null("ShelfWall%d" % (i + 1))
		if s == null or not (s is Sprite2D) or s.position != layout.SHELF_SLOTS[i] or s.z_index != -1:
			shelves_ok = false
	_check(shelves_ok, "靠墙置物架 ×3 位于 SHELF_SLOTS（z=-1 贴墙，#93）")
	_check(scene.get_node_or_null("WorkTable") == null, "旧 WORK_TABLE 单图已撤除（#93）")
	var dt1: Node2D = scene.get_node_or_null("DeviceTable")
	var dt2: Node2D = scene.get_node_or_null("DeviceTable2")
	_check(dt1 != null and dt2 != null, "工作台 ×2 已实例化（#93）")
	_check(dt1 != null and dt1.global_position == layout.DEVICE_TABLE_SLOTS[0] \
		and dt2 != null and dt2.global_position == layout.DEVICE_TABLE_SLOTS[1], "工作台位于 DEVICE_TABLE_SLOTS（#93）")
	if dt1 != null and dt2 != null:
		_check(dt1.get_node("SlotL").global_position == layout.DEVICE_SLOTS[0] \
			and dt1.get_node("SlotR").global_position == layout.DEVICE_SLOTS[1] \
			and dt2.get_node("SlotL").global_position == layout.DEVICE_SLOTS[2] \
			and dt2.get_node("SlotR").global_position == layout.DEVICE_SLOTS[3], "桌面槽位 = DEVICE_SLOTS（单一权威，#93）")
		_check(dt1.get_node("SlotL").is_in_group("device_slot"), "桌面槽位在 device_slot 组（#93）")
	_check(layout.MICROWAVE_SLOTS[0] == layout.DEVICE_SLOTS[0] and layout.MICROWAVE_SLOTS[1] == layout.DEVICE_SLOTS[1],
		"微波炉默认槽位 = 桌面 1 两槽（设备上桌，#93）")
	_check(microwave.global_position == layout.DEVICE_SLOTS[0], "微波炉摆上桌面槽位（#93）")
	var cases_ok := true
	for i in 2:
		var dc: Node = scene.get_node_or_null("DisplayCase%d" % (i + 1))
		if dc == null or not (dc is Sprite2D) or dc.position != layout.DISPLAY_SLOTS[i] or dc.z_index != 0:
			cases_ok = false
	_check(cases_ok, "展示柜 ×2 位于 DISPLAY_SLOTS（z=0 参与 y-sort，#93）")
	# 走道校核：设备排（微波炉底缘 230+121）与柜台碰撞体顶缘（吧台中心 y+64-16=660）之间主走道 ≥ 260px
	var aisle: float = (layout.COUNTER_BAR_POS.y + 64.0 - 16.0) - (layout.DEVICE_SLOTS[0].y + 121.0)
	_check(aisle >= 260.0, "设备排与柜台间主走道 %.0fpx ≥ 260（玩家直径 234，#93）" % aisle)

	# ===== #67 反馈层（世界飘字 + 金币飞行 + 结算 count-up） =====
	var feedback: Node = scene.get_node_or_null("FloatingFeedback")
	_check(feedback != null, "FloatingFeedback 存在于 MainScene（#67）")
	if feedback != null:
		var before: int = feedback.get_child_count()
		feedback.call("show_gain", Vector2(500, 400), 20)
		_check(feedback.get_child_count() > before, "show_gain 生成飘字子节点（#67）")
		var float_label: Label = null
		for child in feedback.get_children():
			if child is Label:
				float_label = child
		_check(float_label != null and float_label.text == "+20", "飘字文本为 +20（#67）")
		feedback.call("show_penalty", Vector2(500, 400), "差评")
		var penalty_ok := false
		for child in feedback.get_children():
			if child is Label and child.text == "差评":
				penalty_ok = true
		_check(penalty_ok, "show_penalty 生成红色差评飘字（#67）")
		for child in feedback.get_children():
			child.free()

	# ===== 汇总 =====
	var status := "PASS" if _fail_count == 0 else "FAIL"
	print("=".repeat(50))
	print("SMOKE TEST RESULT: %s (failures=%d)" % [status, _fail_count])
	print("=".repeat(50))
	get_tree().quit(0 if _fail_count == 0 else 1)

# ==================== 辅助 ====================

## 手动驱动射线：设置玩家朝向/位置，更新射线并强制检测
func _face_and_ray(player, target, face: Vector2) -> void:
	player.global_position = target.global_position + Vector2(0, 280)
	player.set("facing_direction", face)
	var ray: RayCast2D = player.get_node("InteractionRay")
	# 交互距离与 player_character.gd 的 INTERACTION_DISTANCE=280.0 保持一致
	ray.target_position = face * 280.0
	ray.force_raycast_update()
	# 重置交互冷却，避免连续调用被拦截
	player.set("_interaction_cooldown", 0.0)

func _check(cond: bool, msg: String) -> void:
	if cond:
		print_rich("[color=green]  [OK] %s[/color]" % msg)
	else:
		_fail_count += 1
		print_rich("[color=red]  [FAIL] %s[/color]" % msg)
