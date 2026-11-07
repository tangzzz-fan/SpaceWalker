import Foundation
import RealityKit
import simd

struct TorusMeshData: Equatable, Sendable {
    var positions: [SIMD3<Float>]
    var normals: [SIMD3<Float>]
    var indices: [UInt32]
}

enum OrbitRing {
    static func torus(
        majorRadius: Float,
        minorRadius: Float,
        majorSegments: Int = 128,
        minorSegments: Int = 6
    ) -> TorusMeshData {
        precondition(majorSegments >= 3 && minorSegments >= 3)

        var positions: [SIMD3<Float>] = []
        var normals: [SIMD3<Float>] = []
        let count = majorSegments * minorSegments
        positions.reserveCapacity(count)
        normals.reserveCapacity(count)

        for major in 0..<majorSegments {
            let u = 2 * Float.pi * Float(major) / Float(majorSegments)
            let cosU = cos(u)
            let sinU = sin(u)
            for minor in 0..<minorSegments {
                let v = 2 * Float.pi * Float(minor) / Float(minorSegments)
                let cosV = cos(v)
                let sinV = sin(v)
                let normal = SIMD3<Float>(cosU * cosV, sinV, sinU * cosV)
                let center = SIMD3<Float>(cosU * majorRadius, 0, sinU * majorRadius)
                positions.append(center + normal * minorRadius)
                normals.append(normal)
            }
        }

        var indices: [UInt32] = []
        indices.reserveCapacity(count * 6)
        for major in 0..<majorSegments {
            let nextMajor = (major + 1) % majorSegments
            for minor in 0..<minorSegments {
                let nextMinor = (minor + 1) % minorSegments
                let a = UInt32(major * minorSegments + minor)
                let b = UInt32(nextMajor * minorSegments + minor)
                let c = UInt32(nextMajor * minorSegments + nextMinor)
                let d = UInt32(major * minorSegments + nextMinor)
                indices.append(contentsOf: [a, b, c, a, c, d])
            }
        }

        return TorusMeshData(positions: positions, normals: normals, indices: indices)
    }

    static func mesh(_ data: TorusMeshData, name: String) throws -> MeshResource {
        var descriptor = MeshDescriptor(name: name)
        descriptor.positions = MeshBuffers.Positions(data.positions)
        descriptor.normals = MeshBuffers.Normals(data.normals)
        descriptor.primitives = .triangles(data.indices)
        return try MeshResource.generate(from: [descriptor])
    }
}

struct OrbitRig: Equatable, Sendable {
    static let pitchRange: ClosedRange<Float> = 0.08...(Float.pi * 0.47)
    static let distanceRange: ClosedRange<Float> = 4.0...18.0
    static let yawSensitivity: Float = 0.006
    static let pitchSensitivity: Float = 0.004

    var yaw: Float = 0.38
    var pitch: Float = 0.52
    var distance: Float = 12.0

    func cameraPosition() -> SIMD3<Float> {
        let horizontal = distance * cos(pitch)
        return SIMD3(horizontal * sin(yaw), distance * sin(pitch), horizontal * cos(yaw))
    }

    mutating func rotate(deltaX: Float, deltaY: Float) {
        yaw += deltaX * Self.yawSensitivity
        pitch = min(max(pitch + deltaY * Self.pitchSensitivity, Self.pitchRange.lowerBound), Self.pitchRange.upperBound)
    }

    mutating func dolly(scale: Float) {
        guard scale > 0 else { return }
        distance = min(max(distance / scale, Self.distanceRange.lowerBound), Self.distanceRange.upperBound)
    }
}
