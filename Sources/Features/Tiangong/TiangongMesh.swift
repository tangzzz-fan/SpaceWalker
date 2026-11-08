import RealityKit
import simd

/// RealityKit 只提供圆锥，没有锥台也没有母线旋转体。天宫的前锥段、后锥段、
/// 神舟返回舱与发动机喷管都是「一条母线绕轴转一圈」，统一走 `revolve`。
enum TiangongMesh {
    /// 端盖只在自由端需要。贴合到别的零件上的那一端必须留空：
    /// 两个共面的封盖会 z-fighting，渲染出来是一圈放射状锯齿。
    enum Caps {
        case none, lower, upper, both
    }

    /// 母线点：x = 半径，y = 轴向比例（0 在 −Y 端，1 在 +Y 端）。
    /// `instances` 把同一个母线复制成多份并共用一个网格——同材质的小件必须合并，
    /// 否则 10 个喷口就是 10 个 draw call。
    static func revolve(
        profile: [SIMD2<Float>],
        height: Float,
        sides: Int = 32,
        caps: Caps = .both,
        instances: [float4x4] = [matrix_identity_float4x4]
    ) -> MeshResource {
        guard profile.count >= 2, height > 0, sides >= 3 else {
            return MeshResource.generateBox(size: 0.01)
        }

        let half = height / 2
        let ringCount = profile.count
        var positions: [SIMD3<Float>] = []
        var normals: [SIMD3<Float>] = []
        var uvs: [SIMD2<Float>] = []
        var indices: [UInt32] = []

        for ring in 0..<ringCount {
            let point = profile[ring]
            let y = -half + min(max(point.y, 0), 1) * height
            let tangent = tangentAt(profile, ring: ring)
            let normal = simd_normalize(SIMD2(tangent.y, -tangent.x))
            for side in 0..<sides {
                let angle = Float(side) / Float(sides) * 2 * .pi
                let dx = cos(angle)
                let dz = sin(angle)
                positions.append(SIMD3(point.x * dx, y, point.x * dz))
                normals.append(SIMD3(normal.x * dx, normal.y, normal.x * dz))
                uvs.append(SIMD2(Float(side) / Float(sides), point.y))
            }
        }

        for ring in 0..<(ringCount - 1) {
            for side in 0..<sides {
                let next = (side + 1) % sides
                let lower = UInt32(ring * sides + side)
                let lowerNext = UInt32(ring * sides + next)
                let upper = UInt32((ring + 1) * sides + side)
                let upperNext = UInt32((ring + 1) * sides + next)
                indices += [lower, lowerNext, upper, upper, lowerNext, upperNext]
            }
        }

        if let first = profile.first, first.x > 0, caps == .lower || caps == .both {
            let base = UInt32(positions.count)
            for side in 0..<sides {
                let angle = Float(side) / Float(sides) * 2 * .pi
                positions.append(SIMD3(first.x * cos(angle), -half, first.x * sin(angle)))
                normals.append(SIMD3(0, -1, 0))
                uvs.append(SIMD2(0.5 + 0.5 * cos(angle), 0.5 + 0.5 * sin(angle)))
            }
            let center = UInt32(positions.count)
            positions.append(SIMD3(0, -half, 0))
            normals.append(SIMD3(0, -1, 0))
            uvs.append(SIMD2(0.5, 0.5))
            for side in 0..<sides {
                let current = base + UInt32(side)
                let next = base + UInt32((side + 1) % sides)
                indices += [center, next, current]
            }
        }

        if let last = profile.last, last.x > 0, caps == .upper || caps == .both {
            let base = UInt32(positions.count)
            for side in 0..<sides {
                let angle = Float(side) / Float(sides) * 2 * .pi
                positions.append(SIMD3(last.x * cos(angle), half, last.x * sin(angle)))
                normals.append(SIMD3(0, 1, 0))
                uvs.append(SIMD2(0.5 + 0.5 * cos(angle), 0.5 + 0.5 * sin(angle)))
            }
            let center = UInt32(positions.count)
            positions.append(SIMD3(0, half, 0))
            normals.append(SIMD3(0, 1, 0))
            uvs.append(SIMD2(0.5, 0.5))
            for side in 0..<sides {
                let current = base + UInt32(side)
                let next = base + UInt32((side + 1) % sides)
                indices += [center, current, next]
            }
        }

        if instances.count > 1 {
            let basePositions = positions
            let baseNormals = normals
            let baseUVs = uvs
            let baseIndices = indices
            positions = []
            normals = []
            uvs = []
            indices = []
            for (slot, transform) in instances.enumerated() {
                let rotation = simd_float3x3(
                    SIMD3(transform.columns.0.x, transform.columns.0.y, transform.columns.0.z),
                    SIMD3(transform.columns.1.x, transform.columns.1.y, transform.columns.1.z),
                    SIMD3(transform.columns.2.x, transform.columns.2.y, transform.columns.2.z)
                )
                let offset = UInt32(slot * basePositions.count)
                for position in basePositions {
                    let moved = transform * SIMD4(position, 1)
                    positions.append(SIMD3(moved.x, moved.y, moved.z))
                }
                for normal in baseNormals {
                    normals.append(simd_normalize(rotation * normal))
                }
                uvs.append(contentsOf: baseUVs)
                indices.append(contentsOf: baseIndices.map { $0 + offset })
            }
        }

        var descriptor = MeshDescriptor(name: "revolve")
        descriptor.positions = MeshBuffer(positions)
        descriptor.normals = MeshBuffer(normals)
        descriptor.textureCoordinates = MeshBuffer(uvs)
        descriptor.primitives = .triangles(indices)
        return (try? MeshResource.generate(from: [descriptor]))
            ?? MeshResource.generateBox(size: 0.01)
    }

    static func frustum(
        topRadius: Float,
        bottomRadius: Float,
        height: Float,
        sides: Int = 32,
        caps: Caps = .both
    ) -> MeshResource {
        revolve(
            profile: [SIMD2(bottomRadius, 0), SIMD2(topRadius, 1)],
            height: height,
            sides: sides,
            caps: caps
        )
    }

    static func placement(_ position: SIMD3<Float>, _ orientation: simd_quatf) -> float4x4 {
        var matrix = simd_float4x4(orientation)
        matrix.columns.3 = SIMD4(position, 1)
        return matrix
    }

    private static func tangentAt(_ profile: [SIMD2<Float>], ring: Int) -> SIMD2<Float> {
        let previous = profile[max(ring - 1, 0)]
        let next = profile[min(ring + 1, profile.count - 1)]
        let delta = next - previous
        return simd_length(delta) > 1e-6 ? delta : SIMD2(1, 0)
    }
}
