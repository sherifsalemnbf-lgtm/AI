import Foundation

public enum TechnicalScorer {
    public static func evaluate(
        _ metrics: TechnicalMetrics,
        rejectThreshold: Double
    ) -> (score: Double, reasons: [CullReason]) {
        let sharpnessScore = min(1, log1p(max(0, metrics.sharpness)) / log1p(1_500))
        let meanDistance = abs(metrics.meanLuminance - 0.5) * 2
        let tonalScore = max(0, 1 - meanDistance * 0.7)
        let clippingPenalty = min(1, (metrics.darkClipRatio + metrics.brightClipRatio) * 1.8)
        let exposureScore = tonalScore * (1 - clippingPenalty)
        let eyeScore: Double = metrics.faceCount > 0
            ? 1 - (Double(metrics.closedEyeFaceCount) / Double(metrics.faceCount))
            : 1
        let score = min(1, max(0, sharpnessScore * 0.58 + exposureScore * 0.27 + eyeScore * 0.15))

        var reasons: [CullReason] = []
        if metrics.sharpness < 28 { reasons.append(.blurred) }
        if metrics.meanLuminance < 0.14 || metrics.darkClipRatio > 0.42 { reasons.append(.underexposed) }
        if metrics.meanLuminance > 0.88 || metrics.brightClipRatio > 0.42 { reasons.append(.overexposed) }
        if metrics.closedEyeFaceCount > 0 { reasons.append(.closedEyes) }

        if score >= rejectThreshold {
            reasons.removeAll { $0 == .blurred && metrics.sharpness >= 20 }
        }
        return (score, reasons.sorted())
    }
}
