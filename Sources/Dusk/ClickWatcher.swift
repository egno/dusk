import AppKit

/// Calls back on any mouse button press, in any app. Mouse monitors need no Accessibility permission.
@MainActor
final class ClickWatcher {
    private var monitors: [Any] = []
    private let onClick: () -> Void

    init(onClick: @escaping () -> Void) {
        self.onClick = onClick
    }

    func start() {
        guard monitors.isEmpty else { return }
        let mask: NSEvent.EventTypeMask = [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        if let global = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: { [weak self] _ in
            MainActor.assumeIsolated { self?.onClick() }
        }) { monitors.append(global) }
        // Global monitors skip Dusk's own events, e.g. a click on its menu bar icon.
        if let local = NSEvent.addLocalMonitorForEvents(matching: mask, handler: { [weak self] event in
            self?.onClick()
            return event
        }) { monitors.append(local) }
    }

    func stop() {
        monitors.forEach(NSEvent.removeMonitor)
        monitors = []
    }
}
