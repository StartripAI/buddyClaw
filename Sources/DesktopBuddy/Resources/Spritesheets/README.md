# Spritesheets

BuddyClaw V1 的像素宠物资源不是普通展示图，而是要直接进入运行时裁切和播放的生产资产。
如果只追求“看起来可爱”，但没有统一布局、统一基线和统一帧顺序，最终效果就会出现切错、拉伸、马赛克、角色飘移、状态跳变等问题。

这份规范的目标是把“生成图片”变成“生成可落地资产”。

## 为什么现在会看起来像马赛克

当前仓库里已有的 PNG 更接近展示稿，而不是严格的运行时 spritesheet：

- 有的图是 `2x2` 大格布局，有的更像 `4x1` 横条
- 部分图透明留白太大，真实角色只占画布很小一部分
- 部分图存在分隔线、导出辅助线或预览感
- 各物种的脚底基线不一致，导致播放时像“上下跳”
- 同一角色的 4 帧动作差异过大，像是 4 个不同角色

而当前运行时代码需要的是“稳定、统一、可裁切”的精灵表。

## V1 统一标准

首发版本统一采用一套最稳的基础格式：

- 文件格式：`PNG`
- 背景：`透明`
- 基础动画：`4 列 x 1 行`
- 单格尺寸：`256x256`
- 总尺寸：`1024x256`
- 单个文件只放一个物种
- 不放背景、不放地面、不放 UI、不放文字、不放边框
- 不放棋盘格、不放参考线、不放导出分隔线

这是当前最稳、最容易批量生产、也最适合后续代码接入的方案。

## 文件命名

文件名必须与 `Species` 枚举值一致。

当前支持的物种键如下：

- `duck`
- `goose`
- `blob`
- `cat`
- `dragon`
- `octopus`
- `owl`
- `penguin`
- `turtle`
- `snail`
- `ghost`
- `axolotl`
- `capybara`
- `cactus`
- `robot`
- `rabbit`
- `mushroom`
- `chonk`

示例：

- `cat.png`
- `robot.png`
- `axolotl.png`

## 当前资源覆盖情况

仓库目前已有正式 PNG 的物种：

- `cat`
- `dragon`
- `duck`
- `ghost`
- `penguin`
- `robot`

其余物种若没有对应 PNG，会回退到 ASCII 渲染。

建议优先补齐以下高辨识度物种：

1. `goose`
2. `blob`
3. `axolotl`
4. `rabbit`
5. `capybara`
6. `mushroom`

## 单格构图规则

每一帧都必须满足以下规则：

- 角色始终朝同一方向，推荐默认朝右
- 角色缩放比例固定，不能一帧胖一帧瘦
- 角色脚底必须落在同一高度
- 角色整体位于画面中央偏下
- 头顶保留少量安全边距，不要顶格
- 左右留白尽量一致
- 不要因为动作大而改变角色在格子里的锚点

推荐占比：

- 角色总高度占单格高度的 `70% ~ 80%`
- 左右安全边距各保留约 `10% ~ 15%`
- 底部安全边距建议 `8% ~ 12%`

## 4 帧顺序

V1 基础 sheet 的 4 帧顺序固定如下：

1. `idle_1`：站立待机主帧
2. `idle_2`：轻微呼吸或眨眼
3. `walk_1`：左脚向前或身体轻微向前倾
4. `walk_2`：右脚向前或身体轻微反向摆动

注意：

- 帧与帧之间只能是“小幅动作变化”
- 不要换表情体系
- 不要换比例
- 不要换朝向
- 不要让第 3、4 帧变成“奔跑”或“跳跃”

## 像素风格规则

BuddyClaw 的目标不是插画感，而是“桌面宠物像素精灵”。

风格上必须坚持：

- 纯 `pixel art`
- 轮廓清晰
- 像素块明确
- 禁止平滑抗锯齿
- 禁止厚涂、写实、半写实
- 禁止强景深、摄影感高光、复杂材质
- 配色控制在简洁范围内，建议 `8 ~ 16` 个主色
- 外轮廓颜色稳定，优先深棕或深灰，不建议纯黑过重

不建议：

- 毛发细节过多
- 渐变过密
- 单帧里有太多小装饰
- 一只角色同时包含太多颜色分区

## 透明背景规范

必须满足：

- 背景完全透明
- 不允许保留灰底、白底、彩底
- 不允许包含棋盘格贴图
- 不允许带“演示用底座”或投影阴影

如果模型很容易偷偷加背景，请在 prompt 中重复强调：

- `transparent background`
- `no background`
- `no floor`
- `no shadow`
- `no border`
- `no checkerboard`

## 推荐生产流程

### 路线 A：最省心

直接生成一张 `1024x256` 的 `4x1` spritesheet。

适合：

- 模型对 spritesheet 输出稳定
- 你希望一次拿到可预览结果

### 路线 B：最稳

先分别生成 4 张单帧图，再手动或脚本拼成一个 sheet。

适合：

- 你要求一致性最高
- 你发现模型一次出整张 sheet 时容易串帧
- 你想先挑最好的单帧再组合

如果走路线 B，单帧仍然要遵循同样的构图规则，最后按固定顺序拼接。

## 单帧生产规范

如果采用逐帧生成，单帧建议：

- 输出尺寸：`512x512` 或 `1024x1024`
- 透明背景
- 角色居中偏下
- 只生成单个角色
- 不带任何装饰物

之后在拼表前做一次统一：

- 缩放统一
- 脚底基线统一
- 左右留白统一
- 最终每格裁成 `256x256`

## 当前版本建议只做一个基础状态

为了保证首发质量，建议先做“基础待机/行走 4 帧”。

不要一开始就要求模型一次产出：

- 待机
- 说话
- 抚摸
- 睡觉
- 跳跃
- 进化

这会让一致性明显下降。

推荐交付节奏：

1. 先把所有物种的 `4x1` 基础 sheet 做稳
2. 再补扩展状态
3. 扩展状态优先级：`talk` -> `sleep` -> `pet` -> `jump` -> `evolve`

## 扩展状态规划

后续如果你要做完整动画集，推荐拆成多个独立文件，而不是塞进一张超大图。

推荐命名：

- `cat.base.png`
- `cat.talk.png`
- `cat.sleep.png`
- `cat.pet.png`
- `cat.jump.png`
- `cat.evolve.png`

对应帧数建议：

- `base`：4 帧
- `talk`：2 到 4 帧
- `sleep`：2 到 4 帧
- `pet`：2 到 4 帧
- `jump`：4 帧
- `evolve`：4 到 6 帧

但在 V1，没有必要一开始就做全套。

## 验收标准

一张图只有同时满足以下条件，才算可以进仓库：

- 打开后背景完全透明
- 没有棋盘格、边框、文字、导出线
- 总尺寸正确
- 每格尺寸正确
- 4 帧顺序正确
- 角色脚底基线一致
- 角色大小一致
- 角色朝向一致
- 帧间动作变化自然
- 放大到 `400%` 看，边缘仍然干净，不是模糊插值

## 常见失败模式

### 1. 看起来像“马赛克”

常见真实原因不是分辨率低，而是：

- 角色只占单格很小一部分，被代码放大后显得碎
- 模型画的不是像素风，而是普通插画被硬缩小
- 输出自带插值和平滑边缘

### 2. 播放时角色上下抖

原因通常是：

- 4 帧脚底不在同一基线
- 每帧的透明留白不同

### 3. 播放时像换了 4 只宠物

原因通常是：

- 模型没有保持角色 identity
- 一次要求动作太多
- 每帧姿态变化过大

### 4. 切出来位置不对

原因通常是：

- 不是标准 `4x1`
- 单格尺寸不一致
- 图里藏了分隔线或额外边距

## 面向图像大模型的通用 Prompt 模板

把下面模板里的 `{物种}` 替换掉即可：

```text
请为一个 macOS 桌面宠物应用设计像素风精灵表。

主题：一只{物种}
风格：复古 2D pixel art，Q版，可爱，清晰像素边缘，适合桌面宠物，不要写实，不要3D，不要厚涂，不要插画海报感

输出要求：
- transparent background
- sprite sheet
- 4 columns, 1 row
- each frame 256x256
- total image size 1024x256
- same character in all four frames
- same scale in all four frames
- same facing direction in all four frames
- same foot baseline in all four frames
- character centered slightly lower in each frame
- no background
- no floor
- no shadow
- no text
- no border
- no checkerboard
- no guide lines

四帧顺序：
1. idle standing
2. subtle breathing or blinking
3. walk frame with left foot forward
4. walk frame with right foot forward

细节要求：
- crisp pixel art
- no anti-aliasing
- limited color palette
- stable silhouette
- cute desktop companion feeling
- only small motion changes between frames
```

## 通用负面 Prompt

```text
realistic, semi-realistic, painterly, blurry, anti-aliased, 3d render, glossy, cinematic lighting, watercolor, soft shading, poster illustration, background scene, floor, ground shadow, text, border, UI, checkerboard background, guide lines, inconsistent character design, different camera angle, different scale, extra limbs, deformed anatomy
```

## 中文版 Prompt 模板

```text
请生成一个适用于 macOS 桌面宠物应用的像素风精灵表。

主角：{物种}
视觉方向：复古 2D pixel art，Q版，可爱，轮廓清晰，像素块明确，适合作为桌面悬浮宠物。

严格要求：
- 透明背景
- 单张 sprite sheet
- 4列1行
- 每格 256x256
- 总尺寸 1024x256
- 同一个角色连续4帧
- 4帧保持同一朝向、同一比例、同一脚底基线
- 角色位于每格中间偏下
- 不要背景，不要地面，不要投影，不要文字，不要边框，不要棋盘格，不要分隔线
- 不要写实，不要3D，不要插画厚涂，不要模糊边缘，不要抗锯齿

帧顺序：
1. 站立待机
2. 轻微呼吸或眨眼
3. 左脚向前的轻微行走帧
4. 右脚向前的轻微行走帧

风格补充：
- 用色简洁
- 外轮廓稳定
- 各帧动作变化小但清晰
- 角色具有陪伴感和亲和力
```

## 更稳的逐帧 Prompt 模板

如果模型一次做整张 spritesheet 不稳定，改用逐帧生成。

单帧模板：

```text
请生成一个适用于 macOS 桌面宠物应用的像素风角色单帧。

主角：{物种}
动作：{站立待机 / 轻微呼吸 / 左脚前行走 / 右脚前行走}

严格要求：
- 透明背景
- 单个角色
- 正方形画布
- 角色位于中央偏下
- 角色脚底清晰，方便后续统一基线
- 纯 pixel art
- 边缘锐利
- 不要背景，不要投影，不要文字，不要边框，不要棋盘格
- 保持与其他帧同一角色、同一体型、同一朝向
```

## 物种专项补充词

以下补充词建议加在通用 prompt 后面，用于稳定角色设定。

### duck

- 小黄鸭
- 圆润身体
- 橙色扁嘴
- 短腿

### goose

- 白色小鹅
- 长脖子
- 橙色嘴和脚
- 有一点认真表情

### blob

- 果冻史莱姆
- 柔软轮廓
- 半透明感但仍保持像素风
- 简单脸部表情

### cat

- 橘猫或奶牛猫
- 圆脸
- 小耳朵
- 短尾巴

### dragon

- 幼龙
- 小翅膀
- 短尾巴
- 可爱而不是凶猛

### octopus

- 小章鱼
- 头大身小
- 触手简化
- 不要过多吸盘细节

### owl

- 圆头猫头鹰
- 大眼睛
- 小翅膀贴身

### penguin

- 小企鹅
- 黑白配色
- 橙色嘴脚
- 圆滚滚

### turtle

- 小乌龟
- 壳体圆润
- 四肢简化
- 低重心

### snail

- 小蜗牛
- 壳体醒目
- 触角简化
- 行动缓慢但可爱

### ghost

- 小幽灵
- 漂浮裙边
- 软糯表情
- 不要恐怖风

### axolotl

- 六角恐龙
- 两侧外鳃明显
- 粉色或浅色系
- 表情呆萌

### capybara

- 卡皮巴拉
- 长方圆润身体
- 平静治愈感
- 小耳朵小眼睛

### cactus

- 拟人小仙人掌
- 圆柱或团状轮廓
- 小花盆可选，但不建议 V1 带底座
- 表情简单

### robot

- 小机器人
- 方形头或圆角机身
- 简单面屏表情
- 机械细节克制

### rabbit

- 小兔子
- 长耳朵
- 短尾巴
- 站姿轻盈

### mushroom

- 蘑菇生物
- 菌盖醒目
- 身体很简洁
- 森林精灵感但不要背景

### chonk

- 团子感生物
- 极简圆润轮廓
- 肥嘟嘟
- 重点在轮廓可爱和辨识度

## 推荐的补图顺序

如果你要批量生产，建议按下面顺序做：

1. `goose`
2. `blob`
3. `axolotl`
4. `rabbit`
5. `capybara`
6. `mushroom`
7. `octopus`
8. `owl`
9. `turtle`
10. `snail`
11. `cactus`
12. `chonk`

这些角色能明显提升“宠物池”的丰富度，同时又比较适合像素风表达。

## 入库前自检

拿到图后，入库前至少做这 10 个检查：

1. 文件名是否与物种 key 完全一致
2. 是否为透明 PNG
3. 是否为 `1024x256`
4. 是否严格 `4x1`
5. 是否没有文字、边框、棋盘格、分隔线
6. 4 帧角色是否确实是同一只
7. 脚底是否对齐
8. 放大后是否仍是清晰像素边缘
9. 角色在每格中的占比是否一致
10. 第 3、4 帧是否只是轻微走路，而不是大动作

## 给设计师或外包方的一句话要求

如果你只想给对方一句最核心的话，用这句：

“请按桌面宠物运行时资产来做，不要做展示海报；我要透明背景、4x1、每格 256x256、同一角色同一基线的纯像素风 spritesheet。” 
