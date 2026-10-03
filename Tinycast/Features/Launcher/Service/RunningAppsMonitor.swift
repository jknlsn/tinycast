import AppKit

/// Tracks running apps for the launcher's indicator, live from NSWorkspace.
@MainActor
@Observable
final class RunningAppsMonitor {
    private(set) var runningBundleIDs: Set<String> = []
    @ObservationIgnored private var observers: [NotificationToken] = []

    init() {
        refresh()
        let center = NSWorkspace.shared.notificationCenter
        for name in [
            NSWorkspace.didLaunchApplicationNotification,
            NSWorkspace.didTerminateApplicationNotification
        ] {
            let token = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.refresh()
                    guard name == NSWorkspace.didTerminateApplicationNotification else { return }
                    // A dying app can still sit in the snapshot this notification arrives with.
                    Task { @MainActor [weak self] in
                        try? await Task.sleep(for: .milliseconds(500))
                        self?.refresh()
                    }
                }
            }
            observers.append(NotificationToken(token, center: center))
        }
    }

    /// True while the entry's bundle runs; drives the running dot and the Quit action.
    func isRunning(_ app: AppEntry) -> Bool {
        guard let bundleID = app.bundleID else { return false }
        return runningBundleIDs.contains(bundleID)
    }

    /// Re-reads the live set; the palette also calls this on open, so a missed event can't stick.
    func refresh() {
        let next = Set(
            NSWorkspace.shared.runningApplications.filter { !$0.isTerminated }
                .compactMap(\.bundleIdentifier))
        // Helpers and agents fire these too, so republish only on a real change.
        guard next != runningBundleIDs else { return }
        runningBundleIDs = next
    }
}
