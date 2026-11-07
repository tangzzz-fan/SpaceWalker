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

    static func convexHull(_ points: [SIMD2<Float>]) -> [Int] {
        guard points.count >= 3 else { return Array(points.indices) }
        let sorted = points.indices.sorted {
            points[$0].x == points[$1].x ? points[$0].y < points[$1].y : points[$0].x < points[$1].x
        }

        func cross(_ o: Int, _ a: Int, _ b: Int) -> Float {
            (points[a].x - points[o].x) * (points[b].y - points[o].y)
                - (points[a].y - points[o].y) * (points[b].x - points[o].x)
        }

        var lower: [Int] = []
        for index in sorted {
            while lower.count >= 2, cross(lower[lower.count - 2], lower[lower.count - 1], index) <= 0 {
                lower.removeLast()
            }
            lower.append(index)
        }
        var upper: [Int] = []
        for index in sorted.reversed() {
            while upper.count >= 2, cross(upper[upper.count - 2], upper[upper.count - 1], index) <= 0 {
                upper.removeLast()
            }
            upper.append(index)
        }
        lower.removeLast()
        upper.removeLast()
        return lower + upper
    }

    static func hullRing(_ points: [SIMD3<Float>]) -> [SIMD3<Float>] {
        guard points.count >= 3 else { return points }
        var centroid = SIMD3<Float>(0, 0, 0)
        for point in points {
            let length = simd_length(point)
            guard length > 0.0001 else { continue }
            centroid += point / length
        }
        let length = simd_length(centroid)
        guard length > 0.0001 else { return points }
        let center = centroid / length
        let reference = abs(center.y) < 0.9 ? SIMD3<Float>(0, 1, 0) : SIMD3<Float>(1, 0, 0)
        let u = simd_normalize(simd_cross(reference, center))
        let v = simd_cross(center, u)

        let projected = points.map { SIMD2<Float>(simd_dot($0, u), simd_dot($0, v)) }
        return convexHull(projected).map { points[$0] }
    }

    static func sphericalPolygon(points: [SIMD3<Float>], radius: Float) -> StarMeshData {
        polygon(ring: hullRing(points), radius: radius)
    }

    static func polygon(ring: [SIMD3<Float>], radius: Float) -> StarMeshData {
        guard ring.count >= 3 else { return StarMeshData(positions: [], normals: [], indices: []) }

        var centroid = SIMD3<Float>(0, 0, 0)
        for point in ring {
            centroid += simd_normalize(point)
        }
        let center = simd_normalize(centroid) * radius
        let vertices = ring.map { simd_normalize($0) * radius }

        var positions: [SIMD3<Float>] = []
        var normals: [SIMD3<Float>] = []
        var indices: [UInt32] = []

        for index in 0..<vertices.count {
            let a = vertices[index]
            let b = vertices[(index + 1) % vertices.count]
            let base = UInt32(positions.count)
            positions.append(contentsOf: [center, a, b])
            normals.append(contentsOf: [
                simd_normalize(center), simd_normalize(a), simd_normalize(b),
            ])
            indices.append(contentsOf: [base, base + 1, base + 2, base, base + 2, base + 1])
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
