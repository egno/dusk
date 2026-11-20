import AppKit
import DuskCore
import ServiceManagement

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private enum Key {
        static let level = "dimLevel"
        static let backlight = "useBacklight"
        static let restoreOnClick = "restoreOnClick"
        static let shortcut = "shortcut"
    }

    private static let levels: [(String, Double)] = [("Black", 0), ("10%", 0.1), ("25%", 0.25), ("50%", 0.5)]

    private let defaults = UserDefaults.standard
    private let backlight = BacklightBackend()
    private let gamma = GammaBackend()
    private lazy var controller = DimController(
        level: defaults.object(forKey: Key.level) as? Double ?? 0.1,
        displays: activeDisplays,
        backends: { [unowned self] in
            var backends: [DimmingBackend] = [self.gamma]
            if self.useBacklight, let backlight = self.backlight { backends.insert(backlight, at: 0) }
            return backends
        })
    private lazy var hotKey = HotKey { [unowned self] in self.controller.toggle() }
    private lazy var clicks = ClickWatcher { [unowned self] in self.controller.restore() }
    private let recorder = ShortcutRecorder()
    private var statusItem: NSStatusItem!
    private var hotKeyFailed = false

    private var useBacklight: Bool {
        get { defaults.object(forKey: Key.backlight) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Key.backlight) }
    }

    private var restoreOnClick: Bool {
        get { defaults.object(forKey: Key.restoreOnClick) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Key.restoreOnClick) }
    }

    private var shortcut: Shortcut {
        get {
            defaults.data(forKey: Key.shortcut).flatMap { try? JSONDecoder().decode(Shortcut.self, from: $0) }
                ?? .default
        }
        set { defaults.set(try? JSONEncoder().encode(newValue), forKey: Key.shortcut) }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
        updateIcon()

        controller.onChange = { [unowned self] dimmed in
            if dimmed && restoreOnClick { clicks.start() } else { clicks.stop() }
            updateIcon()
        }
        hotKeyFailed = !hotKey.register(shortcut)

        // Displays coming and going, or waking from sleep, can reset gamma behind our back: start over undimmed.
        NotificationCenter.default.addObserver(
            self, selector: #selector(displaysChanged),
            name: NSApplication.didChangeScreenParametersNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(displaysChanged), name: NSWorkspace.didWakeNotification, object: nil)
    }

    @objc private func displaysChanged() {
        controller.restore()
    }

    func applicationWillTerminate(_ notification: Notification) {
        controller.restore()
    }

    private func updateIcon() {
        let name = controller.isDimmed ? "moon.fill" : "sun.max"
        statusItem.button?.image = NSImage(systemSymbolName: name, accessibilityDescription: "Dusk")
    }

    // MARK: Menu

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        let toggle = item(controller.isDimmed ? "Restore Brightness" : "Dim Displays", #selector(toggleDim))
        if !hotKeyFailed, shortcut.key.count == 1 {
            toggle.keyEquivalent = shortcut.key.lowercased()
            toggle.keyEquivalentModifierMask = modifierFlags(shortcut.modifiers)
        }
        menu.addItem(toggle)
        if hotKeyFailed {
            let warning = NSMenuItem(title: "\(shortcut.label) is taken by another app", action: nil, keyEquivalent: "")
            warning.isEnabled = false
            menu.addItem(warning)
        }
        menu.addItem(.separator())

        let levelMenu = NSMenu()
        for (index, (title, value)) in Self.levels.enumerated() {
            let i = item(title, #selector(setLevel(_:)))
            i.tag = index
            i.state = abs(controller.level - value) < 0.001 ? .on : .off
            levelMenu.addItem(i)
        }
        let levelItem = NSMenuItem(title: "Dim To", action: nil, keyEquivalent: "")
        levelItem.submenu = levelMenu
        menu.addItem(levelItem)

        let click = item("Restore on Mouse Click", #selector(toggleRestoreOnClick))
        click.state = restoreOnClick ? .on : .off
        menu.addItem(click)

        let hw = item("Also Lower Hardware Backlight", #selector(toggleBacklight))
        hw.state = useBacklight ? .on : .off
        hw.isEnabled = backlight != nil
        hw.toolTip = "On top of gamma dimming, lowers the real backlight on displays that support it (built-in, Apple, LG UltraFine)."
        menu.addItem(hw)

        menu.addItem(item("Hotkey: \(shortcut.label)…", #selector(recordShortcut)))

        let login = item("Launch at Login", #selector(toggleLaunchAtLogin))
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(login)

        menu.addItem(.separator())
        menu.addItem(item("Quit Dusk", #selector(quit), key: "q"))
    }

    private func item(_ title: String, _ action: Selector, key: String = "") -> NSMenuItem {
        let i = NSMenuItem(title: title, action: action, keyEquivalent: key)
        i.target = self
        return i
    }

    private func modifierFlags(_ m: Shortcut.Modifiers) -> NSEvent.ModifierFlags {
        var f: NSEvent.ModifierFlags = []
        if m.contains(.command) { f.insert(.command) }
        if m.contains(.option) { f.insert(.option) }
        if m.contains(.control) { f.insert(.control) }
        if m.contains(.shift) { f.insert(.shift) }
        return f
    }

    @objc private func toggleDim() {
        controller.toggle()
    }

    @objc private func setLevel(_ sender: NSMenuItem) {
        let wasDimmed = controller.isDimmed
        controller.restore()
        controller.level = Self.levels[sender.tag].1
        defaults.set(controller.level, forKey: Key.level)
        if wasDimmed { controller.dim() }
    }

    @objc private func toggleRestoreOnClick() {
        restoreOnClick.toggle()
        if controller.isDimmed && restoreOnClick { clicks.start() } else { clicks.stop() }
    }

    @objc private func toggleBacklight() {
        controller.restore()
        useBacklight.toggle()
    }

    @objc private func recordShortcut() {
        controller.restore()
        hotKey.unregister()
        recorder.record(current: shortcut) { [unowned self] new in
            if let new, hotKey.register(new) {
                shortcut = new
                hotKeyFailed = false
            } else {
                if new != nil {
                    let alert = NSAlert()
                    alert.messageText = "\(new!.label) is already used by another app."
                    alert.runModal()
                }
                hotKeyFailed = !hotKey.register(shortcut)
            }
        }
    }

    @objc private func toggleLaunchAtLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            NSAlert(error: error).runModal()
        }
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
