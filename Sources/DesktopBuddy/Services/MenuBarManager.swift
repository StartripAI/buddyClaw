import AppKit
import Foundation

@MainActor
public final class MenuBarManager: NSObject {
    public var onSelectSpecies: ((Species) -> Void)?
    public var onSelectArtStyle: ((ArtStyle) -> Void)?
    public var onSelectScalePercent: ((Double) -> Void)?
    public var onTalk: (() -> Void)?
    public var onOpenMemoryCenter: (() -> Void)?
    public var onImportContent: (() -> Void)?
    public var onReviewToday: (() -> Void)?
    public var onResetCompanion: (() -> Void)?
    public var onOpenSettings: (() -> Void)?
    public var onToggleMute: ((Bool) -> Void)?
    public var onToggleActivityMonitoring: ((Bool) -> Void)?
    public var onQuit: (() -> Void)?

    private let companionProvider: () -> Companion
    private let settingsProvider: () -> DesktopBuddySettings
    private let distributionChannelProvider: () -> DistributionChannel
    private let activityMonitoringActiveProvider: () -> Bool
    private let spriteCatalog: VerifiedSpriteCatalog
    private let statusItem: NSStatusItem

    public init(
        companionProvider: @escaping () -> Companion,
        settingsProvider: @escaping () -> DesktopBuddySettings,
        distributionChannelProvider: @escaping () -> DistributionChannel = { .current },
        activityMonitoringActiveProvider: @escaping () -> Bool = { false },
        spriteCatalog: VerifiedSpriteCatalog = VerifiedSpriteCatalog()
    ) {
        self.companionProvider = companionProvider
        self.settingsProvider = settingsProvider
        self.distributionChannelProvider = distributionChannelProvider
        self.activityMonitoringActiveProvider = activityMonitoringActiveProvider
        self.spriteCatalog = spriteCatalog
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()
        rebuildMenu()
    }

    public func refresh() {
        let companion = companionProvider()
        statusItem.button?.title = statusTitle(for: companion)
        rebuildMenu()
    }

    private func rebuildMenu() {
        let companion = companionProvider()
        let settings = settingsProvider()
        let currentStyle = settings.preferredArtStyle
        let channel = distributionChannelProvider()

        statusItem.button?.title = statusTitle(for: companion)

        let menu = NSMenu()

        let speciesRoot = NSMenuItem(title: L10n.text("选宠物", "Companion"), action: nil, keyEquivalent: "")
        speciesRoot.submenu = makeSpeciesMenu(currentStyle: currentStyle, selectedSpecies: companion.species)
        menu.addItem(speciesRoot)

        let styleRoot = NSMenuItem(title: L10n.text("选风格", "Style"), action: nil, keyEquivalent: "")
        styleRoot.submenu = makeStyleMenu(selectedStyle: currentStyle, species: companion.species)
        menu.addItem(styleRoot)

        let sizeRoot = NSMenuItem(title: L10n.text("大小", "Size"), action: nil, keyEquivalent: "")
        sizeRoot.submenu = makeSizeMenu(selectedPercent: settings.petScalePercent)
        menu.addItem(sizeRoot)

        let resetItem = NSMenuItem(title: L10n.text("重置宠物", "Reset Pet"), action: #selector(resetCompanion), keyEquivalent: "0")
        resetItem.target = self
        menu.addItem(resetItem)

        menu.addItem(.separator())

        let talkItem = NSMenuItem(title: L10n.text("聊天…", "Chat…"), action: #selector(talkNow), keyEquivalent: "t")
        talkItem.target = self
        menu.addItem(talkItem)

        let memoryItem = NSMenuItem(title: L10n.text("记忆中心…", "Memory Center…"), action: #selector(openMemoryCenter), keyEquivalent: "k")
        memoryItem.target = self
        menu.addItem(memoryItem)

        let reviewItem = NSMenuItem(title: L10n.text("回顾今天", "Review Today"), action: #selector(reviewToday), keyEquivalent: "r")
        reviewItem.target = self
        menu.addItem(reviewItem)

        let importItem = NSMenuItem(title: L10n.text("导入资料…", "Import Content…"), action: #selector(importContent), keyEquivalent: "i")
        importItem.target = self
        menu.addItem(importItem)

        let activityTitle = channel == .appStore
            ? L10n.text("活动记录（需显式开启）", "Activity Capture (Opt-in)")
            : L10n.text("活动记录", "Activity Capture")
        let activityItem = NSMenuItem(title: activityTitle, action: #selector(toggleActivityMonitoring), keyEquivalent: "")
        activityItem.target = self
        activityItem.state = settings.activityMonitoringEnabled ? .on : .off
        menu.addItem(activityItem)

        let settingsItem = NSMenuItem(title: L10n.text("设置…", "Settings…"), action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        let muteItem = NSMenuItem(title: L10n.text("静音", "Mute"), action: #selector(toggleMute), keyEquivalent: "m")
        muteItem.target = self
        muteItem.state = settings.isMuted ? .on : .off
        menu.addItem(muteItem)

        let quitItem = NSMenuItem(title: L10n.text("退出 BuddyClaw", "Quit BuddyClaw"), action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    private func makeSpeciesMenu(currentStyle: ArtStyle, selectedSpecies: Species) -> NSMenu {
        let menu = NSMenu()
        for species in spriteCatalog.availableSpecies {
            let item = NSMenuItem(title: "\(species.emoji) \(species.localizedName)", action: #selector(selectSpecies(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = species.rawValue
            item.state = species == selectedSpecies ? .on : .off
            item.isEnabled = spriteCatalog.isAvailable(style: currentStyle, species: species)
            menu.addItem(item)
        }
        return menu
    }

    private func makeStyleMenu(selectedStyle: ArtStyle, species: Species) -> NSMenu {
        let menu = NSMenu()
        for style in spriteCatalog.availableStyles {
            let item = NSMenuItem(title: style.displayName, action: #selector(selectArtStyle(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = style.rawValue
            item.state = style == selectedStyle ? .on : .off
            item.isEnabled = spriteCatalog.isAvailable(style: style, species: species)
            menu.addItem(item)
        }
        return menu
    }

    private func makeSizeMenu(selectedPercent: Double) -> NSMenu {
        let menu = NSMenu()
        for percent in [25.0, 50.0, 75.0, 100.0, 125.0] {
            let item = NSMenuItem(title: "\(Int(percent))%", action: #selector(selectScalePercent(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = NSNumber(value: percent)
            item.state = abs(selectedPercent - percent) < 0.5 ? .on : .off
            menu.addItem(item)
        }
        return menu
    }

    private func statusTitle(for companion: Companion) -> String {
        let prefix = activityMonitoringActiveProvider() ? "● " : ""
        return "\(prefix)\(companion.species.emoji) \(companion.name)"
    }

    @objc private func selectSpecies(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? String,
              let species = Species(rawValue: rawValue) else { return }
        onSelectSpecies?(species)
    }

    @objc private func selectArtStyle(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? String,
              let style = ArtStyle(rawValue: rawValue) else { return }
        onSelectArtStyle?(style)
    }

    @objc private func selectScalePercent(_ sender: NSMenuItem) {
        guard let boxed = sender.representedObject as? NSNumber else { return }
        onSelectScalePercent?(boxed.doubleValue)
    }

    @objc private func talkNow() { onTalk?() }
    @objc private func openMemoryCenter() { onOpenMemoryCenter?() }
    @objc private func importContent() { onImportContent?() }
    @objc private func reviewToday() { onReviewToday?() }
    @objc private func resetCompanion() { onResetCompanion?() }
    @objc private func openSettings() { onOpenSettings?() }

    @objc private func toggleMute() {
        let newValue = !settingsProvider().isMuted
        onToggleMute?(newValue)
        refresh()
    }

    @objc private func toggleActivityMonitoring() {
        let newValue = !settingsProvider().activityMonitoringEnabled
        onToggleActivityMonitoring?(newValue)
        refresh()
    }

    @objc private func quit() { onQuit?() }
}
