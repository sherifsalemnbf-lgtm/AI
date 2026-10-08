import Foundation
import Testing
@testable import FlashCullCore

@Test func rejectsSeverelyBlurredFrame() {
    let metrics = TechnicalMetrics(
        sharpness: 2,
        meanLuminance: 0.5,
        darkClipRatio: 0,
        brightClipRatio: 0
    )
    let result = TechnicalScorer.evaluate(metrics, rejectThreshold: 0.32)
    #expect(result.reasons.contains(.blurred))
}

@Test func rejectsClosedEyesWhenFaceWasDetected() {
    let metrics = TechnicalMetrics(
        sharpness: 900,
        meanLuminance: 0.5,
        darkClipRatio: 0,
        brightClipRatio: 0,
        faceCount: 1,
        closedEyeFaceCount: 1
    )
    let result = TechnicalScorer.evaluate(metrics, rejectThreshold: 0.32)
    #expect(result.reasons.contains(.closedEyes))
}

@Test func duplicateGroupingKeepsHighestScore() {
    let metrics = TechnicalMetrics(sharpness: 100, meanLuminance: 0.5, darkClipRatio: 0, brightClipRatio: 0)
    let lower = CullResult(path: "/a.raw", pixelWidth: 10, pixelHeight: 10, perceptualHash: 0xAAAA, metrics: metrics, score: 0.5, rejected: false, reasons: [])
    let higher = CullResult(path: "/b.raw", pixelWidth: 10, pixelHeight: 10, perceptualHash: 0xAAAB, metrics: metrics, score: 0.9, rejected: false, reasons: [])
    let output = DuplicateGrouper.markDuplicates(in: [lower, higher], maximumDistance: 2)
    #expect(output[0].duplicateOf == "/b.raw")
    #expect(output[0].reasons.contains(.duplicate))
    #expect(output[1].duplicateOf == nil)
}

@Test func writesAdobeCompatibleRatingAndProtectsExistingSidecar() throws {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: folder) }
    let image = folder.appendingPathComponent("photo.nef")
    let metrics = TechnicalMetrics(sharpness: 100, meanLuminance: 0.5, darkClipRatio: 0, brightClipRatio: 0)
    let result = CullResult(path: image.path, pixelWidth: 10, pixelHeight: 10, perceptualHash: 0, metrics: metrics, score: 0.9, rejected: false, reasons: [])

    let first = try XMPWriter.write(results: [result])
    #expect(first.written == 1)
    let sidecar = XMPWriter.sidecarURL(for: image)
    let content = try String(contentsOf: sidecar, encoding: .utf8)
    #expect(content.contains("xmp:Rating=\"5\""))
    #expect(content.contains("xmp:Label=\"Green\""))

    let second = try XMPWriter.write(results: [result])
    #expect(second.skippedExisting == 1)
}
