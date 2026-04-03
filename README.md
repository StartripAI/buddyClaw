# BuddyClaw

![BuddyClaw hero](./docs/assets/promo/promo-01-hero-wide.png)

BuddyClaw is a local-first macOS desktop pet that lives in your menu bar, walks on your desktop, remembers what matters on-device, and stays playful instead of pretending to be a cloud chatbot.

BuddyClaw 是一个本地优先的 macOS 菜单栏桌宠。它会待在你的桌面上、陪着你工作、把记忆留在本机里，并且首先是一只“好玩、有性格、愿意常驻”的宠物，而不是伪装成云端聊天窗口。

**Tags:** `macOS` `desktop pet` `local-first` `SwiftUI` `menu bar app` `pixel art` `ASCII art` `offline memory` `bilingual`

[Direct DMG Download](https://github.com/StartripAI/buddyClaw/raw/main/downloads/BuddyClaw.dmg) · [Latest Releases](https://github.com/StartripAI/buddyClaw/releases/latest) · [All Releases](https://github.com/StartripAI/buddyClaw/releases) · [Source Code](https://github.com/StartripAI/buddyClaw)

## GitHub About

**Description**

Local-first bilingual macOS desktop pet with Pixel, ASCII, and Claw styles, menu bar controls, and on-device memory.

**Topics**

`macos`, `desktop-pet`, `swift`, `swiftui`, `menu-bar-app`, `local-first`, `offline-first`, `pixel-art`, `ascii-art`, `companion-app`

## Why BuddyClaw

- Local-first by default: notes, imports, event memory, and offline extractive answers stay on your Mac.
- Fast menu-bar controls: switch pet, style, and size instantly without opening a settings maze.
- Three-style architecture: `Pixel`, `ASCII`, and `Claw`.
- Native desktop feel: menu bar app, floating pet window, speech bubbles, quick reactions, and zero fake cloud mystique.
- Built for people who smile at a certain warm terminal coding companion and want that feeling reborn as its own desktop-native creature.

## What Ships Today

- `Pixel` style is the formal production look.
- `ASCII` style is built in and always available.
- `Claw` style now ships as a bundled selectable style alongside `Pixel` and `ASCII`.
- `Memory Center` lets you import local content, write manual notes, ask offline questions, and review the local timeline.
- System-following bilingual UI: Chinese on Chinese systems, English on English systems.

## At A Glance

![BuddyClaw styles](./docs/assets/promo/promo-02-styles.png)

![BuddyClaw memory](./docs/assets/promo/promo-03-memory.png)

![BuddyClaw controls](./docs/assets/promo/promo-04-menu-controls.png)

![BuddyClaw download](./docs/assets/promo/promo-05-download.png)

## Feature Highlights

### 1. A desktop pet first

BuddyClaw puts the pet experience first:

- pick a pet directly from the menu bar
- switch style instantly
- change size in one click
- reset the current pet without deleting files

### 2. Local memory, not fake cloud magic

BuddyClaw keeps a local SQLite memory vault for:

- imported Markdown, TXT, JSON, and BuddyPack files
- manual notes
- event memories such as app switches, focus milestones, petting, reviews, and offline questions
- daily summaries

Answers are extractive and source-backed. If the app cannot find enough support locally, it says so clearly.

### 3. Three-style product lane

- `Pixel`: crisp sprite-sheet production assets
- `ASCII`: code-rendered fallback with real product entry points restored
- `Claw`: bundled warm amber mascot art with the same first-class menu and settings entry points as the other styles

## Download

The fastest path is the direct DMG stored in the repository, with GitHub Releases reserved for signed/notarized publishing flows.

- Download [BuddyClaw.dmg](https://github.com/StartripAI/buddyClaw/raw/main/downloads/BuddyClaw.dmg)
- Or open [Releases](https://github.com/StartripAI/buddyClaw/releases)
- Drag `BuddyClaw.app` into `Applications`

### Distribution Channels

- `Direct DMG`: keeps the original local-first desktop experience, with activity capture enabled by default and fully stored on-device.
- `Mac App Store`: ships through a sandboxed Xcode archive/export flow, with activity capture off by default until you explicitly enable it.
- Both channels ship the same bundled `Pixel`, `ASCII`, and `Claw` styles.

## Build From Source

### Requirements

- macOS 14+
- Xcode

### Build

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swift build
```

### Build The Xcode Hosts

```bash
ruby ./scripts/generate_xcodeproj.rb
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project BuddyClaw.xcodeproj -scheme BuddyClawDirect -destination 'generic/platform=macOS' CODE_SIGNING_ALLOWED=NO build
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project BuddyClaw.xcodeproj -scheme BuddyClawAppStore -destination 'generic/platform=macOS' CODE_SIGNING_ALLOWED=NO build
```

### Test

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swift test
```

### Local Release Dry Run

```bash
./scripts/release_buddyclaw.sh --codesign-identity - --output-dir ./dist/local --skip-notarize
```

### App Store Archive

```bash
./scripts/archive_app_store.sh --skip-export --output-dir ./dist/app-store-local
./scripts/archive_app_store.sh --team-id YOURTEAMID --output-dir ./dist/app-store
```

The signed App Store path expects your Apple Developer account to be actively signed in inside Xcode so `xcodebuild` can fetch signing assets.

## Product Notes

- BuddyClaw is a menu-bar accessory app, so it does not show in the Dock by default.
- The app validates production pixel sprites before release.
- Release bundles keep runtime assets only and strip authoring docs/scripts from the shipped app.
- The bundled release now includes `PixelSprites` and `ClawSprites`, with `ASCII` always available as the code-rendered fallback.
- The repository now includes a generated `BuddyClaw.xcodeproj` host with `BuddyClawDirect` and `BuddyClawAppStore` schemes on top of the shared Swift package.

---

# 中文说明

## BuddyClaw 是什么

BuddyClaw 是一只本地优先的 macOS 桌宠：

- 常驻菜单栏
- 在桌面上悬浮和移动
- 有自己的名字、个性和宠物形态
- 支持本地记忆中心
- 支持离线抽取式问答
- 支持快速切换宠物、风格和大小

它不是“把聊天框塞进桌面”的产品，而是一只真正围绕陪伴感来设计的原生桌宠。

## 这版的核心卖点

- 本地优先：资料、笔记、时间线记忆都保存在本机
- 桌宠优先：菜单栏第一层就是 `选宠物 / 选风格 / 大小 / 重置宠物`
- 双语优先：系统是中文就显示中文，系统是英文就显示英文
- 成品优先：支持 release 打包、DMG 输出、资源校验

## 当前风格系统

- `像素 Pixel`
  现在的正式生产风格，桌宠运行时默认使用它

- `ASCII`
  代码渲染版本已经恢复为正式可选入口，不再是隐藏 fallback

- `Claw`
  现在已经随应用一起打包，和 `Pixel`、`ASCII` 一样可以直接切换使用

## 记忆中心能做什么

记忆中心不是主入口，但它保留下来，适合长期使用：

- 导入 Markdown / TXT / JSON / BuddyPack
- 写手动笔记
- 查看时间线事件
- 回顾今天
- 做离线本地问答

BuddyClaw 会明确告诉你回答是否来自本地命中，而不会假装自己是云端模型。

## 安装方式

- 直接下载 [BuddyClaw.dmg](https://github.com/StartripAI/buddyClaw/raw/main/downloads/BuddyClaw.dmg)
- 或进入 [Releases](https://github.com/StartripAI/buddyClaw/releases)
- 将 `BuddyClaw.app` 拖入 `Applications`

### 分发渠道

- `Direct DMG`：保留原本的本地优先桌宠体验，活动记录默认开启，但数据始终只保存在本机。
- `Mac App Store`：通过 sandbox + Xcode archive/export 链路发布，活动记录默认关闭，只有你显式开启后才会开始采样。
- 两个渠道都自带 `Pixel`、`ASCII`、`Claw` 三种风格。

## 从源码运行

构建：

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swift build
```

Xcode 宿主工程：

```bash
ruby ./scripts/generate_xcodeproj.rb
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project BuddyClaw.xcodeproj -scheme BuddyClawDirect -destination 'generic/platform=macOS' CODE_SIGNING_ALLOWED=NO build
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project BuddyClaw.xcodeproj -scheme BuddyClawAppStore -destination 'generic/platform=macOS' CODE_SIGNING_ALLOWED=NO build
```

测试：

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swift test
```

本地打包：

```bash
./scripts/release_buddyclaw.sh --codesign-identity - --output-dir ./dist/local --skip-notarize
```

App Store 归档：

```bash
./scripts/archive_app_store.sh --skip-export --output-dir ./dist/app-store-local
./scripts/archive_app_store.sh --team-id YOURTEAMID --output-dir ./dist/app-store
```

要走带签名的 App Store 导出流程，需要先确保你的 Apple Developer 账号已经在 Xcode 内处于登录有效状态，这样 `xcodebuild` 才能自动拉取签名资产。

## 一个小小的气质说明

如果你也喜欢某种温暖、偏橙色、带点终端气质的编码伙伴氛围，BuddyClaw 会让你看出那一点点熟悉感。  
但它最终想成为的，是一只真正属于自己世界观的本地桌宠。
