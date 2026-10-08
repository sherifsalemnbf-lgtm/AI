import Foundation

public struct CullingEngine: Sendable {
    public static let supportedExtensions: Set<String> = [
        "3fr", "arw", "cr2", "cr3", "dng", "erf", "fff", "heic", "heif", "jpeg", "jpg",
        "mos", "mrw", "nef", "nrw", "orf", "pef", "png", "raf", "raw", "rw2", "srw", "tif", "tiff"
    ]

    private let configuration: CullingConfiguration

    public init(configuration: CullingConfiguration = .init()) {
        self.configuration = configuration
    }

    public func discover(in directory: URL, limit: Int? = nil) throws -> [URL] {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: directory.path, isDirectory: &isDirectory), isDirectory.boolValue,
              let enumerator = FileManager.default.enumerator(
                at: directory,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
              ) else {
            throw FlashCullError.invalidDirectory(directory.path)
        }
        var urls: [URL] = []
        while let url = enumerator.nextObject() as? URL {
            if Self.supportedExtensions.contains(url.pathExtension.lowercased()) {
                urls.append(url)
                if let limit, urls.count >= limit { break }
            }
        }
        return urls
    }

    public func run(directory: URL, limit: Int? = nil) async throws -> RunSummary {
        let started = ContinuousClock.now
        let urls = try discover(in: directory, limit: limit)
        let analyzer = ImageAnalyzer(configuration: configuration)
        var iterator = urls.makeIterator()
        var results: [CullResult] = []
        var failures: [String] = []
        results.reserveCapacity(urls.count)

        await withTaskGroup(of: Result<CullResult, Error>.self) { group in
            for _ in 0..<min(configuration.workerCount, urls.count) {
                if let url = iterator.next() {
                    group.addTask { Result { try analyzer.analyze(url) } }
                }
            }
            while let completed = await group.next() {
                switch completed {
                case .success(let result): results.append(result)
                case .failure(let error): failures.append(String(describing: error))
                }
                if let url = iterator.next() {
                    group.addTask { Result { try analyzer.analyze(url) } }
                }
            }
        }

        results.sort { $0.path.localizedStandardCompare($1.path) == .orderedAscending }
        results = DuplicateGrouper.markDuplicates(in: results, maximumDistance: configuration.duplicateDistance)
        let elapsed = started.duration(to: .now)
        let seconds = Double(elapsed.components.seconds) + Double(elapsed.components.attoseconds) / 1e18
        return RunSummary(
            discovered: urls.count,
            analyzed: results.count,
            rejected: results.lazy.filter(\.rejected).count,
            duplicates: results.lazy.filter { $0.reasons.contains(.duplicate) }.count,
            failures: failures,
            elapsedSeconds: seconds,
            results: results
        )
    }
}
