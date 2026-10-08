import CoreGraphics
import Foundation
import ImageIO
import Vision

public struct ImageAnalyzer: Sendable {
    private let configuration: CullingConfiguration

    public init(configuration: CullingConfiguration) {
        self.configuration = configuration
    }

    public func analyze(_ url: URL) throws -> CullResult {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            throw FlashCullError.unreadableImage(url.path)
        }
        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        let width = properties?[kCGImagePropertyPixelWidth] as? Int ?? 0
        let height = properties?[kCGImagePropertyPixelHeight] as? Int ?? 0
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: configuration.thumbnailSize,
            kCGImageSourceShouldCacheImmediately: true
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            throw FlashCullError.unreadableImage(url.path)
        }
        let luma = try grayscale(image, width: 128, height: 128)
        let baseMetrics = metrics(from: luma, width: 128, height: 128)
        let faces = configuration.analyzeFaces ? faceMetrics(in: image) : (0, 0)
        let fullMetrics = TechnicalMetrics(
            sharpness: baseMetrics.sharpness,
            meanLuminance: baseMetrics.meanLuminance,
            darkClipRatio: baseMetrics.darkClipRatio,
            brightClipRatio: baseMetrics.brightClipRatio,
            faceCount: faces.0,
            closedEyeFaceCount: faces.1
        )
        let evaluation = TechnicalScorer.evaluate(fullMetrics, rejectThreshold: configuration.rejectThreshold)
        return CullResult(
            path: url.path,
            pixelWidth: width,
            pixelHeight: height,
            perceptualHash: differenceHash(luma, width: 128, height: 128),
            metrics: fullMetrics,
            score: evaluation.score,
            rejected: !evaluation.reasons.isEmpty,
            reasons: evaluation.reasons
        )
    }

    private func grayscale(_ image: CGImage, width: Int, height: Int) throws -> [UInt8] {
        var pixels = [UInt8](repeating: 0, count: width * height)
        let created = pixels.withUnsafeMutableBytes { bytes -> Bool in
            guard let context = CGContext(
                data: bytes.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width,
                space: CGColorSpaceCreateDeviceGray(),
                bitmapInfo: CGImageAlphaInfo.none.rawValue
            ) else { return false }
            context.interpolationQuality = .medium
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard created else { throw FlashCullError.unreadableImage("grayscale raster") }
        return pixels
    }

    private func metrics(from pixels: [UInt8], width: Int, height: Int) -> TechnicalMetrics {
        let count = Double(pixels.count)
        let mean = Double(pixels.reduce(0) { $0 + Int($1) }) / count / 255
        let dark = Double(pixels.lazy.filter { $0 <= 5 }.count) / count
        let bright = Double(pixels.lazy.filter { $0 >= 250 }.count) / count
        var laplacians = [Double]()
        laplacians.reserveCapacity((width - 2) * (height - 2))
        for y in 1..<(height - 1) {
            for x in 1..<(width - 1) {
                let i = y * width + x
                let value = 4 * Int(pixels[i]) - Int(pixels[i - 1]) - Int(pixels[i + 1])
                    - Int(pixels[i - width]) - Int(pixels[i + width])
                laplacians.append(Double(value))
            }
        }
        let lapMean = laplacians.reduce(0, +) / Double(laplacians.count)
        let variance = laplacians.reduce(0) { $0 + ($1 - lapMean) * ($1 - lapMean) } / Double(laplacians.count)
        return TechnicalMetrics(
            sharpness: variance,
            meanLuminance: mean,
            darkClipRatio: dark,
            brightClipRatio: bright
        )
    }

    private func differenceHash(_ pixels: [UInt8], width: Int, height: Int) -> UInt64 {
        var hash: UInt64 = 0
        for y in 0..<8 {
            let sourceY = y * height / 8
            for x in 0..<8 {
                let leftX = x * width / 9
                let rightX = (x + 1) * width / 9
                if pixels[sourceY * width + leftX] > pixels[sourceY * width + rightX] {
                    hash |= UInt64(1) << UInt64(y * 8 + x)
                }
            }
        }
        return hash
    }

    private func faceMetrics(in image: CGImage) -> (Int, Int) {
        let request = VNDetectFaceLandmarksRequest()
        let handler = VNImageRequestHandler(cgImage: image, orientation: .up)
        guard (try? handler.perform([request])) != nil,
              let observations = request.results else { return (0, 0) }
        let closed = observations.reduce(into: 0) { count, face in
            guard let landmarks = face.landmarks else { return }
            let eyes = [landmarks.leftEye, landmarks.rightEye].compactMap { $0 }
            guard eyes.count == 2 else { return }
            if eyes.allSatisfy({ eyeAspectRatio($0.normalizedPoints) < 0.16 }) { count += 1 }
        }
        return (observations.count, closed)
    }

    private func eyeAspectRatio(_ points: [CGPoint]) -> CGFloat {
        guard points.count >= 6 else { return 1 }
        let xs = points.map(\.x)
        let ys = points.map(\.y)
        let width = (xs.max() ?? 0) - (xs.min() ?? 0)
        let height = (ys.max() ?? 0) - (ys.min() ?? 0)
        return width > 0 ? height / width : 1
    }
}
