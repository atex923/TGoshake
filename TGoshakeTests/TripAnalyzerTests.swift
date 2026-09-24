import XCTest
@testable import TGoshake

final class TripAnalyzerTests: XCTestCase {
    func testTrainPresetCarLimitsAndManualFallback() {
        XCTAssertEqual(Array(TripPresetCatalog.carNumbers(for: "EMU3000 自強號").prefix(12)), (1...12).map(String.init))
        XCTAssertEqual(TripPresetCatalog.carNumbers(for: "普悠瑪號").filter { $0 != "其他" }.count, 8)
        XCTAssertEqual(TripPresetCatalog.carNumbers(for: "EMU900 區間車").filter { $0 != "其他" }.count, 10)
        XCTAssertEqual(TripPresetCatalog.carNumbers(for: "其他"), ["其他"])
    }

    func testStrongBurstBecomesIntenseWindow() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let samples = (0..<1_000).map { index -> MotionSample in
            let time = Double(index) / 100
            let quiet = 0.006 * sin(2 * .pi * 4 * time)
            let burst = (time >= 4 && time < 5) ? 0.30 * sin(2 * .pi * 7 * time) : 0
            return makeSample(elapsed: time, utc: start.addingTimeInterval(time), verticalG: quiet + burst)
        }

        let result = TripAnalyzer.analyze(motion: samples, locations: [])
        XCTAssertFalse(result.isEmpty)
        XCTAssertTrue(result.contains { $0.severity == .intense && $0.startElapsed < 5 && $0.endElapsed > 4 })
        XCTAssertTrue(result.allSatisfy { $0.locationUncertain })
    }

    func testShortInputProducesNoAnalysisWindow() {
        let samples = (0..<5).map { makeSample(elapsed: Double($0) / 100, utc: Date(), verticalG: 0) }
        XCTAssertTrue(TripAnalyzer.analyze(motion: samples, locations: []).isEmpty)
    }

    func testBandPassPreservesCountAndFiniteValuesAcrossGap() {
        var timestamps = (0..<100).map { Double($0) / 100 }
        timestamps += (0..<100).map { 2 + Double($0) / 100 }
        let values = timestamps.map { sin(2 * .pi * 5 * $0) }
        let filtered = SignalFilter.zeroPhaseBandPass(values, timestamps: timestamps, lowHz: 0.5, highHz: 30)
        XCTAssertEqual(filtered.count, values.count)
        XCTAssertTrue(filtered.allSatisfy(\.isFinite))
    }

    private func makeSample(elapsed: Double, utc: Date, verticalG: Double) -> MotionSample {
        MotionSample(
            elapsed: elapsed,
            utcTime: utc,
            totalX: 0,
            totalY: 0,
            totalZ: 1 + verticalG,
            userX: 0,
            userY: 0,
            userZ: verticalG,
            gravityX: 0,
            gravityY: 0,
            gravityZ: 1,
            rotationX: 0,
            rotationY: 0,
            rotationZ: 0,
            roll: 0,
            pitch: 0,
            yaw: 0
        )
    }
}
