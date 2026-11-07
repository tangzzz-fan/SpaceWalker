import CoreMotion
import Foundation
import simd

@MainActor
final class DeviceAttitude {
    private static let updateInterval: TimeInterval = 1.0 / 60.0
    private static let smoothingTime: Double = 0.02

    private let manager = CMMotionManager()
    private let reportsRate = ProcessInfo.processInfo.environment["SPACEWALKER_MOTIONLOG"] == "1"
    private var sink: ((simd_quatf) -> Void)?
    private var smoothed: simd_quatf?
    private var lastTimestamp: TimeInterval = 0
    private var windowStart: TimeInterval = 0
    private var windowSamples = 0
    private var convention: AttitudeMath.Convention?
    private(set) var isAvailable = false

    func start(sink: @escaping (simd_quatf) -> Void) {
        self.sink = sink
        guard manager.isDeviceMotionAvailable else {
            SessionLog.append("sky.motion unavailable")
            return
        }
        guard !isAvailable else { return }
        isAvailable = true
        manager.deviceMotionUpdateInterval = Self.updateInterval
        manager.startDeviceMotionUpdates(using: .xArbitraryZVertical, to: .main) { [weak self] motion, error in
            guard error == nil, let motion else { return }
            let rotation = motion.attitude.quaternion
            let sample = MotionSample(
                attitude: simd_quatf(
                    ix: Float(rotation.x),
                    iy: Float(rotation.y),
                    iz: Float(rotation.z),
                    r: Float(rotation.w)
                ),
                gravity: SIMD3<Float>(
                    Float(motion.gravity.x),
                    Float(motion.gravity.y),
                    Float(motion.gravity.z)
                ),
                timestamp: motion.timestamp
            )
            MainActor.assumeIsolated {
                self?.ingest(sample)
            }
        }
        SessionLog.append("sky.motion started intervalMs=17")
    }

    func stop() {
        manager.stopDeviceMotionUpdates()
        isAvailable = false
        smoothed = nil
        lastTimestamp = 0
        windowStart = 0
        windowSamples = 0
    }

    private func ingest(_ sample: MotionSample) {
        let solution = AttitudeMath.solve(attitude: sample.attitude, gravity: sample.gravity)
        if solution.convention != convention {
            convention = solution.convention
            SessionLog.append("sky.motion convention=\(solution.convention.rawValue)")
        }

        var target = solution.sceneOrientation
        let dt = lastTimestamp > 0 ? min(max(sample.timestamp - lastTimestamp, 0.001), 0.25) : 0
        lastTimestamp = sample.timestamp

        if let current = smoothed {
            if simd_dot(current.vector, target.vector) < 0 {
                target = simd_quatf(vector: -target.vector)
            }
            let alpha = Float(1 - exp(-dt / Self.smoothingTime))
            smoothed = simd_slerp(current, target, alpha).normalized
        } else {
            smoothed = target
        }

        guard let value = smoothed else { return }
        sink?(value)
        reportRate(at: sample.timestamp, forward: solution.deviceForward)
    }

    private func reportRate(at timestamp: TimeInterval, forward: SIMD3<Float>) {
        guard reportsRate else { return }
        if windowStart == 0 {
            windowStart = timestamp
        }
        windowSamples += 1
        let elapsed = timestamp - windowStart
        guard elapsed >= 1 else { return }
        SessionLog.append(
            String(
                format: "sky.motion rate=%.0f fwd=%.2f,%.2f,%.2f",
                Double(windowSamples) / elapsed,
                Double(forward.x),
                Double(forward.y),
                Double(forward.z)
            )
        )
        windowSamples = 0
        windowStart = timestamp
    }
}

private struct MotionSample: Sendable {
    var attitude: simd_quatf
    var gravity: SIMD3<Float>
    var timestamp: TimeInterval
}
