# BuddyClaw Promo Prompts For Banana

These prompts are designed to fix the current promo images:
- all cards must be complete
- no clipped mascots
- no cropped UI
- no overflowing ASCII block
- clean alignment inside every color block
- Pixel / ASCII / Claw must all be clearly visible

Use one prompt per image.

## Global Rules

Add this shared constraint block to every prompt:

```text
Design a polished 16:9 landscape promotional graphic for a macOS desktop pet app called BuddyClaw.

Visual direction:
- premium indie software launch graphic
- editorial poster composition
- warm dark-to-amber palette with soft cream cards
- playful but clean
- sharp typography
- strong grid alignment
- equal padding and spacing
- every card and visual element fully visible
- no clipping, no overlap, no off-edge content
- no mascot cut off by the frame
- all text and artwork must stay well inside their containers
- high contrast and highly legible

Brand requirements:
- BuddyClaw is a local-first macOS menu bar desktop pet
- it has three visual styles: Pixel, ASCII, and Claw
- Pixel must look like crisp retro sprite art
- ASCII must look like original terminal character art
- Claw must look like a warm amber mascot style
- all three styles should feel equally important

Layout requirements:
- use a strict grid
- align headings, subtitles, preview cards, and captions
- center visual content within each preview card
- keep consistent card radii and shadows
- do not let text float randomly
- do not place any text too close to card edges
- do not crop any preview, mascot, or label

Output:
- 16:9
- product marketing graphic
- complete composition
- presentation-ready
```

## Negative Prompt

Use this with every image:

```text
cropped text, clipped mascot, cut off UI, overlapping labels, messy layout, bad kerning, random spacing, uneven margins, off-center content, incomplete card, partial preview, extra fingers, deformed pet, low contrast text, unreadable text, too much text, poster collage chaos, watermark, logo mashup, mockup frame, browser chrome, phone frame, distorted terminal window, blurry sprite, low resolution, duplicated character, broken ascii, floating elements
```

## 1. Hero Image

Filename target:

```text
promo-01-hero-wide.png
```

Prompt:

```text
Create a flagship hero image for BuddyClaw.

Composition:
- large BuddyClaw title on the left
- short supporting copy under the title
- three stacked style cards on the right
- top card = Pixel
- middle card = ASCII
- bottom card = Claw
- each style card must have:
  - a style label
  - a short subtitle
  - one centered preview area
  - fully visible content

Important:
- the ASCII card must be complete and neatly aligned inside its dark preview box
- do not crop the ASCII cat or let it spill outside the box
- do not crop the Pixel strip
- do not crop the Claw strip
- all three right-side cards must have equal size and equal spacing
- the bottom pill on the left must be fully visible and centered vertically inside its cream block

Suggested text:
- Title: BuddyClaw
- Subtitle line 1: A desktop pet with warm terminal energy.
- Subtitle line 2: Three visual styles, one native companion.
- Pixel subtitle: Crisp pixel desktop pet
- ASCII subtitle: Original terminal character style
- Claw subtitle: Warm amber mascot style
- Bottom pill: Menu bar app • instant style switching • fully local

Art direction:
- dark atmospheric background
- warm amber glow
- premium launch poster feel
- strong contrast between cream style cards and dark background
```

## 2. Style Comparison Image

Filename target:

```text
promo-02-styles.png
```

Prompt:

```text
Create a clean style comparison image for BuddyClaw.

Composition:
- large heading across the top
- three equal vertical cards below
- left card = Pixel
- middle card = ASCII
- right card = Claw

Each card must contain:
- title at top-left
- short subtitle under title
- one centered preview panel in the middle
- short two-line description at the bottom

Important:
- every card must use exactly the same internal alignment system
- title, subtitle, preview panel, and body copy must line up consistently across all three cards
- the ASCII preview must show a complete terminal cat and must not overlap with any explanatory text
- the preview artwork in every card must be centered and fully visible
- all cards must have equal heights, equal inner padding, and equal preview panel sizes

Suggested text:
- Main heading: Three styles, one companion
- Chinese subheading: 三种风格，一只陪伴你的桌宠
- Pixel description: Sharp retro sprite sheets. Crisp and production-ready.
- ASCII description: Terminal-born character charm. Minimal, readable, iconic.
- Claw description: Warm amber mascot energy. Original, soft, desktop-native.
```

## 3. Memory Image

Filename target:

```text
promo-03-memory.png
```

Prompt:

```text
Create a feature promo image for BuddyClaw's local memory experience.

Composition:
- dark background
- large heading at top-left
- three large cream cards across the canvas
- left card = Timeline
- center card = Ask
- right card = Notes
- small BuddyClaw mascots can appear as accents, but must never be cropped or touch the image edge

Important:
- every feature card must be complete and comfortably padded
- no mascot should be cut off by the top or side edge
- all text blocks inside cards must fit naturally
- do not overflow the Ask answer block
- align the card titles along a clean baseline
- the bottom yellow tags must have centered text and equal spacing

Suggested text:
- Heading: Keeps memory on your Mac
- Chinese subtitle: 资料、笔记、时间线和离线问答都留在本机
- Left card title: Timeline
- Center card title: Ask
- Right card title: Notes
- Bottom tags: SQLite vault / Offline answers / Local timeline
```

## 4. Menu Controls Image

Filename target:

```text
promo-04-menu-controls.png
```

Prompt:

```text
Create a product image showing BuddyClaw's quick controls.

Composition:
- soft light background
- large title at top-left
- left side: a cream macOS-style menu panel
- right side: a dark instant-switching showcase panel

Left menu panel content:
- BuddyClaw menu
- Pick Pet
- Pick Style
- Size
- Reset Pet
- Chat
- Memory Center
- Review Today
- Settings

Right panel content:
- heading: Instant switching
- subheading: Pixel / ASCII / Claw
- show three style examples clearly
- include size chips at the bottom: 25%, 50%, 75%, 100%, 125%

Important:
- the right panel must actually show all three styles, not just mascot colors
- use a complete ASCII preview, not a cropped or partial one
- every size chip must have centered text
- do not let any preview float or touch the panel edge
- all list items in the left menu must align cleanly
```

## 5. Download / CTA Image

Filename target:

```text
promo-05-download.png
```

Prompt:

```text
Create a launch-ready download image for BuddyClaw.

Composition:
- warm dark amber background
- large BuddyClaw title on the left
- short two-line value statement below
- mascot strip or character lineup on the right
- one bottom cream pill containing the distribution line

Important:
- every mascot in the right lineup must be fully visible
- no character may be clipped by the image edge
- keep the lineup balanced and evenly spaced
- the bottom pill must be wide enough for all text
- all chip text at the top must be centered inside each chip

Suggested text:
- Title: BuddyClaw
- Copy line 1: A local-first desktop creature
- Copy line 2: for people who still love warm terminal energy.
- Bottom pill: GitHub · DMG · Pixel · ASCII · Claw · bilingual UI
- Top chips: Download DMG / macOS / Menu bar pet / Local-first
```

## Extra Repair Instruction

If Banana still tries to produce incomplete previews, append this exact line:

```text
Every preview, mascot, card, label, and text block must be fully contained inside its own visual box and fully contained inside the final image frame. Nothing may be cropped, cut off, partially hidden, or overlapping.
```

## Most Important Note

For these promo graphics, Banana should prioritize:

1. complete composition
2. alignment
3. clear style differentiation
4. fully visible content
5. minimal clean text

If it struggles with long bilingual text, keep the text shorter rather than breaking layout.
