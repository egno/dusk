import CoreGraphics

public typealias DisplayID = CGDirectDisplayID

/// One way of making displays darker, e.g. the hardware backlight or the gamma table.
@MainActor
public protocol DimmingBackend: AnyObject {
    /// Dims the displays this backend can handle to `level` (0...1) of their current brightness and remembers the
    /// originals. Returns the displays it dimmed.
    func dim(_ displays: [DisplayID], to level: Double) -> Set<DisplayID>
    /// Puts every display dimmed since the last restore back to its remembered brightness.
    func restore()
}

/// Toggles between dimmed and normal. Backends stack: each dims every display it can, so a display whose backlight
/// can't go fully dark (e.g. an LG UltraFine at 0) is darkened further by gamma.
@MainActor
public final class DimController {
    public private(set) var isDimmed = false
    /// Fraction of the original brightness to dim to.
    public var level: Double
    public var onChange: ((Bool) -> Void)?

    private let displays: () -> [DisplayID]
    private let backends: () -> [DimmingBackend]
    private var used: [DimmingBackend] = []

    public init(level: Double, displays: @escaping () -> [DisplayID], backends: @escaping () -> [DimmingBackend]) {
        self.level = min(max(level, 0), 1)
        self.displays = displays
        self.backends = backends
    }

    public func toggle() {
        isDimmed ? restore() : dim()
    }

    public func dim() {
        guard !isDimmed else { return }
        let all = displays()
        used = backends().filter { !$0.dim(all, to: level).isEmpty }
        isDimmed = true
        onChange?(true)
    }

    public func restore() {
        guard isDimmed else { return }
        used.forEach { $0.restore() }
        used = []
        isDimmed = false
        onChange?(false)
    }
}
