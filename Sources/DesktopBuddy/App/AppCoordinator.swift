import AppKit
import Combine
import Foundation
import SwiftUI
import UniformTypeIdentifiers

@MainActor
public final class AppCoordinator: NSObject {
    private let distributionChannel = DistributionChannel.current
    private let storage = StorageManager()
    private let generator = CompanionGenerator()
    private let dialogueBank = DialogueBank.shared
    private let nameTable = NameTable.shared
    private let spriteCatalog = VerifiedSpriteCatalog()
    private lazy var companionIdentity = CompanionIdentityService(
        storage: storage,
        generator: generator,
        nameTable: nameTable,
        spriteCatalog: spriteCatalog
    )

    private var appState: AppStateStore?
    private var spriteAnimator: SpriteAnimator?
    private var speechBubbleManager = SpeechBubbleManager()
    private var growthTracker: GrowthTracker?
    private var workStateObserver = WorkStateObserver()
    private var reactiveCommentEngine = ReactiveCommentEngine()
    private var menuBarManager: MenuBarManager?
    private var windowManager: WindowManager?
    private var vaultStore: VaultStore?
    private var answerProvider: ExtractiveAnswerProvider?
    private var settingsWindowController: NSWindowController?
    private var memoryCenterWindowController: NSWindowController?
    private var memoryCenterViewModel: MemoryCenterViewModel?
    private var lastRecordedSnapshot: WorkSnapshot?
    private var committedCompanionProfile: StoredCompanionProfile?
    private var previewCompanionProfile: StoredCompanionProfile?
    private var committedSettingsSnapshot: DesktopBuddySettings?
    private var previewSettingsSnapshot: DesktopBuddySettings?
    private var cancellables = Set<AnyCancellable>()

    public override init() {
        super.init()
    }

    public func start() async {
        let loadedSettings = storage.loadSettings()
        let identity = companionIdentity.loadOrCreateProfile(settings: loadedSettings)
        let settings = normalizedSettings(loadedSettings, species: identity.profile.species)
        let growthState = storage.loadGrowthState()

        if settings != loadedSettings {
            storage.saveSettings(settings)
        }

        let appState = AppStateStore(
            settings: settings,
            companionProfile: identity.profile,
            companion: identity.companion,
            growthState: growthState
        )
        self.appState = appState
        self.committedCompanionProfile = identity.profile
        self.committedSettingsSnapshot = settings

        let spriteAnimator = SpriteAnimator(
            companion: identity.companion,
            scale: settings.petScale,
            artStyle: settings.preferredArtStyle
        )
        self.spriteAnimator = spriteAnimator
        speechBubbleManager.setDefaultDisplayDuration(settings.speechBubbleSeconds)

        let growthTracker = GrowthTracker(initialState: growthState)
        self.growthTracker = growthTracker

        await configureVaultIfPossible(for: appState)
        buildWindowLayer(appState: appState, spriteAnimator: spriteAnimator)
        buildMenuBar(appState: appState)
        setupWorkObserver(appState: appState)
        setupPersistenceBindings(appState: appState)

        windowManager?.start()
        presentActivityMonitoringOnboardingIfNeeded()

        if !settings.isMuted {
            speechBubbleManager.show(
                text: dialogueBank.randomLine(for: .greeting),
                style: .speech
            )
        }

        if settings.openSettingsOnLaunch {
            openSettings()
        }
    }

    private func configureVaultIfPossible(for appState: AppStateStore) async {
        do {
            let vault = try VaultStore()
            self.vaultStore = vault
            self.answerProvider = ExtractiveAnswerProvider(vault: vault)
            _ = try await vault.bootstrapStarterPackIfNeeded(enabled: appState.settings.starterPackEnabled)
            await refreshVaultState()
        } catch {
            NSLog("BuddyClaw failed to initialize vault: \(error.localizedDescription)")
        }
    }

    private func buildWindowLayer(appState: AppStateStore, spriteAnimator: SpriteAnimator) {
        let windowManager = WindowManager(
            animator: spriteAnimator,
            bubbleManager: speechBubbleManager,
            companionProvider: { [weak appState] in appState?.companion ?? spriteAnimator.companion },
            growthProvider: { [weak appState] in appState?.growthState ?? GrowthState() },
            settingsProvider: { [weak appState] in appState?.settings ?? .default },
            onPet: { [weak self] in self?.handlePet() },
            onTalk: { [weak self] in self?.handleTalk() }
        )
        self.windowManager = windowManager
    }

    private func buildMenuBar(appState: AppStateStore) {
        let menuBarManager = MenuBarManager(
            companionProvider: { [weak self, weak appState] in
                appState?.companion ?? Companion(
                    rarity: .common,
                    species: self?.spriteCatalog.defaultSpecies ?? .cat,
                    eye: .dot,
                    hat: .none,
                    shiny: false,
                    stats: [:],
                    name: L10n.text("伙伴", "Buddy"),
                    personality: "",
                    hatchedAt: Date().timeIntervalSince1970
                )
            },
            settingsProvider: { [weak appState] in appState?.settings ?? .default },
            distributionChannelProvider: { [weak self] in self?.distributionChannel ?? .direct },
            activityMonitoringActiveProvider: { [weak appState] in appState?.isActivityMonitoringActive ?? false },
            spriteCatalog: spriteCatalog
        )

        menuBarManager.onSelectSpecies = { [weak self] species in self?.selectSpeciesImmediately(species) }
        menuBarManager.onSelectArtStyle = { [weak self] style in self?.selectArtStyleImmediately(style) }
        menuBarManager.onSelectScalePercent = { [weak self] percent in self?.selectScalePercentImmediately(percent) }
        menuBarManager.onTalk = { [weak self] in self?.handleTalk() }
        menuBarManager.onOpenMemoryCenter = { [weak self] in self?.openMemoryCenter(selectedTab: .library) }
        menuBarManager.onImportContent = { [weak self] in self?.importKnowledgeFiles() }
        menuBarManager.onReviewToday = { [weak self] in self?.reviewToday() }
        menuBarManager.onResetCompanion = { [weak self] in self?.resetCompanionImmediately() }
        menuBarManager.onOpenSettings = { [weak self] in self?.openSettings() }
        menuBarManager.onToggleMute = { [weak self] newValue in self?.setMuted(newValue) }
        menuBarManager.onToggleActivityMonitoring = { [weak self] newValue in self?.setActivityMonitoringEnabled(newValue) }
        menuBarManager.onQuit = { NSApp.terminate(nil) }

        self.menuBarManager = menuBarManager
        menuBarManager.refresh()
    }

    private func setupWorkObserver(appState: AppStateStore) {
        workStateObserver.snapshotHandler = { [weak self, weak appState] snapshot in
            guard let self, let appState else { return }

            let previousSnapshot = self.lastRecordedSnapshot
            self.lastRecordedSnapshot = snapshot
            appState.latestWorkSnapshot = snapshot

            if let update = self.growthTracker?.recordSample(snapshot: snapshot) {
                appState.growthState = self.growthTracker?.exportState() ?? appState.growthState
                self.storage.saveGrowthState(appState.growthState)
                self.reactToGrowth(update)
            }

            if appState.settings.memoryCaptureEnabled, let vaultStore = self.vaultStore {
                Task {
                    do {
                        try await vaultStore.recordSnapshotTransition(
                            previous: previousSnapshot,
                            current: snapshot,
                            retentionDays: appState.settings.rawEventRetentionDays
                        )
                        await self.refreshVaultState()
                    } catch {
                        NSLog("BuddyClaw failed recording snapshot transition: \(error.localizedDescription)")
                    }
                }
            }

            if let decision = self.reactiveCommentEngine.evaluate(
                snapshot: snapshot,
                companion: appState.companion,
                growthState: appState.growthState,
                proactiveCommentsEnabled: appState.settings.proactiveCommentsEnabled && !appState.settings.isMuted
            ) {
                self.reactiveCommentEngine.markFired(key: decision.key)
                if decision.key == "morningGreeting" {
                    self.growthTracker?.markMorningGreetingIfNeeded(date: snapshot.capturedAt)
                    appState.growthState = self.growthTracker?.exportState() ?? appState.growthState
                }
                if let suggestedState = decision.suggestedState {
                    self.spriteAnimator?.setState(suggestedState, duration: 1.5, fallBackTo: .idle)
                }
                self.speechBubbleManager.show(text: decision.text, style: decision.style)

                if appState.settings.memoryCaptureEnabled, let vaultStore = self.vaultStore {
                    Task {
                        do {
                            try await vaultStore.recordEvent(
                                MemoryEvent(
                                    kind: .proactiveComment,
                                    timestamp: snapshot.capturedAt,
                                    summary: decision.text,
                                    metadata: ["key": decision.key],
                                    frontmostApp: snapshot.frontmostAppName
                                ),
                                retentionDays: appState.settings.rawEventRetentionDays
                            )
                            await self.refreshVaultState()
                        } catch {
                            NSLog("BuddyClaw failed recording proactive comment: \(error.localizedDescription)")
                        }
                    }
                }
            }
        }
        refreshActivityMonitoring(resetSnapshot: true)
    }

    private func setupPersistenceBindings(appState: AppStateStore) {
        appState.$settings
            .sink { [weak self] settings in
                guard let self else { return }
                self.storage.saveSettings(settings)
                self.committedSettingsSnapshot = settings
                self.speechBubbleManager.setDefaultDisplayDuration(settings.speechBubbleSeconds)
                self.spriteAnimator?.updateScale(settings.petScale)
                self.spriteAnimator?.updateCompanion(appState.companion, artStyle: settings.preferredArtStyle)
                self.refreshActivityMonitoring(resetSnapshot: settings.activityMonitoringEnabled == false)
                self.windowManager?.refreshContent()
                self.menuBarManager?.refresh()

                if let vaultStore = self.vaultStore {
                    Task {
                        do {
                            _ = try await vaultStore.bootstrapStarterPackIfNeeded(enabled: settings.starterPackEnabled)
                            await self.refreshVaultState()
                        } catch {
                            NSLog("BuddyClaw failed refreshing starter pack state: \(error.localizedDescription)")
                        }
                    }
                }
            }
            .store(in: &cancellables)

        appState.$growthState
            .sink { [weak self] state in
                self?.storage.saveGrowthState(state)
            }
            .store(in: &cancellables)
    }

    private func handlePet() {
        guard let growthTracker, let appState else { return }
        let update = growthTracker.recordPetting()
        appState.growthState = growthTracker.exportState()
        storage.saveGrowthState(appState.growthState)
        reactToGrowth(update)
        spriteAnimator?.pet()

        if appState.settings.memoryCaptureEnabled, let vaultStore {
            Task {
                do {
                    try await vaultStore.recordEvent(
                        MemoryEvent(
                            kind: .petting,
                            summary: L10n.format("你摸了摸 %@。", "You patted %@.", appState.companion.name),
                            metadata: ["companion": appState.companion.name],
                            frontmostApp: appState.latestWorkSnapshot?.frontmostAppName
                        ),
                        retentionDays: appState.settings.rawEventRetentionDays
                    )
                    await self.refreshVaultState()
                } catch {
                    NSLog("BuddyClaw failed recording petting event: \(error.localizedDescription)")
                }
            }
        }

        if !appState.settings.isMuted {
            var line = dialogueBank.randomLine(for: .petting)
            if let flavor = dialogueBank.speciesFlavor(species: appState.companion.species) {
                line += " " + flavor
            }
            speechBubbleManager.show(text: line, style: .reaction, duration: 4)
        }
    }

    private func handleTalk() {
        guard let appState else { return }

        if appState.libraryStats.itemCount > 0 {
            spriteAnimator?.talkPulse(duration: 0.8)
            if !appState.settings.isMuted {
                speechBubbleManager.show(
                    text: L10n.text(
                        "我把记忆中心打开啦。直接问我最近做了什么，或者某个关键词在哪里出现过。",
                        "I opened Memory Center. Try asking what you did recently or where a keyword showed up."
                    ),
                    style: .thought,
                    duration: 5
                )
            }
            openMemoryCenter(selectedTab: .ask)
            return
        }

        let category: DialogueCategory
        if let snapshot = appState.latestWorkSnapshot {
            let hour = Calendar.current.component(.hour, from: snapshot.capturedAt)
            if hour < 6 || hour >= 23 {
                category = .nightGreeting
            } else if snapshot.continuousCodingSeconds > 5_400 {
                category = .restReminder
            } else if WorkStateObserver.isCoding(bundleIdentifier: snapshot.frontmostBundleIdentifier ?? "") {
                category = .coding
            } else if snapshot.idleSeconds > 300 {
                category = .bored
            } else {
                category = .idle
            }
        } else {
            category = .idle
        }

        var line = dialogueBank.randomLine(for: category)
        if let flavor = dialogueBank.speciesFlavor(species: appState.companion.species) {
            line += " " + flavor
        }

        spriteAnimator?.talkPulse(duration: 1.2)
        speechBubbleManager.show(text: line, style: .speech, duration: 6)

        if let growthTracker {
            let update = growthTracker.recordConversation()
            appState.growthState = growthTracker.exportState()
            storage.saveGrowthState(appState.growthState)
            reactToGrowth(update)
        }
    }

    private func reviewToday() {
        guard let appState, let vaultStore else {
            speechBubbleManager.show(text: L10n.text("本地记忆库还没准备好。", "The local memory vault is not ready yet."), style: .system, duration: 4)
            return
        }

        Task {
            do {
                if let summary = try await vaultStore.todaySummary() {
                    let trailing = summary.highlights.isEmpty ? "" : " " + summary.highlights.joined(separator: " / ")
                    speechBubbleManager.show(
                        text: summary.headline + trailing,
                        style: .system,
                        duration: 7
                    )
                    try await vaultStore.recordEvent(
                        MemoryEvent(
                            kind: .dailyReview,
                            summary: L10n.text("查看了今日回顾。", "Opened today's review."),
                            metadata: [:],
                            frontmostApp: appState.latestWorkSnapshot?.frontmostAppName
                        ),
                        retentionDays: appState.settings.rawEventRetentionDays
                    )
                    await refreshVaultState()
                } else {
                    speechBubbleManager.show(
                        text: L10n.text(
                            "今天还没有足够多的本地记忆可以回顾。",
                            "There is not enough local memory yet to review today."
                        ),
                        style: .thought,
                        duration: 5
                    )
                }
            } catch {
                speechBubbleManager.show(
                    text: L10n.format("今天的回顾暂时打不开：%@", "Today's review is unavailable right now: %@", error.localizedDescription),
                    style: .system,
                    duration: 5
                )
            }
        }
    }

    private func reactToGrowth(_ update: GrowthUpdate) {
        guard update.evolved, let appState else { return }
        spriteAnimator?.triggerEvolution()
        speechBubbleManager.show(
            text: dialogueBank.randomLine(for: .evolution) + " \(update.currentStage.localizedName)!",
            style: .system,
            duration: 6
        )
        appState.growthState = growthTracker?.exportState() ?? appState.growthState
    }

    private func openSettings() {
        guard let appState else { return }

        if let controller = settingsWindowController {
            controller.showWindow(nil)
            controller.window?.makeKeyAndOrderFront(nil)
            controller.window?.setContentSize(NSSize(width: 620, height: 680))
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        previewCompanionProfile = nil
        previewSettingsSnapshot = nil
        committedSettingsSnapshot = appState.settings

        let view = SettingsView(
            initialSettings: appState.settings,
            initialProfile: appState.companionProfile,
            initialCompanion: appState.companion,
            distributionChannel: distributionChannel,
            isActivityMonitoringActive: appState.isActivityMonitoringActive,
            availableSpecies: companionIdentity.availableSpecies,
            availableStyles: spriteCatalog.availableStyles,
            styleAvailability: { [weak self] style, species in
                self?.spriteCatalog.isAvailable(style: style, species: species) ?? (style == .ascii)
            }
        ) { [weak self] species, settings in
            self?.previewCompanion(for: species, settings: settings) ?? appState.companion
        } onReset: { [weak self] settings in
            self?.previewResetCompanion(settings: settings) ?? appState.companion
        } onSave: { [weak self] settings in
            self?.commitSettings(settings: settings)
        } onDismiss: { [weak self] didCommit in
            self?.handleSettingsWindowDismiss(didCommit: didCommit)
        }

        let hostingController = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: hostingController)
        window.title = L10n.text("BuddyClaw 设置", "BuddyClaw Settings")
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.setContentSize(NSSize(width: 620, height: 680))
        window.center()

        let controller = NSWindowController(window: window)
        controller.showWindow(nil)
        self.settingsWindowController = controller
        NSApp.activate(ignoringOtherApps: true)
    }

    private func openMemoryCenter(selectedTab: MemoryCenterTab) {
        guard let appState, let vaultStore, let answerProvider else {
            speechBubbleManager.show(
                text: L10n.text(
                    "本地记忆库正在准备中，稍后再来看看。",
                    "The local memory vault is still getting ready. Please check back in a moment."
                ),
                style: .system,
                duration: 4
            )
            return
        }

        if let controller = memoryCenterWindowController, let viewModel = memoryCenterViewModel {
            if selectedTab == .ask {
                viewModel.primeAsk()
            } else {
                viewModel.selectedTab = selectedTab
            }
            controller.showWindow(nil)
            controller.window?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            Task { await viewModel.refresh() }
            return
        }

        let viewModel = MemoryCenterViewModel(
            selectedTab: selectedTab,
            vault: vaultStore,
            answerProvider: answerProvider,
            settingsProvider: { [weak appState] in
                appState?.settings ?? .default
            },
            appStateUpdater: { [weak appState] stats, digest, askResult in
                appState?.libraryStats = stats
                appState?.recentMemoryDigest = digest
                appState?.lastAskResult = askResult
            },
            importHandler: { [weak self] in
                self?.importKnowledgeFiles()
            }
        )
        self.memoryCenterViewModel = viewModel

        let view = MemoryCenterView(viewModel: viewModel)
        let hostingController = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: hostingController)
        window.title = L10n.text("BuddyClaw 记忆中心", "BuddyClaw Memory Center")
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.setContentSize(NSSize(width: 840, height: 680))
        window.center()

        let controller = NSWindowController(window: window)
        controller.showWindow(nil)
        self.memoryCenterWindowController = controller
        NSApp.activate(ignoringOtherApps: true)
    }

    private func importKnowledgeFiles() {
        guard let appState, let vaultStore else {
            speechBubbleManager.show(text: L10n.text("记忆库尚未初始化完成。", "The memory vault has not finished initializing."), style: .system, duration: 4)
            return
        }

        let panel = NSOpenPanel()
        panel.title = L10n.text("导入资料到 BuddyClaw", "Import Content Into BuddyClaw")
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [
            .plainText,
            .json,
            UTType(filenameExtension: "md"),
            UTType(filenameExtension: "markdown"),
            UTType(filenameExtension: "buddypack"),
        ].compactMap { $0 }

        guard panel.runModal() == .OK else { return }
        let urls = panel.urls
        guard urls.isEmpty == false else { return }

        Task {
            do {
                let result = try await vaultStore.importFiles(
                    at: urls,
                    retentionDays: appState.settings.rawEventRetentionDays
                )
                await refreshVaultState()
                await memoryCenterViewModel?.refresh()
                speechBubbleManager.show(
                    text: L10n.format("我刚把 %d 条资料收进记忆库了。", "I just added %d items to the memory vault.", result.importedCount),
                    style: .system,
                    duration: 5
                )
            } catch {
                speechBubbleManager.show(
                    text: L10n.format("导入失败了：%@", "Import failed: %@", error.localizedDescription),
                    style: .system,
                    duration: 5
                )
            }
        }
    }

    private func commitSettings(settings: DesktopBuddySettings) {
        guard let appState else { return }
        let activeSpecies = previewCompanionProfile?.species ?? appState.companionProfile.species
        let normalized = normalizedSettings(
            resolveActivityMonitoringRequest(proposed: settings, existing: appState.settings),
            species: activeSpecies
        )

        appState.settings = normalized
        storage.saveSettings(normalized)
        if let previewCompanionProfile {
            applyCompanionProfile(previewCompanionProfile, settings: normalized, persist: true)
        } else {
            applyCompanionProfile(appState.companionProfile, settings: normalized, persist: false)
        }

        if let vaultStore {
            Task {
                do {
                    _ = try await vaultStore.bootstrapStarterPackIfNeeded(enabled: normalized.starterPackEnabled)
                    await refreshVaultState()
                } catch {
                    NSLog("BuddyClaw failed applying settings to vault: \(error.localizedDescription)")
                }
            }
        }
    }

    private func previewCompanion(for species: Species, settings: DesktopBuddySettings) -> Companion {
        guard let appState else { return spriteAnimator?.companion ?? fallbackCompanion() }
        let normalized = normalizedSettings(settings, species: species)
        previewSettingsSnapshot = normalized

        if let committedCompanionProfile, committedCompanionProfile.species == species {
            previewCompanionProfile = nil
            applyCompanionProfile(committedCompanionProfile, settings: normalized, persist: false)
            return appState.companion
        }

        if let previewCompanionProfile, previewCompanionProfile.species == species {
            applyCompanionProfile(previewCompanionProfile, settings: normalized, persist: false)
            return appState.companion
        }

        let profile = companionIdentity.previewProfile(for: species, settings: normalized)
        previewCompanionProfile = profile
        applyCompanionProfile(profile, settings: normalized, persist: false)
        return appState.companion
    }

    private func previewResetCompanion(settings: DesktopBuddySettings) -> Companion {
        guard let appState else { return spriteAnimator?.companion ?? fallbackCompanion() }
        let normalized = normalizedSettings(settings, species: spriteCatalog.defaultSpecies)
        previewSettingsSnapshot = normalized
        let profile = companionIdentity.resetProfile(settings: normalized)
        previewCompanionProfile = profile
        applyCompanionProfile(profile, settings: normalized, persist: false)
        return appState.companion
    }

    private func handleSettingsWindowDismiss(didCommit: Bool) {
        if didCommit == false {
            revertPreviewIfNeeded()
        }
        previewCompanionProfile = nil
        previewSettingsSnapshot = nil
        settingsWindowController = nil
    }

    private func revertPreviewIfNeeded() {
        guard let committedCompanionProfile else { return }
        applyCompanionProfile(
            committedCompanionProfile,
            settings: committedSettingsSnapshot ?? appState?.settings ?? .default,
            persist: false
        )
    }

    private func applyCompanionProfile(
        _ profile: StoredCompanionProfile,
        settings: DesktopBuddySettings? = nil,
        persist: Bool
    ) {
        guard let appState else { return }
        let effectiveSettings = normalizedSettings(settings ?? previewSettingsSnapshot ?? appState.settings, species: profile.species)
        let companion = companionIdentity.companion(for: profile, settings: effectiveSettings)
        appState.companionProfile = profile
        appState.companion = companion
        spriteAnimator?.updateScale(effectiveSettings.petScale)
        spriteAnimator?.updateCompanion(companion, artStyle: effectiveSettings.preferredArtStyle)
        windowManager?.refreshContent()
        menuBarManager?.refresh()

        if persist {
            companionIdentity.persist(profile)
            committedCompanionProfile = profile
            committedSettingsSnapshot = effectiveSettings
            previewCompanionProfile = nil
            previewSettingsSnapshot = nil
        }
    }

    private func fallbackCompanion() -> Companion {
        let species = spriteCatalog.defaultSpecies
        return Companion(
            rarity: .common,
            species: species,
            eye: .dot,
            hat: .none,
            shiny: false,
            stats: [:],
            name: L10n.text("伙伴", "Buddy"),
            personality: "",
            hatchedAt: Date().timeIntervalSince1970
        )
    }

    private func setMuted(_ isMuted: Bool) {
        guard let appState else { return }
        appState.settings.isMuted = isMuted
        if isMuted {
            speechBubbleManager.hideImmediately()
        } else {
            speechBubbleManager.show(
                text: dialogueBank.randomLine(for: .greeting),
                style: .speech,
                duration: 4
            )
        }
    }

    private func setActivityMonitoringEnabled(_ isEnabled: Bool) {
        guard let appState else { return }
        var proposed = appState.settings
        proposed.activityMonitoringEnabled = isEnabled
        appState.settings = resolveActivityMonitoringRequest(proposed: proposed, existing: appState.settings)
    }

    private func resetCompanionImmediately() {
        guard let appState else { return }
        let profile = companionIdentity.resetProfile(settings: appState.settings)
        applyCompanionProfile(profile, persist: true)
        if appState.settings.isMuted == false {
            speechBubbleManager.show(
                text: L10n.text("我已经换成新的正式形态啦。", "Your new official pet is ready."),
                style: .system,
                duration: 4
            )
        }
    }

    private func selectSpeciesImmediately(_ species: Species) {
        guard let appState else { return }
        let normalized = normalizedSettings(appState.settings, species: species)
        appState.settings = normalized
        let profile = companionIdentity.previewProfile(for: species, settings: normalized)
        applyCompanionProfile(profile, settings: normalized, persist: true)
    }

    private func selectArtStyleImmediately(_ style: ArtStyle) {
        guard let appState else { return }
        var settings = appState.settings
        settings.preferredArtStyle = style
        appState.settings = normalizedSettings(settings, species: appState.companionProfile.species)
    }

    private func selectScalePercentImmediately(_ percent: Double) {
        guard let appState else { return }
        var settings = appState.settings
        settings.petScalePercent = percent
        appState.settings = normalizedSettings(settings, species: appState.companionProfile.species)
    }

    private func normalizedSettings(_ settings: DesktopBuddySettings, species: Species) -> DesktopBuddySettings {
        var normalized = settings
        normalized.petScalePercent = min(max(normalized.petScalePercent, 25), 125)
        normalized.preferredArtStyle = spriteCatalog.resolvedStyle(
            preferred: normalized.preferredArtStyle,
            species: species
        )
        return normalized
    }

    private func resolveActivityMonitoringRequest(
        proposed: DesktopBuddySettings,
        existing: DesktopBuddySettings
    ) -> DesktopBuddySettings {
        var resolved = proposed
        guard proposed.activityMonitoringEnabled != existing.activityMonitoringEnabled else {
            return resolved
        }

        if proposed.activityMonitoringEnabled {
            let consentGranted = requestActivityMonitoringConsentIfNeeded()
            resolved.activityMonitoringEnabled = consentGranted
            resolved.hasSeenPrivacyOnboarding = true
            resolved.activityMonitoringConsentState = consentGranted ? .granted : .declined
        } else if distributionChannel.requiresExplicitActivityConsent {
            resolved.activityMonitoringConsentState = .declined
            resolved.hasSeenPrivacyOnboarding = true
        }

        return resolved
    }

    private func refreshActivityMonitoring(resetSnapshot: Bool) {
        guard let appState else { return }
        let capabilities = ActivityMonitoringPolicy.observationCapabilities(
            settings: appState.settings,
            channel: distributionChannel
        )

        if capabilities.isEmpty {
            workStateObserver.stop()
            if resetSnapshot {
                lastRecordedSnapshot = nil
                appState.latestWorkSnapshot = nil
            }
        } else {
            workStateObserver.start(capabilities: capabilities)
        }

        appState.isActivityMonitoringActive = workStateObserver.isMonitoringActive
        menuBarManager?.refresh()
    }

    private func presentActivityMonitoringOnboardingIfNeeded() {
        guard distributionChannel == .appStore, let appState else { return }
        guard appState.settings.hasSeenPrivacyOnboarding == false else { return }

        let consentGranted = requestActivityMonitoringConsentIfNeeded()
        appState.settings.activityMonitoringEnabled = consentGranted
        appState.settings.hasSeenPrivacyOnboarding = true
        appState.settings.activityMonitoringConsentState = consentGranted ? .granted : .declined
    }

    private func requestActivityMonitoringConsentIfNeeded() -> Bool {
        guard appState != nil else { return false }
        guard distributionChannel.requiresExplicitActivityConsent else { return true }
        guard appState?.settings.activityMonitoringConsentState != .granted else {
            return true
        }

        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = L10n.text(
            "是否启用活动记录？",
            "Enable activity capture?"
        )
        alert.informativeText = L10n.text(
            "BuddyClaw 只会在你显式开启后，才在本机记录前台应用切换、活跃节奏，以及在获得辅助功能授权后的全局键盘和鼠标活动。",
            "BuddyClaw only records frontmost-app switches, activity rhythm, and global keyboard or mouse activity on this Mac after you explicitly enable it and grant Accessibility when needed."
        )
        alert.addButton(withTitle: L10n.text("稍后再说", "Not Now"))
        alert.addButton(withTitle: L10n.text("启用活动记录", "Enable Activity Capture"))
        NSApp.activate(ignoringOtherApps: true)

        return alert.runModal() == .alertSecondButtonReturn
    }

    private func refreshVaultState() async {
        guard let appState, let vaultStore else { return }
        do {
            appState.libraryStats = try await vaultStore.libraryStats()
            appState.recentMemoryDigest = try await vaultStore.latestDigest()
        } catch {
            NSLog("BuddyClaw failed refreshing vault state: \(error.localizedDescription)")
        }
    }
}
