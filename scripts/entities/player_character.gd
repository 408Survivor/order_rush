## 文件: scripts/entities/player_character.gd
## 职责: 玩家角色的移动控制（Phase 1 简化版）
## 依赖: 无（纯移动，暂不含交互）

extends CharacterBody2D

# ==================== 常量 ====================
const MOVE_SPEED := 200.0  ## 像素/秒

# ==================== 节点引用 ====================
@onready var sprite: Sprite2D = $Sprite2D

# ==================== 状态变量 ====================
var _input_vector := Vector2.ZERO

# ==================== 生命周期 ====================

func _ready() -> void:
	print_rich("[color=green]Player ready at %s[/color]" % str(global_position))

func _physics_process(_delta: float) -> void:
	# 读取 WASD/方向键输入
	_input_vector = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	
	# 计算移动速度
	velocity = _input_vector * MOVE_SPEED
	
	# 执行移动（自带碰撞处理）
	move_and_slide()
	
	# 根据移动方向翻转 Sprite
	if _input_vector.x < 0:
		sprite.scale.x = -0.2  # 向左翻转
	elif _input_vector.x > 0:
		sprite.scale.x = 0.2   # 向右（默认）
