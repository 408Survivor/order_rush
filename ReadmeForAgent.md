# 爆单时刻 (Order Rush) — Agent 快速上下文

> **本文件由开发者每次会话结束时发起，由 Kimi 更新。**
> **新会话开始时，请优先阅读此文件，以快速加载项目上下文。**
> 最后更新：2026-07-08（Session 2 收工）

---

## 1. 项目概述（一句话）

**爆单时刻 (Order Rush)**：2D 俯视角预制菜小餐馆经营模拟游戏，融合《飞机大厨》的高频操作爽感与《杯杯倒满的》PC 键盘经营深度。Godot 4.x + GDScript。

---

## 2. 当前阶段与进度

| Phase | 名称 | 状态 | 进度 | 关键里程碑 |
|-------|------|------|------|------------|
| P0 | 🎨 美术风格锁定 | ✅ 完成 | **100%** | 6/6 核心素材已生成（1张占位需后续重生成） |
| P1 | 🎮 核心循环 | 🔒 锁定 | 0% | 等待 P0 完成 |
| P2-P9 | 后续阶段 | 🔒 锁定 | 0% | 见开发手册 |

**P0 目标**：生成 6 张核心素材 → 导入 Godot → 测试显示 → Git commit

---

## 3. 已生成素材（P0 最小清单）

| 素材 | 文件名 | 状态 | 路径 |
|------|--------|------|------|
| 玩家厨师（俯视角） | `player_chef_idle.png` | ✅ | `assets/art/characters/` |
| 顾客（俯视角） | `customer_office_waiting.png` | ✅ | `assets/art/characters/` |
| 微波炉 | `microwave_idle.png` | ✅（占位版，需重生成） | `assets/art/items/` |
| 料理包 | `meal_kungpao.png` | ✅ | `assets/art/items/` |
| 成品菜 | `dish_kungpao_plated.png` | ✅（透明背景+蒸汽） | `assets/art/items/` |
| 地板 Tile | `floor_tile.png` | ✅ | `assets/art/environment/` |

**AI 生成工具**：即梦 5.0 Lite（已锁定风格）
**有效提示词结构**：`Overhead view, bird eye view from directly above, [主体描述], [统一风格后缀]`

---

## 4. 待办事项（Next）

| 优先级 | 任务 | 批次 | 状态 |
|--------|------|------|------|
| P0 | 生成微波炉俯视角（占位版） | 004 | ✅ 完成（v2选中，需后续重生成） |
| P0 | 生成料理包 | 005 | ✅ 完成（v2选中，无文字空白标签） |
| P0 | 生成成品菜 | 006 | ✅ 完成（v2选中，透明背景+蒸汽） |
| P0 | 生成地板 Tile | 007 | ✅ 完成（v4选中，十字勾缝适合拼接） |
| P0 | 导入 Godot，设置 Filter: Nearest | — | ⏳ 下一步：统一导入测试 |
| P0 | Git commit: `p0: art style baseline` | — | ⏳ 导入测试通过后执行 |
|--------|------|------|------|
| P0 | 生成微波炉俯视角 | 004 | ⏳ 待执行 |
| P0 | 生成料理包 | 005 | ⏳ 待执行 |
| P0 | 生成成品菜 | 006 | ✅ 完成（v2选中，透明背景+蒸汽） |
| P0 | 生成地板 Tile | 007 | ✅ 完成（v4选中，十字勾缝适合拼接） |
| P0 | 导入 Godot，设置 Filter: Nearest | — | ⏳ 下一步：统一导入测试 |
| P0 | Git commit: `p0: art style baseline` | — | ⏳ 导入测试通过后执行 |

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
- 场景：PascalCase (`Microwave.tscn`)
- 脚本：snake_case (`microwave.gd`)
- 变量/函数：snake_case
- 常量：UPPER_SNAKE_CASE
- 信号：`order_completed`, `item_picked_up`
- 文件：snake_case (`player_chef_idle.png`)

### 生成存档结构（每次生成一个批次）
```
archive/generations/001-chef_front_view/
├── 001.txt          # 平台/参数/提示词/经验记录
├── xxx_v1.png
└── xxx_v2.png
```

---

## 6. 上次会话关键决策与发现

**2026-07-08 Session 2**

| 发现 | 详情 |
|------|------|
| ✅ Phase 0 全部 6 张素材已生成 | 002-007 批次完成，全部放入 assets/ |
| ✅ 透明背景在提示词中加入"透明背景"后生效 | 006 成品菜、007 地板 Tile 成功 |
| ⚠️ 即梦精简提示词（移除否定词）有效 | v3 提示词版本通过平台规则验证 |
| ⚠️ 微波炉需后续重生成 | 004 批次透视偏正面，非严格俯视角 |

**已生成批次**：
- 001：厨师正面立绘（2张，UI备用）
- 002：厨师俯视角（4张，v1选中为 `player_chef_idle.png`）
- 003：顾客俯视角（4张，v1选中为 `customer_office_waiting.png`）
- 004：微波炉占位版（4张，v2选中，需后续重生成）
- 005：料理包（4张，v2选中为 `meal_kungpao.png`）
- 006：成品菜装盘（4张，v2选中为 `dish_kungpao_plated.png`，透明背景+蒸汽）
- 007：地板 Tile（4张，v4选中为 `floor_tile.png`）

---
## 7. 快速导航（文档索引）

| 文档 | 路径 | 用途 |
|------|------|------|
| 开发手册 | `docs/开发手册_v1.0.md` | 技术规范、代码框架、Git规范 |
| AI提示词库 | `docs/prompts/AI美术提示词库_v1.0.md` | 所有素材的生成提示词 |
| 进度看板 | `docs/进度看板.md` | 实时进度追踪 |
| 汇报模板 | `docs/进度汇报模板.md` | 向 Kimi 汇报的格式 |
| 可视化看板 | `Lookme.html` | 浏览器打开的可视化进度 |
| 给人看的README | `README.md` | 项目总览、目录结构 |

---

## 8. 给 Kimi 的启动指令（复制用）

新会话开始时，请执行以下动作：
1. 阅读本文件（`ReadmeForAgent.md`）
2. 阅读 `docs/进度看板.md` 了解最新状态
3. 根据"待办事项（Next）"继续推进任务
4. 如有需要，阅读 `docs/开发手册_v1.0.md` 获取技术规范

---

> **提示**：开发者每次会话结束时说"同步到文件"，请更新此文件和 `docs/进度看板.md`。开发者每次说"开始今天的开发"，请从此文件加载上下文。
