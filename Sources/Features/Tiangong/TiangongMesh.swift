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

    /// 半开的舱壳：只造一段圆弧（含厚度、两端封口、两条侧壁），缺口朝向由外部旋转决定。
    /// RealityKit 没有裁剪平面，所以剖面不是"切"，是"本来就只有这一半"。
    static func arcShell(
        radius: Float,
        thickness: Float,
        height: Float,
        sweep: Float,
        sides: Int = 28
    ) -> MeshResource {
        guard radius > thickness, thickness > 0, height > 0, sweep > 0, sides >= 4 else {
            return MeshResource.generateBox(size: 0.01)
        }

        let half = height / 2
        let inner = radius - thickness
        var positions: [SIMD3<Float>] = []
        var normals: [SIMD3<Float>] = []
        var uvs: [SIMD2<Float>] = []
        var indices: [UInt32] = []

        func addQuad(
            _ a: SIMD3<Float>, _ b: SIMD3<Float>, _ c: SIMD3<Float>, _ d: SIMD3<Float>,
            _ normal: SIMD3<Float>,
            _ uvA: SIMD2<Float>, _ uvB: SIMD2<Float>, _ uvC: SIMD2<Float>, _ uvD: SIMD2<Float>
        ) {
            let base = UInt32(positions.count)
            positions += [a, b, c, d]
            normals += [normal, normal, normal, normal]
            uvs += [uvA, uvB, uvC, uvD]
            indices += [base, base + 1, base + 2, base, base + 2, base + 3]
        }

        for step in 0..<sides {
            let t0 = Float(step) / Float(sides)
            let t1 = Float(step + 1) / Float(sides)
            let a0 = -sweep / 2 + t0 * sweep
            let a1 = -sweep / 2 + t1 * sweep
            let d0 = SIMD3(cos(a0), 0, sin(a0))
            let d1 = SIMD3(cos(a1), 0, sin(a1))

            let outerNormal = simd_normalize(d0 + d1)
            addQuad(
                SIMD3(d0.x * radius, -half, d0.z * radius),
                SIMD3(d0.x * radius, half, d0.z * radius),
                SIMD3(d1.x * radius, half, d1.z * radius),
                SIMD3(d1.x * radius, -half, d1.z * radius),
                outerNormal,
                SIMD2(t0, 0), SIMD2(t0, 1), SIMD2(t1, 1), SIMD2(t1, 0)
            )

            addQuad(
                SIMD3(d1.x * inner, half, d1.z * inner),
                SIMD3(d0.x * inner, half, d0.z * inner),
                SIMD3(d0.x * inner, -half, d0.z * inner),
                SIMD3(d1.x * inner, -half, d1.z * inner),
                -outerNormal,
                SIMD2(t1, 1), SIMD2(t0, 1), SIMD2(t0, 0), SIMD2(t1, 0)
            )
            // 内壁两个绕序各出一份：从舱内看过去是背面，只出一份会被剔除掉。
            addQuad(
                SIMD3(d1.x * inner, -half, d1.z * inner),
                SIMD3(d0.x * inner, -half, d0.z * inner),
                SIMD3(d0.x * inner, half, d0.z * inner),
                SIMD3(d1.x * inner, half, d1.z * inner),
                -outerNormal,
                SIMD2(t1, 0), SIMD2(t0, 0), SIMD2(t0, 1), SIMD2(t1, 1)
            )

            addQuad(
                SIMD3(d0.x * radius, half, d0.z * radius),
                SIMD3(d0.x * inner, half, d0.z * inner),
                SIMD3(d1.x * inner, half, d1.z * inner),
                SIMD3(d1.x * radius, half, d1.z * radius),
                SIMD3(0, 1, 0),
                SIMD2(t0, 1), SIMD2(t0, 0), SIMD2(t1, 0), SIMD2(t1, 1)
            )

            addQuad(
                SIMD3(d1.x * inner, -half, d1.z * inner),
                SIMD3(d0.x * inner, -half, d0.z * inner),
                SIMD3(d0.x * radius, -half, d0.z * radius),
                SIMD3(d1.x * radius, -half, d1.z * radius),
                SIMD3(0, -1, 0),
                SIMD2(t1, 0), SIMD2(t0, 0), SIMD2(t0, 1), SIMD2(t1, 1)
            )
        }

        for angle in [-sweep / 2, sweep / 2] {
            let direction = SIMD3(cos(angle), 0, sin(angle))
            let tangent = SIMD3(-sin(angle), 0, cos(angle))
            addQuad(
                SIMD3(direction.x * inner, -half, direction.z * inner),
                SIMD3(direction.x * inner, half, direction.z * inner),
                SIMD3(direction.x * radius, half, direction.z * radius),
                SIMD3(direction.x * radius, -half, direction.z * radius),
                tangent,
                SIMD2(0, 0), SIMD2(0, 1), SIMD2(1, 1), SIMD2(1, 0)
            )
        }

        var descriptor = MeshDescriptor(name: "arcShell")
        descriptor.positions = MeshBuffer(positions)
        descriptor.normals = MeshBuffer(normals)
        descriptor.textureCoordinates = MeshBuffer(uvs)
        descriptor.primitives = .triangles(indices)
        return (try? MeshResource.generate(from: [descriptor]))
            ?? MeshResource.generateBox(size: 0.01)
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
