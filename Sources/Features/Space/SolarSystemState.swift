import Foundation

struct SolarSystemState: Equatable, Sendable {
    static let rateRange: ClosedRange<Double> = 0.1...30
    static let scrubRange: ClosedRange<Double> = -365.25...365.25

    var epochJulianDay: Double = SolarSystemState.todayEpoch()
    var days: Double = 0
    var daysPerSecond: Double = 1
    var isPaused = false
    var selected: BodyID?
    var showsOrbits = true
    var narrative = ScaleNarrative()

    var rateInRange: Double {
        min(max(daysPerSecond, Self.rateRange.lowerBound), Self.rateRange.upperBound)
    }

    var julianDay: Double { epochJulianDay + days }

    static func todayEpoch(now: Date = Date()) -> Double {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        let startOfDay = calendar.startOfDay(for: now)
        return Ephemeris.julianDay(utc: startOfDay)
    }

    static func scrubbed(_ days: Double) -> Double {
        min(max(days, scrubRange.lowerBound), scrubRange.upperBound)
    }

    /// PRD-UI:183：流速档位以「x 天/秒」上状态条。整数不带小数，0.1 档保留一位。
    static func rateStatusText(_ rate: Double) -> String {
        if rate == rate.rounded() {
            return "\(Int(rate)) 天/秒"
        }
        return String(format: "%.1f 天/秒", rate)
    }

    static func statusDetail(days: Double, isPaused: Bool, rate: Double) -> String {
        let phase = isPaused ? "已暂停" : "运行中"
        return "\(phase) · 第 \(Int(days)) 天 · \(rateStatusText(rate))"
    }
}

enum SolarSystemAction: Equatable, Sendable {
    case advance(seconds: Double)
    case setRate(Double)
    case scrub(days: Double)
    case togglePause
    case select(BodyID?)
    case toggleOrbits
    case reset
    case enterOverview
    case finishScaleNarrative
}

/// ADR-0006 D4：真比例不做开关，做一帧叙事。每次进入全览最多播一次，
/// 播完自动回教学比例；状态机只记「播没播」，计时由视图驱动。
struct ScaleNarrative: Equatable, Sendable {
    static let duration: Double = 0.6
    static let rulerText = "此刻行星直径 < 1 像素"

    enum Phase: Equatable, Sendable {
        case idle
        case playing
        case played
    }

    private(set) var phase: Phase = .idle
    private(set) var playCount = 0

    var isPlaying: Bool { phase == .playing }

    mutating func enterOverview() {
        guard phase == .idle else { return }
        phase = .playing
        playCount += 1
    }

    mutating func finish() {
        guard phase == .playing else { return }
        phase = .played
    }
}

enum SolarSystemReducer {
    static func reduce(_ state: inout SolarSystemState, _ action: SolarSystemAction) {
        switch action {
        case .advance(let seconds):
            guard !state.isPaused, seconds > 0 else { return }
            state.days = SolarSystemState.scrubbed(state.days + seconds * state.rateInRange)

        case .scrub(let days):
            state.days = SolarSystemState.scrubbed(days)

        case .setRate(let rate):
            state.daysPerSecond = min(
                max(rate, SolarSystemState.rateRange.lowerBound),
                SolarSystemState.rateRange.upperBound
            )

        case .togglePause:
            state.isPaused.toggle()

        case .select(let id):
            state.selected = id

        case .toggleOrbits:
            state.showsOrbits.toggle()

        case .reset:
            state.days = 0
            state.selected = nil

        case .enterOverview:
            state.narrative.enterOverview()

        case .finishScaleNarrative:
            state.narrative.finish()
        }
    }
}
