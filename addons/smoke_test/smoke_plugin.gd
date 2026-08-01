## 文件: tests/plugin/smoke_plugin.gd
## 职责: 冒烟测试（EditorPlugin 方式）：交互闭环（issue #2）+ 顾客排队（issue #3）
## 运行: 在 project.godot [editor_plugins] 注册 "res://addons/smoke_test/plugin.cfg" 后，
##       Godot --path . --editor --quit-after N 会自动执行并输出 PASS/FAIL
## 注意: 编辑器进程会运行 @tool 节点的 _physics_process（玩家/顾客脚本含 is_editor_hint 分支）；
##       顾客在编辑器进程用直接位移（物理不步进），运行模式走 move_and_slide 真实碰撞

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

	# ===== 1. 空手靠近料理包 → 拾取 =====
	_face_and_ray(player, meal, Vector2.UP)
	_check(player.call("try_interact"), "空手面对料理包按 E 应成功拾取")
	_check(player.get("held_item") == meal, "拾取后 held_item 应为该料理包")
	_check(_picked_up_count == 1, "item_picked_up 信号应发出 1 次")
	_check(meal.get_parent() == player.get_node("HeldItemPivot"), "料理包应挂到 HeldItemPivot 下")

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
	var manager = scene.get_node("CustomerManager")
	var counter = scene.get_node("CounterPoint")
	_check(manager != null, "CustomerManager 存在于 MainScene")
	_check(counter != null, "CounterPoint 存在于 MainScene")

	# 模拟真实 Timer 节奏生成（3s 间隔 < 走到柜台 ~3.1s，
	# 验证槽位按在场数分配：c2 不与行走中的 c1 撞槽）
	var c1 = manager.call("spawn_customer")
	await get_tree().create_timer(3.0).timeout
	var c2 = manager.call("spawn_customer")
	await get_tree().create_timer(3.0).timeout
	var c3 = manager.call("spawn_customer")
	await get_tree().create_timer(2.5).timeout

	_check(c1 != null and c2 != null and c3 != null, "顾客按间隔连续生成成功")
	_check(c2.get("queue_slot") == counter.global_position - Vector2(150.0, 0.0), "c2 分配槽位 1（不与行走中的 c1 撞槽）")
	_check(c3.get("queue_slot") == counter.global_position - Vector2(300.0, 0.0), "c3 分配槽位 2")
	_check(manager.call("get_queue_count") == 3, "3 名顾客应全部入队")
	_check(manager.call("get_front_customer") == c1, "队首应为第一名顾客（c1）")
	_check(c1.call("is_waiting") and c2.call("is_waiting") and c3.call("is_waiting"), "顾客到达槽位后处于 WAITING")

	# 槽位不重叠（间距 150 > 碰撞直径 130，留容差按 >120 断言）
	var gap_ok: bool = c1.global_position.distance_to(c2.global_position) > 120.0 \
		and c2.global_position.distance_to(c3.global_position) > 120.0
	_check(gap_ok, "相邻顾客间距充足（不重叠）")

	# 队首位于柜台服务点（供订单系统索引）
	_check(c1.global_position.distance_to(counter.global_position) < 100.0, "队首位于柜台服务点")

	# 队列满时不再生成（max_queue=3，槽位 0-2 均在屏幕内）
	_check(manager.call("spawn_customer") == null, "队伍满（3/3）时生成被拒绝")

	# ===== 5. 订单循环：交付→结算→补位→重复 =====
	# 注意：编辑器进程物理不步进，RayCast2D 查询结果不稳定，
	# 本段直接调用内部交互方法（_interact_with_*）验证逻辑，射线路径由游戏运行模式保证
	# 玩家此时已手持第 3 段产出的成品菜（dish）
	var gsm = scene.get_node("/root/GameStateManager")
	_check(gsm != null, "GameStateManager (autoload) 可访问")
	_check(gsm.get_active_order_count() == 1, "队首到达后自动生成订单")
	_check(c1.get("order_id") != -1, "队首顾客绑定订单 id")
	_check(player.get("held_item") != null and player.get("held_item").is_in_group("dish"), "玩家手持成品菜（第 3 段产出）")

	# 第一轮交付：手持成品菜交付队首 c1
	_check(player.call("_interact_with_customer", c1), "手持成品菜交付队首顾客成功")
	_check(gsm.revenue == 20, "交付后营业额 +20")
	_check(gsm.get_active_order_count() == 1, "旧订单已结算，新队首订单已生成（count=1）")
	_check(manager.call("get_queue_count") == 2, "队首离开，队列剩 2 人")

	# 补位：c2 前移到柜台并生成新订单
	await get_tree().create_timer(2.0).timeout
	_check(manager.call("get_front_customer") == c2, "补位后队首为 c2")
	_check(gsm.get_active_order_count() == 1, "新队首自动生成新订单")

	# 第二轮循环：加热（料理包2）→ 交付 c2 → 营业额累加 → c3 补位
	var meal2 = scene.get_node("Items/MealPackage2")
	player.call("_interact_with_pickable", meal2)
	player.call("_interact_with_appliance", microwave)
	await get_tree().create_timer(3.5).timeout
	player.call("_interact_with_appliance", microwave)
	_check(player.get("held_item") != null and player.get("held_item").is_in_group("dish"), "第二轮取出成品菜")
	_check(player.call("_interact_with_customer", c2), "第二轮交付 c2 成功")
	_check(gsm.revenue == 40, "营业额累加至 40")
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
	_check(gsm.get_active_order_count() == 0, "无残留订单")
	_check(manager.call("get_queue_count") == 0, "队列已清空")
	_check(player.get("held_item") == null, "玩家空手（无残留物品）")

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
