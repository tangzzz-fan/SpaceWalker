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

    static func chunk(for stars: [Star]) -> StarMeshData {
        merge(
            stars.map {
                sphere(
                    center: StarField.position(for: $0),
                    radius: StarField.cubeSize(for: $0.magnitude)
                )
            }
        )
    }
}
