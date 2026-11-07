import Foundation

struct SolarSystemState: Equatable, Sendable {
    static let rateRange: ClosedRange<Double> = 0.1...30
    static let dayCeiling: Double = 1_000_000

    var days: Double = 0
    var daysPerSecond: Double = 1
    var isPaused = false
    var selected: BodyID?
    var showsOrbits = true

    var rateInRange: Double {
        min(max(daysPerSecond, Self.rateRange.lowerBound), Self.rateRange.upperBound)
    }
}

enum SolarSystemAction: Equatable, Sendable {
    case advance(seconds: Double)
    case setRate(Double)
    case togglePause
    case select(BodyID?)
    case toggleOrbits
    case reset
}

enum SolarSystemReducer {
    static func reduce(_ state: inout SolarSystemState, _ action: SolarSystemAction) {
        switch action {
        case .advance(let seconds):
            guard !state.isPaused, seconds > 0 else { return }
            state.days += seconds * state.rateInRange
            state.days.formTruncatingRemainder(dividingBy: SolarSystemState.dayCeiling)

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

        }
    }
}
