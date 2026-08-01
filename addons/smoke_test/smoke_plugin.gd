## 文件: tests/plugin/smoke_plugin.gd
## 职责: 冒烟测试（EditorPlugin 方式）：交互闭环（#2）+ 顾客排队（#3）+ 订单循环（#4）
##       + P2 订单队列/耐心值/超时差评（#20）
## 运行: 在 project.godot [editor_plugins] 注册 "res://addons/smoke_test/plugin.cfg" 后，
##       Godot --path . --editor --quit-after N 会自动执行并输出 PASS/FAIL
## 注意: 编辑器进程会运行 @tool 节点的 _physics_process（玩家/顾客脚本含 is_editor_hint 分支）；
##       顾客在编辑器进程用直接位移（物理不步进），运行模式走 move_and_slide 真实碰撞
## P2: GameStateManager._process 在编辑器进程被拦截，耐心倒计时由测试手动 tick_patience 推进

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
	get_tree().root.add_child(scene)
	await get_tree().process_frame
	await get_tree().process_frame

	var player = scene.get_node("PlayerCharacter")
	var microwave = scene.get_node("Microwave")
	var meal = scene.get_node("Items/MealPackage")

	# 监听信号（验收标准：信号命名规范 item_picked_up / item_placed）
	# 注意：编辑器进程中对非 @tool 脚本的成员访问需用动态 API
	player.connect("item_picked_up", func(_item): _picked_up_count += 1)
	player.connect("item_placed", func(_item): _placed_count += 1)

	# ===== 场景要素就位 =====
	_check(player != null, "PlayerCharacter 存在于 MainScene")
	_check(microwave != null, "Microwave 存在于 MainScene")
	_check(meal != null, "MealPackage 存在于 MainScene")

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
	_check(meal.global_position == layout.get_slot_position(layout.MEAL_SLOTS, 0), "料理包位于货架槽位 0")
	_check(scene.get_node("Table1").position == layout.TABLE_SLOTS[0], "餐桌位于就餐区槽位 0")
	_check(layout.QUEUE_SPACING == 200.0 and manager.get("queue_spacing") == 200.0, "队列间距接入布局系统（200）")

	# ===== 1. 空手靠近料理包 → 拾取 =====
	_face_and_ray(player, meal, Vector2.UP)
	_check(player.call("try_interact"), "空手面对料理包按 E 应成功拾取")
	_check(player.get("held_item") == meal, "拾取后 held_item 应为该料理包")
	_check(_picked_up_count == 1, "item_picked_up 信号应发出 1 次")
	_check(meal.get_parent() == player.get_node("HeldItemPivot"), "料理包应挂到 HeldItemPivot 下")

	# ===== 1.5 中途放下（issue #22）：Q 放下 → 恢复可拾取 → 再拾取 =====
	_check(player.call("drop_held_item"), "手持时按 Q 放下应成功")
	_check(player.get("held_item") == null, "放下后玩家空手")
	_check(meal.get_parent() == scene.get_node("Items"), "料理包挂回场景 Items 容器")
	_check(abs(meal.global_position.distance_to(player.global_position) - 50.0) < 1.0, "放下位置为玩家身前约 50px")
	_check(meal.collision_layer == 8 and meal.collision_mask == 0, "放下后恢复可拾取碰撞（layer=8）")
	_face_and_ray(player, meal, Vector2.UP)
	# 编辑器进程物理不步进：物品重挂场景后需等一帧注册到物理服务器，射线查询才命中
	await get_tree().process_frame
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

	# 第一轮交付：手持成品菜交付 c1 → 好评 +1
	_check(player.call("_interact_with_customer", c1), "手持成品菜交付 c1 成功")
	_check(gsm.revenue == 20, "交付后营业额 +20")
	_check(gsm.good_reviews == 1 and gsm.bad_reviews == 0, "交付成功 → 好评 +1（差评 0）")
	_check(gsm.get_active_order_count() == 2, "c1 订单结算，队列剩 2 单（c2/c3）")
	_check(manager.call("get_queue_count") == 2, "c1 离店，队列剩 2 人")

	# 补位：c2 前移到柜台（已有订单，无需重建）
	await get_tree().create_timer(2.0).timeout
	_check(manager.call("get_front_customer") == c2, "补位后队首为 c2")
	_check(gsm.get_active_order_count() == 2, "补位顾客已有订单，不重复下单（count=2）")

	# 第二轮：加热（料理包2）→ 交付 c2 → 好评 +2
	var meal2 = scene.get_node("Items/MealPackage2")
	player.call("_interact_with_pickable", meal2)
	player.call("_interact_with_appliance", microwave)
	await get_tree().create_timer(3.5).timeout
	player.call("_interact_with_appliance", microwave)
	_check(player.get("held_item") != null and player.get("held_item").is_in_group("dish"), "第二轮取出成品菜")
	_check(player.call("_interact_with_customer", c2), "第二轮交付 c2 成功")
	_check(gsm.revenue == 40, "营业额累加至 40")
	_check(gsm.good_reviews == 2, "好评累加至 2")
	await get_tree().create_timer(2.0).timeout
	_check(manager.call("get_front_customer") == c3, "补位后队首为 c3")

	# 第三轮：加热（料理包3）→ 交付 c3 → 队列清空 → 无状态残留
	var meal3 = scene.get_node("Items/MealPackage3")
	player.call("_interact_with_pickable", meal3)
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
	_check(manager.call("get_queue_count") == 0, "超时顾客离店，队列清空")
	_check(c4.get("order_id") == -1 and c5.get("order_id") == -1 and c6.get("order_id") == -1, "超时顾客订单已解绑")

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
