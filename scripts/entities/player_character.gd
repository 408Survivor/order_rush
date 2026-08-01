## 文件: scripts/entities/player_character.gd
## 职责: 玩家角色控制：移动、交互（拾取/放置）、手持物品管理、交互提示
## 依赖: 无（交互对象通过组标签交互，见开发手册 4.3/4.4）
## 注意: 交互检测使用前方 RayCast2D（InteractionRay），提示显示在屏幕底部

@tool
extends CharacterBody2D

# ==================== 信号 ====================
## 拾取物品时发出（命名遵循 ReadmeForAgent 第 5 节规范）
signal item_picked_up(item: Node2D)
## 放置物品到设备时发出
signal item_placed(item: Node2D)

# ==================== 常量 ====================
const MOVE_SPEED := 200.0           ## 像素/秒
const INTERACTION_DISTANCE := 280.0 ## 交互检测距离（像素，覆盖贴合距离≈273）
const INTERACTION_COOLDOWN := 0.25  ## 交互冷却（秒），防止连按

# ==================== 节点引用 ====================
@onready var sprite: Sprite2D = $Sprite2D
@onready var interaction_ray: RayCast2D = $InteractionRay
@onready var held_item_pivot: Marker2D = $HeldItemPivot
@onready var prompt_label: Label = $InteractionPrompt/PromptLabel

# ==================== 状态变量 ====================
## 当前手持物品（Node2D，如 MealPackage）
var held_item: Node2D = null

## 面对方向（用于交互检测和 Sprite 翻转）
var facing_direction := Vector2.DOWN

var _input_vector := Vector2.ZERO
var _interaction_cooldown := 0.0

# ==================== 生命周期 ====================

func _ready() -> void:
	add_to_group("player")

	# 确保交互射线初始方向正确
	interaction_ray.target_position = facing_direction * INTERACTION_DISTANCE
	hide_prompt()
	print_rich("[color=green]Player ready at %s[/color]" % str(global_position))

func _process(delta: float) -> void:
	# 交互冷却倒计时
	if _interaction_cooldown > 0.0:
		_interaction_cooldown -= delta

	# 每帧刷新交互提示（根据当前面对的目标 + 手持状态）
	_update_prompt()

func _physics_process(_delta: float) -> void:
	# @tool：编辑器进程不执行游戏移动逻辑（防止编辑场景时副作用）
	if Engine.is_editor_hint():
		return
	# 读取 WASD/方向键输入
	_input_vector = Input.get_vector("move_left", "move_right", "move_up", "move_down")

	velocity = _input_vector * MOVE_SPEED
	move_and_slide()

	# 更新面向方向（用于交互检测与 Sprite 翻转）
	if _input_vector != Vector2.ZERO:
		facing_direction = _input_vector.normalized()
		_update_sprite_direction()

	# 交互射线始终指向当前面对方向
	interaction_ray.target_position = facing_direction * INTERACTION_DISTANCE

func _input(event: InputEvent) -> void:
	# @tool：编辑器进程不响应游戏输入（防止编辑场景时触发交互改变场景）
	if Engine.is_editor_hint():
		return
	# E / Space 触发交互
	if event.is_action_pressed("interact"):
		try_interact()

# ==================== 交互系统 ====================

## 尝试与前方对象交互（核心交互逻辑）：
## 1. 手持物品时 → 尝试放入设备（微波炉）
## 2. 空手时 → 尝试从设备取出 / 拾取地上的物品
## 输出: bool（是否成功触发交互）
func try_interact() -> bool:
	if _interaction_cooldown > 0.0:
		return false
	_interaction_cooldown = INTERACTION_COOLDOWN

	# 交互前强制刷新射线，确保使用最新朝向/位置（不依赖物理帧更新）
	interaction_ray.force_raycast_update()
	var interactable := _get_interactable_object()
	if interactable == null:
		return false

	# 手持物品：优先尝试放入设备
	if held_item != null:
		if interactable.is_in_group("appliance"):
			return _interact_with_appliance(interactable)
		elif interactable.is_in_group("customer"):
			return _interact_with_customer(interactable)
		return false

	# 空手：取出 / 拾取
	if interactable.is_in_group("appliance"):
		return _interact_with_appliance(interactable)
	elif interactable.is_in_group("pickable"):
		return _interact_with_pickable(interactable)

	return false

## 获取交互射线命中的可交互对象（跳过手持物品——它挂在玩家面前会挡住射线）
func _get_interactable_object() -> Node2D:
	if interaction_ray.is_colliding():
		var collider := interaction_ray.get_collider()
		if collider != null and collider.is_in_group("interactable") and collider != held_item:
			return collider
	return null

## 与设备交互（微波炉）：手持→放入；空手→取出
func _interact_with_appliance(appliance: Node2D) -> bool:
	if held_item != null:
		if appliance.can_accept_item(held_item):
			var item := held_item
			_drop_from_hand()
			appliance.accept_item(item)
			item_placed.emit(item)
			return true
	else:
		var item: Node2D = appliance.give_item()
		if item != null:
			_pick_up_item(item)
			return true

	return false

## 与可拾取物品交互（地上的料理包）
func _interact_with_pickable(pickable: Node2D) -> bool:
	if held_item != null:
		return false
	_pick_up_item(pickable)
	return true

## 与顾客交互（交付成品菜，issue #4）
func _interact_with_customer(customer: Node2D) -> bool:
	if held_item == null:
		return false
	if not held_item.is_in_group("dish"):
		return false
	if not customer.can_accept_dish(held_item):
		return false
	var dish := held_item
	_drop_from_hand()
	customer.receive_dish(dish)
	return true

# ==================== 手持物品管理 ====================

## 拾取物品到手，挂到 HeldItemPivot 上显示
## 输入: item (Node2D) - 必须是可手持物品
func _pick_up_item(item: Node2D) -> void:
	if held_item != null:
		push_warning("Already holding an item, cannot pick up another")
		return

	held_item = item

	# 从原父节点移出，挂到玩家身上
	if item.get_parent() != null:
		item.get_parent().remove_child(item)
	held_item_pivot.add_child(item)
	item.position = Vector2.ZERO
	item.scale = Vector2.ONE * 0.8  # 手持时稍微缩小
	item.visible = true             # 防御：确保物品可见
	# 手持物品禁用碰撞：不再参与物理/交互检测（否则会挡住前方的交互射线）
	if item is Area2D:
		item.collision_layer = 0
		item.collision_mask = 0

	item_picked_up.emit(item)
	print_rich("[color=cyan]Picked up: %s[/color]" % item.name)

## 从手上移除物品（不落回场景，交给设备接管）
func _drop_from_hand() -> void:
	if held_item == null:
		return
	var item := held_item
	held_item = null
	if item.get_parent() != null:
		item.get_parent().remove_child(item)
	item.scale = Vector2.ONE

## 根据移动方向更新 Sprite 朝向（flip_h，避免 scale.x 翻转瞬移问题）
func _update_sprite_direction() -> void:
	if facing_direction.x < 0:
		sprite.flip_h = true
	elif facing_direction.x > 0:
		sprite.flip_h = false

# ==================== 交互提示 ====================

## 根据当前目标与手持状态刷新底部提示文案
func _update_prompt() -> void:
	var target := _get_interactable_object()
	if target == null:
		hide_prompt()
		return

	var text := ""
	if held_item != null:
		# 手持物品：设备可接受 → 放入；顾客 → 交付（区分可收/不可收与物品类型）
		if target.is_in_group("appliance") and target.can_accept_item(held_item):
			text = "[E] 放入%s" % _friendly_name(target)
		elif target.is_in_group("customer"):
			if held_item.is_in_group("dish"):
				if target.can_accept_dish(held_item):
					text = "[E] 交付%s" % _friendly_name(target)
				else:
					text = "[E] 交付（先服务队首）"
			else:
				text = "料理包需先加热"
	else:
		# 空手：可拾取 → 提示拾取；设备加热完成 → 提示取出
		if target.is_in_group("pickable"):
			text = "[E] 拾取%s" % _friendly_name(target)
		elif target.is_in_group("appliance") and target.is_done():
			text = "[E] 取出%s" % _friendly_name(target)

	if text == "":
		hide_prompt()
	else:
		show_prompt(text)

## 读取交互对象的显示名（优先用对象的 display_name 属性）
func _friendly_name(node: Node) -> String:
	var custom: Variant = node.get("display_name")
	if custom != null:
		return str(custom)
	return node.name

func show_prompt(text: String) -> void:
	prompt_label.text = text
	prompt_label.visible = true

func hide_prompt() -> void:
	prompt_label.text = ""
	prompt_label.visible = false
