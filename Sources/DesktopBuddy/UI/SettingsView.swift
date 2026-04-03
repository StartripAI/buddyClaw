import SwiftUI

public struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var settings: DesktopBuddySettings
    @State private var selectedSpecies: Species
    @State private var previewCompanion: Companion
    @State private var didCommit = false
    @State private var suppressAutomaticPreview = false

    private let distributionChannel: DistributionChannel
    private let isActivityMonitoringActive: Bool
    private let availableSpecies: [Species]
    private let availableStyles: [ArtStyle]
    private let styleAvailability: @MainActor (ArtStyle, Species) -> Bool
    private let onPreview: @MainActor (Species, DesktopBuddySettings) -> Companion
    private let onReset: @MainActor (DesktopBuddySettings) -> Companion
    private let onSave: @MainActor (DesktopBuddySettings) -> Void
    private let onDismiss: @MainActor (Bool) -> Void

    public init(
        initialSettings: DesktopBuddySettings,
        initialProfile: StoredCompanionProfile,
        initialCompanion: Companion,
        distributionChannel: DistributionChannel,
        isActivityMonitoringActive: Bool,
        availableSpecies: [Species],
        availableStyles: [ArtStyle],
        styleAvailability: @escaping @MainActor (ArtStyle, Species) -> Bool,
        onPreview: @escaping @MainActor (Species, DesktopBuddySettings) -> Companion,
        onReset: @escaping @MainActor (DesktopBuddySettings) -> Companion,
        onSave: @escaping @MainActor (DesktopBuddySettings) -> Void,
        onDismiss: @escaping @MainActor (Bool) -> Void
    ) {
        _settings = State(initialValue: initialSettings)
        _selectedSpecies = State(initialValue: initialProfile.species)
        _previewCompanion = State(initialValue: initialCompanion)
        self.distributionChannel = distributionChannel
        self.isActivityMonitoringActive = isActivityMonitoringActive
        self.availableSpecies = availableSpecies
        self.availableStyles = availableStyles
        self.styleAvailability = styleAvailability
        self.onPreview = onPreview
        self.onReset = onReset
        self.onSave = onSave
        self.onDismiss = onDismiss
    }

    public var body: some View {
        VStack(spacing: 0) {
            Form {
                Section(L10n.text("当前预览", "Preview")) {
                    HStack(alignment: .top, spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("\(previewCompanion.species.emoji) \(previewCompanion.name)")
                                .font(.title3.weight(.semibold))
                            Text(previewCompanion.species.localizedName)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text(previewCompanion.personality)
                                .font(.body)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 8) {
                            Text(previewCompanion.rarity.localizedName + " " + previewCompanion.rarity.stars)
                                .font(.subheadline.weight(.semibold))
                            Text(L10n.text("最强属性：", "Top Stat: ") + previewCompanion.bones.strongestStat.localizedName)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                            Text(L10n.text("最弱属性：", "Lowest Stat: ") + previewCompanion.bones.weakestStat.localizedName)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        statChip(.debugging, value: previewCompanion.stats[.debugging] ?? 0)
                        statChip(.patience, value: previewCompanion.stats[.patience] ?? 0)
                        statChip(.chaos, value: previewCompanion.stats[.chaos] ?? 0)
                        statChip(.wisdom, value: previewCompanion.stats[.wisdom] ?? 0)
                        statChip(.snark, value: previewCompanion.stats[.snark] ?? 0)
                    }
                    .padding(.top, 4)
                }

                Section(L10n.text("宠物与外观", "Pet & Appearance")) {
                    Picker(L10n.text("正式宠物", "Companion"), selection: $selectedSpecies) {
                        ForEach(availableSpecies, id: \.self) { species in
                            Text("\(species.emoji) \(species.localizedName)").tag(species)
                        }
                    }

                    Picker(L10n.text("风格", "Style"), selection: $settings.preferredArtStyle) {
                        ForEach(availableStyles, id: \.self) { style in
                            Text(style.displayName)
                                .tag(style)
                                .disabled(styleAvailability(style, selectedSpecies) == false)
                        }
                    }

                    Text(L10n.text(
                        "菜单栏里的“选宠物 / 选风格 / 大小”会立即生效；这里保留完整预览和偏好设置。",
                        "The menu bar applies Companion / Style / Size instantly; this window keeps the full preview and preferences."
                    ))
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                    Button(L10n.text("重置宠物（恢复默认猫猫）", "Reset Pet (Default Cat)")) {
                        let companion = onReset(settings)
                        suppressAutomaticPreview = true
                        selectedSpecies = companion.species
                        settings.preferredArtStyle = resolvedStyle(for: companion.species, preferred: settings.preferredArtStyle)
                        previewCompanion = companion
                        suppressAutomaticPreview = false
                    }
                }

                Section(L10n.text("交互设置", "Interaction")) {
                    Toggle(L10n.text("静音", "Mute"), isOn: $settings.isMuted)
                    Toggle(L10n.text("启用主动评论", "Enable proactive comments"), isOn: $settings.proactiveCommentsEnabled)
                    Toggle(L10n.text("允许在桌面移动", "Allow desktop movement"), isOn: $settings.movementEnabled)
                    Toggle(L10n.text("记录本地记忆", "Capture local memory"), isOn: $settings.memoryCaptureEnabled)
                    Toggle(
                        distributionChannel == .appStore
                            ? L10n.text("启用活动记录（需显式同意）", "Enable activity capture (opt-in)")
                            : L10n.text("启用活动记录", "Enable activity capture"),
                        isOn: $settings.activityMonitoringEnabled
                    )
                    Toggle(L10n.text("启用 Starter Pack", "Enable starter pack"), isOn: $settings.starterPackEnabled)

                    HStack {
                        Text(L10n.text("气泡时长", "Bubble Duration"))
                        Slider(value: $settings.speechBubbleSeconds, in: 4 ... 18, step: 1)
                        Text("\(Int(settings.speechBubbleSeconds))s")
                            .monospacedDigit()
                    }

                    HStack {
                        Text(L10n.text("宠物大小", "Pet Size"))
                        Slider(value: $settings.petScalePercent, in: 25 ... 125, step: 5)
                        Text("\(Int(settings.petScalePercent))%")
                            .monospacedDigit()
                    }

                    TextField(
                        L10n.text(
                            "用户种子覆盖（留空则用当前登录用户名）",
                            "User seed override (leave empty to use the current login name)"
                        ),
                        text: Binding(
                            get: { settings.userIdentifierOverride ?? "" },
                            set: { settings.userIdentifierOverride = $0.isEmpty ? nil : $0 }
                        )
                    )
                    .textFieldStyle(.roundedBorder)

                    Stepper(value: $settings.rawEventRetentionDays, in: 30 ... 365, step: 15) {
                        Text(
                            L10n.currentLanguage.isChinese
                                ? "事件保留天数：\(settings.rawEventRetentionDays) 天"
                                : "Event retention: \(settings.rawEventRetentionDays) days"
                        )
                        .monospacedDigit()
                    }

                    Picker(L10n.text("默认问答范围", "Default Ask Scope"), selection: $settings.defaultAskScope) {
                        ForEach(AskScope.allCases, id: \.self) { scope in
                            Text(scope.displayName).tag(scope)
                        }
                    }

                    Picker(L10n.text("主题模式", "Theme"), selection: $settings.themeMode) {
                        ForEach(ThemeMode.allCases, id: \.self) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                }

                Section(L10n.text("权限提示", "Permissions")) {
                    Text(
                        distributionChannel == .appStore
                            ? L10n.text(
                                isActivityMonitoringActive
                                    ? "当前状态：活动记录已开启，BuddyClaw 会把前台应用和活跃节奏保存在本机。关闭开关后会立即停止新的活动采样。"
                                    : "当前状态：活动记录默认关闭。只有在你显式开启后，BuddyClaw 才会记录前台应用和活跃节奏，而且数据仍然只保存在本机。",
                                isActivityMonitoringActive
                                    ? "Current status: activity capture is on. BuddyClaw keeps frontmost-app and activity rhythm data on this Mac only. Turning the toggle off stops new sampling immediately."
                                    : "Current status: activity capture is off by default. BuddyClaw only records frontmost-app and activity rhythm data after you explicitly enable it, and the data stays on this Mac."
                            )
                            : L10n.text(
                                "Direct 版默认保留本地活动记录体验；如果你关闭它，BuddyClaw 会立刻停止新的活动采样。",
                                "The direct-distribution build keeps local activity capture enabled by default; if you turn it off, BuddyClaw stops new sampling immediately."
                            )
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                    Text(
                        L10n.text(
                            distributionChannel == .appStore
                                ? "若要记录全局键盘与鼠标活跃度，请在你开启活动记录后，再到“系统设置 > 隐私与安全性 > 辅助功能”中授权 BuddyClaw。"
                                : "若要统计全局键盘与鼠标活跃度，请在“系统设置 > 隐私与安全性 > 辅助功能”中授权 BuddyClaw。",
                            distributionChannel == .appStore
                                ? "To observe global keyboard and mouse activity, enable activity capture first, then allow BuddyClaw under System Settings > Privacy & Security > Accessibility."
                                : "To observe global keyboard and mouse activity, allow BuddyClaw under System Settings > Privacy & Security > Accessibility."
                        )
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)

            Divider()

            HStack {
                Button(L10n.text("取消", "Cancel")) {
                    dismiss()
                }

                Spacer()

                Button(L10n.text("保存", "Save")) {
                    didCommit = true
                    onSave(settings)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(width: 620, height: 680)
        .onChange(of: selectedSpecies) { _, newValue in
            guard suppressAutomaticPreview == false else { return }
            normalizePreferredStyle(for: newValue)
            previewCompanion = onPreview(newValue, settings)
        }
        .onChange(of: settings.preferredArtStyle) { _, newValue in
            guard suppressAutomaticPreview == false else { return }
            if styleAvailability(newValue, selectedSpecies) == false {
                normalizePreferredStyle(for: selectedSpecies)
            }
            previewCompanion = onPreview(selectedSpecies, settings)
        }
        .onChange(of: settings.petScalePercent) { _, _ in
            guard suppressAutomaticPreview == false else { return }
            previewCompanion = onPreview(selectedSpecies, settings)
        }
        .onDisappear {
            onDismiss(didCommit)
        }
    }

    private func resolvedStyle(for species: Species, preferred: ArtStyle) -> ArtStyle {
        let candidates: [ArtStyle] = [preferred, .pixel, .ascii, .claw]
        for candidate in candidates {
            if styleAvailability(candidate, species) {
                return candidate
            }
        }
        return .ascii
    }

    private func normalizePreferredStyle(for species: Species) {
        let resolved = resolvedStyle(for: species, preferred: settings.preferredArtStyle)
        guard resolved != settings.preferredArtStyle else { return }
        suppressAutomaticPreview = true
        settings.preferredArtStyle = resolved
        suppressAutomaticPreview = false
    }

    private func statChip(_ stat: StatName, value: Int) -> some View {
        HStack {
            Text(stat.localizedName)
            Spacer()
            Text("\(value)")
                .monospacedDigit()
        }
        .font(.footnote.weight(.medium))
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
