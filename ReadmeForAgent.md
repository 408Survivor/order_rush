# 爆单时刻 (Order Rush) — Agent 快速上下文

> **本文件由开发者每次会话结束时发起，由 Kimi 更新。**
> **新会话开始时，请优先阅读此文件，以快速加载项目上下文。**
> 最后更新：2026-08-01（Session 5：issue #2 交互系统完成并合并；开发环境切换 Godot 4.6.3）

---

## 1. 项目概述（一句话）

**爆单时刻 (Order Rush)**：2D 俯视角预制菜小餐馆经营模拟游戏，融合《飞机大厨》的高频操作爽感与《杯杯倒满的》PC 键盘经营深度。Godot 4.x + GDScript。

**仓库**：https://github.com/408Survivor/order_rush （私有，SSH: `git@github.com:408Survivor/order_rush.git`）

---

## 2. 当前阶段与进度

| Phase | 名称 | 状态 | 关键里程碑 |
|-------|------|------|------------|
| P0 | 🎨 美术风格锁定 | ✅ 完成 | 6/6 核心素材已生成（微波炉为占位版，见 issue #1） |
| P1 | 🎮 核心循环 | 🔄 开发中 | 项目初始化 + 玩家移动 + **交互系统（issue #2 ✅ 已合并）**；顾客系统（issue #3）下一个开工 |
| P2-P9 | 后续阶段 | 🔒 锁定 | 见开发手册 |

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
| #2 | [P1] 交互系统：E 键拾取/放置物品 | ✅ 已完成（PR #7 合并） |
| #3 | [P1] 顾客系统：生成与排队逻辑 | #2 ✅ 已满足，下一个开工 |
| #4 | [P1] 订单循环最小闭环（P1 收口） | #2 #3 |

---

## 4. 已生成素材（P0 最小清单）

| 素材 | 文件名 | 状态 | 路径 |
|------|--------|------|------|
| 玩家厨师（俯视角） | `player_chef_idle.png` | ✅ | `assets/art/characters/` |
| 顾客（俯视角） | `customer_office_waiting.png` | ✅ | `assets/art/characters/` |
| 微波炉 | `microwave_idle.png` | ⚠️ 占位版（issue #1） | `assets/art/items/` |
| 料理包 | `meal_kungpao.png` | ✅ | `assets/art/items/` |
| 成品菜 | `dish_kungpao_plated.png` | ✅ | `assets/art/items/` |
| 地板 Tile | `floor_tile.png` | ✅ | `assets/art/environment/` |

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
