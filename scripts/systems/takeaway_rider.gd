## 文件: scripts/systems/takeaway_rider.gd
## 职责: 骑手视觉（P4）——外卖订单结算时（骑手取餐/超时空手）在外卖口短暂出现，反馈骑手事件
## 依赖: GameStateManager/UITheme (autoload)；复用顾客素材 + 蓝色调（P0 无骑手素材，后续 AI 生成替换）
## 注意: @tool + 编辑器进程不连接信号（纯视觉，测试无需断言骑手）

@tool
extends Node2D

const RIDER_TEXTURE := preload("res://assets/art/characters/rider.png")  # #63：骑手专属素材（蓝头盔俯视角）
const RIDER_SCALE := 0.35
const RIDER_STAY := 1.2     ## 骑手停留秒数
const RIDER_OFFSET := Vector2(0, -70)  ## 出现在外卖口上方

var _sprite: Sprite2D = null
var _hide_timer := 0.0

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	if not GameStateManager.takeaway_completed.is_connected(_on_takeaway_done):
		GameStateManager.takeaway_completed.connect(_on_takeaway_done)
	if not GameStateManager.takeaway_failed.is_connected(_on_takeaway_done):
		GameStateManager.takeaway_failed.connect(_on_takeaway_done)

func _process(delta: float) -> void:
	if _sprite == null or not _sprite.visible:
		return
	_hide_timer -= delta
	if _hide_timer <= 0.0:
		_sprite.visible = false

## 外卖结算（完成/失败）→ 骑手现身（取餐或空手离开，短暂停留）
func _on_takeaway_done(_order_id: int, _revenue: int = 0) -> void:
	_show_rider()

## 骑手出现在外卖口（复用顾客素材 + 蓝色调）
func _show_rider() -> void:
	if _sprite == null:
		_sprite = Sprite2D.new()
		_sprite.texture = RIDER_TEXTURE
		_sprite.scale = Vector2.ONE * RIDER_SCALE
		add_child(_sprite)
	var counter := get_parent().get_node_or_null("TakeoutCounter")
	if counter != null:
		_sprite.global_position = counter.global_position + RIDER_OFFSET
	_sprite.modulate = Color.WHITE  # #63：骑手素材已带蓝色，不再整图染色
	_sprite.visible = true
	_hide_timer = RIDER_STAY
