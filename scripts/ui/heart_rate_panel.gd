## 文件: scripts/ui/heart_rate_panel.gd
## 职责: 心率面板（#82 全局营业压力）——左下常驻小面板：心形图标 + 压力条 + 数值，
##       随 GameStateManager 压力事件增减（置于 Toast 上方，与临时提示错开）
## 依赖: GameStateManager/UITheme (autoload)；静态结构在 scenes/ui/HeartRatePanel.tscn
## 注意: @tool + 编辑器进程不连接信号（冒烟测试手动调 refresh 断言）；纯显示无副作用

@tool
extends CanvasLayer

# ==================== 节点引用 ====================
@onready var _panel: PanelContainer = $Panel
@onready var _bar: ProgressBar = $Panel/Margin/HBox/Bar
@onready var _value_label: Label = $Panel/Margin/HBox/Value

func _ready() -> void:
	# 纹理九宫格面板 + bar 轨道样式（@tool 下同样生效，纯视觉无副作用）
	_panel.add_theme_stylebox_override("panel", UITheme.make_panel_texture_style())
	_bar.add_theme_stylebox_override("background", UITheme.make_bar_bg_style())
	_bar.max_value = GameStateManager.STRESS_MAX
	refresh()
	if Engine.is_editor_hint():
		return
	# 运行模式监听心率变化（命名方法 + is_connected 防热重载/多实例重复连接）
	if not GameStateManager.heart_rate_changed.is_connected(_on_heart_rate_changed):
		GameStateManager.heart_rate_changed.connect(_on_heart_rate_changed)

func _on_heart_rate_changed(_value: float) -> void:
	refresh()

## 与 GameStateManager.heart_rate 同步（运行模式信号驱动，测试/编辑器进程手动调用）
func refresh() -> void:
	var value: float = GameStateManager.heart_rate
	_bar.value = value
	_bar.add_theme_stylebox_override("fill", UITheme.make_bar_fill_style(stress_color_name(value)))
	_value_label.text = "%d" % int(round(value))
	_value_label.add_theme_color_override("font_color", stress_ui_color(value))

## 压力三档色（<50 绿 / <80 黄 / ≥80 红），返回 bar 纹理色名
func stress_color_name(value: float) -> String:
	if value >= 80.0:
		return "red"
	if value >= 50.0:
		return "yellow"
	return "green"

## 压力三档对应的 UI 功能色（数值文本用）
func stress_ui_color(value: float) -> Color:
	match stress_color_name(value):
		"red":
			return UITheme.COLOR_RED
		"yellow":
			return UITheme.COLOR_YELLOW
	return UITheme.COLOR_GREEN
