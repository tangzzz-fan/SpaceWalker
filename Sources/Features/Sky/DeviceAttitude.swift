import CoreMotion
import Foundation
import os
import simd

private final class AttitudeBox: @unchecked Sendable {
    private let lock = OSAllocatedUnfairLock(initialState: SIMD3<Float>(0, 0, -1))

    func set(_ value: SIMD3<Float>) {
        lock.withLock { $0 = value }
    }

    func value() -> SIMD3<Float> {
        lock.withLock { $0 }
    }
}

@MainActor
final class DeviceAttitude {
    private let manager = CMMotionManager()
    private let box = AttitudeBox()
    private(set) var isAvailable = false

    func start() {
        guard manager.isDeviceMotionAvailable else {
            SessionLog.append("sky.motion unavailable")
            return
        }
        isAvailable = true
        manager.gyroUpdateInterval = 1.0 / 30.0
        manager.deviceMotionUpdateInterval = 1.0 / 30.0
        manager.startDeviceMotionUpdates(using: .xArbitraryZVertical, to: .main) { [box] motion, _ in
            guard let motion else { return }
            let q = motion.attitude.quaternion
            let rotation = simd_quatf(vector: SIMD4<Float>(Float(q.x), Float(q.y), Float(q.z), Float(q.w)))
            let forward = rotation.act(SIMD3<Float>(0, 0, -1))
            box.set(SIMD3<Float>(forward.x, forward.z, forward.y))
        }
        SessionLog.append("sky.motion started")
    }

    func stop() {
        manager.stopDeviceMotionUpdates()
        isAvailable = false
    }

    func currentForward() -> SIMD3<Float>? {
        isAvailable ? box.value() : nil
    }
}
