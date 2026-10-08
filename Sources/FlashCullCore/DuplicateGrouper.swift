import Foundation

public enum DuplicateGrouper {
    public static func markDuplicates(in input: [CullResult], maximumDistance: Int) -> [CullResult] {
        guard input.count > 1 else { return input }
        var results = input
        var buckets: [UInt16: [Int]] = [:]

        for index in results.indices {
            let hash = results[index].perceptualHash
            var candidates = Set<Int>()
            for shift in stride(from: 0, through: 48, by: 16) {
                let band = UInt16(truncatingIfNeeded: hash >> UInt64(shift))
                for candidate in buckets[band] ?? [] {
                    candidates.insert(candidate)
                }
            }

            let matches = candidates.filter {
                hammingDistance(hash, results[$0].perceptualHash) <= maximumDistance
            }
            if let best = matches.max(by: { results[$0].score < results[$1].score }) {
                if results[best].score >= results[index].score {
                    mark(index, duplicateOf: best, in: &results)
                } else {
                    let previousRoot = results[best].duplicateOf ?? results[best].path
                    for candidate in results.indices where results[candidate].path == previousRoot || results[candidate].duplicateOf == previousRoot {
                        if candidate != index { mark(candidate, duplicateOf: index, in: &results) }
                    }
                }
            }

            for shift in stride(from: 0, through: 48, by: 16) {
                let band = UInt16(truncatingIfNeeded: hash >> UInt64(shift))
                buckets[band, default: []].append(index)
            }
        }
        return results
    }

    public static func hammingDistance(_ lhs: UInt64, _ rhs: UInt64) -> Int {
        (lhs ^ rhs).nonzeroBitCount
    }

    private static func mark(_ index: Int, duplicateOf keeperIndex: Int, in results: inout [CullResult]) {
        results[index].duplicateOf = results[keeperIndex].path
        results[index].rejected = true
        if !results[index].reasons.contains(.duplicate) {
            results[index].reasons.append(.duplicate)
            results[index].reasons.sort()
        }
    }
}
