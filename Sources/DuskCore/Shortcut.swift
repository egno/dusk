/// A global hotkey: a virtual key code plus Carbon modifier flags, with a label for the menu.
public struct Shortcut: Codable, Equatable, Sendable {
    public struct Modifiers: OptionSet, Codable, Sendable {
        public let rawValue: UInt32
        public init(rawValue: UInt32) { self.rawValue = rawValue }
        // Carbon's cmdKey, shiftKey, optionKey, controlKey.
        public static let command = Modifiers(rawValue: 1 << 8)
        public static let shift = Modifiers(rawValue: 1 << 9)
        public static let option = Modifiers(rawValue: 1 << 11)
        public static let control = Modifiers(rawValue: 1 << 12)
    }

    public var keyCode: UInt32
    public var modifiers: Modifiers
    /// The key's character as typed, e.g. "D" or "F5".
    public var key: String

    public init(keyCode: UInt32, modifiers: Modifiers, key: String) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.key = key
    }

    /// ⌃⌥⌘D
    public static let `default` = Shortcut(keyCode: 2, modifiers: [.control, .option, .command], key: "D")

    /// A global hotkey needs ⌘, ⌃ or ⌥ so it doesn't swallow ordinary typing.
    public var isValid: Bool {
        !modifiers.isDisjoint(with: [.command, .control, .option])
    }

    public var label: String {
        var s = ""
        if modifiers.contains(.control) { s += "⌃" }
        if modifiers.contains(.option) { s += "⌥" }
        if modifiers.contains(.shift) { s += "⇧" }
        if modifiers.contains(.command) { s += "⌘" }
        return s + key
    }
}
