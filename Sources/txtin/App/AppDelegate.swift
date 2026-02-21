import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarManager: MenuBarManager?
    private let terminationReason = "txtin menu bar active"

    func applicationDidFinishLaunching(_ notification: Notification) {
        enforceSingleInstance()

        NSApp.setActivationPolicy(.accessory)
        ProcessInfo.processInfo.disableAutomaticTermination(terminationReason)

        PermissionsManager.shared.refresh()
        ConfigManager.shared.refresh()

        TxtinCoordinator.shared.setupHotkey()

        menuBarManager = MenuBarManager(
            coordinator: TxtinCoordinator.shared,
            appState: AppState.shared
        )
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationWillTerminate(_ notification: Notification) {
        ProcessInfo.processInfo.enableAutomaticTermination(terminationReason)
    }

    private func enforceSingleInstance() {
        guard let bundleID = Bundle.main.bundleIdentifier else { return }
        let currentPID = ProcessInfo.processInfo.processIdentifier
        let duplicates = NSRunningApplication
            .runningApplications(withBundleIdentifier: bundleID)
            .filter { $0.processIdentifier != currentPID }

        guard !duplicates.isEmpty else { return }

        for app in duplicates {
            _ = app.terminate()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            for app in duplicates where !app.isTerminated {
                _ = app.forceTerminate()
            }
        }
    }
}
