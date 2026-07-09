# 爆单时刻 — AI 美术素材生成提示词库 v1.0

> 最后更新: 2026-07-08
> 风格: 俯视角 2D 扁平插画，Q版比例，暖色高饱和
> 推荐工具: 即梦（首选，透明背景稳定）> 豆包（快速迭代）> 可灵（角色一致性）
> 版本记录: v1.0 初始版; v1.1 更新俯视角提示词（添加 overhead view / bird eye view）; v1.2 针对即梦移除独立负面提示词框（将排除要求融入正面提示词）

---

## 📌 使用指南

### 生成流程
1. **先跑风格基准测试**: 用"风格测试"提示词生成3-5张，确定最满意的一组
2. **固定风格后缀**: 选定后，所有提示词末尾加上相同的 `[风格后缀]`（见下方）
3. **逐个生成**: 每类素材先生成1张，检查透视和比例是否统一
4. **状态变体**: 有状态变化的物件（微波炉、顾客），一次生成全部变体

### 风格后缀（固定不变，贴在每个提示词末尾）

> **即梦用户注意**: 即梦没有负面提示词输入框，所有排除要求已融入下方后缀中。直接复制整段贴在提示词末尾即可。

```
Top-down perspective, flat vector illustration, warm saturated colors,
chibi proportion with big head and small body, clean bold outlines,
2D game asset, transparent background, single object centered, filling the frame,
no text, no watermark, no signature, no 3d render, no realistic, no photograph,
no gradient background, no white background, no cluttered background,
no multiple objects, no cropped, no blurry, no low quality,
no distorted perspective, no side view, no front view,
no confusing shadows, no logo, no frame, no border,
crisp edges, game-ready sprite, soft shadows,
cozy atmosphere, consistent lighting from top-left
```

### 负面提示词参考（非即梦工具使用）

> **即梦用户可忽略此区块** — 即梦没有负面提示词输入框，上述风格后缀已包含全部排除要求。
> 以下列表供豆包/可灵/Stable Diffusion 等支持负面提示词的工具参考：

```
3d render, realistic, photorealistic, photograph, gradient background,
white background, cluttered background, multiple objects, cropped,
blurry, low quality, distorted perspective, side view, front view,
confusing shadows, text, watermark, logo, signature, frame, border
```

### 推荐参数设置

| 参数 | 建议值 | 说明 |
|------|--------|------|
| 分辨率 | 1024x1024 | 正方形，俯视角最佳 |
| 比例 | 1:1 | 游戏 sprite 标准比例 |
| 背景 | 透明 | 必须勾选透明背景（PNG） |
| 风格强度 | 70-85% | 过低风格不统一，过高限制创意 |
| 生成数量 | 4张/次 | 选最佳1张，其余备用 |

---

## 一、角色类（characters/）

### 1. 玩家角色 — 厨师（player_chef.png）

**场景用途**: 玩家操控的主角，俯视角站立，手持物品姿态

**推荐工具**: 即梦（角色一致性最好）

> **⚠️ 生成经验（2026-07-08）**: 首次使用 `top-down perspective` 生成时，即梦输出为**正面正视图**（能看到完整脸部和正面身体），而非俯视角。这两张正面图被保存为 `chef_front_view_v1.png` / `v2.png`，可用作游戏 logo、标题画面、角色选择头像等 UI 素材。游戏内俯视角 sprite 需要重新生成。

**提示词 v1（正面立绘，可用作 UI/Logo）**:
```
A chibi chef character, top-down perspective, wearing white apron and red scarf,
white chef hat, standing pose, holding a small empty tray with both hands,
neutral happy expression, big round head, small body, short limbs,
flat vector illustration, warm saturated colors, clean bold outlines,
2D game asset, transparent background, single object centered, filling the frame,
no text, no watermark, crisp edges, game-ready sprite, soft shadows,
cozy atmosphere, consistent lighting from top-left
```

**提示词 v2（俯视角游戏内 sprite，推荐使用）**:
```
Overhead view, bird eye view from directly above, looking straight down from ceiling,
a chibi chef character seen from above, only the top of white chef hat visible,
shoulders and arms spread to sides, white apron and red scarf seen from above,
small body, big round head shape from top, no face visible, only top of head,
flat vector illustration, warm saturated colors, clean bold outlines,
2D game asset, transparent background, single object centered, filling the frame,
no text, no watermark, crisp edges, game-ready sprite, soft shadows,
cozy atmosphere, consistent lighting from top-left
```

**负面提示词**:
```
side view, front view, back view, walking pose, sitting, realistic, 3d,
multiple characters, cluttered background, gradient background,
text, watermark, signature, blurry, low quality
```

**变体需求**（Phase 1只需站立，后续补充）:
| 变体 | 文件名 | 修改部分 | 备注 |
|------|--------|----------|------|
| 正面立绘（UI备用） | `chef_front_view_v1.png` / `v2.png` | 手持空托盘 | 可用作 logo/头像/标题画面 |
| 俯视站立（空手） | `player_chef_idle.png` | 从上方只能看到帽子顶部 | 游戏内 sprite |
| 站立（手持物品） | `player_chef_holding.png` | 后续用代码叠加物品 | 不需要单独图 |

**Godot 导入设置**:
- Filter: Nearest
- Size Limit: 512（角色不需要太大）

---

### 2. 顾客 — 上班族（customer_office.png）

**场景用途**: 堂食顾客，手机点餐姿态

**提示词**:
```
A chibi office worker character, top-down perspective, wearing blue shirt and black pants,
holding a smartphone in right hand, looking at phone, standing pose,
big round head, small body, short limbs, casual hairstyle,
flat vector illustration, warm saturated colors, clean bold outlines,
2D game asset, transparent background, single object centered, filling the frame,
no text, no watermark, crisp edges, game-ready sprite, soft shadows,
cozy atmosphere, consistent lighting from top-left
```

**变体需求**:
| 变体 | 文件名 | 描述 |
|------|--------|------|
| 等待中 | `customer_office_waiting.png` | 看手机，耐心条状态 |
| 用餐中 | `customer_office_eating.png` | 手持筷子，面前有碗 |
| 满意离开 | `customer_office_happy.png` | 微笑，竖大拇指 |

**Godot 导入设置**:
- Filter: Nearest
- Size Limit: 512

---

### 3. 顾客 — 学生（customer_student.png）

**场景用途**: 增加顾客多样性，背着书包

**提示词**:
```
A chibi student character, top-down perspective, wearing red hoodie and jeans,
carrying a backpack, holding a phone, standing pose, big round head,
small body, short limbs, youthful hairstyle,
flat vector illustration, warm saturated colors, clean bold outlines,
2D game asset, transparent background, single object centered, filling the frame,
no text, no watermark, crisp edges, game-ready sprite, soft shadows,
cozy atmosphere, consistent lighting from top-left
```

**变体**: 同上班族（waiting/eating/happy）

---

## 二、物品类（items/）

### 4. 料理包 — 宫保鸡丁（meal_kungpao.png）

**场景用途**: 从冰柜取出，未加热的预制菜包装

**提示词**:
```
A frozen meal package, top-down perspective, rectangular plastic bag with red label,
"宫保鸡丁" text area (blank), sealed edges, slightly frosty texture,
flat vector illustration, warm saturated colors, clean bold outlines,
2D game asset, transparent background, single object centered, filling the frame,
no text, no watermark, crisp edges, game-ready sprite, soft shadows,
cozy atmosphere, consistent lighting from top-left
```

**注意**: 如需中文标签，先生成无文字版本，后期用 Godot Label 节点叠加文字。

**Godot 导入设置**:
- Filter: Nearest
- Size Limit: 256（小物品不需要太大）

---

### 5. 料理包 — 鱼香肉丝（meal_yuxiang.png）【可选】

**提示词**:
```
A frozen meal package, top-down perspective, rectangular plastic bag with green label,
sealed edges, slightly frosty texture,
flat vector illustration, warm saturated colors, clean bold outlines,
2D game asset, transparent background, single object centered, filling the frame,
no text, no watermark, crisp edges, game-ready sprite
```

---

### 6. 成品菜 — 宫保鸡丁装盘（dish_kungpao_plated.png）

**场景用途**: 微波炉加热完成后，玩家端给顾客

**提示词**:
```
A plate of kung pao chicken, top-down perspective, white round ceramic plate,
chicken pieces with peanuts and red chili peppers, steaming hot food,
garnished with green onions, appetizing presentation,
flat vector illustration, warm saturated colors, clean bold outlines,
2D game asset, transparent background, single object centered, filling the frame,
no text, no watermark, crisp edges, game-ready sprite, soft shadows,
cozy atmosphere, consistent lighting from top-left
```

**变体**:
| 变体 | 文件名 | 描述 |
|------|--------|------|
| 普通装盘 | `dish_kungpao_plated.png` | 标准版本 |
| 带蒸汽（可选）| `dish_kungpao_steam.png` | 加热刚取出时 |

---

### 7. 外卖袋（takeaway_bag.png）

**场景用途**: Phase 4 外卖系统，打包好的外卖袋

**提示词**:
```
A takeaway food bag, top-down perspective, white paper bag with red logo area,
folded top, slightly bulging from food inside,
flat vector illustration, warm saturated colors, clean bold outlines,
2D game asset, transparent background, single object centered, filling the frame,
no text, no watermark, crisp edges, game-ready sprite
```

---

## 三、设备类（items/ 或 environment/）

### 8. 微波炉 — 空闲状态（microwave_idle.png）

**场景用途**: 核心设备，可交互对象

> ⚠️ **注意（2026-07-08）**: 当前版本（004批次）为正面+顶部3/4视角，非严格俯视角。
> 透明背景未生效，需后期抠图。作为 Phase 0 占位使用，**后续需重新生成严格俯视角版本**。
> 重生成提示词调整：加强"只能看到顶面，完全看不到正面"的描述。

**提示词（v3 即梦精简版，2026-07-08 通过）**:
```
俯视正上方，从天花板正下方看，一台微波炉，银色机身，
黑色玻璃门，右侧控制面板，扁平矢量插画，Q版比例，
粗线条描边，2D游戏素材，画面居中，清晰边缘，
柔和阴影，温馨氛围，左上光源
```

> 即梦设置：透明背景勾选、1024×1024、1:1、风格强度75%
> 生成结果：4张均为正面+顶部视角，v2 选中（最简洁，白色背景方便抠图）
> 后续重生成建议：在提示词中加入"只能看到顶面，完全看不到正面"

**变体（必须全部生成，状态切换用）**:
| 状态 | 文件名 | 与空闲的区别 | 提示词修改 |
|------|--------|-------------|-----------|
| 空闲 | `microwave_idle.png` | 绿色指示灯 | 基础版 |
| 加热中 | `microwave_heating.png` | 黄色指示灯，内部发光 | + "yellow indicator light glowing, internal warm light visible through door" |
| 完成 | `microwave_done.png` | 红色指示灯闪烁 | + "red indicator light blinking, done state" |

**建议**: 也可以只生成一张 `microwave_base.png`，然后在 Godot 中用 `IndicatorSprite` 节点（彩色圆点）显示状态，更灵活。

**Godot 导入设置**:
- Filter: Nearest
- Size Limit: 512

---

### 9. 冰柜/冰箱（fridge.png）

**场景用途**: 取料理包的来源，储物设备

**提示词**:
```
A commercial refrigerator, top-down perspective, white double-door fridge,
metal handles, slightly worn texture, rectangular shape,
flat vector illustration, warm saturated colors, clean bold outlines,
2D game asset, transparent background, single object centered, filling the frame,
no text, no watermark, crisp edges, game-ready sprite
```

---

### 10. 炒锅（wok.png）【Phase 2准备】

**场景用途**: Level 2 即烹设备

**提示词**:
```
A Chinese wok on stove, top-down perspective, black round wok with handles,
sitting on gas burner, red and blue flame visible, kitchen environment,
flat vector illustration, warm saturated colors, clean bold outlines,
2D game asset, transparent background, single object centered, filling the frame,
no text, no watermark, crisp edges, game-ready sprite
```

---

### 11. 餐桌（table_dining.png）

**场景用途**: 顾客用餐位置

**提示词**:
```
A dining table with chairs, top-down perspective, square wooden table,
4 wooden chairs around it, simple design, light brown wood texture,
flat vector illustration, warm saturated colors, clean bold outlines,
2D game asset, transparent background, single object centered, filling the frame,
no text, no watermark, crisp edges, game-ready sprite
```

---

## 四、环境类（environment/）

### 12. 地板 Tile（floor_tile.png）

**场景用途**: 店铺地面，可拼接重复

**提示词**:
```
A kitchen floor tile, top-down perspective, light gray ceramic tiles,
subtle grout lines forming grid, clean surface, slight reflection,
64x64 pixel game tile, seamless pattern,
flat vector illustration, warm saturated colors, clean bold outlines,
2D game asset, transparent background, single object centered, filling the frame,
no text, no watermark, crisp edges, game-ready sprite
```

**Godot 使用方式**:
1. 导入为 `Texture`
2. 创建 `TileMapLayer` 节点
3. 在 `TileSet` 中配置此图作为 atlas tile
4. 设置 Tile Size: 64x64

**Godot 导入设置**:
- Filter: Nearest（必须！Tile 不能模糊）
- Repeat: Enabled（如果需要无缝重复）

---

### 13. 墙壁/柜台（counter.png）

**场景用途**: 店铺边界，阻挡玩家移动

**提示词**:
```
A kitchen counter, top-down perspective, L-shaped wooden counter,
light brown wood with metal edge, clean surface,
flat vector illustration, warm saturated colors, clean bold outlines,
2D game asset, transparent background, single object centered, filling the frame,
no text, no watermark, crisp edges, game-ready sprite
```

---

### 14. 店铺背景（shop_background.png）【可选】

**场景用途**: 整个店铺俯视角全貌，可作为底图参考

**提示词**:
```
A small Chinese restaurant interior, top-down perspective,
3 dining tables, kitchen counter, fridge, microwave on shelf,
warm lighting, cozy atmosphere, clean and organized,
flat vector illustration, warm saturated colors, clean bold outlines,
2D game asset, transparent background, filling the frame,
no text, no watermark, crisp edges, game-ready sprite
```

**注意**: 这张只作为布局参考，实际游戏中用 TileMap + 独立物件搭建场景，不要直接当背景图。

---

## 五、UI 类（ui/）

### 15. 订单气泡（ui_order_bubble.png）

**场景用途**: 顾客头顶显示订单内容

**提示词**:
```
A speech bubble UI element, top-down perspective, rounded rectangle shape,
white background with orange border, small triangle pointer at bottom,
clean and simple, game UI,
flat vector illustration, warm saturated colors, clean bold outlines,
2D game asset, transparent background, single object centered, filling the frame,
no text, no watermark, crisp edges, game-ready sprite
```

**Godot 使用方式**: 用 `NinePatchRect` 节点，配置此图为纹理，设置可拉伸区域。

---

### 16. 耐心条背景（ui_patience_bar_bg.png）

**提示词**:
```
A progress bar background UI element, horizontal rectangle,
light gray fill with dark gray border, rounded corners,
flat vector illustration, clean simple design,
2D game asset, transparent background, single object centered, filling the frame,
no text, no watermark, crisp edges, game-ready sprite
```

### 17. 耐心条填充（ui_patience_bar_fill.png）

**提示词**:
```
A progress bar fill UI element, horizontal rectangle,
gradient from green to yellow to red, rounded corners,
flat vector illustration, clean simple design,
2D game asset, transparent background, single object centered, filling the frame,
no text, no watermark, crisp edges, game-ready sprite
```

**Godot 使用方式**: `TextureProgressBar` 节点，bg 为背景，fill 为填充。

---

### 18. 按钮背景（ui_button_normal.png / ui_button_pressed.png）

**提示词（普通）**:
```
A game button UI element, rounded rectangle, orange fill with white border,
3D slightly raised effect, clean and simple,
flat vector illustration, warm saturated colors, clean bold outlines,
2D game asset, transparent background, single object centered, filling the frame,
no text, no watermark, crisp edges, game-ready sprite
```

**提示词（按下）**:
```
A game button UI element, rounded rectangle, darker orange fill with white border,
3D slightly pressed effect, clean and simple,
flat vector illustration, warm saturated colors, clean bold outlines,
2D game asset, transparent background, single object centered, filling the frame,
no text, no watermark, crisp edges, game-ready sprite
```

---

## 六、Phase 0 最小素材清单（必须先生成这些）

Phase 1 可运行所需的最少素材（6张）：

| 优先级 | 素材 | 文件名 | 存放路径 |
|--------|------|--------|----------|
| P0 | 玩家厨师 | `player_chef_idle.png` | `assets/art/characters/` |
| P0 | 顾客上班族 | `customer_office_waiting.png` | `assets/art/characters/` |
| P0 | 微波炉基础 | `microwave_idle.png` | `assets/art/items/` |
| P0 | 料理包 | `meal_kungpao.png` | `assets/art/items/` |
| P0 | 成品菜 | `dish_kungpao_plated.png` | `assets/art/items/` |
| P0 | 地板Tile | `floor_tile.png` | `assets/art/environment/` |

**有了这6张，Phase 1 就可以开始编码了。** 其他素材可以在 Phase 1 开发过程中陆续补充。

---

## 七、生成工具对照与技巧

### 即梦（推荐）
- **优点**: 透明背景最稳定，游戏 asset 生成效果好
- **缺点**: 免费额度有限
- **技巧**: 勾选"透明背景"，一次生成4张选最佳
- **适合**: 所有角色、设备、物品

### 豆包
- **优点**: 速度快，免费额度多
- **缺点**: 透明背景不稳定，需要后期抠图
- **技巧**: 先生成带纯色背景的，用 remove.bg 或 Photoshop 抠图
- **适合**: 快速迭代、测试 prompt、环境/背景类

### 可灵
- **优点**: 角色一致性最好，同角色多姿态稳定
- **缺点**: 游戏 asset 不是强项
- **技巧**: 用"角色参考"功能锁定角色形象
- **适合**: 需要多姿态的角色（后续Phase）

---

## 八、素材导入 Godot 检查清单

每导入一张素材，按以下步骤操作：

1. [ ] 将 PNG 放入正确的子目录（`characters/`、`items/`、`environment/`、`ui/`）
2. [ ] 在 Godot **FileSystem** 面板中选中该文件
3. [ ] 切换到 **Import** 标签
4. [ ] 设置 **Filter** = `Nearest`（扁平风格必须！）
5. [ ] 设置 **Size Limit**（角色512，物品256，环境512）
6. [ ] 点击 **Reimport**
7. [ ] 创建测试 Sprite2D 节点，确认显示正常
8. [ ] 在文件名后打勾，记录到本文件的"素材状态"部分

---

## 九、素材状态记录表

> 由开发者手动维护，生成并导入后在此打勾。

| 序号 | 素材名 | 文件路径 | 生成状态 | 导入状态 | 测试通过 | 备注 |
|------|--------|----------|----------|----------|----------|------|
| 1 | 玩家厨师（俯视角） | `characters/player_chef_idle.png` | ✅ | ☐ | ☐ | 002批次v1选中 |
| 1a | 玩家厨师正面立绘 | `characters/chef_front_view_v1.png` | ✅ | ☐ | ☐ | UI备用（logo/头像） |
| 1b | 玩家厨师正面立绘 | `characters/chef_front_view_v2.png` | ✅ | ☐ | ☐ | UI备用（logo/头像） |
| 2 | 顾客上班族 | `characters/customer_office_waiting.png` | ✅ | ☐ | ☐ | 003批次v1选中 |
| 3 | 微波炉 | `items/microwave_idle.png` | ✅（占位） | ☐ | ☐ | 004批次v2，需后续重生成 |
| 4 | 料理包 | `items/meal_kungpao.png` | ✅ | ☐ | ☐ | 005批次v2，无文字空白标签 |
| 5 | 成品菜 | `items/dish_kungpao_plated.png` | ✅ | ☐ | ☐ | 006批次v2，透明背景+蒸汽 |
| 6 | 地板Tile | `environment/floor_tile.png` | ✅ | ☐ | ☐ | 007批次v4，十字勾缝适合拼接 |
| 7 | 顾客学生 | `characters/customer_student.png` | ☐ | ☐ | ☐ | 可选 |
| 8 | 冰柜 | `items/fridge.png` | ☐ | ☐ | ☐ | 可选 |
| 9 | 炒锅 | `items/wok.png` | ☐ | ☐ | ☐ | Phase 2 |
| 10 | 餐桌 | `items/table_dining.png` | ☐ | ☐ | ☐ | 可选 |
| 11 | 订单气泡 | `ui/ui_order_bubble.png` | ☐ | ☐ | ☐ | Phase 2 |
| 12 | 耐心条 | `ui/ui_patience_bar_*.png` | ☐ | ☐ | ☐ | Phase 2 |
| 13 | 按钮 | `ui/ui_button_*.png` | ☐ | ☐ | ☐ | Phase 3+ |

---

> 完成 Phase 0 全部素材后，使用 `进度汇报模板` 向 Kimi 汇报，解锁 Phase 1 详细编码指导。
