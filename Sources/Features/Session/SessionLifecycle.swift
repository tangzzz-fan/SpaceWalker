import Foundation

enum SessionPhase: String, Equatable, Sendable {
    case idle
    case running
    case suspended
    case interrupted
    case failed
}

enum SessionEvent: Equatable, Sendable {
    case appeared
    case disappeared
    case becameActive
    case becameInactive
    case enteredBackground
}

enum SessionCommand: Equatable, Sendable {
    case start
    case stop
    case suspend
    case resume
}

struct SessionTransition: Equatable, Sendable {
    var phase: SessionPhase
    var command: SessionCommand?
}

enum SessionLifecycle {
    static func transition(from phase: SessionPhase, on event: SessionEvent) -> SessionTransition {
        switch (phase, event) {
        case (_, .appeared):
            return phase == .running
                ? SessionTransition(phase: .running, command: nil)
                : SessionTransition(phase: .running, command: .start)

        case (_, .disappeared):
            return phase == .idle
                ? SessionTransition(phase: .idle, command: nil)
                : SessionTransition(phase: .idle, command: .stop)

        case (.running, .becameActive):
            return SessionTransition(phase: .running, command: nil)

        case (.suspended, .becameActive), (.interrupted, .becameActive):
            return SessionTransition(phase: .running, command: .resume)

        case (.idle, .becameActive), (.failed, .becameActive):
            return SessionTransition(phase: phase, command: nil)

        case (.running, .becameInactive):
            return SessionTransition(phase: .interrupted, command: .suspend)

        case (.suspended, .becameInactive):
            return SessionTransition(phase: .interrupted, command: nil)

        case (.idle, .becameInactive), (.interrupted, .becameInactive), (.failed, .becameInactive):
            return SessionTransition(phase: phase, command: nil)

        case (.running, .enteredBackground):
            return SessionTransition(phase: .suspended, command: .suspend)

        case (.idle, .enteredBackground), (.suspended, .enteredBackground),
             (.interrupted, .enteredBackground), (.failed, .enteredBackground):
            return SessionTransition(phase: phase, command: nil)
        }
    }
}
