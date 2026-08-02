## 文件: scripts/systems/particle_fx.gd
## 职责: 粒子特效工具（P9）——一次性爆发粒子（金币/蒸汽/警示），无素材依赖（CPUParticles2D）
## 依赖: 无；静态方法 burst 供各场景节点调用（交付/加热/超时反馈）

@tool
extends Node

## 在指定位置爆发一组粒子（自动清理）
## parent: 挂载父节点；position: 局部位置；color: 粒子色；count: 数量；gravity: 重力方向
static func burst(parent: Node, position: Vector2, color: Color, count: int = 12, \
		gravity: Vector2 = Vector2(0, -300), spread: float = 180.0, life: float = 0.6) -> void:
	var p := CPUParticles2D.new()
	p.position = position
	p.amount = count
	p.lifetime = life
	p.one_shot = true
	p.explosiveness = 1.0
	p.emitting = true
	p.direction = Vector2.UP
	p.spread = spread
	p.gravity = gravity
	p.initial_velocity_min = 80.0
	p.initial_velocity_max = 220.0
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.5
	p.color = color
	parent.add_child(p)
	# 自动清理：生命周期结束后移除
	var tree := parent.get_tree()
	if tree == null:
		return
	var timer := tree.create_timer(life + 0.3)
	timer.timeout.connect(func() -> void:
		if is_instance_valid(p):
			p.queue_free()
	)
