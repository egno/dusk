import CoreGraphics

public typealias DisplayID = CGDirectDisplayID

/// One way of making displays darker, e.g. the hardware backlight or the gamma table.
@MainActor
public protocol DimmingBackend: AnyObject {
    /// Dims the displays this backend can handle to `level` (0...1) of their current brightness and remembers the
    /// originals. Returns the displays it dimmed; the rest are offered to the next backend.
    func dim(_ displays: [DisplayID], to level: Double) -> Set<DisplayID>
    /// Puts every display dimmed since the last restore back to its remembered brightness.
    func restore()
}

/// Toggles between dimmed and normal, trying backends in priority order for each display.
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
        var remaining = displays()
        used = []
        for backend in backends() where !remaining.isEmpty {
            let handled = backend.dim(remaining, to: level)
            if !handled.isEmpty { used.append(backend) }
            remaining.removeAll { handled.contains($0) }
        }
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
