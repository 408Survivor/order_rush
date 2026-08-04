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
	_check(layout.WORLD_SIZE == Vector2(1920, 1080), "世界尺寸 1920x1080")
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
	_check(str(meal.get_node("Sprite2D").texture.resource_path).contains("meal_pack_kungpao.svg"), "料理包纹理按 dish_type 区分（#54）")
	_check(str(freezer.call("take_hint")) != "", "冰柜取货提示文本非空（#54）")
	_check(freezer.call("take_from_slot", 3) == null, "格 4 预留位取货返回 null（#54）")
	# 取货边界：距离 >340 失败；手持时失败
	player.global_position = freezer.global_position + Vector2(0, 500)
	_check(player.call("try_take_from_freezer", 1) == false, "距离 >340 取货失败（#54）")
	player.global_position = freezer.global_position + Vector2(0, 150)
	_check(player.call("try_take_from_freezer", 1) == false, "手持时取货失败（#54）")

	# ===== 1.5 中途放下（issue #22）：Q 放下 → 恢复可拾取 → 再拾取 =====
	_check(player.call("drop_held_item"), "手持时按 Q 放下应成功")
	_check(player.get("held_item") == null, "放下后玩家空手")
	_check(meal.get_parent() == scene.get_node("Items"), "料理包挂回场景 Items 容器")
	_check(abs(meal.global_position.distance_to(player.global_position) - 50.0) < 1.0, "放下位置为玩家身前约 50px")
	_check(meal.collision_layer == 8 and meal.collision_mask == 0, "放下后恢复可拾取碰撞（layer=8）")
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

	# 顾客生成时序：入口(80,520)→柜台(1350,520) 距离 1270px / 160 ≈ 7.9s，
	# 槽位按在场数分配（c2 不与行走中的 c1 撞槽）
	var c1 = manager.call("spawn_customer")
	await get_tree().create_timer(8.5).timeout
	var c2 = manager.call("spawn_customer")
	await get_tree().create_timer(7.5).timeout
	var c3 = manager.call("spawn_customer")
	await get_tree().create_timer(6.0).timeout

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

	# P2：每位顾客到达即下单 → 3 名顾客 = 3 个并发订单
	_check(gsm.get_active_order_count() == 3, "3 名顾客就位后订单队列应有 3 单（P2 多单并发）")
	board.call("refresh")
	_check(board.get("_cards").size() == 3, "订单面板显示 3 张卡片")
	# #48：订单卡片图标——菜品贴纸 + 满耐心笑脸（第一张卡 = c1，dish_override=kungpao）
	var first_card: Dictionary = board.get("_cards").values()[0]
	_check(str(first_card["dish_icon"].texture.resource_path).contains("dish_kungpao.svg"), "订单卡片菜品图标为宫保鸡丁贴纸（#48）")
	_check(str(first_card["mood_icon"].texture.resource_path).contains("mood_happy.svg"), "满耐心表情为笑脸（#48）")
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
	_check(str(player.get("held_item").get_node("Sprite2D").texture.resource_path).contains("dish_kungpao.svg"), "成品菜纹理按 dish_type 区分（#54）")
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
	# 等待上一批顾客全部离店（柜台→入口 1270px ≈ 7.9s）后生成新一批
	await get_tree().create_timer(8.5).timeout
	var c4 = manager.call("spawn_customer")
	await get_tree().create_timer(8.5).timeout
	var c5 = manager.call("spawn_customer")
	await get_tree().create_timer(7.5).timeout
	var c6 = manager.call("spawn_customer")
	await get_tree().create_timer(6.0).timeout
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

	# HUD 拆行（#32 第③步）：DayTimeLabel 天数行 + TimeLabel 倒计时行
	scene.get_node("RevenueHUD").call("_update_all")
	var day_text: String = scene.get_node("RevenueHUD/Panel/Margin/VBox/DayTimeLabel").text
	var time_text: String = scene.get_node("RevenueHUD/Panel/Margin/VBox/TimeLabel").text
	_check(day_text.contains("第 1 天") and day_text.contains("calendar.svg"), "HUD 天数行（图标化）")
	_check(time_text.contains("营业剩余 90s") and time_text.contains("timer.svg"), "HUD 倒计时行（图标化）")
	_check(scene.get_node_or_null("RevenueHUD/Panel/Margin/VBox/TimeBar") != null, "HUD 时间进度条节点存在（#48）")

	# 倒计时推进（未到点不触发打烊）
	gsm.tick_business_time(10.0)
	_check(absf(gsm.business_time_left - (gsm.BUSINESS_TIME_PER_DAY - 10.0)) < 0.01, "营业倒计时随 tick 递减")
	_check(gsm.is_shop_open, "未到点仍营业")
	scene.get_node("RevenueHUD").call("_update_all")
	_check(scene.get_node("RevenueHUD/Panel/Margin/VBox/TimeBar").value < 100.0, "HUD 时间条随倒计时减少（#48）")

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
	_check(layout.PICKUP_POINT == Vector2(1640, 520), "外卖口点位右移至柜台旁（#50）")
	_check(layout.SPAWN_POINT == Vector2(960, 300), "玩家出生点位（#50）")

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
	_check(load("res://assets/art/props/microwave.svg") != null, "微波炉素材文件存在（#51）")
	_check(load("res://assets/art/props/freezer.svg") != null, "冰柜素材文件存在（#51）")
	_check(load("res://assets/art/props/table.svg") != null, "餐桌素材文件存在（#51）")
	_check(load("res://assets/art/props/counter_bar.svg") != null, "吧台素材文件存在（#51）")
	_check(load("res://assets/art/props/wall_top.svg") != null, "墙体素材文件存在（#51）")
	var mw_sprite: Sprite2D = microwave.get_node_or_null("Sprite2D")
	_check(mw_sprite != null and mw_sprite.texture != null \
		and str(mw_sprite.texture.resource_path).contains("props/microwave.svg"), "微波炉 Sprite2D 换用手绘素材（#51）")
	var tables_ok := true
	for i in 4:
		var t: Node = scene.get_node_or_null("Table%d" % (i + 1))
		if t == null or not (t is Sprite2D):
			tables_ok = false
	_check(tables_ok, "餐桌 Table1..Table4 存在且为 Sprite2D（#51）")
	_check(scene.get_node_or_null("CounterBar1") != null and scene.get_node_or_null("Cashier") != null, "吧台与收银机已陈设（#51）")
	_check(scene.get_node_or_null("Door") != null and scene.get_node_or_null("FloorMat") != null, "店门与门内地垫已陈设（#51）")

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
