# 爆单时刻 (Order Rush) — Agent 快速上下文

> **本文件由开发者每次会话结束时发起，由 Kimi 更新。**
> **新会话开始时，请优先阅读此文件，以快速加载项目上下文。**
> 最后更新：2026-08-01（Session 7：P1 核心循环完成——订单循环+布局重画+交互优化；下一步：P2 订单系统）

---

## 1. 项目概述（一句话）

**爆单时刻 (Order Rush)**：2D 俯视角预制菜小餐馆经营模拟游戏，融合《飞机大厨》的高频操作爽感与《杯杯倒满的》PC 键盘经营深度。Godot 4.x + GDScript。

**仓库**：https://github.com/408Survivor/order_rush （私有，SSH: `git@github.com:408Survivor/order_rush.git`）

---

## 2. 当前阶段与进度

| Phase | 名称 | 状态 | 关键里程碑 |
|-------|------|------|------------|
| P0 | 🎨 美术风格锁定 | ✅ 完成 | 6/6 核心素材已生成（微波炉为占位版，见 issue #1）；素材已去白底转透明 |
| P1 | 🎮 核心循环 | ✅ **完成** | 移动+交互+顾客+布局+**订单循环（#4）** 全通；P1 收口（调试面板/tag 待补） |
| P2 | 📋 订单系统 | 🔄 **下一个** | 订单队列+耐心值+完成/超时/差评（见开发手册） |
| P3-P9 | 后续阶段 | 🔒 锁定 | 见开发手册 |

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
| — | [P2] 订单系统：耐心值/超时/差评 | **下一个开工**（开 issue 挂上） |

---

## 4. 已生成素材（P0 最小清单）

| 素材 | 文件名 | 状态 | 路径 |
|------|--------|------|------|
| 玩家厨师（俯视角） | `player_chef_idle.png` | ✅ 透明背景 | `assets/art/characters/` |
| 顾客（俯视角） | `customer_office_waiting.png` | ✅ 透明背景 | `assets/art/characters/` |
| 微波炉 | `microwave_idle.png` | ⚠️ 占位版（issue #1），已去底 | `assets/art/items/` |
| 料理包 | `meal_kungpao.png` | ✅ 透明背景 | `assets/art/items/` |
| 成品菜 | `dish_kungpao_plated.png` | ✅ 透明背景（GrabCut 去底） | `assets/art/items/` |
| 地板 Tile | `floor_tile.png` | ✅ 满铺贴图不处理 | `assets/art/environment/` |

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
