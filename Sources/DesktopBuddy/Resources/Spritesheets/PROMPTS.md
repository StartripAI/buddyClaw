# BuddyClaw Sprite Prompt Pack

这份文件提供可直接复制的 prompt 组合。
推荐做法是：

1. 先复制“主模板”
2. 再补上“物种补充词”
3. 如果模型不稳，再切到“逐帧模板”

## 主模板

```text
请为一个 macOS 桌面宠物应用设计像素风精灵表。

主题：一只{物种}
风格：retro 2D pixel art, cute mascot, desktop companion, crisp edges, limited color palette, consistent silhouette

Output requirements:
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
- no anti-aliasing

Frame order:
1. idle standing
2. subtle breathing or blinking
3. walk frame with left foot forward
4. walk frame with right foot forward

The motion difference between frames should be small and clean.
This must look like a production-ready game sprite sheet, not a poster or concept art.
```

## 负面词

```text
realistic, semi-realistic, painterly, blurry, anti-aliased, 3d render, glossy lighting, watercolor, soft shading, cinematic, poster, concept art, background scene, floor, ground shadow, text, border, UI, checkerboard background, guide lines, inconsistent character, different camera angle, different scale, extra limbs, deformation
```

## 逐帧模板

```text
请生成一个适用于 macOS 桌面宠物应用的像素风角色单帧。

主角：{物种}
动作：{站立待机 / 轻微呼吸 / 左脚前行走 / 右脚前行走}

要求：
- transparent background
- single character only
- square canvas
- character centered slightly lower
- same character identity as the other frames
- same body proportions
- same facing direction
- pure pixel art
- crisp edges
- no background
- no shadow
- no border
- no text
- no checkerboard
- no anti-aliasing
```

## 物种补充词速查

### duck

```text
small yellow duck, round body, orange flat beak, tiny legs
```

### goose

```text
small white goose, long neck, orange beak, orange feet, slightly serious but cute expression
```

### blob

```text
cute slime creature, jelly-like body, soft rounded silhouette, simple face
```

### cat

```text
cute house cat, round face, small ears, short tail, warm and friendly
```

### dragon

```text
baby dragon, tiny wings, short tail, cute and friendly, not fierce
```

### octopus

```text
cute tiny octopus, oversized head, simplified tentacles, minimal details
```

### owl

```text
round owl, large eyes, compact body, tiny wings
```

### penguin

```text
small penguin, black and white body, orange beak and feet, round and soft
```

### turtle

```text
cute turtle, rounded shell, simplified limbs, low center of gravity
```

### snail

```text
cute snail, clear spiral shell, simplified antennae, slow gentle feeling
```

### ghost

```text
cute ghost, soft floating body, friendly face, not scary
```

### axolotl

```text
cute axolotl, visible external gills on both sides, pastel colors, silly adorable expression
```

### capybara

```text
cute capybara, calm healing vibe, rounded rectangular body, tiny ears and eyes
```

### cactus

```text
cute cactus creature, simple rounded cactus silhouette, tiny face, minimal details
```

### robot

```text
cute small robot, simple screen face, compact body, restrained mechanical details
```

### rabbit

```text
cute rabbit, long ears, short tail, light and playful silhouette
```

### mushroom

```text
cute mushroom creature, prominent mushroom cap, simple tiny body, whimsical but clean
```

### chonk

```text
super round chubby creature, simple adorable silhouette, minimal facial details, strong mascot feel
```

## 一个完整示例

下面是 `axolotl` 的完整可投喂版本：

```text
请为一个 macOS 桌面宠物应用设计像素风精灵表。

主题：一只六角恐龙
风格：retro 2D pixel art, cute mascot, desktop companion, crisp edges, limited color palette, consistent silhouette

角色补充：cute axolotl, visible external gills on both sides, pastel colors, silly adorable expression

Output requirements:
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
- no anti-aliasing

Frame order:
1. idle standing
2. subtle breathing or blinking
3. walk frame with left foot forward
4. walk frame with right foot forward

The motion difference between frames should be small and clean.
This must look like a production-ready game sprite sheet, not a poster or concept art.
```

负面词：

```text
realistic, semi-realistic, painterly, blurry, anti-aliased, 3d render, glossy lighting, watercolor, soft shading, cinematic, poster, concept art, background scene, floor, ground shadow, text, border, UI, checkerboard background, guide lines, inconsistent character, different camera angle, different scale, extra limbs, deformation
```
