import CoreGraphics
import Darwin
import DuskCore

/// Every active display, built-in and external.
func activeDisplays() -> [DisplayID] {
    var count: UInt32 = 0
    guard CGGetActiveDisplayList(0, nil, &count) == .success, count > 0 else { return [] }
    var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
    guard CGGetActiveDisplayList(count, &ids, &count) == .success else { return [] }
    return Array(ids.prefix(Int(count)))
}

/// Real backlight, via the private DisplayServices framework: built-in panels and Apple displays (Studio Display,
/// Pro Display XDR). Leaves everything else to the gamma backend.
@MainActor
final class BacklightBackend: DimmingBackend {
    private typealias CanChange = @convention(c) (CGDirectDisplayID) -> Bool
    private typealias Get = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
    private typealias Set_ = @convention(c) (CGDirectDisplayID, Float) -> Int32

    private let canChange: CanChange
    private let get: Get
    private let set: Set_
    private var saved: [DisplayID: Float] = [:]

    /// Nil when the framework or its functions are missing.
    init?() {
        guard let lib = dlopen("/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_LAZY),
              let can = dlsym(lib, "DisplayServicesCanChangeBrightness"),
              let get = dlsym(lib, "DisplayServicesGetBrightness"),
              let set = dlsym(lib, "DisplayServicesSetBrightness") else { return nil }
        canChange = unsafeBitCast(can, to: CanChange.self)
        self.get = unsafeBitCast(get, to: Get.self)
        self.set = unsafeBitCast(set, to: Set_.self)
    }

    func dim(_ displays: [DisplayID], to level: Double) -> Set<DisplayID> {
        var handled = Set<DisplayID>()
        for d in displays where canChange(d) {
            var current: Float = 0
            guard get(d, &current) == 0, set(d, current * Float(level)) == 0 else { continue }
            saved[d] = current
            handled.insert(d)
        }
        return handled
    }

    func restore() {
        for (d, brightness) in saved { _ = set(d, brightness) }
        saved = [:]
    }
}

/// Scales each display's gamma table. Works on any display, including ones without DDC; macOS resets it if Dusk
/// quits or crashes, so a display can't get stuck dark.
@MainActor
final class GammaBackend: DimmingBackend {
    private struct Table {
        var red: [CGGammaValue], green: [CGGammaValue], blue: [CGGammaValue]
        var count: UInt32
    }

    private var saved: [DisplayID: Table] = [:]

    func dim(_ displays: [DisplayID], to level: Double) -> Set<DisplayID> {
        var handled = Set<DisplayID>()
        let f = CGGammaValue(level)
        for d in displays {
            let capacity = CGDisplayGammaTableCapacity(d)
            guard capacity > 0 else { continue }
            var t = Table(red: .init(repeating: 0, count: Int(capacity)),
                          green: .init(repeating: 0, count: Int(capacity)),
                          blue: .init(repeating: 0, count: Int(capacity)), count: 0)
            guard CGGetDisplayTransferByTable(d, capacity, &t.red, &t.green, &t.blue, &t.count) == .success,
                  t.count > 0 else { continue }
            let ok = CGSetDisplayTransferByTable(d, t.count, t.red.map { $0 * f }, t.green.map { $0 * f },
                                                 t.blue.map { $0 * f })
            guard ok == .success else { continue }
            saved[d] = t
            handled.insert(d)
        }
        return handled
    }

    func restore() {
        for (d, t) in saved {
            CGSetDisplayTransferByTable(d, t.count, t.red, t.green, t.blue)
        }
        saved = [:]
    }
}
