import Foundation
import RealityKit
import simd

struct StarMeshData: Equatable, Sendable {
    var positions: [SIMD3<Float>]
    var normals: [SIMD3<Float>]
    var indices: [UInt32]
}

enum StarFieldBuilder {
    static func cube(center: SIMD3<Float>, size: Float) -> StarMeshData {
        let half = size / 2
        let corners = [
            SIMD3<Float>(-half, -half, -half),
            SIMD3<Float>(half, -half, -half),
            SIMD3<Float>(half, half, -half),
            SIMD3<Float>(-half, half, -half),
            SIMD3<Float>(-half, -half, half),
            SIMD3<Float>(half, -half, half),
            SIMD3<Float>(half, half, half),
            SIMD3<Float>(-half, half, half),
        ]
        let faces: [(SIMD3<Float>, [Int])] = [
            (SIMD3(0, 0, -1), [0, 3, 2, 1]),
            (SIMD3(0, 0, 1), [4, 5, 6, 7]),
            (SIMD3(-1, 0, 0), [0, 4, 7, 3]),
            (SIMD3(1, 0, 0), [1, 2, 6, 5]),
            (SIMD3(0, -1, 0), [0, 1, 5, 4]),
            (SIMD3(0, 1, 0), [3, 7, 6, 2]),
        ]

        var positions: [SIMD3<Float>] = []
        var normals: [SIMD3<Float>] = []
        var indices: [UInt32] = []

        for (normal, corners4) in faces {
            let base = UInt32(positions.count)
            for index in corners4 {
                positions.append(center + corners[index])
                normals.append(normal)
            }
            indices.append(contentsOf: [base, base + 1, base + 2, base, base + 2, base + 3])
        }

        return StarMeshData(positions: positions, normals: normals, indices: indices)
    }

    static func sphere(center: SIMD3<Float>, radius: Float, segments: Int = 6, rings: Int = 4) -> StarMeshData {
        var positions: [SIMD3<Float>] = []
        var normals: [SIMD3<Float>] = []
        var indices: [UInt32] = []

        for ring in 0...rings {
            let phi = Float.pi * Float(ring) / Float(rings)
            for segment in 0...segments {
                let theta = 2 * Float.pi * Float(segment) / Float(segments)
                let normal = SIMD3<Float>(
                    sin(phi) * cos(theta),
                    cos(phi),
                    sin(phi) * sin(theta)
                )
                positions.append(center + normal * radius)
                normals.append(normal)
            }
        }

        let stride = segments + 1
        for ring in 0..<rings {
            for segment in 0..<segments {
                let a = UInt32(ring * stride + segment)
                let b = UInt32(ring * stride + segment + 1)
                let c = UInt32((ring + 1) * stride + segment + 1)
                let d = UInt32((ring + 1) * stride + segment)
                indices.append(contentsOf: [a, b, c, a, c, d])
            }
        }

        return StarMeshData(positions: positions, normals: normals, indices: indices)
    }

    static func tube(from start: SIMD3<Float>, to end: SIMD3<Float>, radius: Float) -> StarMeshData {
        let axis = end - start
        let length = simd_length(axis)
        guard length > 0.0001 else {
            return StarMeshData(positions: [], normals: [], indices: [])
        }
        let direction = axis / length
        let reference = abs(direction.y) < 0.9 ? SIMD3<Float>(0, 1, 0) : SIMD3<Float>(1, 0, 0)
        let right = simd_normalize(simd_cross(direction, reference)) * radius
        let up = simd_normalize(simd_cross(direction, right)) * radius
        let corners = [right + up, -right + up, -right - up, right - up]

        var positions: [SIMD3<Float>] = []
        var normals: [SIMD3<Float>] = []
        var indices: [UInt32] = []

        for index in 0..<4 {
            let current = corners[index]
            let next = corners[(index + 1) % 4]
            let normal = simd_normalize(current + next)
            let base = UInt32(positions.count)
            positions.append(contentsOf: [start + current, end + current, end + next, start + next])
            normals.append(contentsOf: [normal, normal, normal, normal])
            indices.append(contentsOf: [
                base, base + 1, base + 2, base, base + 2, base + 3,
                base, base + 2, base + 1, base, base + 3, base + 2,
            ])
        }

        return StarMeshData(positions: positions, normals: normals, indices: indices)
    }

    static func constellation(_ segments: [(SIMD3<Float>, SIMD3<Float>)], radius: Float) -> StarMeshData {
        merge(segments.map { tube(from: $0.0, to: $0.1, radius: radius) })
    }

    static func merge(_ chunks: [StarMeshData]) -> StarMeshData {
        var positions: [SIMD3<Float>] = []
        var normals: [SIMD3<Float>] = []
        var indices: [UInt32] = []

        for chunk in chunks {
            let offset = UInt32(positions.count)
            positions.append(contentsOf: chunk.positions)
            normals.append(contentsOf: chunk.normals)
            indices.append(contentsOf: chunk.indices.map { $0 + offset })
        }

        return StarMeshData(positions: positions, normals: normals, indices: indices)
    }

    static func mesh(_ data: StarMeshData, name: String) throws -> MeshResource {
        var descriptor = MeshDescriptor(name: name)
        descriptor.positions = MeshBuffers.Positions(data.positions)
        descriptor.normals = MeshBuffers.Normals(data.normals)
        descriptor.primitives = .triangles(data.indices)
        return try MeshResource.generate(from: [descriptor])
    }

    static func buckets(for stars: [Star]) -> [[Star]] {
        var grouped = Array(repeating: [Star](), count: StarField.bucketEdges.count - 1)
        for star in stars {
            grouped[StarField.bucketIndex(for: star.magnitude)].append(star)
        }
        return grouped
    }

    static func selectableBuckets(for stars: [Star]) -> [[Star]] {
        buckets(for: stars.filter(\.isSelectable))
    }

    static func backgroundStars(for stars: [Star]) -> [Star] {
        stars.filter { !$0.isSelectable }
    }

    static func chunk(for stars: [Star], scale: Float = 1) -> StarMeshData {
        merge(
            stars.map {
                sphere(
                    center: StarField.position(for: $0),
                    radius: StarField.cubeSize(for: $0.magnitude) * scale
                )
            }
        )
    }
}
