import Foundation
import simd

struct SkyRig: Equatable, Sendable {
    static let pitchRange: ClosedRange<Float> = (-1.35)...1.35
    static let dragSensitivity: Float = 0.004

    var yaw: Float = 0
    var pitch: Float = 0

    var orientation: simd_quatf {
        let yawRotation = simd_quatf(angle: yaw, axis: SIMD3(0, 1, 0))
        let pitchRotation = simd_quatf(angle: pitch, axis: SIMD3(1, 0, 0))
        // yaw/pitch 描述的是「相机」：先抬头再左右转，相机不会滚。
        // 但这里要的是星空的朝向，得取逆——直接用 Ry·Rx 的话，
        // 俯仰 40° 之后再横着转，整片天会跟着滚（实测最大 58°）。
        return pitchRotation.inverse * yawRotation.inverse
    }

    mutating func drag(deltaX: Float, deltaY: Float) {
        yaw += deltaX * Self.dragSensitivity
        pitch = Self.clamp(pitch + deltaY * Self.dragSensitivity)
    }

    private static func clamp(_ value: Float) -> Float {
        min(max(value, pitchRange.lowerBound), pitchRange.upperBound)
    }
}

enum AttitudeMath {
    enum Convention: String, Sendable {
        case deviceToReference = "device->reference"
        case referenceToDevice = "reference->device"
    }

    struct Solution: Sendable {
        var sceneOrientation: simd_quatf
        var deviceForward: SIMD3<Float>
        var convention: Convention
        var gravityError: SIMD2<Float>
    }

    static let worldGravity = SIMD3<Float>(0, -1, 0)
    static let referenceToWorld = simd_quatf(angle: -.pi / 2, axis: SIMD3<Float>(1, 0, 0))

    static func solve(attitude: simd_quatf, gravity: SIMD3<Float>) -> Solution {
        let asDeviceToReference = referenceToWorld * attitude
        let asReferenceToDevice = referenceToWorld * attitude.inverse
        let errorA = simd_length(asDeviceToReference.act(gravity) - worldGravity)
        let errorB = simd_length(asReferenceToDevice.act(gravity) - worldGravity)
        let usesDeviceToReference = errorA <= errorB
        let world = usesDeviceToReference ? asDeviceToReference : asReferenceToDevice

        return Solution(
            sceneOrientation: world.inverse,
            deviceForward: world.act(SIMD3<Float>(0, 0, -1)),
            convention: usesDeviceToReference ? .deviceToReference : .referenceToDevice,
            gravityError: SIMD2<Float>(errorA, errorB)
        )
    }
}
