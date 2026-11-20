import AppKit
import DuskCore

/// A small window that captures the next key combination as the new hotkey. Esc cancels.
@MainActor
final class ShortcutRecorder: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private var monitor: Any?
    private var completion: ((Shortcut?) -> Void)?
    private let label = NSTextField(labelWithString: "")

    func record(current: Shortcut, completion: @escaping (Shortcut?) -> Void) {
        finish(nil)
        self.completion = completion

        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 320, height: 110),
                         styleMask: [.titled, .closable], backing: .buffered, defer: false)
        w.title = "Dusk Hotkey"
        w.isReleasedWhenClosed = false
        w.level = .floating
        w.delegate = self

        let title = NSTextField(labelWithString: "Press the new shortcut")
        title.font = .boldSystemFont(ofSize: 13)
        label.stringValue = "Current: \(current.label)   ·   Esc to cancel"
        label.textColor = .secondaryLabelColor
        let stack = NSStackView(views: [title, label])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.translatesAutoresizingMaskIntoConstraints = false
        w.contentView?.addSubview(stack)
        if let content = w.contentView {
            NSLayoutConstraint.activate([
                stack.centerXAnchor.constraint(equalTo: content.centerXAnchor),
                stack.centerYAnchor.constraint(equalTo: content.centerYAnchor),
            ])
        }

        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handle(event)
            return nil
        }
        window = w
        w.center()
        NSApp.activate(ignoringOtherApps: true)
        w.makeKeyAndOrderFront(nil)
    }

    private func handle(_ event: NSEvent) {
        if event.keyCode == 53, event.modifierFlags.intersection(.deviceIndependentFlagsMask).isEmpty {
            finish(nil)  // Esc
            return
        }
        guard let shortcut = Shortcut(event: event) else { return }
        guard shortcut.isValid else {
            label.stringValue = "Include ⌘, ⌃ or ⌥"
            NSSound.beep()
            return
        }
        finish(shortcut)
    }

    private func finish(_ shortcut: Shortcut?) {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        let done = completion
        completion = nil
        window?.delegate = nil
        window?.close()
        window = nil
        done?(shortcut)
    }

    func windowWillClose(_ notification: Notification) {
        finish(nil)
    }
}
