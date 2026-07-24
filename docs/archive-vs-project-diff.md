# 归档 vs 本地项目 — 对比报告

> **对比时点**：2026-07-23（归档合并任务执行日）
> **对比双方**：`docs/design-archive.md`（由 5 份对话提炼稿合并，覆盖 2026-07-08 ~ 07-22）vs 本地项目 `/Users/liutongqing/Downloads/GameDev/order_rush` 实际文件 + GitHub 仓库实况（经 GitHub 插件核实）
> **总体结论**：本地项目与归档记录的 Session 4 结束状态**高度一致**——自 2026-07-22 起项目无实质推进，PR #5/#6 未合并、issue #1–#4 全部 OPEN、本地仍停在 `docs/session-4-sync` 分支。主要问题是两份"给人看"的文档（README.md、Lookme.html）严重过时。

---

## 1. 缺失文件（归档记录存在、本地不存在）

| # | 文件 | 归档依据 | 本地核查结果 | 说明 |
|---|------|----------|--------------|------|
| 1.1 | `.github/ISSUE_TEMPLATE/{feature_task,art_asset,bug_report}.md` | 提炼稿 05：PR #5（`chore/issue-templates`）新建 3 个模板 | 本地无 `.github/` 目录；`origin/main` 文件树中亦无 | **PR #5 从未合并**（GitHub 插件核实：PR #5 至今 state=open），模板只存在于未合并的 PR 分支上 |
| 1.2 | `docs/ideas.md` | 提炼稿 01/02：手册约定的新想法收容所，"未创建" | 不存在 | 与归档一致，仍属悬缺 |
| 1.3 | `icon.svg` | 提炼稿 04：`project.godot` 引用 `res://icon.svg`，"未见创建记录" | 不存在（`project.godot` 第 22 行仍引用） | 引擎会用默认图标兜底，但引用悬空 |
| 1.4 | `scripts/entities/microwave.gd`、`customer.gd`、`scripts/ui/debug_panel.gd`、`scenes/entities/Microwave.tscn` | 提炼稿 01/02：P1 代码框架 5 份脚本中未实施的 3 份 | 均不存在 | 与归档一致，对应 issue #2–#4 未开工 |
| 1.5 | 手持物品系统代码（HeldItemPivot / InteractionArea / 拾取放下逻辑） | 提炼稿 04：Session 3 结尾"代码刚交付、未验证" | `scripts/entities/player_character.gd` 仅含移动代码（MOVE_SPEED 常量 + flip_h 翻转），无 HeldItemPivot/InteractionArea | **交付的代码从未落地**——Session 3 中断点原样保留至今 |

## 2. 状态不一致（本地文档记载 vs 归档记录的实际进展）

| # | 位置 | 本地记载 | 归档记录的实际状态 | 评估 |
|---|------|----------|--------------------|------|
| 2.1 | `README.md`（第 8–14 行项目信息表） | 引擎"Godot 4.4.x"、"当前阶段 🔄 Phase 0 进行中"、"总体进度 30%（2/6 核心素材）" | 提炼稿 03：P0 已 100% 完成（6/6）；提炼稿 04/05：实际运行 Godot 4.7.stable、P1 已 ~30% | **严重过时**，停留在 Session 1 收工状态。归档 01 记载的文件更新优先级（README 为 P2 最低）正是病根 |
| 2.2 | `Lookme.html`（第 109–111 行） | "Phase 0: 美术风格锁定 · 30% 完成 · 2/6 素材" | 同上，P0 早已完成、P1 进行中 | **严重过时**，同为 P2 优先级从未更新 |
| 2.3 | `docs/进度看板.md`、`ReadmeForAgent.md` | P0 ✅ 完成、P1 ~30%、任务权威来源 = GitHub Issues、最后更新 2026-07-22 | 提炼稿 05：Session 4 收工同步内容 | **一致**，无落后 |
| 2.4 | `project.godot` 第 21 行 `config/features` | `("4.7", "Mobile")` | 提炼稿 04：AI 写入时为 `("4.4", "Mobile")`，并记录了"版本口径不一致"遗留项 | 已被修正（Godot 4.7 编辑器保存时自动写入或手工改），遗留项部分核销；但 README/开发手册的 4.4 口径未同步 |
| 2.5 | `docs/进度看板.md` 活动记录首行 | "2026-07-05 项目文档体系建立" | 提炼稿 01/02：文档体系实际建立于 2026-07-08（Session 1） | 日期小瑕疵（±3 天），不影响使用 |
| 2.6 | `archive/generations/001-chef_front_view/` 图片数 | 本地有 `chef_front_v1.png` ~ `v4.png` 共 **4 张** | 提炼稿 01/02：001 批次仅记录 **2 张**（jimeng-2026-07-08-8816/9083，即 v1/v2） | 本地比归档多 2 张（v3/v4），来源在对话归档中无记录，疑为用户事后补充或归档遗漏 |
| 2.7 | Git 分支状态 | 当前停在 `docs/session-4-sync`（与 origin 同步）；`main` 停在 `e2fbda0` | 提炼稿 05：Session 4 结束时即此状态，待用户合并 PR 后切回 main | 一致——但意味着**合并动作至今未发生** |
| 2.8 | GitHub 仓库实况（插件核实） | PR #5、#6 均 **open/unmerged**；issue #1–#4 全部 **OPEN** | 提炼稿 05 遗留事项第 1、2 条：待用户合并 PR、开工 issue #2 | 自 07-22 起零进展，全部遗留事项悬置 |

## 3. 遗留事项核销（归档 TODO → 本地现状）

### 3.1 已完成（核销 ✅）

| 遗留事项 | 归档出处 | 本地证据 |
|----------|----------|----------|
| Git 仓库初始化 + `p0: art style baseline` commit | 提炼稿 01/02/03 | `git log`：`caf4607 chore: 初始化` → `f8eee46 p0: art style baseline`（重写后哈希） |
| Godot 项目创建（`project.godot`） | 提炼稿 01 遗留"Godot 项目未创建" | `project.godot` 存在，配置与提炼稿 04 记载一致 |
| `.gitignore` 落地 | 提炼稿 01 遗留"未落地为文件" | 存在且生效（`.import`/`.godot/`/`.DS_Store` 均正确排除，git 恰追踪 60 个文件，与提炼稿 05 记载吻合） |
| P0 六素材生成（004–007 批次） | 提炼稿 01 遗留 | 提炼稿 03 已完成；`assets/art/` 与 `archive/generations/001–007` 全部就位 |
| 素材导入 Godot + Filter: Nearest + 显示测试 | 提炼稿 03 遗留 | 提炼稿 04 已完成；`project.godot` 全局 `default_texture_filter=0`，`.import` 缓存存在 |
| 定期推送 GitHub 备份 | 提炼稿 01 用户要求 | 提炼稿 05 已完成；`origin` = `git@github.com:408Survivor/order_rush.git` |
| project.godot features 版本口径 | 提炼稿 04 遗留"建议统一" | 已为 `("4.7", "Mobile")`（但见 2.1/2.4：README/手册未同步） |

### 3.2 仍悬而未决（❌ 无进展）

| 遗留事项 | 归档出处 | 现状 |
|----------|----------|------|
| 微波炉俯视角重生成（008 批次） | 提炼稿 03/04 → issue #1 | issue #1 OPEN，`microwave_idle.png` 仍是 004 占位版 |
| 004/005 素材抠图（白底） | 提炼稿 03 | 未处理 |
| 厨师图等白底问题（P0 后处理） | 提炼稿 04 | 未处理 |
| 手持物品系统落地 + MealPackage 场景 | 提炼稿 04 中断点 → issue #2 | issue #2 OPEN，代码未落地（见 1.5） |
| P1 剩余验收：微波炉加热/顾客流程/订单闭环 | 提炼稿 04 → issue #3/#4 | issue #3、#4 OPEN |
| F1 调试面板"待开 issue" | 提炼稿 05 | 未开 issue |
| Git tag `p1` | 提炼稿 04/05 | 无 tag（`git tag` 为空） |
| 合并 PR #5 → PR #6，切回 main | 提炼稿 05 遗留第 1 条 | 两个 PR 均 OPEN（见 2.8） |
| `docs/ideas.md` 创建 | 提炼稿 01/02 | 不存在 |
| `icon.svg` | 提炼稿 04 | 不存在 |
| 即梦 CLI（dreamina）安装 | 提炼稿 01/02/03 | 批量生成阶段再议，未执行 |
| Lookme.html 与个人网页合并 | 提炼稿 02 | 未执行 |
| `ai-project-companion` Skill 新对话实测 | 提炼稿 01/02 | 项目外事项，无从本地核实 |

## 4. 仅本地存在（归档未覆盖的内容）

| # | 内容 | 评估 |
|---|------|------|
| 4.1 | `project.godot` 新增 `[layer_names]`（5 个 2D 物理层命名：World/Player/Interactables/Items/Customers）、`renderer/rendering_method="mobile"`、`textures/vram_compression/import_etc2_astc=true`、`[animation]` 兼容配置 | 归档未记载，应为 Godot 4.7 编辑器保存项目时自动写入；物理层命名与提炼稿 04 记载的"InteractionArea 设 Layer 3（Interactables）"方案吻合，建议补记进开发手册 |
| 4.2 | `scripts/**/*.gd.uid` 文件（Godot 4.4+ 脚本 UID） | Godot 4.7 自动生成，归档未提及；正常，应纳入 Git |
| 4.3 | `docs/.archive-extract/`（5 份提炼稿，本次归档任务的输入） | 未被 git 追踪（`git status` 显示 untracked） |
| 4.4 | `docs/工作流规范.md`、`docs/Phase_0_执行指南.md` | 提炼稿 05 的 Session 4 项目快照中漏列，实际存在且内容完好（提炼稿 01/02 有创建记录）——属快照遗漏，非异常 |
| 4.5 | 本地残留 `refs/original/refs/heads/main`（filter-branch 备份引用） | 提炼稿 05 未提及的副作用：导致 `git log --all` 同时出现重写前后两套哈希（d98ff7a/e2fbda0 等），建议清理 |
| 4.6 | 001 批次 v3/v4 两张图 | 见 2.6，归档无记录 |

## 5. 建议动作（按优先级）

1. **合并 PR #5 → PR #6**（GitHub 上均 OPEN），本地切回 `main` 拉取同步——这是归档记录的全部后续流程（issue #2 开工）的前置条件，已悬置一天以上。
2. **更新 README.md 与 Lookme.html**：README 项目信息表改为 Godot 4.7 / Phase 1 开发中；Lookme.html 进度从"P0 30%、2/6 素材"更新到当前状态。两者在归档的更新优先级中垫底（P2），已证实会被长期遗忘，建议今后并入收工同步的强制清单。
3. **清理 `refs/original/refs/heads/main`**：`git update-ref -d refs/original/refs/heads/main`，消除双套哈希的干扰。
4. **开工 issue #2 时注意**：提炼稿 04 交付过的手持物品系统方案（HeldItemPivot y=-40、InteractionArea 半径 60、Layer 3）可直接作为起点，不必从零设计；`project.godot` 中 5 个物理层已命名就绪。
5. **补建 `icon.svg` 与 `docs/ideas.md`**：前者消除 project.godot 悬空引用，后者恢复手册约定的想法收容所。
6. **归档文件入库**：建议将 `docs/design-archive.md`、本报告及 `docs/.archive-extract/` 一并 commit（`docs: 合并历史对话归档`），避免再次散失。
7. **核实 001 批次 v3/v4 图片来源**（用户确认后补记 `archive/generations/001-chef_front_view/001.txt`），保持存档规范的"记录完整"原则。
8. **统一版本口径**：README/开发手册中的"Godot 4.4.x"统一改为 4.7（project.godot 已先行）。

---

*附：`docs/.archive-extract/` 目录已核查，无子代理遗留的临时脚本（`_*.py`、`_*.txt` 等），无需清理。*
