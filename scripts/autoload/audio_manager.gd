## 文件: scripts/autoload/audio_manager.gd
## 职责: 音频管理（P9）——监听游戏信号播放 SFX + BGM 播放接口；音效为程序化生成 WAV（assets/audio/sfx/）
## 依赖: GameStateManager (autoload)；@tool 编辑器进程不播放（冒烟测试静默）
## 注意: BGM 由 SunoAI 外部生成后放入 assets/audio/bgm/（当前无文件，接口就绪静默跳过）

@tool
extends Node

var _bgm_player: AudioStreamPlayer = null
var bgm_playing := false

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_bgm_player = AudioStreamPlayer.new()
	add_child(_bgm_player)
	# 监听游戏信号 → 自动 SFX（命名方法 + is_connected 防热重载重复连接）
	if not GameStateManager.order_completed.is_connected(_on_order_completed):
		GameStateManager.order_completed.connect(_on_order_completed)
	if not GameStateManager.order_failed.is_connected(_on_order_failed):
		GameStateManager.order_failed.connect(_on_order_failed)
	if not GameStateManager.takeaway_created.is_connected(_on_takeaway_created):
		GameStateManager.takeaway_created.connect(_on_takeaway_created)
	if not GameStateManager.takeaway_completed.is_connected(_on_takeaway_completed):
		GameStateManager.takeaway_completed.connect(_on_takeaway_completed)
	if not GameStateManager.takeaway_failed.is_connected(_on_takeaway_failed):
		GameStateManager.takeaway_failed.connect(_on_takeaway_failed)
	if not GameStateManager.event_started.is_connected(_on_event_started):
		GameStateManager.event_started.connect(_on_event_started)

# ==================== 公共 API ====================

## 播放一个音效（短促，播完自释放；任意节点可调）
func play_sfx(sfx_name: String, volume_db: float = -8.0) -> void:
	if Engine.is_editor_hint():
		return
	var stream: AudioStream = load("res://assets/audio/sfx/%s.wav" % sfx_name)
	if stream == null:
		return
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = volume_db
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()

## 播放 BGM（文件由 SunoAI 生成后放入 assets/audio/bgm/；不存在则静默跳过）
func play_bgm(bgm_name: String, volume_db: float = -6.0) -> void:
	if Engine.is_editor_hint() or _bgm_player == null:
		return
	var stream: AudioStream = load("res://assets/audio/bgm/%s" % bgm_name)
	if stream == null:
		return
	_bgm_player.stream = stream
	_bgm_player.volume_db = volume_db
	_bgm_player.play()
	bgm_playing = true

func stop_bgm() -> void:
	if _bgm_player != null:
		_bgm_player.stop()
	bgm_playing = false

# ==================== 信号响应 ====================

func _on_order_completed(_order_id: int, _revenue: int) -> void:
	play_sfx("deliver")

func _on_order_failed(_order_id: int) -> void:
	play_sfx("timeout")

func _on_takeaway_created(_order_id: int) -> void:
	play_sfx("new_order")

func _on_takeaway_completed(_order_id: int, _revenue: int) -> void:
	play_sfx("deliver")

func _on_takeaway_failed(_order_id: int) -> void:
	play_sfx("timeout")

func _on_event_started(_event_type: int) -> void:
	play_sfx("event")
