import RealityKit
import simd

/// RealityKit 只提供圆锥，没有锥台。天宫实验舱的前锥段与神舟返回舱都是
/// 「粗端收细到一个小圆」的锥台，用圆锥近似会变成尖头戳在圆柱端面上。
enum TiangongMesh {
    static func frustum(
        topRadius: Float,
        bottomRadius: Float,
        height: Float,
        sides: Int = 32
    ) -> MeshResource {
        var positions: [SIMD3<Float>] = []
        var indices: [UInt32] = []
        let half = height / 2

        for index in 0...sides {
            let angle = Float(index) / Float(sides) * 2 * .pi
            let x = cos(angle)
            let z = sin(angle)
            positions.append(SIMD3(bottomRadius * x, -half, bottomRadius * z))
            positions.append(SIMD3(topRadius * x, half, topRadius * z))
        }

        for index in 0..<sides {
            let bottom = UInt32(index * 2)
            let top = bottom + 1
            let nextBottom = bottom + 2
            let nextTop = bottom + 3
            indices += [bottom, nextBottom, top, top, nextBottom, nextTop]
        }

        let bottomCenter = UInt32(positions.count)
        positions.append(SIMD3(0, -half, 0))
        for index in 0..<sides {
            let current = UInt32(index * 2)
            let next = UInt32((index + 1) * 2)
            indices += [bottomCenter, next, current]
        }

        let topCenter = UInt32(positions.count)
        positions.append(SIMD3(0, half, 0))
        for index in 0..<sides {
            let current = UInt32(index * 2 + 1)
            let next = UInt32((index + 1) * 2 + 1)
            indices += [topCenter, current, next]
        }

        var descriptor = MeshDescriptor(name: "frustum")
        descriptor.positions = MeshBuffer(positions)
        descriptor.primitives = .triangles(indices)
        return (try? MeshResource.generate(from: [descriptor]))
            ?? MeshResource.generateBox(size: 0.01)
    }
}
