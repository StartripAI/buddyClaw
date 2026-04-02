import AppKit
import Combine
import Foundation

@MainActor
public final class WorkStateObserver: ObservableObject {
    @Published public private(set) var snapshot = WorkSnapshot()

    public var snapshotHandler: (@MainActor (WorkSnapshot) -> Void)?

    private var globalMonitorTokens: [Any] = []
    private var activateObserver: NSObjectProtocol?
    private var sampleTimer: Timer?
    private var buildCheckWorkItem: DispatchWorkItem?

    private var activityEvents: [Date] = []
    private var appSwitchEvents: [Date] = []
    private var lastInteractionAt = Date()
    private var sessionStartAt = Date()
    private var codingSessionStartAt: Date?
    private var pendingBuildFailure = false
    private var lastBuildCheckAt: Date = .distantPast

    public init() {}

    deinit {
        sampleTimer?.invalidate()
        sampleTimer = nil
        if let activateObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(activateObserver)
        }
        for token in globalMonitorTokens {
            NSEvent.removeMonitor(token)
        }
        buildCheckWorkItem?.cancel()
    }

    public func start() {
        guard sampleTimer == nil else { return }

        activateObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            MainActor.assumeIsolated {
                self?.handleActivatedApplication(notification)
            }
        }

        let masks: [NSEvent.EventTypeMask] = [
            .keyDown,
            .flagsChanged,
            .leftMouseDown,
            .rightMouseDown,
            .mouseMoved,
            .scrollWheel,
        ]

        for mask in masks {
            if let token = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.markActivity(isKeyEvent: mask == .keyDown || mask == .flagsChanged)
                }
            }) {
                globalMonitorTokens.append(token)
            }
        }

        sample()
        sampleTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.sample()
            }
        }
    }

    public func stop() {
        sampleTimer?.invalidate()
        sampleTimer = nil

        if let activateObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(activateObserver)
            self.activateObserver = nil
        }

        for token in globalMonitorTokens {
            NSEvent.removeMonitor(token)
        }
        globalMonitorTokens.removeAll()

        buildCheckWorkItem?.cancel()
        buildCheckWorkItem = nil
    }

    private func markActivity(isKeyEvent: Bool) {
        let now = Date()
        lastInteractionAt = now
        activityEvents.append(now)
        trimArrays(now: now)

        if now.timeIntervalSince(sessionStartAt) > 15 * 60 {
            sessionStartAt = now
        }

        if let bundleIdentifier = NSWorkspace.shared.frontmostApplication?.bundleIdentifier,
           Self.isCoding(bundleIdentifier: bundleIdentifier) {
            codingSessionStartAt = codingSessionStartAt ?? now
        }

        if isKeyEvent == false {
            // Mouse activity still counts toward general session time.
        }
    }

    private func handleActivatedApplication(_ notification: Notification) {
        let now = Date()
        appSwitchEvents.append(now)
        trimArrays(now: now)

        if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
           Self.isCoding(bundleIdentifier: app.bundleIdentifier ?? "") {
            codingSessionStartAt = codingSessionStartAt ?? now
        } else {
            codingSessionStartAt = nil
        }

        sample()
    }

    private func sample() {
        let now = Date()
        trimArrays(now: now)

        let frontmost = NSWorkspace.shared.frontmostApplication
        let bundleIdentifier = frontmost?.bundleIdentifier
        let localizedName = frontmost?.localizedName

        if let bundleIdentifier, Self.isCoding(bundleIdentifier: bundleIdentifier) {
            codingSessionStartAt = codingSessionStartAt ?? now
        } else {
            codingSessionStartAt = nil
        }

        let activeSessionSeconds = max(0, now.timeIntervalSince(sessionStartAt))
        let continuousCodingSeconds = codingSessionStartAt.map { max(0, now.timeIntervalSince($0)) } ?? 0
        let idleSeconds = max(0, now.timeIntervalSince(lastInteractionAt))

        if let bundleIdentifier, bundleIdentifier.contains("Xcode") || bundleIdentifier.contains("com.apple.dt.Xcode") {
            triggerBestEffortBuildFailureCheckIfNeeded()
        } else {
            pendingBuildFailure = false
        }

        let snapshot = WorkSnapshot(
            capturedAt: now,
            frontmostAppName: localizedName,
            frontmostBundleIdentifier: bundleIdentifier,
            idleSeconds: idleSeconds,
            activeSessionSeconds: activeSessionSeconds,
            continuousCodingSeconds: continuousCodingSeconds,
            keyPressesLastMinute: activityEvents.filter { now.timeIntervalSince($0) <= 60 }.count,
            appSwitchesLastTenMinutes: appSwitchEvents.filter { now.timeIntervalSince($0) <= 600 }.count,
            recentBuildFailure: pendingBuildFailure
        )

        self.snapshot = snapshot
        snapshotHandler?(snapshot)
    }

    private func trimArrays(now: Date) {
        activityEvents.removeAll { now.timeIntervalSince($0) > 60 }
        appSwitchEvents.removeAll { now.timeIntervalSince($0) > 600 }
    }

    private func triggerBestEffortBuildFailureCheckIfNeeded() {
        guard Date().timeIntervalSince(lastBuildCheckAt) > 90 else { return }
        lastBuildCheckAt = Date()

        buildCheckWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            let command = [
                "/usr/bin/log",
                "show",
                "--last",
                "90s",
                "--style",
                "compact",
                "--predicate",
                "(process == \"Xcode\" OR process == \"xcbuild\")",
            ]

            let process = Process()
            process.executableURL = URL(fileURLWithPath: command[0])
            process.arguments = Array(command.dropFirst())

            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = Pipe()

            do {
                try process.run()
                process.waitUntilExit()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let text = String(data: data, encoding: .utf8) ?? ""
                let lowercased = text.lowercased()

                let foundFailure =
                    lowercased.contains("build failed") ||
                    lowercased.contains("command compile") && lowercased.contains("failed") ||
                    lowercased.contains("error:") && lowercased.contains("failed")

                DispatchQueue.main.async {
                    self?.pendingBuildFailure = foundFailure
                }
            } catch {
                DispatchQueue.main.async {
                    self?.pendingBuildFailure = false
                }
            }
        }

        buildCheckWorkItem = workItem
        DispatchQueue.global(qos: .utility).async(execute: workItem)
    }

    public static func isCoding(bundleIdentifier: String) -> Bool {
        let value = bundleIdentifier.lowercased()
        return value.contains("xcode")
            || value.contains("visual-studio-code")
            || value.contains("code")
            || value.contains("zed")
            || value.contains("jetbrains")
            || value.contains("iterm")
            || value.contains("terminal")
            || value.contains("nova")
            || value.contains("sublime")
    }
}
