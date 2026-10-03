import AppKit

@MainActor
@Observable
final class RunningAppsMonitor {
    private(set) var runningBundleIDs: Set<String> = []
    private var runningAppPaths: Set<String> = []
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

    func isRunning(_ app: AppEntry) -> Bool {
        app.kind == .application && app.bundleID != nil && runningAppPaths.contains(app.id)
    }

    /// Re-reads the live set; the palette also calls this on open, so a missed event can't stick.
    func refresh() {
        let apps = NSWorkspace.shared.runningApplications.filter { !$0.isTerminated }
        let bundleIDs = Set(apps.compactMap(\.bundleIdentifier))
        let paths = Set(apps.compactMap { $0.bundleURL?.resolvingSymlinksInPath().standardizedFileURL.path })
        if bundleIDs != runningBundleIDs { runningBundleIDs = bundleIDs }
        if paths != runningAppPaths { runningAppPaths = paths }
    }
}
