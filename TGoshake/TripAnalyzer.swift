import Foundation

enum TripAnalyzer {
    static let analysisVersion = "0.0.1-bandpass-window-2"

    private struct PreparedSample {
        let source: MotionSample
        let lateral: Double
        let longitudinal: Double
        let vertical: Double

        var resultant: Double {
            sqrt(lateral * lateral + longitudinal * longitudinal + vertical * vertical)
        }
    }

    static func analyze(motion: [MotionSample], locations: [LocationSample]) -> [AnalysisWindow] {
        guard motion.count >= 10 else { return [] }
        let prepared = prepare(motion)
        guard let first = prepared.first, let last = prepared.last else { return [] }

        var drafts: [AnalysisWindow] = []
        var start = first.source.elapsed
        var index = 0

        while start <= last.source.elapsed {
            while index < prepared.count && prepared[index].source.elapsed < start { index += 1 }
            var endIndex = index
            while endIndex < prepared.count && prepared[endIndex].source.elapsed < start + 1.0 { endIndex += 1 }
            let window = Array(prepared[index..<endIndex])
            if window.count >= 10 {
                drafts.append(makeWindow(samples: window, start: start, end: start + 1.0, locations: locations))
            }
            start += 0.5
        }

        guard !drafts.isEmpty else { return [] }
        let vertical = drafts.map(\.verticalRMS)
        let lateral = drafts.map(\.lateralRMS)
        let p95 = drafts.map(\.resultantP95)
        let jerk = drafts.map(\.jerkRMS)
        let rotation = drafts.map(\.rotationRMS)

        for i in drafts.indices {
            drafts[i].score =
                0.40 * robustZ(vertical[i], values: vertical) +
                0.25 * robustZ(lateral[i], values: lateral) +
                0.20 * robustZ(p95[i], values: p95) +
                0.10 * robustZ(jerk[i], values: jerk) +
                0.05 * robustZ(rotation[i], values: rotation)
        }

        let scores = drafts.map(\.score).sorted()
        for i in drafts.indices {
            let rank = scores.partitioningIndex { $0 >= drafts[i].score }
            let percentile = scores.count == 1 ? 1.0 : Double(rank) / Double(scores.count - 1)
            drafts[i].percentile = min(max(percentile, 0), 1)
            drafts[i].severity = severity(for: drafts[i].percentile)
        }
        return drafts
    }

    private static func makeWindow(
        samples: [PreparedSample],
        start: Double,
        end: Double,
        locations: [LocationSample]
    ) -> AnalysisWindow {
        let lateral = samples.map(\.lateral)
        let longitudinal = samples.map(\.longitudinal)
        let vertical = samples.map(\.vertical)
        let resultant = samples.map(\.resultant)
        let rotation = samples.map {
            sqrt($0.source.rotationX * $0.source.rotationX + $0.source.rotationY * $0.source.rotationY + $0.source.rotationZ * $0.source.rotationZ)
        }
        var jerks: [Double] = []
        if samples.count > 1 {
            for i in 1..<samples.count {
                let dt = samples[i].source.elapsed - samples[i - 1].source.elapsed
                if dt > 0, dt < 0.1 {
                    jerks.append((samples[i].resultant - samples[i - 1].resultant) / dt)
                }
            }
        }

        let location = nearestLocation(to: (start + end) / 2, locations: locations)
        let uncertain = location == nil || (location?.horizontalAccuracy ?? .infinity) > 50
        return AnalysisWindow(
            id: UUID(),
            startElapsed: start,
            endElapsed: end,
            lateralRMS: rms(lateral),
            longitudinalRMS: rms(longitudinal),
            verticalRMS: rms(vertical),
            resultantRMS: rms(resultant),
            resultantP95: percentile(resultant, 0.95),
            peak: resultant.map(abs).max() ?? 0,
            jerkRMS: rms(jerks),
            rotationRMS: rms(rotation),
            score: 0,
            percentile: 0,
            severity: .calm,
            latitude: location?.latitude,
            longitude: location?.longitude,
            horizontalAccuracy: location?.horizontalAccuracy,
            locationUncertain: uncertain,
            sampleCount: samples.count
        )
    }

    private static func prepare(_ samples: [MotionSample]) -> [PreparedSample] {
        let timestamps = samples.map(\.elapsed)
        let lateral = SignalFilter.zeroPhaseBandPass(samples.map(\.lateralMS2), timestamps: timestamps, lowHz: 0.5, highHz: 30)
        let longitudinal = SignalFilter.zeroPhaseBandPass(samples.map(\.longitudinalMS2), timestamps: timestamps, lowHz: 0.5, highHz: 30)
        let vertical = SignalFilter.zeroPhaseBandPass(samples.map(\.verticalMS2), timestamps: timestamps, lowHz: 0.5, highHz: 30)
        return samples.indices.map {
            PreparedSample(source: samples[$0], lateral: lateral[$0], longitudinal: longitudinal[$0], vertical: vertical[$0])
        }
    }

    private static func nearestLocation(to elapsed: Double, locations: [LocationSample]) -> LocationSample? {
        let candidates = locations.filter { $0.isValid }
        guard let nearest = candidates.min(by: { abs($0.elapsed - elapsed) < abs($1.elapsed - elapsed) }),
              abs(nearest.elapsed - elapsed) <= 10 else { return nil }
        return nearest
    }

    private static func rms(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        return sqrt(values.reduce(0) { $0 + $1 * $1 } / Double(values.count))
    }

    private static func percentile(_ values: [Double], _ value: Double) -> Double {
        let sorted = values.sorted()
        guard !sorted.isEmpty else { return 0 }
        let index = min(Int((Double(sorted.count - 1) * value).rounded()), sorted.count - 1)
        return sorted[index]
    }

    private static func robustZ(_ value: Double, values: [Double]) -> Double {
        let center = percentile(values, 0.5)
        let deviations = values.map { abs($0 - center) }
        let mad = percentile(deviations, 0.5)
        guard mad > 0.000_001 else { return 0 }
        return (value - center) / (1.4826 * mad)
    }

    private static func severity(for percentile: Double) -> Severity {
        if percentile >= 0.95 { return .intense }
        if percentile >= 0.80 { return .noticeable }
        if percentile >= 0.50 { return .attention }
        return .calm
    }
}

private extension Array where Element == Double {
    func partitioningIndex(where predicate: (Double) -> Bool) -> Int {
        var low = 0
        var high = count
        while low < high {
            let mid = (low + high) / 2
            if predicate(self[mid]) { high = mid } else { low = mid + 1 }
        }
        return low
    }
}
