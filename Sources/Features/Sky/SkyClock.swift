import Foundation

struct SkyClock: Equatable, Sendable {
    private(set) var base: Date
    private(set) var offsetHours: Double

    init(base: Date = Date(), offsetHours: Double = 0) {
        self.base = base
        self.offsetHours = min(max(offsetHours, -24), 24)
    }

    var isNow: Bool {
        abs(offsetHours) < 1.0 / 120
    }

    func instant(now: Date = Date()) -> Date {
        isNow ? now : base.addingTimeInterval(offsetHours * 3600)
    }

    mutating func setOffset(hours: Double, at now: Date = Date()) {
        let wasNow = isNow
        offsetHours = min(max(hours, -24), 24)
        if wasNow, !isNow {
            base = now
        }
    }

    mutating func reset(to date: Date = Date()) {
        base = date
        offsetHours = 0
    }
}
