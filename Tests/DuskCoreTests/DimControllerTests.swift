import Testing
@testable import DuskCore

@MainActor
final class FakeBackend: DimmingBackend {
    let supports: Set<DisplayID>
    var dimmed: [DisplayID: Double] = [:]
    var restores = 0

    init(supports: Set<DisplayID>) { self.supports = supports }

    func dim(_ displays: [DisplayID], to level: Double) -> Set<DisplayID> {
        let handled = Set(displays).intersection(supports)
        for d in handled { dimmed[d] = level }
        return handled
    }

    func restore() {
        dimmed = [:]
        restores += 1
    }
}

@MainActor
struct DimControllerTests {
    @Test func backendsStackOnDisplaysTheySupport() {
        let backlight = FakeBackend(supports: [1])
        let gamma = FakeBackend(supports: [1, 2, 3])
        let c = DimController(level: 0.25, displays: { [1, 2, 3] }, backends: { [backlight, gamma] })

        c.dim()

        #expect(c.isDimmed)
        #expect(backlight.dimmed == [1: 0.25])
        #expect(gamma.dimmed == [1: 0.25, 2: 0.25, 3: 0.25])
    }

    @Test func toggleRestoresOnlyUsedBackends() {
        let unused = FakeBackend(supports: [])
        let gamma = FakeBackend(supports: [1])
        let c = DimController(level: 0.1, displays: { [1] }, backends: { [unused, gamma] })

        c.toggle()
        c.toggle()

        #expect(!c.isDimmed)
        #expect(gamma.restores == 1)
        #expect(unused.restores == 0)
        #expect(gamma.dimmed.isEmpty)
    }

    @Test func repeatedDimAndRestoreAreIgnored() {
        let gamma = FakeBackend(supports: [1])
        var changes: [Bool] = []
        let c = DimController(level: 0.5, displays: { [1] }, backends: { [gamma] })
        c.onChange = { changes.append($0) }

        c.restore()
        c.dim()
        c.dim()
        c.restore()
        c.restore()

        #expect(changes == [true, false])
        #expect(gamma.restores == 1)
    }

    @Test func levelIsClamped() {
        #expect(DimController(level: 3, displays: { [] }, backends: { [] }).level == 1)
        #expect(DimController(level: -1, displays: { [] }, backends: { [] }).level == 0)
    }

    @Test func shortcutLabelAndValidity() {
        #expect(Shortcut.default.label == "⌃⌥⌘D")
        #expect(Shortcut.default.isValid)
        #expect(!Shortcut(keyCode: 2, modifiers: [.shift], key: "D").isValid)
    }
}
