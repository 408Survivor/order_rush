# 爆单时刻 (Order Rush) — Agent 快速上下文

> **本文件由开发者每次会话结束时发起，由 Kimi 更新。**
> **新会话开始时，请优先阅读此文件，以快速加载项目上下文。**
> 最后更新：2026-08-04（Session 11：UI 观感翻新 #48 合并；P9 内容随 #49 一并合入 main；下一步：开发者 F5 实测新 UI / P7 二期 L2/L3）

---

## 1. 项目概述（一句话）

**爆单时刻 (Order Rush)**：2D 俯视角预制菜小餐馆经营模拟游戏，融合《飞机大厨》的高频操作爽感与《杯杯倒满的》PC 键盘经营深度。Godot 4.x + GDScript。

**仓库**：https://github.com/408Survivor/order_rush （私有，SSH: `git@github.com:408Survivor/order_rush.git`）

---

## 2. 当前阶段与进度

| Phase | 名称 | 状态 | 关键里程碑 |
|-------|------|------|------------|
| P0 | 🎨 美术风格锁定 | ✅ 完成 | 6/6 核心素材已生成（微波炉为占位版，见 issue #1）；素材已去白底转透明 |
| P1 | 🎮 核心循环 | ✅ **完成** | 移动+交互+顾客+布局+订单循环（#4）全通；P1 收口（调试面板/tag 待补） |
| P2 | 📋 订单系统 | ✅ **完成** | 订单队列（3 单并发）+耐心值+完成/超时/差评（#20）；中途放下（#22）；布局重构（#24） |
| P3 | 💰 经济系统 | ✅ **完成** | 收入/成本/日结算/进入下一天（#28）；UI 风格升级（#32：暖色板/图标集/面板纹理/版式） |
| P4 | 🛵 外卖系统 | ✅ **完成** | 外卖订单+骑手 ETA+四色时间裕度+打包流程+超时罚款（#34）；骑手素材为占位待替换 |
| P5 | ⚙️ 设备升级 | ✅ **完成** | 升级商店+第二微波炉+加热加速+冰柜扩容+JSON 存档（#36） |
| P6 | 🃏 卡牌系统 | ✅ **完成** | 口碑抽卡 3 选 1 + 10 卡 Modifier 流派构筑（#38） |
| P7 | 🍲 多菜品+难度 | ✅ **一期完成** | 3 种 L1 菜品/招牌菜熟练度/7 天难度/特殊事件（#40）；二期 L2 炒锅/L3 现做 |
| P8 | 👤 角色系统 | ✅ **完成** | 角色选择界面 + 主厨/快手主厨（加热 ×0.85）+ JSON 存档（#44） |
| P9 | ✨ Polish | ✅ **完成** | 程序化音效×12/audio_manager/粒子反馈/按钮动画/itch 配置（#46，内容随 PR #49 合入） |
| — | 🎨 UI 观感翻新 | ✅ **完成** | 9 面板 tscn 化 + 贴纸图标/立体按钮/纹理进度条/订单卡重设计（#48，PR #49）；冒烟 229 断言 |

---

## 3. 开发工作流（issue/PR 驱动，2026-07-22 启用）

1. **所有任务先进 GitHub Issues**（目标 / 验收标准 / 上下文 三段式，模板已配）
2. **所有改动走分支 + PR**，不直接推 main；commit 关联 issue 号（如 `(#2)`）
3. PR 描述写 `Closes #N`，合并后 issue 自动关闭
4. 分支命名：`类型/issue号-简述`，如 `feature/2-interact-pickup`

**当前任务看板 → GitHub Issues**（不再在本文件手维护待办状态）：

| Issue | 任务 | 依赖 |
|-------|------|-------|
| #1 | [P0 收尾] 微波炉俯视角素材重生成 | 无，不阻塞 |
| #2 | [P1] 交互系统：E 键拾取/放置物品 | ✅ 已完成（PR #7） |
| #3 | [P1] 顾客系统：生成与排队逻辑 | ✅ 已完成（PR #8） |
| #4 | [P1] 订单循环最小闭环（P1 收口） | ✅ 已完成（PR #13） |
| #9 | [P1] 店内布局四区划分 | ✅ 已完成（PR #10） |
| #11 | [P0 收尾] 素材去底（白底→透明） | ✅ 已完成（PR #12） |
| #16 | [P1] 布局重画（素材缩小+空间重排） | ✅ 已完成（PR #17） |
| #18 | [P1] 交互范围优化（身前扇区 ±45°） | ✅ 已完成（PR #19） |
| #20 | [P2] 订单系统：订单队列/耐心值/超时差评 | ✅ 已完成（PR #21） |
| #22 | [P2 补充] 中途放下：Q 键手持物品放回场景 | ✅ 已完成（PR #23） |
| #24 | [P2 收尾] 布局重构：1920x1080 + LayoutManager 可扩展布局 | ✅ 已完成（PR #25） |
| #26 | [P2 收尾] 界面优化：订单面板/HUD 整合/Toast 反馈/风格统一 | ✅ 已完成（PR #27） |
| #28 | [P3] 经济系统：收入/成本/日结算/进入下一天 | ✅ 已完成（PR #29） |
| #30 | [P3 收尾] UI 全面升级：中文字体/调色板/图标化/动画反馈 | ✅ 已完成（PR #31） |
| — | [P3 收尾] UI 风格升级：暖色板统一 + 图标集 + 面板纹理 + 版式（#32，发行级观感） | ✅ 已完成（PR #33） |
| #34 | [P4] 外卖系统：外卖订单 + 骑手 ETA + 时间裕度 + 打包流程 | ✅ 已完成（PR #35） |
| #36 | [P5] 设备升级：升级商店 + 第二微波炉 + 加热加速 + 冰柜扩容 + JSON 存档 | ✅ 已完成（PR #37） |
| #38 | [P6] 卡牌系统：口碑抽卡 + 3 选 1 + Modifier 流派构筑（10 张卡） | ✅ 已完成（PR #39） |
| #40 | [P7 一期] 多菜品+难度：3 种 L1 菜品/招牌菜/7 天难度/特殊事件 | ✅ 已完成（PR #41） |
| #42 | [风格] 浅色主题：杯杯倒满式奶油白底 + 糖果色 + 贴纸图标 | ✅ 已完成（PR #43） |
| #44 | [P8] 角色系统：角色选择界面 + 2 角色 + 技能生效 + 存档 | ✅ 已完成（PR #45） |
| #46 | [P9] Polish：程序化音效 + 音频系统 + 粒子 + UI 动画 + itch 配置 | ✅ 已完成（原 PR #47 分支被 #48 作基点，内容随 PR #49 squash 一并合入；#47 已关闭） |
| #48 | [风格] UI 观感翻新：9 面板 tscn 化 + 图标/按钮/进度条/卡片重设计 | ✅ 已完成（PR #49） |
| — | [反馈层] 世界坐标飘字（+20/差评）/金币飞行动画/结算 count-up | 待办（可开 issue，并入后续 Polish） |
| — | [P7 二期] L2 炒锅 / L3 现做流程（2 L2 + 1 L3） | 待办（可开 issue） |

---

## 4. 已生成素材（P0 最小清单）

| 素材 | 文件名 | 状态 | 路径 |
|------|--------|------|------|
| 玩家厨师（俯视角） | `player_chef_idle.png` | ✅ 透明背景 | `assets/art/characters/` |
| 顾客（俯视角） | `customer_office_waiting.png` | ✅ 透明背景 | `assets/art/characters/` |
| 微波炉 | `microwave_idle.png` | ⚠️ 占位版（issue #1），已去底 | `assets/art/items/` |
| 料理包 | `meal_kungpao.png` | ✅ 透明背景（P7 多菜品用色调占位区分） | `assets/art/items/` |
| 成品菜 | `dish_kungpao_plated.png` | ✅ 透明背景（GrabCut 去底；P7 同上占位） | `assets/art/items/` |
| 地板 Tile | `floor_tile.png` | ✅ 满铺贴图不处理 | `assets/art/environment/` |
| **UI 图标 ×10（彩色贴纸风）** | `plate/coin/calendar/timer/closed/good/bad/check/cross/order.svg` | ✅ SVG 手绘（#42 浅色主题重画；AI 通道存档 011） | `assets/art/ui/icons/` |
| **UI 面板纹理 ×2（浅色）** | `panel_bg.svg`（奶油白）/ `panel_dark.svg`（奶黄金边） | ✅ SVG 手绘（#42 重画；AI 通道存档 012） | `assets/art/ui/panels/` |
| 中文字体 | `ZCOOLKuaiLe-Regular.ttf` | ✅ 站酷快乐体（SIL OFL） | `assets/fonts/` |

**视觉占位待替换**：骑手（复用顾客素材+蓝色调）、多菜品料理包/成品菜（色调区分）、微波炉（issue #1）

**AI 生成工具**：即梦 5.0 Lite（已锁定风格）
**有效提示词结构**：`Overhead view, bird eye view from directly above, [主体描述], [统一风格后缀]`

---

## 5. 关键规范（不可变）

### 项目目录结构（强制执行）
```
order_rush/
├── assets/art/      # 图片（characters/ items/ environment/ ui/）
├── assets/audio/    # 音频（bgm/ sfx/ ambience/）
├── scenes/          # .tscn 场景文件
├── scripts/         # .gd 脚本文件
├── archive/         # 开发存档（generations/ 按批次编号）
├── docs/            # 文档（开发手册/提示词库/进度看板/汇报模板）
├── resources/       # .tres 数据资源
└── README.md        # 给人看的项目总览
```

### 命名规范
- 场景：PascalCase (`Microwave.tscn`)；脚本/变量/函数：snake_case；常量：UPPER_SNAKE_CASE
- 信号：`order_completed`, `item_picked_up`；文件：snake_case (`player_chef_idle.png`)

### 生成存档结构（每次生成一个批次）
```
archive/generations/001-chef_front_view/
├── 001.txt          # 平台/参数/提示词/经验记录
└── xxx_v1.png ...
```

---

## 6. 历次会话关键决策与发现

**2026-08-04 Session 11（UI 观感翻新 #48 + P9 合入厘清）**

| 事件 | 详情 |
|------|------|
| ✅ issue #48 UI 观感翻新（PR #49） | **9 面板全部 tscn 化**（`scenes/ui/`：RevenueHUD/OrderBoard/OrderCard/TakeawayBoard/ToastManager/DayResultPanel/UpgradeShop/CardDraw/SpecialtyPanel/CharacterSelect），静态结构进场景、脚本只留动态逻辑（@onready 绑定，变量名/方法签名/文本格式全兼容）；**视觉资源**：panel_bg/panel_dark 重绘多层（高光+内阴影+四角金点）+ 新增 panel_card/btn 立体三态/bar 轨道+四色高光填充；**新图标**：菜品×3（dish_kungpao/yuxiang/mapo）+ 耐心表情×3（mood_happy/neutral/angry）+ pack；**修复原 10 图标只画在 viewBox 左上 1/4 的偏心 bug**（全部重绘居中加粗）；**UITheme 新 API**：`dish_icon_path`/`mood_icon_path`/`make_card_style`/`make_button_texture_styles`/`make_bar_bg_style`/`make_bar_fill_style`；**HUD**：新增营业时间进度条 TimeBar（绿→红）+ 营业额收钱弹跳；**订单卡重设计**：菜品大图标 + 纹理耐心条 + 表情随耐心切换（>50%/>20%/≤20%）+ 低耐心红色脉冲；main_scene.gd 5 处 `SCRIPT.new()` → tscn `instantiate()`；冒烟 **229 断言**（+7 条 #48 断言）PASS |
| ⚠️ P9 合入路径厘清 | Session 10.5 的 P9 工作（PR #47，分支 feature/46-polish-audio，commit 8c54e2b）**未合入 main**，而 #48 分支以 8c54e2b 为基点 → PR #49 squash 时 P9 全部内容一并进入 main。处理：PR #47 关闭删分支 + issue #46 关闭（均已留言说明）。**教训：开新分支前先确认基点 commit 已在 origin/main** |
| 💡 `--quit-after N` 是帧数不是秒 | 900 帧≈15s 导致冒烟跑一半被终止（无 RESULT 输出，易误判崩溃）；冒烟用 `--quit-after 12000`（插件自身 quit 先触发，约 80s 跑完） |
| 💡 新 SVG 首轮加载失败 | 新资源无 .import 时编辑器首轮 `load()` 报 Failed loading（UITheme null 容错不崩但断言挂）；首轮跑完生成 .import 后第二轮即绿——**新增资源后冒烟跑两轮** |
| 📌 冒烟断言数 | 229（#48 新增 7 条：菜品图标/表情切换/TimeBar/外卖标题/下一天按钮） |

**2026-08-02 Session 10（P3 经济系统 + UI 全面升级合并）**

| 事件 | 详情 |
|------|------|
| ✅ issue #28 P3 经济系统（PR #29） | 收入 = 菜品基础价 20/单（`get_dish_price()`，打包费/平台扣点公式 P4 外卖启用）；成本 = 食材 6/单 + 耗材 2/单 + 水电 1/次加热 + 房租 30/天（常量集中可调）；营业倒计时 **90s/天**（`tick_business_time` 驱动，与 `tick_patience` 同模式，编辑器进程拦截自动 tick）；`close_shop()` 打烊结算：作废未完成订单 → 利润 = 收入 − 成本 → 并入累计金币 → 发 `shop_closed`（含完整结算结果）；`start_next_day()`：天数 +1、当日统计清零、累计 revenue/评分/金币跨天保留 |
| ✅ 日结算面板（新 `scripts/ui/day_result_panel.gd`） | 打烊自动弹出并暂停游戏：收入 / 成本明细（食材/耗材/水电/房租）/ 利润红绿 / 当日评分 / 累计金币 + 「进入下一天」按钮（恢复暂停→推进天数→隐藏）；日循环清场：顾客移除、订单面板刷新、手持/微波炉内/散落物品清理、料理包重建复位、玩家复位出生点 |
| ✅ issue #30 UI 全面升级（PR #31） | **站酷快乐体**（ZCOOL KuaiLe，SIL OFL 1.1 开源可商用）经 `ThemeDB.fallback_font` 全局生效，`load_dynamic_font` 加载不依赖 import；新 `scripts/autoload/ui_theme.gd` 统一调色板（11 色）+ 面板/按钮样式取代硬编码；经营面板图标化（🗓️⏱️💰👍👎）+ 营业额滚动动画 + 倒计时最后 10s 红色脉冲；订单面板卡片质感（金色描边）+ 圆角 ProgressBar 耐心条 + 弹入/淡出动画；Toast 左侧类型色带 + 图标（✅❌📋）；**结算面板弹出动画修复打烊暂停下动画冻结（process_mode=ALWAYS）**；场景内：顾客头顶 🍛 标记三色、微波炉进度条（加热黄/完成红/空闲绿）、交互提示气泡化 |
| ⚠️ P3 收尾待办 | 打烊暂停/结算面板弹出/「进入下一天」按钮流转的**运行模式实测未做**（编辑器进程不验证暂停路径）→ 下次会话开发者 F5 实测后再开 P4 |
| ✅ issue #32 UI 风格升级（PR #33） | **发行级观感三步**：① 暖色板（深蓝灰→暖木×奶油×金，`ui_theme.gd` 11 色，与暖亮场景同色温）② 图标集（10 个金描边 SVG 替换全部 emoji，`UITheme.icon()` 生成 `[img]` BBCode，RichTextLabel 内联，代码零 emoji 残留；AI 通道存档 011）③ 面板纹理+版式（`StyleBoxTexture` 九宫格金边圆角，结算面板分区+标题金线装饰+成本内嵌区块、经营面板拆行 DayTimeLabel/TimeLabel、倒计时脉冲移至 TimeLabel；AI 通道存档 012）；冒烟 128 断言 PASS |
| ✅ issue #34 P4 外卖系统（PR #35） | **外卖独立队列**（与堂食并行，上限 3 单，25s 定时生成）+ **骑手 ETA 40s** + **时间裕度四色**（红黄绿蓝：>75% 蓝/>50% 绿/>25% 黄/≤25% 红）；**打包流程**：成品菜→外卖口（`PICKUP_POINT 260,520`）按 E 打包→骑手取餐（ETA 归零结算）；未打包超时→**罚款 5 计入成本**（结算面板新增"超时罚款"行）+差评；定价 `get_dish_price(is_takeout)`：外卖 = 20+2 打包费+3 平台补贴−2 扣点 = **23**（比堂食高但有时间压力）；外卖面板（右侧：ETA 进度条四色+待打包/已打包）；骑手视觉复用顾客素材+蓝色调（占位，后续 AI 生成）；冒烟 145 断言 PASS |
| ✅ issue #36 P5 设备升级（PR #37） | 新 autoload `upgrade_manager.gd`：三档升级状态 + `UPGRADES` 常量定义 + `buy_upgrade`（扣钱/应用/存档/`upgrades_changed` 信号）+ **JSON 存档 `user://save_p5.json`**（启动加载/购买保存，写失败仅告警）；**升级商店**（`upgrade_shop.gd`）：日结算面板"升级设备"次按钮打开（暂停中可交互），3 项——第二微波炉 80（`MICROWAVE_SLOTS[1]` 实例化）/ 加热加速 50（3.0s→2.2s 即时生效）/ 冰柜扩容 60（料理包 3→5，`_get_meal_names()` 首包名保持 "MealPackage" 兼容）；金币不足置灰/已购防重复；冒烟 159 断言 PASS |
| 💡 squash 合并链冲突处理 | 分支 B 基于分支 A 开发，A 被 squash 合并后，B 上原 A 的提交与新 main **内容相同但 hash 不同** → gh 报 not mergeable；解决：`git rebase origin/main`（自动 skip 重复提交）→ `git push --force-with-lease` → 等 GitHub 冲突检测刷新（UNKNOWN→CLEAN）→ 再合并 |
| 📌 经济数值（当前） | 宫保鸡丁 20 / 食材 6 / 耗材 2 / 房租 30 / 水电 1 / 营业 90s；全部常量集中在 `GameStateManager.gd`，可调 |
| ✅ issue #38 P6 卡牌系统（PR #39） | 新 autoload `card_manager.gd`：**10 张卡** + Modifier 三查接口（`get_value` 累加/`get_multiplier` 连乘/`has_flag` 标记）；**口碑抽卡**（3 选 1，消耗 3 口碑，口碑 = 累计好评）；效果覆盖价格/好评/耐心/ETA/加热/客流/房租/补贴/罚款/利润；抽卡面板（`card_draw.gd`，日结算"口碑抽卡"入口，暂停中可交互）；打烊结算后重置构筑（**先定格结算数据再清卡**——初版顺序导致 cost_rent 断言 FAIL 已修）；冒烟 189 断言 |
| ✅ issue #40 P7 多菜品+难度（PR #41） | `DISHES` **3 种 L1**（宫保鸡丁 20/鱼香肉丝 22/麻婆豆腐 18）+ 堂食/外卖**随机点菜**（`_dish_override` 测试钩子保既有断言确定性）+ 料理包/成品菜 dish_type 驱动（占位色调）+ **招牌菜**（+20% 基础 + 熟练度 3 次/档 +10% 上限 3 档，`specialty_panel.gd` 选择）+ **7 天难度表**（顾客间隔/耐心/ETA 逐天递减，第 7 天封顶）+ **特殊事件**（设备故障停微波炉 8s/恶劣天气停外卖 15s，`tick_event` 随机触发 + Toast）；L2 炒锅/L3 现做二期；冒烟 206 断言 |
| ✅ issue #42 浅色主题（PR #43） | **杯杯倒满式风格改造**：色板深暖棕→**奶油白 `#FFF6E5`** + 深咖啡字 `#4A3728`（浅底深字）+ **糖果色点缀**（珊瑚粉/薄荷绿/奶黄/天蓝）+ `COLOR_OUTLINE` 深棕描边；面板纹理重画浅色（强调面板奶黄底金边）；**10 图标金线稿→彩色贴纸风**（彩色填充+深棕描边+奶油白细节）；各面板/按钮/进度条/场景文字浅色适配；冒烟 206 断言 |
| 🔍 风格调研（杯杯倒满 Feed The Cups） | Steam app 2336220、Vambear Games（台湾 2 人团队）、**Godot 3.6.1**、**2D 正俯视卡通**（非像素）；浅色明亮（奶油白底+高饱和糖果色）、Q 版 2~2.5 头身、贴纸式图标、气泡对话框、0.1-0.2s 弹跳动画、软萌吐槽文案——作为 #42 改造依据 |

**2026-08-01 Session 9（界面优化）**

| 事件 | 详情 |
|------|------|
| ✅ issue #26 界面优化（PR #27） | 订单队列面板（顶部卡片：菜品+耐心进度条绿→黄→红+秒数，随订单实时增删）；经营面板 HUD 整合（右上圆角面板：营业额/好评/差评）；Toast 反馈（左下：新订单/交付成功+20/超时差评，自动淡出）；风格统一（半透明深色圆角面板+文字描边） |
| 💡 UI 脚本统一 @tool | 冒烟测试在编辑器进程 call 非 @tool 脚本方法会报 "placeholder instance" → 全部 UI 脚本加 @tool + `is_editor_hint()` 拦截信号连接（测试手动触发断言） |
| 💡 Toast 信号连接防重 | 匿名 lambda 无法 is_connected 判重 → 改命名方法 + is_connected（热重载会重复 _ready）；淡出前 is_instance_valid 防御超限提前释放 |
| 📌 新增 UI 文件 | `scripts/ui/order_board.gd`（订单面板）、`scripts/ui/toast_manager.gd`（Toast）；MainScene 节点：OrderBoard/ToastManager + RevenueHUD 改造为 Panel>Margin>VBox 结构 |

**2026-08-01 Session 8（P2 订单系统完成）**

| 事件 | 详情 |
|------|------|
| ✅ issue #20 P2 订单系统（PR #21） | **3 单并发**订单队列（每位顾客到达槽位即下单）；耐心值由 GameStateManager 驱动（tick_patience，30s）；完成→好评+1/营业额+20，超时→差评+1/顾客离店补位；评分 HUD；交付任意有单顾客（不强制队首，校验 dish_type）；顾客头顶实时显示菜品+剩余秒数（绿→黄→红） |
| ✅ issue #22 中途放下（PR #23） | Q 键放下手持物品到身前 50px，挂回 Items 容器、恢复碰撞（layer=8）可再拾取；提示 UI 手持面对空处显示 [Q] 放下 |
| ✅ issue #24 布局重构（PR #25） | **LayoutManager autoload 单一权威配置**：世界 1920x1080、四区矩形、关键点位、设备/货架/餐桌槽位；main_scene.gd 按配置动态生成区域色块/标签/餐桌并摆位；相机锁定场景级（整店可见）；预留微波炉×2/冰柜/料理包×6/餐桌×4/外卖口/队列 5 人 |
| 💡 编辑器进程物理不步进（延续） | 物品 remove_child→add_child 重挂后需等一帧（process_frame）才被物理服务器注册，射线查询才命中——放下测试必须 await 一帧 |
| 💡 动态调用返回值 | `var x := obj.call("method")` / 动态 get_node 方法返回值是 Variant，`:=` 无法推断 → 需显式类型标注（`var x: int = ...`） |
| 💡 顾客行走距离随布局变 | 入口→柜台 1270px / 160 ≈ 7.9s（旧布局 640px≈4s）；测试时序按距离重算（8.5s/7.5s/6.0s 节奏） |
| 💡 main_scene 动态生成幂等 | @tool 场景动态生成节点必须 has_node 防护（编辑器热重载会重复 _ready） |
| 📌 布局坐标（当前） | 世界 (1920,1080)；柜台 (1350,520)、入口 (80,520)、玩家 (960,260)、微波炉 (1700,180)、料理包 MEAL_SLOTS 前 3 位、餐桌 TABLE_SLOTS 4 张（(450,800) 起间距 350）、队列间距 200（玩法 max_queue=3，空间预留 5 人）、外卖口 (260,520) P4、冰柜 (360,240) P5、微波炉槽位 2 (1440,180) P5。**全部坐标见 `scripts/autoload/layout_manager.gd`，改布局只动这一处** |

**2026-08-01 Session 7（P1 核心循环完成）**

| 事件 | 详情 |
|------|------|
| ✅ issue #4 订单循环（PR #13） | 下单→加热→交付→结算→补位 全通；微波炉加热状态机+进度条；顾客收菜离店；营业额 HUD |
| ✅ issue #16 布局重画（PR #17） | 素材 0.2→0.13（视觉 267px）、碰撞按比例缩小、四区重排；**交付提示根因修复**（顾客漏加 interactable 组）；**离店碰撞清零**（防与补位顾客迎面卡死） |
| ✅ issue #18 交互优化（PR #19） | **身前扇区 ±45°** 交互（范围 160px + 方向点积过滤）；微波炉矩形碰撞 250 |
| 💡 交付提示根因 | customer.gd 只加了 customer 组 → is_in_group("interactable") 过滤掉顾客 → 交付从未真正可用（测试直接调方法绕过未发现）；修复后探针实证 |
| 💡 离店卡死根因 | 离店顾客（走向出口）与补位顾客（走向柜台）迎面碰撞 → leave() 时碰撞清零穿人 |
| 💡 编辑器进程物理限制 | RayCast2D/范围检测在编辑器进程不可靠（物理不步进）→ 测试直接调内部方法，物理路径靠运行模式探针验证 |
| 📌 布局坐标（当前） | 玩家 (450,200)、微波炉 (1000,180) 矩形碰撞、料理包×3 仓库区、柜台 (700,400)、入口 (60,400)、间距 150、交互范围 160+扇区 |

**2026-08-01 Session 6**

| 事件 | 详情 |
|------|------|
| ✅ issue #3 顾客系统完成 | 生成（3s 间隔）→ 槽位分配（按在场数，防撞槽）→ 排队 → 队首索引；PR #8 合并，实测通过 |
| ✅ issue #9 店内布局四区 | 厨房上/前台中/就餐下/仓库左上；视觉色块+Label 分区；PR #10 合并 |
| ✅ issue #11 素材去底 | 7 张素材白底→透明：6 张连通域泛洪（阈值 245）+ dish 用 GrabCut（白盘+白背景亮度法失效）；工具存档 `archive/generations/009-bg-removal/`；PR #12 合并 |
| 💡 去底关键经验 | 白主体+白背景：单一阈值不可兼得（盘沿分隔带决定连通性）；GrabCut 矩形必须盖住整个主体（0.02-0.98 版确认完美）；pip 被 TCC 拦截 → `pip3 install --target /tmp/pylibs` |
| 📌 布局坐标备忘 | 玩家 (500,200)、微波炉 (950,200)、料理包×3 (150,150)/(250,150)/(200,250)、柜台 (640,420)、入口 (40,420)、队伍间距 220 向左 |

**2026-08-01 Session 5**

| 事件 | 详情 |
|------|------|
| ✅ issue #2 交互系统完成 | E 键拾取料理包/放入微波炉/取出 + 提示 UI + 信号 `item_picked_up`/`item_placed`；PR #7 已合并；开发者实测通过 |
| ✅ 冒烟测试通道建立 | `addons/smoke_test/`（EditorPlugin，14 项断言）；运行方式：临时在 project.godot 注册 `[editor_plugins] enabled=PackedStringArray("res://addons/smoke_test/plugin.cfg")` → `Godot --path . --editor --quit-after 900` → 看 PASS/FAIL → 移除注册。**插件注册路径必须写 plugin.cfg 完整路径** |
| ✅ Godot 版本切换 **4.6.3** | `/Applications/Godot.app` 已替换为 4.6.3（开发+验证统一）。4.7.x 崩溃根因：macOS 26 TCC 拦截 Godot 写 `~/Library/Application Support`（日志初始化崩），非代码问题 |
| ⚠️ 启动方式强制 **Finder 双击** | 终端命令行启动 Godot 无 TCC 权限会崩；已授权 Godot.app 完全磁盘访问，双击/F5 正常。`open -a Godot --args ...`（LaunchServices）也可 |
| ✅ 项目基线标记 | `project.godot` `config/features` 已更新为 `"4.6"` |
| ✅ gh CLI 接入 | `408Survivor` 账号已认证（SSH 协议，scope 含 repo）；开 PR：`gh pr create`，合并：`gh pr merge N --squash --delete-branch` |
| ✅ 脚本 @tool 约定 | 游戏脚本统一加 `@tool` + `Engine.is_editor_hint()` 防护（编辑器进程可实例化真实脚本，测试可跑；对游戏运行无副作用） |
| ⚠️ headless 不可用 | `--headless` 在 macOS 26 全部崩溃；自动化验证一律走编辑器模式 |

**2026-07-22 Session 4**

| 事件 | 详情 |
|------|------|
| ✅ 项目上线 GitHub | 私有仓 `408Survivor/order_rush`，main 已推送（5 commits） |
| ⚠️ 历史提交邮箱已重写 | 真实 Gmail 触发 GitHub 隐私保护 → 全部重写为 `408Survivor <64139558+408Survivor@users.noreply.github.com>`，代码内容未变 |
| ✅ 启用 issue/PR 驱动流程 | 建 issue #1-#4，PR #5（issue 模板）待合并；待办状态以后以 GitHub Issues 为准 |

**2026-07-09 Session 3**：P1 开工——初始化 Godot 项目、玩家移动（WASD + 碰撞 + flip_h 翻转，修复了 scale.x 翻转瞬移问题）。

**2026-07-08 Session 2**：P0 全部 6 张素材生成完毕（批次 001-007）；透明背景在提示词加"透明背景"后生效；微波炉 004 批次透视偏正面需重生成（→ issue #1）。

---

## 7. 快速导航（文档索引）

| 文档 | 路径 | 用途 |
|------|------|------|
| 开发手册 | `docs/开发手册_v1.0.md` | 技术规范、代码框架、Git规范 |
| AI提示词库 | `docs/prompts/AI美术提示词库_v1.0.md` | 所有素材的生成提示词 |
| 进度看板 | `docs/进度看板.md` | 实时进度追踪 |
| 汇报模板 | `docs/进度汇报模板.md` | 向 Kimi 汇报的格式 |
| 可视化看板 | `Lookme.html` | 浏览器打开的可视化进度 |
| 任务看板 | GitHub Issues | 待办/状态的唯一权威来源 |

---

## 8. 给 Kimi 的启动指令（会话协议）

- 开发者说 **"开始今天的开发"** → 阅读本文件 → 查看 GitHub Issues 状态 → 从下一个待办 issue 继续
- 开发者说 **"收工"** → 更新本文件和 `docs/进度看板.md`，给一句话总结
- 开发者说 **"开始 issue #N"** → 建分支 → 开发 → commit 关联 #N → 开 PR 附验收自检
- 开发者说 **"这个别忘了：xxx"** → 开 issue 挂上
- 紧急问题说 **"紧急求助"** → 跳过读档直接解决，事后补同步
