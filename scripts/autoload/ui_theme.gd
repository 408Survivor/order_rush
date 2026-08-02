## 文件: scripts/autoload/ui_theme.gd
## 职责: UI 全局主题——统一调色板常量 + 中文字体加载（ThemeDB.fallback_font），
##       让全部 UI 脱离 Godot 默认字体观感（issue #30）
## 依赖: 无（autoload 最先初始化，全局字体即时生效）
## 注意: 字体用 FontFile.load_dynamic_font 直接加载（不依赖 import，编辑器进程/冒烟测试可用）；
##       调色板常量供各 UI 脚本引用，取代散落的硬编码 Color

@tool
extends Node

# ==================== 调色板（统一 UI 配色，各脚本引用此常量） ====================
## #32：暖木 × 奶油 × 金 色系——与俯视角暖色插画世界（地板 225/227/228、玩家 215/192/175）同色温，
##       取代旧深蓝灰冷调（深冷 UI vs 暖亮世界的割裂感来源）
const COLOR_BG := Color("#1C120A")                    ## 深咖啡黑（结算面板底/遮罩氛围）
const COLOR_PANEL := Color(0.17, 0.12, 0.08, 0.90)    ## 面板底色（半透明暖深棕，木纹影调）
const COLOR_PANEL_LIGHT := Color(0.25, 0.18, 0.12, 0.92) ## 亮面板/悬停态
const COLOR_GOLD := Color("#F2C14E")                   ## 强调金（标题/金币/边框）
const COLOR_GOLD_DARK := Color("#C8921F")              ## 按钮底金
const COLOR_GOLD_DARKER := Color("#8F6510")            ## 按钮按下底金
const COLOR_GREEN := Color("#5ED67A")                  ## 成功
const COLOR_YELLOW := Color("#F0B429")                 ## 警告
const COLOR_RED := Color("#F05A4E")                    ## 危险
const COLOR_BLUE := Color("#8FB4E0")                   ## 信息（柔化，减少冷色冲突）
const COLOR_TEXT := Color("#F8F1E3")                   ## 主文本（奶油白）
const COLOR_TEXT_DIM := Color(0.97, 0.94, 0.89, 0.55)  ## 弱文本
const COLOR_BORDER := Color(0.95, 0.85, 0.60, 0.35)    ## 面板描边（暖金）

# ==================== 字体 ====================
const FONT_PATH := "res://assets/fonts/ZCOOLKuaiLe-Regular.ttf"
const FONT_SIZE_BASE := 20

# ==================== 图标（#32 第②步：SVG 图标集替换 emoji） ====================
## 金描边扁平风 SVG 图标（assets/art/ui/icons/），经 RichTextLabel [img] 内联显示
const ICON_PLATE := "res://assets/art/ui/icons/plate.svg"       ## 菜品（订单卡片/顾客头顶）
const ICON_COIN := "res://assets/art/ui/icons/coin.svg"         ## 金钱（营业额/结算资金）
const ICON_CALENDAR := "res://assets/art/ui/icons/calendar.svg" ## 天数
const ICON_TIMER := "res://assets/art/ui/icons/timer.svg"       ## 倒计时
const ICON_CLOSED := "res://assets/art/ui/icons/closed.svg"     ## 打烊
const ICON_GOOD := "res://assets/art/ui/icons/good.svg"         ## 好评
const ICON_BAD := "res://assets/art/ui/icons/bad.svg"           ## 差评
const ICON_CHECK := "res://assets/art/ui/icons/check.svg"       ## 成功（Toast）
const ICON_CROSS := "res://assets/art/ui/icons/cross.svg"       ## 失败（Toast）
const ICON_ORDER := "res://assets/art/ui/icons/order.svg"       ## 新订单（Toast）

## 生成 RichTextLabel 内联图标 BBCode：[img width=h height=h]path[/img]（默认 22px 匹配正文）
static func icon(icon_path: String, size: int = 22) -> String:
	return "[img width=%d height=%d]%s[/img]" % [size, size, icon_path]

## 加载的字体（缓存；null = 加载失败回退系统字体）
var font: Font = null

func _init() -> void:
	_load_font()

func _load_font() -> void:
	if font != null:
		return
	var f := FontFile.new()
	var err := f.load_dynamic_font(FONT_PATH)
	if err == OK:
		font = f
		ThemeDB.fallback_font = f
		ThemeDB.fallback_font_size = FONT_SIZE_BASE
		print_rich("[color=green]UITheme: 中文字体已加载（%s）[/color]" % FONT_PATH)
	else:
		push_warning("UITheme: 字体加载失败（%s, err=%d），回退系统字体" % [FONT_PATH, err])

# ==================== 便捷样式 ====================

## 统一面板样式（半透明深色 + 圆角 + 暖金描边；#32 第③步起主面板改用 make_panel_texture_style 纹理版，
## 本函数保留给需要自定义颜色/小元素（如交互气泡）的场景）
static func make_panel_style(corner_radius: int = 10, bg: Color = COLOR_PANEL, border: Color = COLOR_BORDER) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(corner_radius)
	sb.set_border_width_all(2)
	sb.border_color = border
	return sb

# ==================== 面板纹理（#32 第③步：StyleBoxTexture 九宫格） ====================
const PANEL_TEX_PATH := "res://assets/art/ui/panels/panel_bg.svg"       ## 暖深棕金边圆角
const PANEL_DARK_TEX_PATH := "res://assets/art/ui/panels/panel_dark.svg" ## 深咖啡金边圆角（结算等强调面板）
const PANEL_TEX_MARGIN := 18  ## 九宫格 patch 边距 = 圆角 16 + 金边 3

## 纹理面板样式（九宫格拉伸，角/边不变形）；dark=true 用深咖啡底
static func make_panel_texture_style(dark: bool = false) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	var tex: Texture2D = load(PANEL_DARK_TEX_PATH if dark else PANEL_TEX_PATH)
	if tex != null:
		sb.texture = tex
	sb.texture_margin_left = PANEL_TEX_MARGIN
	sb.texture_margin_right = PANEL_TEX_MARGIN
	sb.texture_margin_top = PANEL_TEX_MARGIN
	sb.texture_margin_bottom = PANEL_TEX_MARGIN
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb

## 金色按钮样式（normal/hover/pressed 三态）
static func make_button_styles() -> Dictionary:
	var normal := StyleBoxFlat.new()
	normal.bg_color = COLOR_GOLD_DARK
	normal.set_corner_radius_all(10)
	normal.set_content_margin_all(10)
	var hover := StyleBoxFlat.new()
	hover.bg_color = COLOR_GOLD
	hover.set_corner_radius_all(10)
	hover.set_content_margin_all(10)
	var pressed := StyleBoxFlat.new()
	pressed.bg_color = COLOR_GOLD_DARKER
	pressed.set_corner_radius_all(10)
	pressed.set_content_margin_all(10)
	return {"normal": normal, "hover": hover, "pressed": pressed}
