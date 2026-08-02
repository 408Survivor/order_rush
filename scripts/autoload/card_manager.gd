## 文件: scripts/autoload/card_manager.gd
## 职责: 卡牌系统（P6）——口碑抽卡（3 选 1）+ 构筑（当日生效的 Modifier 叠加）→ 流派构筑
## 依赖: GameStateManager (autoload，口碑=累计好评数)；无持久化（每日打烊重置，随 roguelike 每轮重抽）
## 注意: 卡牌效果通过 get_value/get_multiplier/has_flag 查询，各系统（价格/耐心/ETA/加热/顾客/房租/罚款/利润）接入

@tool
extends Node

const REPUTATION_COST_PER_DRAW := 3  ## 抽卡消耗口碑（= 累计好评数）

## 卡牌定义（id → 名称/描述/效果字段；效果字段三类：数值累加 value / 乘数 multiplier / 标记 flag）
const CARDS := {
	"premium_price": {"name": "招牌溢价", "desc": "菜品价格 +30%", "price_modifier": 0.30},
	"double_review": {"name": "会员日", "desc": "每单好评 +2", "double_review": true},
	"patient_guests": {"name": "慢工出细活", "desc": "顾客耐心 +15s", "patience_bonus": 15.0},
	"fast_rider": {"name": "闪送合作", "desc": "外卖 ETA +15s", "takeout_eta_bonus": 15.0},
	"industrial_oven": {"name": "工业烤箱", "desc": "加热速度 +25%", "heat_multiplier": 0.75},
	"traffic_peak": {"name": "客流高峰", "desc": "顾客生成间隔 -25%", "spawn_multiplier": 0.75},
	"rent_waiver": {"name": "房东豁免", "desc": "房租减半", "rent_multiplier": 0.5},
	"platform_subsidy": {"name": "平台补贴", "desc": "外卖额外 +5/单", "takeout_extra": 5},
	"penalty_waiver": {"name": "员工关怀", "desc": "外卖超时罚款减半", "penalty_multiplier": 0.5},
	"profit_bonus": {"name": "口碑营销", "desc": "打烊利润 +10%", "profit_multiplier": 1.10},
}

## 当前构筑（当日生效的卡牌 id 列表；打烊时重置，每日重新抽卡）
var active_cards: Array[String] = []

signal cards_changed        ## 构筑变化（抽卡/重置）
signal reputation_changed   ## 口碑变化（抽卡消耗后 UI 刷新）

func _ready() -> void:
	pass  # 无持久化需求

# ==================== 口碑 ====================

## 当前口碑 = 累计好评数（P6 规则：好评即口碑）
func get_reputation() -> int:
	return GameStateManager.good_reviews

# ==================== 构筑与数值查询 ====================

## 当前构筑是否持有某张卡
func has(card_id: String) -> bool:
	return card_id in active_cards

## 数值叠加查询（如 price_modifier 0.3 → 持有即返回累加值）
func get_value(effect_key: String, default_value: float = 0.0) -> float:
	var total := default_value
	for card_id in active_cards:
		if CARDS[card_id].has(effect_key):
			total += CARDS[card_id][effect_key]
	return total

## 乘数查询（多卡相乘，如 rent_multiplier；无卡返回 1.0）
func get_multiplier(effect_key: String) -> float:
	var result := 1.0
	for card_id in active_cards:
		if CARDS[card_id].has(effect_key):
			result *= CARDS[card_id][effect_key]
	return result

## 标记查询（如 double_review；任一持有返回 true）
func has_flag(effect_key: String) -> bool:
	for card_id in active_cards:
		if CARDS[card_id].get(effect_key, false):
			return true
	return false

# ==================== 抽卡 ====================

## 生成 3 张候选（从持有外的卡池随机抽 3）
func draw_offer() -> Array[String]:
	var pool: Array[String] = []
	for card_id: String in CARDS:
		if card_id not in active_cards:
			pool.append(card_id)
	pool.shuffle()
	return pool.slice(0, 3)

## 选择一张卡入构筑：消耗口碑 + 入构筑 + 发信号
## 输出: bool（成功）
func pick_card(card_id: String) -> bool:
	if card_id in active_cards:
		return false
	if not CARDS.has(card_id):
		return false
	if GameStateManager.good_reviews < REPUTATION_COST_PER_DRAW:
		return false
	GameStateManager.good_reviews -= REPUTATION_COST_PER_DRAW
	active_cards.append(card_id)
	cards_changed.emit()
	reputation_changed.emit()
	print_rich("[color=green]Card picked: %s（构筑 %d 张）[/color]" % [CARDS[card_id]["name"], active_cards.size()])
	return true

## 打烊清空构筑（每日重新抽卡，流派构筑按天重置）
func reset_cards() -> void:
	if active_cards.is_empty():
		return
	active_cards.clear()
	cards_changed.emit()
