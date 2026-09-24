import Foundation

enum SignalFilter {
    static func zeroPhaseBandPass(
        _ values: [Double],
        timestamps: [Double],
        lowHz: Double,
        highHz: Double
    ) -> [Double] {
        guard values.count == timestamps.count, values.count >= 20 else { return values }
        var result = values
        for range in continuousRanges(timestamps: timestamps) where range.count >= 20 {
            let times = Array(timestamps[range])
            let intervals = zip(times.dropFirst(), times).map { $0.0 - $0.1 }.filter { $0 > 0 }.sorted()
            guard !intervals.isEmpty else { continue }
            let sampleRate = 1 / intervals[intervals.count / 2]
            let safeHigh = min(highHz, sampleRate * 0.45)
            guard sampleRate > lowHz * 2.2, safeHigh > lowHz else { continue }

            let segment = Array(values[range])
            let forward = applyBandPass(segment, sampleRate: sampleRate, lowHz: lowHz, highHz: safeHigh)
            let reverse = applyBandPass(Array(forward.reversed()), sampleRate: sampleRate, lowHz: lowHz, highHz: safeHigh)
            let filtered = Array(reverse.reversed())
            for (offset, index) in range.enumerated() { result[index] = filtered[offset] }
        }
        return result
    }

    private static func continuousRanges(timestamps: [Double]) -> [Range<Int>] {
        guard !timestamps.isEmpty else { return [] }
        var ranges: [Range<Int>] = []
        var start = 0
        for index in 1..<timestamps.count {
            let dt = timestamps[index] - timestamps[index - 1]
            if dt <= 0 || dt > 0.1 {
                ranges.append(start..<index)
                start = index
            }
        }
        ranges.append(start..<timestamps.count)
        return ranges
    }

    private static func applyBandPass(_ values: [Double], sampleRate: Double, lowHz: Double, highHz: Double) -> [Double] {
        var highPass = Biquad.highPass(sampleRate: sampleRate, frequency: lowHz)
        var lowPass = Biquad.lowPass(sampleRate: sampleRate, frequency: highHz)
        return values.map { lowPass.process(highPass.process($0)) }
    }
}

private struct Biquad {
    let b0: Double
    let b1: Double
    let b2: Double
    let a1: Double
    let a2: Double
    private var x1 = 0.0
    private var x2 = 0.0
    private var y1 = 0.0
    private var y2 = 0.0

    mutating func process(_ x0: Double) -> Double {
        let y0 = b0 * x0 + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
        x2 = x1
        x1 = x0
        y2 = y1
        y1 = y0
        return y0
    }

    static func lowPass(sampleRate: Double, frequency: Double, q: Double = 1 / sqrt(2)) -> Biquad {
        coefficients(sampleRate: sampleRate, frequency: frequency, q: q, highPass: false)
    }

    static func highPass(sampleRate: Double, frequency: Double, q: Double = 1 / sqrt(2)) -> Biquad {
        coefficients(sampleRate: sampleRate, frequency: frequency, q: q, highPass: true)
    }

    private static func coefficients(sampleRate: Double, frequency: Double, q: Double, highPass: Bool) -> Biquad {
        let omega = 2 * Double.pi * frequency / sampleRate
        let cosine = cos(omega)
        let alpha = sin(omega) / (2 * q)
        let a0 = 1 + alpha
        let numerator0 = highPass ? (1 + cosine) / 2 : (1 - cosine) / 2
        let numerator1 = highPass ? -(1 + cosine) : (1 - cosine)
        return Biquad(
            b0: numerator0 / a0,
            b1: numerator1 / a0,
            b2: numerator0 / a0,
            a1: (-2 * cosine) / a0,
            a2: (1 - alpha) / a0
        )
    }
}
