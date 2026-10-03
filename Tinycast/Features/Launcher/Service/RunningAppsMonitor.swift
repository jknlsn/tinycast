import AppKit

@MainActor
@Observable
final class RunningAppsMonitor {
    private(set) var runningBundleIDs: Set<String> = []
    private var runningAppPaths: Set<String> = []
    @ObservationIgnored private var observation: NSKeyValueObservation?

    init() {
        observation = NSWorkspace.shared.observe(
            \.runningApplications, options: .initial
        ) { [weak self] _, _ in
            MainActor.assumeIsolated { self?.refresh() }
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
