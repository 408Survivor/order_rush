# 爆单时刻 (Order Rush) — 设计归档（历史对话权威档案）

> **归档说明**：本文档由 5 份旧 AI 对话提炼稿（2026-07-08 ~ 2026-07-22，位于 `docs/.archive-extract/`）合并去重而成，供未来开发（人类 + AI）查阅。其中提炼稿 01 与 02 源自同一份完整对话记录（项目启动对话），已合并为 Session 1 单一条目。
> **标注约定**：【用户】= 用户明确决定/要求；【AI】= AI 建议或产出。
> **路径说明**：对话发生时项目位于旧路径 `/Users/liutongqing/Downloads/跨设备同步/游戏/爆单时刻/order_rush/`，现已迁移至 `/Users/liutongqing/Downloads/GameDev/order_rush`。

---

## 1. 项目概述

**一句话定位**：爆单时刻（Order Rush）——2D 俯视角预制菜小餐馆经营模拟游戏，融合《飞机大厨》的高频操作爽感与《杯杯倒满》的经营深度与 PC 键盘操作，"堂食 + 外卖"双线程。【用户】

**核心玩法设计**（全部来自用户初始设计案）：

- **核心乐趣**：时间管理 + 订单调度 + 空间移动；排队时长压力是核心张力来源。
- **三级出餐体系**：L1 即热约 6 秒（冰柜取料理包 → 撕开 → 微波炉 → 装盘/装袋）；L2 即烹约 14 秒（多料包组合 → 炒锅按顺序现做）；L3 现做+备菜约 25 秒（开店前备餐模式做凉菜如拍黄瓜，营业中现做高价菜如小炒牛肉）。
- **外卖调度（核心策略层）**：订单到达时间 ≠ 骑手到达时间；每单显示"时间裕度"（骑手 ETA − 制作时间），红黄绿蓝四色紧急度提示；复杂菜提前做、简单菜延后。
- **经营循环**：单局 7–10 分钟模拟一天营业；每日结算 = 收入 − 进货费 − 电费 − 房租。
- **操作**：WASD/方向键移动，空格或 E 交互，手持物品一次一件。

---

## 2. 设计决策汇总

> 玩法/数值/经济设计全部来自用户开场简报（前期调研成果），对话中原样确认，均为【用户】决定；里程碑拆解为【AI】建议。

### 2.1 经济数值

- **每单收入** = 菜品基础价 + 打包费 + 平台补贴 − 平台扣点（基础 20%）+ 好评奖励 − 差评罚款。
- **每日成本** = 食材成本（按售出量）+ 固定房租 + 水电燃气（按设备使用次数）+ 耗材费。

### 2.2 肉鸽卡牌（口碑值打烊后抽卡构筑）

| 流派 | 卡牌示例 |
|------|----------|
| 走量流 | 满减单价 -15% 单量 +30%；冲单每 10 单 +50 金 |
| 品质流 | L3 售价 +40%；打包费翻倍 |
| 外卖专精 | 扣点 -8%；超时罚减半 |
| 堂食专精 | 熟客 20% 免看菜单 |
| 成本流 | 食材 -15%、水电 -30%、耗材 -20% |

### 2.3 局外成长

- **人物 5–6 个**：快手主厨（制作 -15%）、打包达人（打包减半）、精明老板（扣点 -5%）、现炒高手（L3 售价 +20%）、外卖老手（骑手容忍 +5 秒）、社交达人（小费 +100%）。
- **设备升级**：微波炉功率/双腔、冰柜容量、炒锅火力、自动封盖机、外卖打印机、保温柜、排烟系统。
- **店铺装修**。

### 2.4 难度曲线

- Day 1：5 单纯堂食 100% L1 并发 1 → Day 2：8 单 30% 外卖 → Day 3：10 单 70%L1+30%L2 解锁招牌菜 → Day 4：12 单并发 3、50% 外卖、骑手提前到达事件 → Day 5：12 单 50/40/10% L1/L2/L3、扣点上调 25% → Day 6：15 单并发 4、差评师 → Day 7：18 单并发 5、70% 外卖、订单间隔缩短 50%。
- Week 2+：订单量每周 +20%，并发上限 6 单；特殊事件（设备故障/断货/天气/探店博主）。

### 2.5 招牌菜系统

- 每日开店前强制设 1 个；上限 Lv.1=1 / Lv.2=2 / Lv.3=3（Max=3）。
- 效果：售价 +30%、点单率 +20%、堂食小费 +50%、外卖补贴 +5 金币；熟练度连续 3 天制作 -10%、7 天 -20%；高压日点单率额外 +15%，可触发"招牌菜爆单"。

### 2.6 平台与音频

- 平台路线：itch.io 首发付费验证（¥6–15）→ TapTap 免费测试 → Steam 正式发售。【用户】
- 音频：SunoAI（BGM）+ PopPop AI/freesound（音效）；用 AudioBus 分轨管理 BGM/音效。【用户/AI】
- 未来方向：2–4 人多人合作（备餐/烹饪/打包/外卖分工）。【用户】

### 2.7 里程碑计划【AI 建议，12–16 周】

| Phase | 周期 | 核心交付 |
|---|---|---|
| P0 | Week 1 | 美术风格锁定 + 6 张基准素材 |
| P1 | Week 2–3 | 核心循环可运行（1 菜 + 1 堂食顾客 + 1 微波炉 + WASD + 空格交互） |
| P2 | Week 4–5 | 堂食订单 + 耐心值 |
| P3 | Week 6 | 经济结算 + 日循环 |
| P4 | Week 7–8 | 外卖 + 骑手调度 |
| P5–P9 | Week 9–16 | 设备升级、卡牌、多菜品+难度、角色系统、Polish |

**P1 验收标准**：WASD 移动带碰撞；空格取/放/加热；手持一次一件；微波炉放包 → 加热 3 秒 → 指示灯 → 取出；顾客生成 → 入座 → 等待 → 收菜 → 吃 5 秒 → 离开；F1 调试面板；Git tag `p1`。

### 2.8 美术管线决策（Session 2 实战产生）

1. 即梦没有负面提示词输入框【用户】→ 提示词库 v1.2：排除要求以 `no xxx` 融入正面风格后缀【AI】。
2. 即梦平台拦截 `no xxx` 否定句式（判违规）【用户截图反馈】→ v1.3：移除全部否定词、缩短长度、改用中文正面描述【AI】。
3. **"透明背景"必须写进提示词文本**，仅勾选设置不够（004 批次教训）【AI 承认失误并修正】。
4. 最终验证有效的 v3 即梦精简版提示词模板：
   ```
   俯视正上方，从天花板正下方看，[主体描述]，
   扁平矢量插画，Q版比例，粗线条描边，2D游戏素材，
   透明背景，画面居中，单物体，清晰边缘，
   柔和阴影，温馨氛围，左上光源
   ```
5. 004 微波炉占位决策【用户拍板"先这样吧"】：v2 为正面+顶部 3/4 视角、白底，Phase 0 占位，标注"后续需重生成"；重生成方向 = 提示词加入"只能看到顶面，完全看不到正面和侧面"【AI】。
6. 选版标准【AI 建议、用户确认】：005 料理包选 v2（唯一无文字空白红标签，符合"后期用 Godot Label 叠加中文"方案）；006 成品菜选 v2（透明背景首次生效、自带蒸汽、宫保鸡丁四要素齐全）；007 地板选 v4（单块独立 tile 适合 TileMap 拼接、十字勾缝、阴影最柔和）。
7. 料理包倾斜视角可接受【AI 判断，用户默认】：手持物品需看清内容，不像微波炉必须严格俯视。
8. 微波炉状态指示灯方案【AI 重申】：只生成一张底图，Godot 中用 IndicatorSprite 彩色圆点节点显示状态，比生成 idle/heating/done 三张变体更灵活。

### 2.9 P1 实现数值【AI 写入代码】

- `GameStateManager.gd`：`MAX_CONCURRENT_ORDERS := 1`（P1 只支持 1 单）；`OrderState` 枚举：PENDING / COOKING / READY / SERVED / COMPLETED / FAILED（FAILED 标注 Phase 2 启用）。
- 玩家：`MOVE_SPEED := 200.0` 像素/秒；`INTERACTION_RADIUS := 80.0`；`INTERACTION_COOLDOWN := 0.3` 秒；手持物品挂点 `HeldItemPivot` 的 `y = -40`；`InteractionArea` 用 CircleShape2D、半径约 60 像素、Collision 设 Layer 3（Interactables）；玩家 `_ready()` 中 `add_to_group("player")`。（注：手持物品系统代码已交付但未落地，见第 6 节遗留事项。）

---

## 3. 开发规范汇总

### 3.1 目录结构【用户要求严格执行，AI 落实】

```
order_rush/
├── .git/  .gitignore  project.godot  README.md  ReadmeForAgent.md  Lookme.html
├── scenes/{levels,entities,ui,props}        # 所有 .tscn
├── scripts/{autoload,entities,systems,ui,utils,items}  # 所有 .gd
├── assets/
│   ├── art/{characters,items,environment,ui,effects}/
│   ├── audio/{bgm,sfx,ambience}/
│   └── fonts/
├── resources/{data,themes}    # .tres 数据资源、主题
├── archive/generations/       # AI 生成存档（按批次编号）
└── docs/                      # 全部项目文档（纳入 Git）
```

**文件归位铁律**【AI，经用户认可】：`.tscn`→`scenes/`、`.gd`→`scripts/`、`.png`→`assets/art/`、根目录禁止堆文件。

### 3.2 命名规范【用户提出】

- 场景文件：PascalCase（`Microwave.tscn`、`MainScene.tscn`）
- 脚本与变量：snake_case（`microwave.gd`、`order_manager.gd`）
- 信号名：过去分词或动宾结构（`order_completed`、`item_picked_up`）
- 常量：UPPER_SNAKE_CASE
- 最终素材文件名：复制进 `assets/art/` 时不带 `v`、`(selected)` 等版本/解释字样【用户明确要求】，如 `player_chef_idle.png`

### 3.3 代码注释与文档【用户要求】

- 每个脚本顶部注释说明文件职责（实际采用 `## 文件: / ## 职责: / ## 依赖: / ## 注意:` 格式）；每个函数注释输入/输出/副作用；复杂算法（优先级排序、时间裕度计算）逐行注释；代码内用 `==================== 常量 ====================` 分段。
- **禁止魔法数字**：所有数值（加热时间 3 秒、耐心值 30 秒）必须定义为常量或 `@export` 导出变量。

### 3.4 Git 规范

- 每个 Phase 完成 = 一个可提交里程碑；每个 commit 必须可运行【用户要求，AI 强化】。
- commit message 用 Conventional Commits 简化版：`feat/fix/asset/docs/chore`；Phase 验收节点用 `p<N>:` 前缀（如 `p0: art style baseline`）【AI 建议】。
- Phase 结束打 tag：`git tag -a pX -m "Phase X 完成"`【AI 建议】。
- 定期推送 GitHub/Gitee 备份【用户要求】。
- P1 预定 commit 节点（约 10 个）：初始化 → 玩家移动 → 手持物品 → 微波炉 → 顾客 → 完整订单循环 → 调试面板 → 素材 → 验收合并 `p1: core gameplay loop`【AI 规划】。
- `.gitignore`（Session 3 落地）覆盖：Godot（`.import/`、`.godot/`、`*.tmp`、`*.translation`、`export.cfg`、`export_presets.cfg`、`*.import`、`project.binary`）、构建输出（`build/`、`*.exe`、`*.x86_64`、`*.apk`）、系统/编辑器（`.DS_Store`、`Thumbs.db`、`.vscode/`、`.idea/`、`*.swp`、`*.swo`）、日志（`*.log`）。

### 3.5 issue/PR 驱动开发流程（Session 4 确立的核心工作方式）

1. 所有任务先开 issue（「目标 / 验收标准 / 上下文」三段式，验收标准清单供 AI 完成后逐条自检）。
2. 所有改动走分支 + PR，不直接推 main；commit 关联 issue 号（如 `feat: E 键拾取料理包，带碰撞检测 (#2)`）。
3. PR 描述写 `Closes #N`，合并后 issue 自动关闭——任务状态不再手工维护。
4. 分支命名：`类型/issue号-简述`（如 `feature/2-interact-pickup`、`art/1-microwave-regen`），一个 issue 一个分支，做完即删。
5. milestone 对应 Phase（如 `P1 核心循环`）；label 示例：`美术`、`功能`。
6. 分工：用户只"提需求"和"点合并"；AI 负责建 issue、建分支、开发、开 PR 附验收自检，合并后同步 `ReadmeForAgent.md`；merge/close 等改仓库状态的操作留给用户确认。
7. 与 `ReadmeForAgent.md` 体系互补：**GitHub Issues 管任务流转（唯一权威来源），ReadmeForAgent 管会话上下文**。

### 3.6 AI 素材存档规范【用户主导迭代定稿】

- 目录 `archive/generations/`，按**批次编号**组织：`NNN-简要描述/`【用户否决了 AI 最初"按日期分组"的方案】。
- 每个批次内含 `NNN.txt`，记录：平台、模型、参数、完整提示词、生成结果评估表、经验记录、后续行动；当批全部图片（包括被淘汰的）一并保存。
- 选中图命名加标记：`xxx_v1(selected).png`【用户自定】。
- `assets/art/` 只放最终入选素材；`archive/` 保留全部原始生成记录，两者都纳入 Git。

### 3.7 会话交接工作流【用户发起设计，AI 整理成文 `docs/工作流规范.md`】

| 场景 | 标准话术 |
|------|---------|
| 开工 | 「开始今天的开发，请阅读 ReadmeForAgent.md。」 |
| 收工 | 「同步到文件，我要休息了。」或「收工」 |
| 中断 | 「我要中断，先不同步。」 |
| 紧急求助 | 「紧急求助：XXX报错了。」（跳过上下文加载直接解决） |
| 回顾状态 | 「回顾一下项目当前状态。」（只总结不推进） |
| 开工 issue | 「开始 issue #N」→ 建分支 → 开发 → commit 关联 #N → 开 PR 附验收自检 |
| 挂起事项 | 「这个别忘了：xxx」→ 开 issue 挂着 |

- 开工时 AI 依次读 `ReadmeForAgent.md` → `docs/进度看板.md` → 检查 `assets/art/`（Session 4 起改为同时查看 GitHub Issues）。
- 收工时 AI 更新：进度看板 → `ReadmeForAgent.md` → 输出一句话总结（今日完成/明日第一步）。
- 文件更新优先级：P0 = ReadmeForAgent.md + 进度看板；P1 = 工作流规范；P2 = Lookme.html + README.md。
- `ReadmeForAgent.md` 永远放项目根目录、控制在 200 行以内。
- 进度汇报机制【AI 设计，用户采纳】：4 种模板（Commit 完成汇报 / Phase 验收汇报 / Bug 阻塞求助 / 每日简报，见 `docs/进度汇报模板.md`），卡壳超过 2 小时即求助；汇报前先 `git commit`、附运行证明。

### 3.8 防过度工程化原则【用户要求】

- Phase 1 铁律：只做"1 种菜 + 1 个顾客 + 1 台微波炉 + WASD 移动 + 空格交互"，其他想法先记 `docs/ideas.md`。
- 核心理念：「先能跑，再跑好」——不追求完美架构，但追求干净的项目结构。
- 用 Godot 内置（Timer、Tween、AnimationPlayer），不造轮子；状态机优先 match/枚举，不引入状态机插件；寻路保持简单（直线+避障，不必上 A*）。

### 3.9 文档体系分工【AI 建议 + 用户提出关键两件】

- `README.md`：给人看的项目总览【AI】。
- `ReadmeForAgent.md`：给 AI 的快速上下文，新会话零成本加载【用户提出】。
- `Lookme.html`：可视化进度看板（Tailwind + Lucide + 玻璃拟态 + 渐变文字 + 暗黑模式切换），风格对齐用户个人网页 demo（旧路径 `/Users/liutongqing/Downloads/跨设备同步/个人网页/index.html`），后续会与个人网页合并【用户提出】。
- `docs/开发手册_v1.0.md`（55,549 字节：项目约定、12–16 周里程碑、P0/P1 方案、5 份 GDScript 代码框架、Git 规范、20+ 条常见坑、命名速查表）、`docs/进度汇报模板.md`、`docs/进度看板.md`、`docs/Phase_0_执行指南.md`、`docs/工作流规范.md`、`docs/prompts/AI美术提示词库_v1.0.md`【均为 AI 产出】。

---

## 4. 技术要点

### 4.1 引擎与环境

- **引擎**：Godot 4.x + GDScript【用户选定，有 Python 基础】；开发手册写 `4.4.x`，实际安装运行 **v4.7.stable.official.5b4e0cb0f**（Apple M1 arm64，Metal 4.0 - Forward Mobile 渲染器）——存在版本口径不一致，本地 `project.godot` 的 features 后已变为 `"4.7", "Mobile"`。
- **Godot 安装**（macOS）：官网下载 **ARM64 标准版**，不选 .NET 版（纯 GDScript）；首次打开需在系统设置 → 隐私与安全性点「仍要打开」；Mac 按 F6 需 `Fn + F6`。

### 4.2 project.godot 关键配置【AI 写入】

- `config/name="Order Rush"`，tags `("2d","simulation","cooking")`；`run/main_scene="res://scenes/MainScene.tscn"`
- autoload：`GameStateManager="*res://scripts/autoload/GameStateManager.gd"`
- 窗口 1280×720，`stretch/mode="canvas_items"`、`stretch/aspect="expand"`
- `[debug] gdscript/warnings/return_value_discarded=0`
- `[rendering] textures/canvas_textures/default_texture_filter=0`（0 = Nearest，全局纹理过滤）
- 输入映射：`move_left/right/up/down`（WASD/方向键，deadzone 0.5）、`interact`（空格/E）、`debug_toggle`（F1）

### 4.3 已踩过的坑及解法（实战记录）

1. **flip_h vs scale.x 翻转瞬移**：`centered=false` 时锚点在左上角，脚本用 `scale.x = ±0.2` 翻转导致锚点跳跃瞬移。修复：`centered` 改回 `true`、CollisionShape2D position 归 `(0,0)`、脚本改用 `sprite.flip_h`（以中心轴翻转）。教训：**玩家翻转永远用 `flip_h` 而非 `scale.x`**。
2. **autoload 崩溃**：`project.godot` 配了 GameStateManager autoload 但文件不存在 → 运行崩溃/角色不动。解法：先补建 `scripts/autoload/GameStateManager.gd`（extends Node，订单状态机 + `order_state_changed(order_id, new_state)` 信号）。
3. **创建脚本 ≠ 附加脚本**：在 Godot 里创建了 `player_character.gd` 但没绑定到节点不生效，需把脚本拖到节点上【用户发现】。
4. **AI 大图显示只有一角**：生成图约 1024×1024，大于 1280×720 视口 → Sprite2D Scale 改 0.2；`centered=false` 时图片从左上角绘制。
5. **Godot 4 纹理过滤**：Texture2D 导入面板没有 Filter 选项 → 改为在 `project.godot` 全局设 `textures/canvas_textures/default_texture_filter=0`（Nearest）。兜底方案：删除 `.godot/` 缓存目录强制重导入【AI 建议，未实际用到】。
6. **GitHub 邮箱隐私保护**：历史提交含真实 Gmail 触发 `GH007: Your push would publish a private email address`，push 被拒。解法：`git filter-branch` 重写全部历史提交的作者/提交者为 `408Survivor <64139558+408Survivor@users.noreply.github.com>`（代码内容未变；仅限从未推送过的仓库）。教训：**GitHub 开启邮箱隐私保护时，首次推送前统一用 noreply 邮箱**。

### 4.4 AI 美术管线

- **工具优先级**：即梦 > 豆包 > 可灵【AI 建议】；实际锁定**即梦"图片 5.0 Lite"模型**【用户实际操作确认】。
- **生成参数**：1:1、勾选透明背景、风格化/风格强度 75%（文档建议范围 70–85%）、每次 4 张选最佳；实际产出 2048×2048 PNG。
- **风格锁定结论**：扁平矢量插画、Q 版头大身小、暖色高饱和、清晰粗描边、透明背景、左上光源。
- **统一风格后缀（英文长句版）**：`flat vector illustration, warm saturated colors, chibi proportion, clean bold outlines, 2D game asset, transparent background, single object centered, filling the frame, no text, no watermark, crisp edges, game-ready sprite, soft shadows, cozy atmosphere, consistent lighting from top-left`
- **俯视角提示词演进**：
  - v1 `top-down perspective` → 即梦输出**正面正视图**（失败，001 批次教训）
  - v2 `Overhead view, bird eye view from directly above, looking straight down from ceiling, [主体描述], [风格后缀]` → 002/003 批次成功（英文长句版）
  - v3 中文精简版 `俯视正上方，从天花板正下方看` → 004–007 使用；注意对"微波炉"这类训练数据默认为正面图的物体仍会偏 3/4 视角
- **即梦平台规则实测**：① 无负面提示词输入框；② 大量 `no xxx` 否定句会被判违规；③ 输出图右下角带即梦水印；④ 勾选"透明背景"不保证生效，需提示词文本配合。
- **顾客图实为"斜上方约 45° 俯视"**（可见后脑勺），非纯 90°，游戏可用（需看背部区分身份）【AI 判断，用户接受】。
- **中文标签方案**：素材不生成文字，后期用 Godot Label 节点叠加；订单气泡用 NinePatchRect、耐心条用 TextureProgressBar。
- **Godot 导入设置**：Filter: Nearest（Tile 必须）；Size Limit：角色/设备 512、小物品 256；地板走 TileMapLayer + TileSet atlas，Tile Size 64×64，Repeat: Enabled。
- **即梦 CLI（dreamina）**：官网提供 `curl -s https://jimeng.jianying.com/cli | bash` 安装（装到 `~/.dreamina_cli/`，需浏览器 Cookie 认证）；对话时**未安装**，决定先用网页版、批量生成阶段再装【AI 建议，用户未执行】。

### 4.5 P1 代码框架【AI 在开发手册中给出】

5 份脚本——`GameStateManager.gd`（autoload 全局订单状态）、`player_character.gd`、`microwave.gd`（Idle/Heating/Done 状态机）、`customer.gd`（Entering→Waiting→Eating→Leaving）、`debug_panel.gd`（F1 切换显示 OrderManager 状态/活跃订单/设备占用）；调试输出用 `print_rich`/`print_debug`【用户要求】。

---

## 5. 开发历程时间线

### Session 1（2026-07-08 凌晨，「爆单时刻游戏开发规范 / 独立游戏开发」，提炼稿 01+02 同源）

- 用户以完整游戏设计案启动项目；AI 产出整套文档体系：`docs/开发手册_v1.0.md`、`docs/进度汇报模板.md`、`docs/进度看板.md`、`docs/prompts/AI美术提示词库_v1.0.md`（17,751 字节）、`README.md`、`docs/Phase_0_执行指南.md`。
- 建立资源目录 `assets/art/{characters,items,environment,ui,effects}`、`assets/audio/{bgm,sfx,ambience}`、`assets/fonts`、`docs/prompts`。
- P0 美术执行（完成 2/6）：
  - 001 批次厨师图 2 张（`jimeng-2026-07-08-8816/9083`）→ 判定为正面图，存 `chef_front_view_v1/v2.png` 作 UI 备用；提示词库升至 v1.1。
  - 002 批次 4 张俯视厨师（`jimeng-2026-07-08-7607/8184/4285/9847`），7607 透明背景选中 → `assets/art/characters/player_chef_idle.png`。
  - 003 批次 4 张顾客，v1 选中（暖色棕发与厨师风格统一）→ `assets/art/characters/customer_office_waiting.png`。
  - 建 `archive/generations/001/002/003-*` 并写 `001.txt`/`002.txt`/`003.txt`；进度看板更新至 30%。
- 创建 `ReadmeForAgent.md`（4,978 字节）+ `Lookme.html`（26,200 字节）+ `docs/工作流规范.md`（6,507 字节）。
- 创建通用 Skill `ai-project-companion`（位于 Kimi managed skills 目录）【用户发起；用户明确指示此事**不用同步到项目文件**】；Skill 变现问题结论：无直接变现渠道，建议开源+博客引流。
- 对话期间发生一次 full compaction。

### Session 2（2026-07-08，「开发前阅读文档」）

- 按启动流程读 `ReadmeForAgent.md` + 进度看板 + 提示词库，完成 P0 剩余 4 个批次：
  - 004 微波炉：v2 占位（正面+顶部 3/4 视角、白底）→ `assets/art/items/microwave_idle.png`，标注需重生成。
  - 005 料理包：v2 选中（无文字空白红标签）→ `assets/art/items/meal_kungpao.png`。
  - 006 成品菜：v2 选中（透明背景首次生效+蒸汽）→ `assets/art/items/dish_kungpao_plated.png`。
  - 007 地板：v4 选中（单块 tile、十字勾缝）→ `assets/art/environment/floor_tile.png`。
- 提示词库迭代至 v1.2（融入排除要求）→ v1.3（无否定词中文精简版）；应对即梦平台规则两次踩坑。
- 收工同步：ReadmeForAgent.md 进度 30%→100%；进度看板 P0 标 ✅ 完成；清理 ReadmeForAgent.md 重复段落（Edit 多次失败后改用 head/tail shell 完成）。
- **P0 美术风格锁定 100% 完成（6/6 素材）。**

### Session 3（2026-07-09，「爆单时刻开发准备」）

- 安装 Godot 4.7（macOS ARM64 标准版）；`mkdir -p` 落地全部目录（另多建 `scripts/items/`）；`git init` + 新建 `.gitignore` + `project.godot`。
- Git 提交序列：`chore: 初始化 Godot 项目目录结构`（d0b00a5）→ `p0: art style baseline`（c0e669c）→ `docs: 更新进度看板和 ReadmeForAgent.md - Phase 0 完成`（db074eb）→ `feat: 添加玩家角色移动（WASD + 碰撞 + 翻转）` → `fix: 修复角色翻转瞬移，使用 flip_h 替代 scale.x 翻转`（d98ff7a）。
- P0 素材导入 Godot 验收通过；P1 开工：玩家 WASD 移动完成并修复翻转瞬移（修复后用户确认「非常顺滑」）。
- 新建 `scripts/autoload/GameStateManager.gd`；用户创建 `scenes/MainScene.tscn`（初名 TestScene）与 `scenes/entities/PlayerCharacter.tscn`。
- 会话结束于「手持物品系统」代码刚交付（HeldItemPivot/InteractionArea 方案），**用户尚未操作验证**。

### Session 4（2026-07-22 15:45–16:48，「上传项目到 GitHub 私有仓库」）

- 通过 Kimi GitHub 插件创建私有仓 `408Survivor/order_rush`（https://github.com/408Survivor/order_rush ，SSH `git@github.com:408Survivor/order_rush.git`）。
- 首次 push 因历史提交含真实 Gmail 被 GH007 拒绝 → `git filter-branch` 重写为 noreply 身份（新哈希 `e2fbda0/544370e/e02bcab/f8eee46/caf4607`）→ push 成功，推送时 git 追踪 60 个文件、`.git` 约 36 MB。
- 建 issue #1–#4（P0 微波炉重生成 / P1 交互系统 / P1 顾客系统 / P1 订单循环收口），三段式正文。
- 开 PR #5（`chore/issue-templates`，3 个 issue 模板）与 PR #6（`docs/session-4-sync`，收工文档同步，commit `6ef3bca`），均待用户手动合并；建议先 #5 后 #6。
- 确立 issue/PR 驱动流程；沉淀可复用启动语；`ReadmeForAgent.md` 由 146 行精简至 ~120 行，任务状态权威来源迁移到 GitHub Issues。
- 本机 `gh` CLI 不可用，全程用 Kimi GitHub 插件（OAuth）操作。

---

## 6. 遗留事项清单（合并所有对话的 TODO）

### 6.1 素材相关

1. **微波炉俯视角重生成**（→ GitHub issue #1，不阻塞 P1）：004 批次 v2 为占位版（透视偏正面+白底），提示词需加入"只能看到顶面，完全看不到正面和侧面"；要求 `archive/generations/008-microwave_overhead/` 批次存档完整；约定 P1 完成后重生成。
2. **004/005 素材抠图**：微波炉、料理包透明背景未生效（白底），需后期抠图。
3. **厨师图等白底问题**：验收时记为「P0 后处理」已知问题，未解决。
4. **扩展素材**（登记在提示词库状态表，未生成）：顾客学生（`customer_student.png`）、冰柜（`fridge.png`）、炒锅（`wok.png`，P2）、餐桌（`table_dining.png`）、订单气泡（`ui_order_bubble.png`，P2）、耐心条（`ui_patience_bar_*.png`，P2）、按钮（`ui_button_*.png`，P3+）；以及文档提及的 `customer_office_eating.png`、`customer_office_happy.png`、`meal_yuxiang.png`、`takeaway_bag.png`、`counter.png`、`shop_background.png` 等。
5. **即梦 CLI（dreamina）** 待批量生成阶段再安装。

### 6.2 代码/玩法相关

6. **手持物品系统（Session 3 中断点）**：AI 已交付完整方案与代码（HeldItemPivot/InteractionArea + 拾取/放下逻辑），**用户从未验证、代码未落地**；下一步：创建料理包物品场景（MealPackage，Area2D + Sprite2D + interactable 组）放进 MainScene 测试空格拾取/放下。已被 GitHub issue #2 覆盖。
7. **P1 剩余验收项**：微波炉加热 3 秒 + 指示灯（issue #4）、顾客完整流程（生成→排队→收菜→吃 5 秒→离开，issue #3/#4）、空格交互全链路（issue #2）。
8. **F1 调试面板**：进度看板验收项标注"待开 issue"。
9. **P1 收口后**（issue #4 完成）打 Git tag `p1`；P0 完成后解锁 Phase 1 的约定已履行，P1 收口后解锁 P2。

### 6.3 流程/工程相关

10. **用户手动合并 PR #5（issue 模板）和 PR #6（收工文档同步）**，先 #5 后 #6；合并后本地切回 main 拉取同步（Session 4 结束时本地停在 `docs/session-4-sync` 分支）。
11. **开工 issue #2**（E 键交互系统）——合并完成后的下一个动作，口令「开始 issue #2」。
12. **文档未收尾**：手持物品系统完成后需再次更新进度看板与 ReadmeForAgent.md 并提交。
13. **版本口径**：开发手册/README 写 Godot 4.4，实际安装运行 4.7.stable，建议后续统一（本地 project.godot features 已为 4.7）。
14. `docs/ideas.md`（手册中约定的新想法收容所）从未创建。
15. `icon.svg`：project.godot 引用 `res://icon.svg`，对话中无创建记录。
16. `ai-project-companion` Skill 未在新对话实测触发（项目外事项）。
17. Lookme.html 后续与用户个人网页内容合并（用户提出的远期事项）。
18. 远期可选：issue label 体系完善、调度 Copilot 编码 Agent（需先对齐需求，注意额度）。

---

## 附：关键文件索引（对话中提及的项目内文件）

**文档**：`README.md`、`ReadmeForAgent.md`、`Lookme.html`、`docs/开发手册_v1.0.md`、`docs/进度汇报模板.md`、`docs/进度看板.md`、`docs/Phase_0_执行指南.md`、`docs/工作流规范.md`、`docs/prompts/AI美术提示词库_v1.0.md`（已迭代至 v1.3 内容）、`.github/ISSUE_TEMPLATE/{feature_task,art_asset,bug_report}.md`（经 PR #5）

**批次存档**（`archive/generations/`，P0 共 001–007）：`001-chef_front_view/`、`002-chef_overhead_view/`（含 `chef_overhead_v1(selected).png`）、`003-customer_overhead_view/`（含 `customer_overhead_v1(selected).png`）、`004-microwave_overhead/`、`005-meal_package/`、`006-dish_plated/`、`007-floor_tile/`，各含 `NNN.txt` 记录与 v1–v4 候选图；008 为未来微波炉重生成批次。

**最终素材**（`assets/art/`）：`characters/player_chef_idle.png`、`characters/customer_office_waiting.png`、`characters/chef_front_view_v1.png`、`characters/chef_front_view_v2.png`（UI 备用）、`items/microwave_idle.png`（⚠️ 占位）、`items/meal_kungpao.png`、`items/dish_kungpao_plated.png`、`environment/floor_tile.png`

**代码/场景**：`project.godot`、`.gitignore`、`scripts/autoload/GameStateManager.gd`、`scripts/entities/player_character.gd`、`scenes/MainScene.tscn`、`scenes/entities/PlayerCharacter.tscn`；规划中未创建：`scripts/entities/microwave.gd`、`scripts/entities/customer.gd`、`scripts/ui/debug_panel.gd`、`scenes/entities/Microwave.tscn`

**GitHub**：https://github.com/408Survivor/order_rush （私有）；issues #1–#4；PR #5、#6
