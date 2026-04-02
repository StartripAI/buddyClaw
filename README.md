# DesktopBuddy

一个原生 macOS 桌面 AI 伙伴宠物示例工程。

## 构建方式

1. 在 macOS 14+ 上安装 Xcode。
2. 打开 `Package.swift`，让 Xcode 生成工程。
3. 在 target 的 Info 里指定本仓库根目录 `Info.plist`。
4. 运行后会以菜单栏应用启动，不会出现在 Dock。

## 运行前建议

- 在“设置”中填入 Anthropic API Key。
- 若希望统计全局键盘活跃度，请在系统设置中授予辅助功能权限。
- 直接分发场景下，发布时可在 `Info.plist` 中补充 `SUFeedURL` 以启用 Sparkle 自动更新。

## 当前实现说明

- 参考早期桌宠原型，移植了确定性宠物骨骼生成算法。
- 若未提供像素 spritesheet PNG，应用会自动回退到内置 ASCII 渲染。
- AI 名字与个性支持首次孵化时调用可选模型生成；若没有 API Key，会走本地确定性回退方案。
