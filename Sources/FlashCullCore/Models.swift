import Foundation

public struct CullingConfiguration: Sendable {
    public var workerCount: Int
    public var thumbnailSize: Int
    public var analyzeFaces: Bool
    public var duplicateDistance: Int
    public var rejectThreshold: Double

    public init(
        workerCount: Int = max(1, ProcessInfo.processInfo.activeProcessorCount - 2),
        thumbnailSize: Int = 512,
        analyzeFaces: Bool = true,
        duplicateDistance: Int = 6,
        rejectThreshold: Double = 0.32
    ) {
        self.workerCount = max(1, workerCount)
        self.thumbnailSize = max(128, thumbnailSize)
        self.analyzeFaces = analyzeFaces
        self.duplicateDistance = max(0, duplicateDistance)
        self.rejectThreshold = min(max(rejectThreshold, 0), 1)
    }
}

public enum CullReason: String, Codable, Sendable, Comparable {
    case blurred
    case closedEyes
    case duplicate
    case overexposed
    case underexposed

    public static func < (lhs: CullReason, rhs: CullReason) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

public struct TechnicalMetrics: Codable, Sendable, Equatable {
    public let sharpness: Double
    public let meanLuminance: Double
    public let darkClipRatio: Double
    public let brightClipRatio: Double
    public let faceCount: Int
    public let closedEyeFaceCount: Int

    public init(
        sharpness: Double,
        meanLuminance: Double,
        darkClipRatio: Double,
        brightClipRatio: Double,
        faceCount: Int = 0,
        closedEyeFaceCount: Int = 0
    ) {
        self.sharpness = sharpness
        self.meanLuminance = meanLuminance
        self.darkClipRatio = darkClipRatio
        self.brightClipRatio = brightClipRatio
        self.faceCount = faceCount
        self.closedEyeFaceCount = closedEyeFaceCount
    }
}

public struct CullResult: Codable, Sendable, Equatable {
    public let path: String
    public let pixelWidth: Int
    public let pixelHeight: Int
    public let perceptualHash: UInt64
    public let metrics: TechnicalMetrics
    public var score: Double
    public var rejected: Bool
    public var reasons: [CullReason]
    public var duplicateOf: String?

    public init(
        path: String,
        pixelWidth: Int,
        pixelHeight: Int,
        perceptualHash: UInt64,
        metrics: TechnicalMetrics,
        score: Double,
        rejected: Bool,
        reasons: [CullReason],
        duplicateOf: String? = nil
    ) {
        self.path = path
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.perceptualHash = perceptualHash
        self.metrics = metrics
        self.score = score
        self.rejected = rejected
        self.reasons = reasons
        self.duplicateOf = duplicateOf
    }
}

public struct RunSummary: Codable, Sendable {
    public let discovered: Int
    public let analyzed: Int
    public let rejected: Int
    public let duplicates: Int
    public let failures: [String]
    public let elapsedSeconds: Double
    public let results: [CullResult]

    public var photosPerSecond: Double {
        elapsedSeconds > 0 ? Double(analyzed) / elapsedSeconds : 0
    }
}

public enum FlashCullError: Error, CustomStringConvertible {
    case unreadableImage(String)
    case invalidDirectory(String)

    public var description: String {
        switch self {
        case .unreadableImage(let path): "Unable to decode image: \(path)"
        case .invalidDirectory(let path): "Not a readable directory: \(path)"
        }
    }
}
