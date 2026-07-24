# 对话提炼 05：上传项目到 GitHub 私有仓库

> 来源对话：「上传项目到 GitHub 私有仓库」，2026-07-22（Session 4，15:45–16:48）
> 当时工作目录（迁移前旧路径）：`/Users/liutongqing/Downloads/跨设备同步/游戏/爆单时刻`，项目根为其下的 `order_rush/`
> 说明：本稿不含任何密钥/token；对话中通过已授权的 Kimi GitHub 插件（OAuth）操作，凭据未出现在对话文本中。

---

## 1. Git 与 GitHub 相关信息

### 仓库与账号

- GitHub 账号：`408Survivor`
- 仓库：`order_rush`，**私有**，通过 GitHub 插件 `create_repository` 创建（描述："爆单时刻 — Godot 4 独立游戏项目"，`private: true`）
- HTTPS 地址：https://github.com/408Survivor/order_rush
- SSH 远程：`git@github.com:408Survivor/order_rush.git`（`git remote add origin ...`）
- commit 身份：`408Survivor <64139558+408Survivor@users.noreply.github.com>`（noreply 邮箱）
- 分支：`main`（当时唯一分支，无其他远程分支）

### 推送前已有的 5 个本地提交（历史提交，推送后被重写哈希）

| 原哈希 | 提交信息 |
|--------|----------|
| `d98ff7a` | fix: 修复角色翻转瞬移，使用 flip_h 替代 scale.x 翻转 |
| `112dc1b` | feat: 添加玩家角色移动（WASD + 碰撞 + 翻转） |
| `db074eb` | docs: 更新进度看板和 ReadmeForAgent.md - Phase 0 完成 |
| `c0e669c` | p0: art style baseline |
| `d0b00a5` | chore: 初始化 Godot 项目目录结构 |

### 遇到的推送问题及解决（关键事件）

- **首次 push 被拒**：GitHub 返回 `GH007: Your push would publish a private email address`（`push declined due to email privacy restrictions`）。原因：5 个历史提交的作者/提交者均为真实 Gmail `LiuTongqing-MARS <liutongqing89@gmail.com>`，触发 GitHub 邮箱隐私保护。
- **解决办法**：用 `git filter-branch` 重写全部历史提交的作者/提交者元信息（代码内容未变；当时仓库从未推送过，重写无影响）：

```bash
git filter-branch -f --env-filter '
export GIT_AUTHOR_NAME="408Survivor"
export GIT_AUTHOR_EMAIL="64139558+408Survivor@users.noreply.github.com"
export GIT_COMMITTER_NAME="408Survivor"
export GIT_COMMITTER_EMAIL="64139558+408Survivor@users.noreply.github.com"
' -- --all
```

- 重写后新哈希序列：`e2fbda0 / 544370e / e02bcab / f8eee46 / …`（全部变为 noreply 身份），随后 `git push -u origin main` 成功，`main` 建立对 `origin/main` 的跟踪。
- 教训沉淀：**GitHub 开启邮箱隐私保护时，历史提交含真实邮箱会导致 push 被拒，需在首次推送前统一用 noreply 邮箱。**

### .gitignore 决策（沿用已有文件，未改动，确认有效）

`order_rush/.gitignore`（30 行）覆盖：

- Godot：`.import/`、`.godot/`、`*.tmp`、`*.translation`、`export.cfg`、`export_presets.cfg`、`*.import`、`project.binary`
- 构建输出：`build/`、`*.exe`、`*.x86_64`、`*.apk`
- 系统/编辑器：`.DS_Store`、`Thumbs.db`、`.vscode/`、`.idea/`、`*.swp`、`*.swo`
- 日志：`*.log`

推送时 git 追踪 60 个文件、工作树干净；`.git` 目录约 36 MB（项目整体约 120 MB），远低于 GitHub 限制。

### 本次对话新建的 GitHub 对象

**4 个 issue**（milestone/label 体系为口头规划，实际创建的是 issue）：

| # | 标题 | 定位/依赖 |
|---|------|-----------|
| #1 | [P0 收尾] 微波炉俯视角素材重生成 | 不阻塞 P1；004 批次 v2 透视偏正面仅作占位；要求 `archive/generations/008-microwave_overhead/` 批次存档完整 |
| #2 | [P1] 交互系统：E 键拾取/放置物品 | P1 第一个功能；信号命名示例 `item_picked_up` |
| #3 | [P1] 顾客系统：生成与排队逻辑 | 依赖 #2；寻路保持简单（直线+避障，不必上 A*） |
| #4 | [P1] 订单循环：下单→加热→交付→结算最小闭环 | 依赖 #2 #3，P1 收口；信号示例 `order_completed` |

Issue 统一用「目标 / 验收标准 / 上下文」三段式正文。

**2 个 PR**（对话结束时均待用户手动合并，助手按约定不代点 merge）：

| PR | 分支 | 内容 |
|----|------|------|
| #5 | `chore/issue-templates` | 3 个 issue 模板：`.github/ISSUE_TEMPLATE/feature_task.md`、`art_asset.md`、`bug_report.md` |
| #6 | `docs/session-4-sync`（commit `6ef3bca`） | Session 4 收工同步：`ReadmeForAgent.md` + `docs/进度看板.md`（2 files changed, 74 insertions(+), 140 deletions(-)） |

建议合并顺序：先 #5 后 #6。对话结束时本地停在 `docs/session-4-sync` 分支，待合并后切回 main 拉取同步。

### 补充事实

- 本机 `gh` CLI 不可用（`which gh` 失败），故全程用 Kimi GitHub 插件（MCP）操作。
- 助手遵守插件约束：merge、close 等改仓库状态的操作留给用户确认。

---

## 2. 项目状态快照（2026-07-22 时点）

### 项目根目录（`order_rush/`，已是 git 仓库）

```
order_rush/
├── .git/                  # 36 MB
├── .gitignore
├── .godot/                # 已被 gitignore 排除
├── .DS_Store              # 已被 gitignore 排除
├── Lookme.html            # 可视化进度看板（26 KB）
├── README.md              # 7 KB，给人看的项目总览
├── ReadmeForAgent.md      # AI 上下文卡（本次收工时由 146 行精简至 ~120 行）
├── project.godot
├── archive/               # 开发存档（generations/ 按批次编号，P0 共 001–007 批次）
├── assets/                # assets/art/{characters,items,environment,ui}、assets/audio/{bgm,sfx,ambience}
├── docs/                  # 开发手册_v1.0.md、prompts/AI美术提示词库_v1.0.md、进度看板.md、进度汇报模板.md
├── resources/             # .tres 数据资源
├── scenes/                # ui/ props/ levels/ entities/
└── scripts/               # 含 scripts/entities/
```

被 git 排除：`.godot/`、`.DS_Store`、构建输出、编辑器文件等（见第 1 节 .gitignore）。git 实际追踪 60 个文件。

### 进度状态

- **P0 美术风格锁定：✅ 100% 完成**。6/6 核心素材已生成并导入（批次 001–007，即梦 5.0 Lite），微波炉为占位版（→ issue #1）。
- **P1 核心循环：🔄 开发中，约 30%**。已完成：Godot 项目初始化、玩家移动（WASD + 碰撞 + flip_h 翻转，修复过 scale.x 翻转瞬移 bug）。进行中：交互系统（issue #2）。
- **P2–P9 全部锁定**：订单系统 / 经济系统 / 外卖系统 / 设备升级 / 卡牌系统 / 多菜品+难度 / 角色系统 / Polish。
- P1 目标：1 种 L1 菜品 + 1 个堂食顾客 + 1 台微波炉 + WASD 移动 + 交互，可运行完整循环；收口时打 Git tag `p1`。

### 素材清单（P0）

| 素材 | 文件 | 状态 | 路径 |
|------|------|------|------|
| 玩家厨师（俯视角） | `player_chef_idle.png` | ✅ | `assets/art/characters/` |
| 顾客（俯视角） | `customer_office_waiting.png` | ✅ | `assets/art/characters/` |
| 微波炉 | `microwave_idle.png` | ⚠️ 占位版（issue #1） | `assets/art/items/` |
| 料理包 | `meal_kungpao.png` | ✅ | `assets/art/items/` |
| 成品菜（透明背景+蒸汽） | `dish_kungpao_plated.png` | ✅ | `assets/art/items/` |
| 地板 Tile | `floor_tile.png` | ✅ | `assets/art/environment/` |

### 本次收工对文档的修订

- `ReadmeForAgent.md`：清理待办表格重复行（原第 46–65 行同一批任务列了两遍且状态矛盾）；新增第 3 节「开发工作流（issue/PR 驱动）」；写入会话协议口令；任务状态权威来源迁移到 GitHub Issues。
- `docs/进度看板.md`：修正重复行与错误的「总体完成度: 100%」，P1 进度改为 ~30%，补 07-09 / 07-22 活动记录。

---

## 3. 设计决策与开发规范

### 游戏定位

- **爆单时刻 (Order Rush)**：2D 俯视角预制菜小餐馆经营模拟游戏，融合《飞机大厨》的高频操作爽感与《杯杯倒满的》PC 键盘经营深度。Godot 4.x + GDScript。
- 排队时长压力是核心张力来源；P1 阶段仅宫保鸡丁一种菜品。

### issue/PR 驱动开发流程（本次确立的核心工作方式）

1. 所有任务先开 issue（「目标 / 验收标准 / 上下文」三段式，验收标准清单供 AI 完成后逐条自检）。
2. 所有改动走分支 + PR，不直接推 main；commit 关联 issue 号（如 `feat: E 键拾取料理包，带碰撞检测 (#2)`）。
3. PR 描述写 `Closes #N`，合并后 issue 自动关闭——任务状态不再手工维护。
4. 分支命名：`类型/issue号-简述`（如 `feature/2-interact-pickup`、`art/1-microwave-regen`），一个 issue 一个分支，做完即删。
5. milestone 对应 Phase（如 `P1 核心循环`）；label 示例：`美术`、`功能`。
6. 分工：用户只"提需求"和"点合并"；AI 负责建 issue、建分支、开发、开 PR 附验收自检，合并后同步 `ReadmeForAgent.md`。
7. 与 `ReadmeForAgent.md` 体系互补：**GitHub Issues 管任务流转（唯一权威来源），ReadmeForAgent 管会话上下文**。

### 多项目复用的启动语（本次沉淀的可复用资产）

> "这个项目用 issue/PR 驱动流程开发：所有任务先开 issue（用'目标/验收标准/上下文'三段式模板），所有改动走分支 + PR 合入 main，commit 关联 issue 号。请先帮我建仓库并配好 issue 模板，然后把当前待办开成首批 issue。"

或合并 AI Project Companion 模式：

> "用 AI Project Companion 模式初始化这个项目，并按 issue/PR 驱动流程开发：任务先开 issue（目标/验收标准/上下文三段式），改动走分支+PR。"

跨项目差异仅在"验收标准"的写法（游戏项目写"测试场景运行无报错"，写作项目写量化指标）。

### AI Project Companion 会话协议（本次接入）

- **开工**："开始今天的开发" → AI 读 `ReadmeForAgent.md` + 进度看板/Issues → 从下一个待办继续
- **收工**："收工" → AI 更新 `ReadmeForAgent.md` 和 `docs/进度看板.md`，输出一句话总结（"今天完成了 X，明天第一步是 Y"）
- **"开始 issue #N"** → 建分支 → 开发 → commit 关联 #N → 开 PR 附验收自检
- **"这个别忘了：xxx"** → 开 issue 挂着
- 备用口令："紧急求助"（跳过读档直接解决）、"回顾状态"、"继续上次"、"中断"
- 规范：`ReadmeForAgent.md` 永远放项目根目录、控制在 200 行以内。

### 技术与素材规范（对话中引用/重申）

- 命名：场景 PascalCase（`Microwave.tscn`）；脚本/变量/函数 snake_case；常量 UPPER_SNAKE_CASE；信号如 `order_completed`、`item_picked_up`；文件 snake_case。
- 素材导入 Godot 后 Filter 设为 Nearest。
- 玩家翻转用 `flip_h` 而非 `scale.x`（scale.x 会导致瞬移 bug——已修复的历史教训）。
- AI 素材生成：即梦 5.0 Lite（风格已锁定）；有效提示词结构：`Overhead view, bird eye view from directly above, [主体描述], [统一风格后缀]`；透明背景需在提示词中加"透明背景"。
- 每次生成按批次存档：`archive/generations/NNN-名称/`（含 `NNN.txt` 提示词/参数/经验记录 + 候选版本图）。

---

## 4. 遗留事项 / 下一步

1. **用户手动合并 PR #5（issue 模板）和 PR #6（收工文档同步）**，先 #5 后 #6；合并后 AI 在本地切回 main 拉取同步（当时本地停在 `docs/session-4-sync`）。
2. **开工 issue #2**（E 键交互系统）——合并完成后的下一个动作，口令："开始 issue #2"。
3. issue #1（微波炉俯视角重生成）挂着防遗忘，不阻塞 P1，素材就绪后替换。
4. 进度看板中「调试面板按 F1 切换」验收项标注"待开 issue"。
5. P1 收口（issue #4 完成）后打 Git tag `p1`。
6. 远期可选：issue label 体系完善、调度 Copilot 编码 Agent（需先对齐需求，注意额度）。

---

## 5. 提到的文件路径与文件名清单

**项目内（相对 `order_rush/`）：**

- `.gitignore`
- `README.md`
- `ReadmeForAgent.md`
- `Lookme.html`
- `project.godot`
- `docs/进度看板.md`
- `docs/开发手册_v1.0.md`
- `docs/进度汇报模板.md`
- `docs/prompts/AI美术提示词库_v1.0.md`
- `.github/ISSUE_TEMPLATE/feature_task.md`（本次新建，经 PR #5）
- `.github/ISSUE_TEMPLATE/art_asset.md`（本次新建，经 PR #5）
- `.github/ISSUE_TEMPLATE/bug_report.md`（本次新建，经 PR #5）
- `assets/art/characters/player_chef_idle.png`
- `assets/art/characters/customer_office_waiting.png`
- `assets/art/items/microwave_idle.png`
- `assets/art/items/meal_kungpao.png`
- `assets/art/items/dish_kungpao_plated.png`
- `assets/art/environment/floor_tile.png`
- `archive/generations/001-chef_front_view/`（存档结构示例）
- `archive/generations/008-microwave_overhead/`（issue #1 要求的未来批次）
- `scripts/entities/`、`scenes/{ui,props,levels,entities}/`

**项目外 / 环境：**

- 旧工作目录：`/Users/liutongqing/Downloads/跨设备同步/游戏/爆单时刻`（项目迁移前的位置）

**GitHub URL：**

- https://github.com/408Survivor/order_rush
- https://github.com/408Survivor/order_rush/issues/1 ~ #4
- https://github.com/408Survivor/order_rush/pull/5 与 /pull/6
