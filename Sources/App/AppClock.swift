import Foundation

enum AppClock {
    static let launchUptime = ProcessInfo.processInfo.systemUptime

    static func elapsedMilliseconds(now: TimeInterval = ProcessInfo.processInfo.systemUptime) -> Int {
        milliseconds(from: launchUptime, to: now)
    }

    static func milliseconds(from start: TimeInterval, to end: TimeInterval) -> Int {
        Int(((end - start) * 1000).rounded())
    }
}
