import FlashCullCore
import Foundation

@main
enum FlashCullCoreChecks {
    static func main() throws {
        let blurred = TechnicalScorer.evaluate(
            TechnicalMetrics(sharpness: 2, meanLuminance: 0.5, darkClipRatio: 0, brightClipRatio: 0),
            rejectThreshold: 0.32
        )
        try require(blurred.reasons.contains(.blurred), "blur rejection")

        let closedEyes = TechnicalScorer.evaluate(
            TechnicalMetrics(
                sharpness: 900,
                meanLuminance: 0.5,
                darkClipRatio: 0,
                brightClipRatio: 0,
                faceCount: 1,
                closedEyeFaceCount: 1
            ),
            rejectThreshold: 0.32
        )
        try require(closedEyes.reasons.contains(.closedEyes), "closed-eye rejection")

        let metrics = TechnicalMetrics(sharpness: 100, meanLuminance: 0.5, darkClipRatio: 0, brightClipRatio: 0)
        let lower = CullResult(path: "/a.raw", pixelWidth: 10, pixelHeight: 10, perceptualHash: 0xAAAA, metrics: metrics, score: 0.5, rejected: false, reasons: [])
        let higher = CullResult(path: "/b.raw", pixelWidth: 10, pixelHeight: 10, perceptualHash: 0xAAAB, metrics: metrics, score: 0.9, rejected: false, reasons: [])
        let grouped = DuplicateGrouper.markDuplicates(in: [lower, higher], maximumDistance: 2)
        try require(grouped[0].duplicateOf == "/b.raw", "duplicate keeper ranking")
        try require(grouped[0].reasons.contains(.duplicate), "duplicate reason")
        try require(grouped[1].duplicateOf == nil, "keeper preservation")

        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let image = folder.appendingPathComponent("photo.nef")
        let result = CullResult(path: image.path, pixelWidth: 10, pixelHeight: 10, perceptualHash: 0, metrics: metrics, score: 0.9, rejected: false, reasons: [])
        let first = try XMPWriter.write(results: [result])
        try require(first.written == 1, "XMP write")
        let content = try String(contentsOf: XMPWriter.sidecarURL(for: image), encoding: .utf8)
        try require(content.contains("xmp:Rating=\"5\""), "XMP rating")
        try require(content.contains("xmp:Label=\"Green\""), "XMP label")
        let second = try XMPWriter.write(results: [result])
        try require(second.skippedExisting == 1, "existing XMP protection")

        print("PASS: 9 core checks")
    }

    private static func require(_ condition: @autoclosure () -> Bool, _ name: String) throws {
        guard condition() else { throw CheckFailure(name: name) }
    }
}

private struct CheckFailure: Error, CustomStringConvertible {
    let name: String
    var description: String { "check failed: \(name)" }
}
