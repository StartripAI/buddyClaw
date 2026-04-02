# BuddyClaw Sprite Rework Pack

这份文件只处理“需要重生”的 spritesheet。
目标不是泛泛优化，而是逐张把错误说清楚，然后给出可直接投喂图像模型的修正 prompt。

## 当前必须重生的文件

- `dragon.png`
- `ghost.png`
- `chonk.png`
- `mushroom.png`
- `penguin.png`
- `rabbit.png`
- `owl.png`
- `robot.png`

这些图的问题已经不是“透明背景”了，而是“结构不符合运行时资产规范”。

统一问题主要有三类：

1. 把两个半身状态拼进同一张图，而不是 4 个完整角色帧
2. 每一帧不是完整角色，只是头部或身体局部
3. 带了不该出现的文字标签、说明字样或展示稿痕迹

## 所有返工图的统一硬约束

下面这些要求每张图都要加，不要省略：

```text
transparent background
sprite sheet
4 columns, 1 row
each frame 256x256
total image size 1024x256
same full-body character in all four frames
same scale in all four frames
same facing direction in all four frames
same foot baseline in all four frames
full character visible in every frame
character centered slightly lower in each frame
no text
no labels
no border
no guide lines
no checkerboard
no split-body layout
no separate head and body rows
no cropped body parts
no anti-aliasing
```

统一负面词：

```text
realistic, painterly, blurry, anti-aliased, 3d render, glossy, poster, concept art, text, labels, watermark, border, checkerboard background, guide lines, body split across rows, separate head row, cropped character, partial body, multiple different characters
```

## 1. dragon.png

### 当前问题

- 现在这张图左半像是龙头待机，右半像是另一套身体动作
- 不是 4 个完整 frame
- 角色 identity 不连续

### 重生目标

- 做成同一只小绿龙的 4 个完整帧
- 每帧都必须看见完整头、身体、翅膀、尾巴
- 动作变化小，不要换成两套造型

### 精确 Prompt

```text
请生成一个适用于 macOS 桌面宠物应用的像素风 spritesheet。

主角：一只可爱的小绿龙，幼龙，圆头，小翅膀，短尾巴，亲和而不凶

严格要求：
- transparent background
- sprite sheet
- 4 columns, 1 row
- each frame 256x256
- total image size 1024x256
- same full-body baby dragon in all four frames
- full character visible in every frame
- same scale in all four frames
- same facing direction in all four frames
- same foot baseline in all four frames
- character centered slightly lower in each frame
- no text
- no labels
- no border
- no guide lines
- no checkerboard
- no split-body layout
- no separate head row
- no cropped body parts
- no anti-aliasing

Frame order:
1. idle standing
2. subtle blink or breathing
3. walk frame with left foot forward
4. walk frame with right foot forward

Style:
- retro 2D pixel art
- cute desktop companion
- crisp edges
- stable silhouette
- limited color palette
- only small motion changes between frames
```

## 2. ghost.png

### 当前问题

- 现在像是“上排表情 / 下排裙摆”拼贴
- 每帧不是完整幽灵
- 运行时裁切后会像残片

### 重生目标

- 4 个完整的小幽灵帧
- 每帧都要包含完整轮廓、脸、下摆
- 保持同一个幽灵，不要一帧圆一帧扁得太夸张

### 精确 Prompt

```text
请生成一个适用于 macOS 桌面宠物应用的像素风 spritesheet。

主角：一只可爱的小幽灵，软糯轮廓，友好表情，不恐怖

严格要求：
- transparent background
- sprite sheet
- 4 columns, 1 row
- each frame 256x256
- total image size 1024x256
- same full-body ghost in all four frames
- full character visible in every frame
- same scale in all four frames
- same facing direction in all four frames
- same bottom contour baseline in all four frames
- character centered slightly lower in each frame
- no text
- no labels
- no border
- no guide lines
- no checkerboard
- no split-body layout
- no separate face row
- no separate lower-body row
- no cropped body parts
- no anti-aliasing

Frame order:
1. idle floating
2. subtle blink
3. float drift frame left
4. float drift frame right

Style:
- retro 2D pixel art
- cute desktop companion
- soft floating silhouette
- crisp edges
- limited color palette
```

## 3. chonk.png

### 当前问题

- 现在前两帧像脸，后两帧像肚子/下半身
- 不是完整角色
- 角色识别被拆开了

### 重生目标

- 一只完整的团子兽
- 四帧都必须是完整圆润生物
- 重点是“完整轮廓”而不是局部表情特写

### 精确 Prompt

```text
请生成一个适用于 macOS 桌面宠物应用的像素风 spritesheet。

主角：一只超圆润、肥嘟嘟的团子生物，极简脸，强 mascot 感，可爱治愈

严格要求：
- transparent background
- sprite sheet
- 4 columns, 1 row
- each frame 256x256
- total image size 1024x256
- same full-body chubby round creature in all four frames
- full character visible in every frame
- same scale in all four frames
- same facing direction in all four frames
- same foot baseline in all four frames
- character centered slightly lower in each frame
- no text
- no labels
- no border
- no guide lines
- no checkerboard
- no cropped face-only frames
- no cropped belly-only frames
- no split-body layout
- no anti-aliasing

Frame order:
1. idle standing
2. subtle blink
3. tiny step left
4. tiny step right

Style:
- retro 2D pixel art
- very simple silhouette
- stable body shape
- soft pink palette allowed
- only small motion changes
```

## 4. mushroom.png

### 当前问题

- 现在前半是蘑菇，后半像另一只米色小生物
- 角色不一致
- 同一张图里像是两个不同物种

### 重生目标

- 同一只“蘑菇生物”连续 4 帧
- 菌盖和身体必须始终在一起
- 每帧都要是完整角色

### 精确 Prompt

```text
请生成一个适用于 macOS 桌面宠物应用的像素风 spritesheet。

主角：一只可爱的蘑菇生物，红色菌盖带白点，小巧身体，整体是同一个完整角色

严格要求：
- transparent background
- sprite sheet
- 4 columns, 1 row
- each frame 256x256
- total image size 1024x256
- same full-body mushroom creature in all four frames
- mushroom cap and body must stay together in every frame
- full character visible in every frame
- same scale in all four frames
- same facing direction in all four frames
- same foot baseline in all four frames
- character centered slightly lower in each frame
- no text
- no labels
- no border
- no guide lines
- no checkerboard
- no separate cap-only frames
- no separate body-only frames
- no second creature design
- no anti-aliasing

Frame order:
1. idle standing
2. subtle blink
3. walk frame with left foot forward
4. walk frame with right foot forward

Style:
- retro 2D pixel art
- whimsical but clean
- consistent silhouette
- limited color palette
```

## 5. penguin.png

### 当前问题

- 现在前半像企鹅头部，后半像身体下半截
- 不是完整企鹅 frame
- 裁切时会完全错

### 重生目标

- 一只完整小企鹅的 4 帧
- 每帧都包含完整头、身体、脚
- 保持圆滚滚的桌宠感

### 精确 Prompt

```text
请生成一个适用于 macOS 桌面宠物应用的像素风 spritesheet。

主角：一只圆滚滚的小企鹅，黑白配色，橙色嘴和脚，友好可爱

严格要求：
- transparent background
- sprite sheet
- 4 columns, 1 row
- each frame 256x256
- total image size 1024x256
- same full-body penguin in all four frames
- full character visible in every frame
- same scale in all four frames
- same facing direction in all four frames
- same foot baseline in all four frames
- character centered slightly lower in each frame
- no text
- no labels
- no border
- no guide lines
- no checkerboard
- no head-only frames
- no lower-body-only frames
- no split-body layout
- no anti-aliasing

Frame order:
1. idle standing
2. subtle blink
3. tiny waddle left foot forward
4. tiny waddle right foot forward

Style:
- retro 2D pixel art
- desktop companion feeling
- soft rounded silhouette
- crisp edges
```

## 6. rabbit.png

### 当前问题

- 现在前半像兔头，后半像身体残片
- 角色被拆开了
- 不是完整兔兔动画

### 重生目标

- 同一只完整兔兔 4 帧
- 长耳朵要保留，但每帧都必须是完整角色
- 不要做成头像 + 身体拆分结构

### 精确 Prompt

```text
请生成一个适用于 macOS 桌面宠物应用的像素风 spritesheet。

主角：一只可爱小兔子，长耳朵，短尾巴，轻盈柔和，完整角色轮廓清晰

严格要求：
- transparent background
- sprite sheet
- 4 columns, 1 row
- each frame 256x256
- total image size 1024x256
- same full-body rabbit in all four frames
- full character visible in every frame
- same scale in all four frames
- same facing direction in all four frames
- same foot baseline in all four frames
- character centered slightly lower in each frame
- no text
- no labels
- no border
- no guide lines
- no checkerboard
- no head-only frames
- no body fragment frames
- no split-body layout
- no anti-aliasing

Frame order:
1. idle standing
2. subtle blink
3. light step left
4. light step right

Style:
- retro 2D pixel art
- cute and light
- clear ear silhouette
- consistent body proportions
```

## 7. owl.png

### 当前问题

- 现在前半像头部，后半像身体
- 不是完整猫头鹰的 4 帧
- 同样属于拼贴结构错误

### 重生目标

- 一只完整的圆头猫头鹰
- 4 帧都要包含完整头、身体、脚
- 保持桌宠比例，不要拆成两段

### 精确 Prompt

```text
请生成一个适用于 macOS 桌面宠物应用的像素风 spritesheet。

主角：一只圆头猫头鹰，大眼睛，小翅膀，体型紧凑，完整角色可爱友好

严格要求：
- transparent background
- sprite sheet
- 4 columns, 1 row
- each frame 256x256
- total image size 1024x256
- same full-body owl in all four frames
- full character visible in every frame
- same scale in all four frames
- same facing direction in all four frames
- same foot baseline in all four frames
- character centered slightly lower in each frame
- no text
- no labels
- no border
- no guide lines
- no checkerboard
- no face-only row
- no body-only row
- no split-body layout
- no anti-aliasing

Frame order:
1. idle standing
2. subtle blink
3. tiny step left
4. tiny step right

Style:
- retro 2D pixel art
- warm brown palette
- crisp edges
- desktop companion feeling
```

## 8. robot.png

### 当前问题

- 这张已经接近完整角色了
- 但带了文字标签，例如 `idle standing`、`blinking`
- 运行时资源绝对不能带字

### 重生目标

- 保留当前小机器人方向
- 去掉所有文字、说明、标签
- 4 帧都只保留角色本体

### 精确 Prompt

```text
请生成一个适用于 macOS 桌面宠物应用的像素风 spritesheet。

主角：一只可爱的小机器人，方形屏幕脸，简洁机身，屏幕表情友好

严格要求：
- transparent background
- sprite sheet
- 4 columns, 1 row
- each frame 256x256
- total image size 1024x256
- same full-body robot in all four frames
- full character visible in every frame
- same scale in all four frames
- same facing direction in all four frames
- same foot baseline in all four frames
- character centered slightly lower in each frame
- no text
- no labels
- no captions
- no border
- no guide lines
- no checkerboard
- no UI elements
- no anti-aliasing

Frame order:
1. idle standing
2. blink
3. left foot forward walking
4. right foot forward walking

Style:
- retro 2D pixel art
- cute desktop companion
- restrained mechanical details
- dark body with glowing face screen allowed
```

## 推荐投喂方式

最稳的是逐张单独投喂，不要批量让模型一次修 8 张。

推荐顺序：

1. `robot`
2. `penguin`
3. `rabbit`
4. `owl`
5. `ghost`
6. `mushroom`
7. `dragon`
8. `chonk`

原因：

- `robot` 最容易修，成功率高
- `penguin / rabbit / owl / ghost` 都是典型“半身拆分”，修法最明确
- `mushroom / dragon / chonk` 更容易出现角色 identity 漂移，放后面单独盯

## 返工后验收

返工后的图必须同时满足：

1. 白底查看时没有棋盘格、没有文字、没有分隔线
2. 每一帧都是完整角色
3. 4 帧是同一角色，不是两套设计拼在一起
4. 单张图严格是 `1024x256`
5. 运行时视角下能被理解成“站立 / 轻微变化 / 左脚前 / 右脚前”

如果你愿意，下一步我可以继续补一份更狠的版本：

- “把这 8 张图分别改成 Midjourney / GPT 图像 / 其他模型专用 prompt 写法”
- 或者我直接开始做第 1 项代码工作：适配新的 `1024x256 / 4x1` 裁切规则
