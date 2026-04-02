import AppKit
import Foundation

@main
enum DesktopBuddyApp {
    static func main() {
        let application = NSApplication.shared
        let delegate = DesktopBuddyApplicationDelegate()
        application.delegate = delegate
        application.setActivationPolicy(.accessory)
        application.run()
    }
}

@MainActor
final class DesktopBuddyApplicationDelegate: NSObject, NSApplicationDelegate {
    private let coordinator = AppCoordinator()

    func applicationDidFinishLaunching(_ notification: Notification) {
        Task {
            await coordinator.start()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
