## 文件: tests/plugin/smoke_plugin.gd
## 职责: issue #2 交互闭环冒烟测试（EditorPlugin 方式）
## 运行: 在 project.godot [editor_plugins] 注册 "res://tests/plugin" 后，
##       Godot --path . --editor --quit-after N 会自动执行并输出 PASS/FAIL
## 注意: 编辑器进程不跑 _physics_process，测试手动驱动射线与交互冷却

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

	# ===== 3. 空手靠近微波炉 → 取出 =====
	_face_and_ray(player, microwave, Vector2.UP)
	_check(player.call("try_interact"), "空手面对微波炉按 E 应成功取出")
	_check(player.get("held_item") == meal, "取出后 held_item 应为原料理包")
	_check(not microwave.call("is_occupied"), "取出后微波炉应为空")

	# ===== 汇总 =====
	var status := "PASS" if _fail_count == 0 else "FAIL"
	print("=".repeat(50))
	print("SMOKE INTERACT RESULT: %s (failures=%d)" % [status, _fail_count])
	print("=".repeat(50))
	get_tree().quit(0 if _fail_count == 0 else 1)

# ==================== 辅助 ====================

## 手动驱动射线：设置玩家朝向/位置，更新射线并强制检测
func _face_and_ray(player, target, face: Vector2) -> void:
	player.global_position = target.global_position + Vector2(0, 280)
	player.set("facing_direction", face)
	var ray: RayCast2D = player.get_node("InteractionRay")
	# 交互距离与 player_character.gd 的 INTERACTION_DISTANCE=360.0 保持一致
	ray.target_position = face * 360.0
	ray.force_raycast_update()
	# 重置交互冷却，避免连续调用被拦截
	player.set("_interaction_cooldown", 0.0)

func _check(cond: bool, msg: String) -> void:
	if cond:
		print_rich("[color=green]  [OK] %s[/color]" % msg)
	else:
		_fail_count += 1
		print_rich("[color=red]  [FAIL] %s[/color]" % msg)
