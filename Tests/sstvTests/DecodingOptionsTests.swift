import XCTest
@testable import SSTVCore

/// Extended tests for DecodingOptions including phase, skew, and computed properties
final class DecodingOptionsTests: XCTestCase {

    // MARK: - Default Options

    func testDefaultOptions() {
        let options = DecodingOptions.default

        XCTAssertEqual(options.phaseOffsetMs, 0.0)
        XCTAssertEqual(options.skewMsPerLine, 0.0)
        XCTAssertEqual(options.syncRecoveryThreshold, 0.5, accuracy: 0.01)
    }

    // MARK: - Phase Offset

    func testPhaseOffsetClampingViaMutation() {
        // Note: init does NOT trigger didSet, so clamping only applies on mutation
        var options = DecodingOptions()
        options.phaseOffsetMs = 100.0 // Exceeds ±50
        XCTAssertEqual(options.phaseOffsetMs, 50.0, accuracy: 0.001)

        options.phaseOffsetMs = -100.0
        XCTAssertEqual(options.phaseOffsetMs, -50.0, accuracy: 0.001)
    }

    func testPhaseOffsetMutation() {
        var options = DecodingOptions()
        options.phaseOffsetMs = 25.0
        XCTAssertEqual(options.phaseOffsetMs, 25.0, accuracy: 0.001)

        options.phaseOffsetMs = 75.0 // Exceeds max
        XCTAssertEqual(options.phaseOffsetMs, 50.0, accuracy: 0.001)

        options.phaseOffsetMs = -75.0
        XCTAssertEqual(options.phaseOffsetMs, -50.0, accuracy: 0.001)
    }

    func testPhaseOffsetWithinLimits() {
        let options = DecodingOptions(phaseOffsetMs: 5.0)
        XCTAssertEqual(options.phaseOffsetMs, 5.0, accuracy: 0.001)

        let options2 = DecodingOptions(phaseOffsetMs: -5.0)
        XCTAssertEqual(options2.phaseOffsetMs, -5.0, accuracy: 0.001)
    }

    // MARK: - Skew

    func testSkewClampingViaMutation() {
        // Note: init does NOT trigger didSet, so clamping only applies on mutation
        var options = DecodingOptions()
        options.skewMsPerLine = 5.0 // Exceeds ±1.0
        XCTAssertEqual(options.skewMsPerLine, 1.0, accuracy: 0.001)

        options.skewMsPerLine = -5.0
        XCTAssertEqual(options.skewMsPerLine, -1.0, accuracy: 0.001)
    }

    func testSkewMutation() {
        var options = DecodingOptions()
        options.skewMsPerLine = 0.5
        XCTAssertEqual(options.skewMsPerLine, 0.5, accuracy: 0.001)

        options.skewMsPerLine = 2.0 // Exceeds max
        XCTAssertEqual(options.skewMsPerLine, 1.0, accuracy: 0.001)

        options.skewMsPerLine = -2.0
        XCTAssertEqual(options.skewMsPerLine, -1.0, accuracy: 0.001)
    }

    // MARK: - Computed Properties

    func testTotalPhaseOffsetMs() {
        let options = DecodingOptions(phaseOffsetMs: 2.0, skewMsPerLine: 0.1)

        // Line 0: 2.0 + 0 * 0.1 = 2.0
        XCTAssertEqual(options.totalPhaseOffsetMs(forLine: 0), 2.0, accuracy: 0.001)

        // Line 10: 2.0 + 10 * 0.1 = 3.0
        XCTAssertEqual(options.totalPhaseOffsetMs(forLine: 10), 3.0, accuracy: 0.001)

        // Line 100: 2.0 + 100 * 0.1 = 12.0
        XCTAssertEqual(options.totalPhaseOffsetMs(forLine: 100), 12.0, accuracy: 0.001)
    }

    func testSampleOffset() {
        let options = DecodingOptions(phaseOffsetMs: 1.0, skewMsPerLine: 0.0)
        let sampleRate = 44100.0

        // 1.0 ms at 44100 Hz = 44.1 samples
        let offset = options.sampleOffset(forLine: 0, sampleRate: sampleRate)
        XCTAssertEqual(offset, 44.1, accuracy: 0.01)
    }

    func testSampleOffsetWithSkew() {
        let options = DecodingOptions(phaseOffsetMs: 0.0, skewMsPerLine: 0.1)
        let sampleRate = 44100.0

        // Line 10: 0.0 + 10 * 0.1 = 1.0ms → 44.1 samples
        let offset = options.sampleOffset(forLine: 10, sampleRate: sampleRate)
        XCTAssertEqual(offset, 44.1, accuracy: 0.01)
    }

    // MARK: - Limits

    func testMaxPhaseOffsetMs() {
        XCTAssertEqual(DecodingOptions.maxPhaseOffsetMs, 50.0)
    }

    func testMaxSkewMsPerLine() {
        XCTAssertEqual(DecodingOptions.maxSkewMsPerLine, 1.0)
    }

    func testDefaultSyncRecoveryThreshold() {
        XCTAssertEqual(DecodingOptions.defaultSyncRecoveryThreshold, 0.5)
    }

    // MARK: - Description

    func testDescriptionDefault() {
        let options = DecodingOptions()
        XCTAssertEqual(options.description, "DecodingOptions(default)")
    }

    func testDescriptionWithPhase() {
        let options = DecodingOptions(phaseOffsetMs: 1.5)
        XCTAssertTrue(options.description.contains("phase"))
        XCTAssertTrue(options.description.contains("1.50"))
    }

    func testDescriptionWithSkew() {
        let options = DecodingOptions(skewMsPerLine: 0.02)
        XCTAssertTrue(options.description.contains("skew"))
        XCTAssertTrue(options.description.contains("0.0200"))
    }

    func testDescriptionWithBoth() {
        let options = DecodingOptions(phaseOffsetMs: 1.5, skewMsPerLine: 0.02)
        XCTAssertTrue(options.description.contains("phase"))
        XCTAssertTrue(options.description.contains("skew"))
    }
}
