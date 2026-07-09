# Phase 0 执行指南：AI 美术素材生成步骤

> 本指南手把手带你完成 Phase 0 的素材生成。
> 按步骤执行，不要跳过。每完成一步在本文件末尾打勾。

---

## 🛠️ 准备：选择 AI 工具

**推荐优先级**: 即梦 > 豆包 > 可灵

| 工具 | 网址 | 优点 | 缺点 | 适合 |
|------|------|------|------|------|
| **即梦**（推荐） | jimeng.jianying.com | 透明背景最稳定 | 免费额度有限 | 所有角色、设备、物品 |
| **豆包** | doubao.com | 速度快、免费多 | 透明背景不稳定 | 快速迭代、测试 prompt |
| **可灵** | klingai.com | 角色一致性最好 | 游戏 asset 不是强项 | 多姿态角色（后续） |

**Phase 0 建议**: 用即梦。如果免费额度用完，切换豆包，生成后用 remove.bg 或 Photoshop 抠透明背景。

---

## Step 1: 风格测试（10 分钟）

**目标**: 生成 1 张图，确认你的 prompt 能稳定输出俯视角扁平风格。

**操作步骤**:

1. 打开即梦网站，进入**图片生成**页面
2. 清空默认提示词，粘贴以下内容：

```
A chibi chef character, top-down perspective, wearing white apron and red scarf, 
white chef hat, standing pose, holding a small empty tray, neutral happy expression, 
big round head, small body, short limbs, flat vector illustration, warm saturated colors, 
clean bold outlines, 2D game asset, transparent background, single object centered, 
filling the frame, no text, no watermark, crisp edges, game-ready sprite, 
soft shadows, cozy atmosphere, consistent lighting from top-left
```

3. 在**负面提示词**（如果有）或排除词中粘贴：

```
3d render, realistic, photorealistic, photograph, gradient background, 
white background, cluttered background, multiple objects, cropped, blurry, 
low quality, distorted perspective, side view, front view, confusing shadows, 
text, watermark, logo, signature, frame, border
```

4. 设置参数：
   - 比例: **1:1**（正方形）
   - 尺寸: **1024x1024**
   - 风格化: **75%**（或叫"风格强度"，不要拉满）
   - 透明背景: **勾选**（如果有此选项）
   - 生成数量: **4张**（选最佳）

5. 点击**生成**，等待 10-30 秒

6. 检查生成的 4 张图，选择最符合以下标准的一张：
   - ✅ 纯俯视角（90°垂直向下，不是斜着看）
   - ✅ 扁平插画风格（没有 3D 感、没有照片感）
   - ✅ Q 版比例（头大身小，四肢短）
   - ✅ 暖色高饱和（不是灰暗、不是冷色调）
   - ✅ 清晰描边（有明确的黑色或深色轮廓线）
   - ✅ 背景透明或纯色（没有复杂背景）

7. 如果都不符合，**微调提示词**（改 1-2 个词），再生成一次。不要生成超过 3 轮，否则浪费额度。

---

## Step 2: 检查风格一致性（5 分钟）

**目标**: 确认你的风格可以被复现，所有后续素材都能统一。

**操作**:

1. 用**相同的 prompt 结构**，只改主体描述，生成第 2 张测试：

```
A microwave oven, top-down perspective, closed door, metallic silver body, 
black glass door, control panel on right side, rectangular shape, 
flat vector illustration, warm saturated colors, clean bold outlines, 
2D game asset, transparent background, single object centered, filling the frame, 
no text, no watermark, crisp edges, game-ready sprite, soft shadows, 
cozy atmosphere, consistent lighting from top-left
```

2. 检查厨师和微波炉是否看起来像同一款游戏的素材：
   - ✅ 透视角度一致（都是俯视角，角度相同）
   - ✅ 色彩饱和度一致（都暖、都鲜艳，或都柔和）
   - ✅ 描边粗细一致（都有类似的轮廓线）
   - ✅ 比例协调（角色和家具的大小关系合理）

3. 如果一致，恭喜你！锁定这个 prompt 模板。后续只改主体描述，后半段风格后缀不变。

---

## Step 3: 生成 Phase 0 最小清单（6 张核心素材）

**目标**: 生成 Phase 1 可运行所需的最少素材。

**按顺序生成，每生成一张就检查质量**：

### 3.1 玩家厨师（`player_chef_idle.png`）

**存放路径**: `assets/art/characters/`

**提示词**（用你锁定的风格，以下只给出主体部分）：

```
A chibi chef character, top-down perspective, wearing white apron and red scarf, 
white chef hat, standing pose, holding a small empty tray with both hands, 
neutral happy expression, big round head, small body, short limbs
```

**+ 风格后缀**（就是你 Step 1 锁定的后半段，不要改）

**生成后检查**：
- [ ] 背景透明？
- [ ] 纯俯视角？
- [ ] 比例协调（头大身小）？
- [ ] 没有文字/水印？
- [ ] 色彩鲜艳？

**下载后操作**：
1. 在即梦下载原图（PNG 格式）
2. 命名为 `player_chef_idle.png`
3. 放入 `order_rush/assets/art/characters/`

---

### 3.2 顾客上班族（`customer_office_waiting.png`）

**存放路径**: `assets/art/characters/`

**主体提示词**：

```
A chibi office worker character, top-down perspective, wearing blue shirt and black pants, 
holding a smartphone in right hand, looking at phone, standing pose, 
big round head, small body, short limbs, casual hairstyle
```

**+ 风格后缀**

---

### 3.3 微波炉基础（`microwave_idle.png`）

**存放路径**: `assets/art/items/`

**主体提示词**：

```
A microwave oven, top-down perspective, closed door, metallic silver body, 
black glass door, control panel on right side, rectangular shape, simple design
```

**+ 风格后缀**

**注意**：微波炉生成后，检查尺寸。如果太大或太小，后续用 Godot 的 `scale` 调整。重点是透视和风格统一。

---

### 3.4 料理包（`meal_kungpao.png`）

**存放路径**: `assets/art/items/`

**主体提示词**：

```
A frozen meal package, top-down perspective, rectangular plastic bag with red label, 
sealed edges, slightly frosty texture, simple design, Chinese takeout style
```

**+ 风格后缀**

**注意**：不要生成带文字"宫保鸡丁"的版本。保持无文字，后续用 Godot Label 叠加文字。

---

### 3.5 成品菜（`dish_kungpao_plated.png`）

**存放路径**: `assets/art/items/`

**主体提示词**：

```
A plate of kung pao chicken, top-down perspective, white round ceramic plate, 
chicken pieces with peanuts and red chili peppers, steaming hot food, 
garnished with green onions, appetizing presentation
```

**+ 风格后缀**

**注意**：如果 AI 生成的菜和料理包完全不搭（比如料理包是红色袋子，成品是汉堡），没关系。Phase 1 只关心"放入加热后变成另一种东西"的逻辑，具体是什么菜不重要。

---

### 3.6 地板 Tile（`floor_tile.png`）

**存放路径**: `assets/art/environment/`

**主体提示词**：

```
A kitchen floor tile, top-down perspective, light gray ceramic tiles, 
subtle grout lines forming grid, clean surface, slight reflection, 
64x64 pixel game tile, seamless pattern
```

**+ 风格后缀**

**注意**：
- 这张图需要**可无缝拼接**（seamless）。如果 AI 生成的不完美，没关系，Phase 1 先只用一张大图当背景。
- 如果生成效果不好，可以先用**纯色背景**代替，Phase 1 不依赖复杂地板。

---

## Step 4: 素材质量检查（10 分钟）

所有 6 张素材下载后，在文件夹中并排查看：

```
order_rush/assets/art/
├── characters/
│   ├── player_chef_idle.png        ← 检查
│   └── customer_office_waiting.png  ← 检查
├── items/
│   ├── microwave_idle.png           ← 检查
│   ├── meal_kungpao.png             ← 检查
│   └── dish_kungpao_plated.png      ← 检查
└── environment/
    └── floor_tile.png               ← 检查
```

**检查清单**（全部打勾才能进入下一步）：

- [ ] 所有图片都是 **PNG 格式**（不是 JPG）
- [ ] 所有图片都尽量有**透明背景**（如果 AI 没生成透明，背景是纯色也行，后续用 Godot 处理）
- [ ] 所有图片的**透视角度一致**（都是俯视，没有侧面）
- [ ] 所有图片的**风格一致**（看起来像同一款游戏）
- [ ] 所有图片**没有文字/水印/签名**
- [ ] 文件名符合 `snake_case`（小写+下划线）
- [ ] 文件放在了正确的子目录

---

## Step 5: 导入 Godot（15 分钟）

**目标**: 在 Godot 中测试所有素材能正常显示。

**操作步骤**:

1. 打开 Godot 4.x，点击**导入**或**新建项目**
2. 选择 `order_rush/` 文件夹，加载项目
3. 在 **FileSystem** 面板（左下角），展开 `assets/art/`
4. 你应该能看到刚才放入的图片文件
5. 选中 `player_chef_idle.png`
6. 点击顶部的 **Import** 标签（在 Scene/Project/Inspector 旁边）
7. 修改设置：
   - **Filter**: 改为 `Nearest`（下拉菜单选择）
   - **Size Limit**: 设为 `512`（角色不需要太大）
8. 点击 **Reimport** 按钮（如果看不到按钮，说明文件还没被 Godot 识别，先点击一次文件）
9. 对 `customer_office_waiting.png` 重复步骤 5-8（Size Limit 512）
10. 对 `microwave_idle.png` 重复（Size Limit 512）
11. 对 `meal_kungpao.png` 和 `dish_kungpao_plated.png` 重复（Size Limit 256，物品小）
12. 对 `floor_tile.png` 重复（Size Limit 1024，保持清晰度）

**创建测试场景**:

1. 点击 **Scene** → **New Scene**
2. 选择 **Node2D** 作为根节点，命名为 `TestScene`
3. 添加 **Sprite2D** 子节点，命名为 `PlayerSprite`
4. 选中 `PlayerSprite`，在 **Inspector** 中拖动 `player_chef_idle.png` 到 `Texture` 属性
5. 按 **F5** 运行，看看角色是否正常显示
6. 重复添加其他素材的 Sprite2D，测试显示效果

**如果显示正常** → 进入 Step 6
**如果图片模糊** → 检查 Filter 是否设为 Nearest
**如果图片有白底** → 需要在 Photoshop/GIMP/在线工具中抠透明背景

---

## Step 6: Git 提交（5 分钟）

**目标**: 提交素材到 Git，标记 Phase 0 完成。

```bash
# 打开终端，进入项目目录
cd /path/to/order_rush

# 查看状态
git status

# 应该看到所有新素材文件被标记为未跟踪

# 添加所有素材
git add assets/art/

# 提交
git commit -m "asset: add Phase 0 core art assets

- 6 essential sprites for Phase 1 gameplay
- player chef, customer, microwave, meal package, dish, floor tile
- flat vector style, top-down perspective, warm colors
- imported with Filter: Nearest, size limits set"

# 如果有远程仓库，推送
git push origin main
```

**Phase 0 完成！** 🎉

---

## Step 7: 向 Kimi 汇报

复制 `docs/进度汇报模板.md` 中的**模板二：Phase 验收汇报**，填写后发送给我。

或者简化版：

```
【检查点】Phase 0 验收: 美术风格锁定
【状态】✅ 验收通过

【生成的素材】
- player_chef_idle.png → 放在 characters/
- customer_office_waiting.png → 放在 characters/
- microwave_idle.png → 放在 items/
- meal_kungpao.png → 放在 items/
- dish_kungpao_plated.png → 放在 items/
- floor_tile.png → 放在 environment/

【Godot 测试结果】
（描述：在 TestScene 中添加 Sprite2D，所有图片显示正常，Filter 已设 Nearest）

【遇到的问题】
（没有填"无"）

【Git 状态】
最新 commit: asset: add Phase 0 core art assets
```

汇报后，我会：
1. 更新进度看板为 Phase 0 完成
2. 解锁 Phase 1 的详细编码指导
3. 给出下一步的代码框架和场景搭建步骤

---

## 执行状态追踪（请手动打勾）

| Step | 任务 | 状态 | 用时 |
|------|------|------|------|
| 准备 | 确定使用即梦（或备选） | ☐ | |
| 1 | 生成风格测试图（厨师） | ☐ | ~10min |
| 2 | 检查风格一致性（再生成微波炉） | ☐ | ~5min |
| 3.1 | 生成玩家厨师 | ☐ | ~5min |
| 3.2 | 生成顾客 | ☐ | ~5min |
| 3.3 | 生成微波炉 | ☐ | ~5min |
| 3.4 | 生成料理包 | ☐ | ~5min |
| 3.5 | 生成成品菜 | ☐ | ~5min |
| 3.6 | 生成地板 Tile | ☐ | ~5min |
| 4 | 素材质量检查 | ☐ | ~10min |
| 5 | 导入 Godot，测试显示 | ☐ | ~15min |
| 6 | Git 提交 | ☐ | ~5min |
| 7 | 向 Kimi 汇报 | ☐ | ~5min |

**预计总用时**: 1-2 小时（如果 AI 生成顺利）

---

> 开始执行吧！从 Step 1 开始。遇到任何问题随时发截图给我。
