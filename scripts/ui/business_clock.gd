## 文件: scripts/ui/business_clock.gd
## 职责: 营业时间饼图时钟——糖果色扇区表盘 + 随营业倒计时转动的指针（issue #84，替换 #48 线性 TimeBar）
## 依赖: UITheme (autoload) 色板；由 revenue_hud.gd 的 _on_time_changed 调 set_time 驱动
## 注意: @tool：编辑器进程（冒烟测试）_process 拦截脉冲推进，测试手动 _tick_pulse 断言相位
##       指针角度 hand_angle / 紧急态 urgent / 脉冲透明度 pulse_alpha() 均为冒烟断言接口
##       指针 12 点起步（满时间），随已过时间顺时针转满一圈；打烊后回 12 点并灰显表盘

@tool
extends Control

## 表盘扇区数（6 等分全天，糖果色循环填充）
const SECTOR_COUNT := 6
## 末段紧急阈值（最后 10s 红色脉冲，与原 TimeBar/TimeLabel 脉冲一致）
const URGENT_THRESHOLD := 10.0
## 脉冲角速度（rad/s）
const PULSE_SPEED := 6.0

## 剩余营业秒数（set_time 写入）
var time_left := 0.0
## 全天营业秒数（set_time 写入，防 0 除）
var time_total := 90.0
## 是否营业中（false = 打烊，表盘灰显）
var shop_open := true
## 指针角度（弧度，0 = 3 点方向；-PI/2 = 12 点起步，随已过时间顺时针增大）
var hand_angle := -PI / 2.0
## 末段紧急态（营业中且剩余 ≤10s）
var urgent := false

var _pulse_phase := 0.0

## 营业倒计时驱动入口（revenue_hud._on_time_changed 每帧调用，平滑转动）
func set_time(left: float, total: float, open: bool) -> void:
	time_total = maxf(total, 0.01)
	time_left = clampf(left, 0.0, time_total)
	shop_open = open
	var elapsed_ratio := 1.0 - time_left / time_total
	hand_angle = -PI / 2.0 + elapsed_ratio * TAU
	urgent = shop_open and time_left > 0.0 and time_left <= URGENT_THRESHOLD
	queue_redraw()

## 糖果色扇区循环（珊瑚粉/奶黄/薄荷绿/天蓝，与 #42/#48 浅色主题统一）
static func _sector_colors() -> Array[Color]:
	return [UITheme.COLOR_CORAL, UITheme.COLOR_CREAM, UITheme.COLOR_MINT, UITheme.COLOR_SKY]

## 脉冲透明度（0.1~1.0 正弦呼吸；紧急态描边/指针共用）
func pulse_alpha() -> float:
	return 0.55 + 0.45 * sin(_pulse_phase * PULSE_SPEED)

func _process(delta: float) -> void:
	# @tool：编辑器进程不自动推进（冒烟测试手动 _tick_pulse 断言）
	if Engine.is_editor_hint():
		return
	if urgent:
		_tick_pulse(delta)

## 脉冲相位推进 + 重绘（_process 调用；冒烟测试直调验证相位变化）
func _tick_pulse(delta: float) -> void:
	_pulse_phase += delta
	queue_redraw()

func _draw() -> void:
	var center := size / 2.0
	var radius := minf(size.x, size.y) / 2.0 - 3.0
	if radius <= 0.0:
		return
	# 奶油白底盘
	draw_circle(center, radius, UITheme.COLOR_BG)
	# 糖果色扇区（12 点起步顺时针 6 等分；打烊灰显）
	var dim := 1.0 if shop_open else 0.35
	for i in SECTOR_COUNT:
		var a0 := -PI / 2.0 + TAU * float(i) / float(SECTOR_COUNT)
		var a1 := -PI / 2.0 + TAU * float(i + 1) / float(SECTOR_COUNT)
		var col: Color = _sector_colors()[i % _sector_colors().size()]
		col.a *= dim
		_draw_wedge(center, radius - 2.0, a0, a1, col)
	# 扇区分隔线（深棕，手绘贴纸描边）
	for i in SECTOR_COUNT:
		var a := -PI / 2.0 + TAU * float(i) / float(SECTOR_COUNT)
		draw_line(center, center + Vector2.from_angle(a) * (radius - 2.0), UITheme.COLOR_TEXT, 1.5, true)
	# 外圈深棕描边（紧急时叠加红色脉冲环）
	draw_arc(center, radius - 1.0, 0.0, TAU, 48, UITheme.COLOR_TEXT, 3.0, true)
	if urgent:
		var ring := UITheme.COLOR_RED
		ring.a = pulse_alpha()
		draw_arc(center, radius - 1.0, 0.0, TAU, 48, ring, 4.5, true)
	# 指针（深棕；紧急时转红并呼吸）
	var hand_col := UITheme.COLOR_TEXT
	if urgent:
		hand_col = UITheme.COLOR_RED
		hand_col.a = pulse_alpha()
	draw_line(center, center + Vector2.from_angle(hand_angle) * radius * 0.7, hand_col, 4.0, true)
	# 轴心金色铆钉
	draw_circle(center, 4.0, UITheme.COLOR_GOLD_DARK)
	draw_arc(center, 4.0, 0.0, TAU, 16, UITheme.COLOR_TEXT, 1.5, true)

## 单个扇区（圆心 + 弧线采样多边形）
func _draw_wedge(center: Vector2, radius: float, a0: float, a1: float, col: Color) -> void:
	var points := PackedVector2Array()
	points.append(center)
	const STEPS := 8
	for s in STEPS + 1:
		var a := lerpf(a0, a1, float(s) / float(STEPS))
		points.append(center + Vector2.from_angle(a) * radius)
	draw_colored_polygon(points, col)
