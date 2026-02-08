import XCTest
@testable import SSTVCore

/// Tests for decoder state machine, diagnostics, and mode parameters
final class DecoderStateTests: XCTestCase {

    // MARK: - DiagnosticInfo Tests

    func testDiagnosticInfoCreation() {
        let diagnostic = DiagnosticInfo(
            level: .warning,
            category: .sync,
            message: "Test message",
            data: ["key": "value"]
        )

        XCTAssertEqual(diagnostic.level, .warning)
        XCTAssertEqual(diagnostic.category, .sync)
        XCTAssertEqual(diagnostic.message, "Test message")
        XCTAssertEqual(diagnostic.data["key"], "value")

        // Verify timestamp is recent (within last second)
        let now = Date()
        XCTAssertLessThanOrEqual(diagnostic.timestamp.timeIntervalSince(now), 1.0)
        XCTAssertGreaterThanOrEqual(diagnostic.timestamp.timeIntervalSince(now), -1.0)
    }

    func testDiagnosticInfoWithEmptyData() {
        let diagnostic = DiagnosticInfo(
            level: .info,
            category: .general,
            message: "No data"
        )

        XCTAssertTrue(diagnostic.data.isEmpty)
    }

    func testDiagnosticLevels() {
        let debug = DiagnosticInfo(level: .debug, category: .general, message: "Debug")
        let info = DiagnosticInfo(level: .info, category: .general, message: "Info")
        let warning = DiagnosticInfo(level: .warning, category: .general, message: "Warning")
        let error = DiagnosticInfo(level: .error, category: .general, message: "Error")

        // Just verify all levels can be created
        XCTAssertEqual(debug.level, .debug)
        XCTAssertEqual(info.level, .info)
        XCTAssertEqual(warning.level, .warning)
        XCTAssertEqual(error.level, .error)
    }

    func testDiagnosticCategories() {
        let categories: [DiagnosticInfo.Category] = [.sync, .demodulation, .decoding, .timing, .general]

        for category in categories {
            let diagnostic = DiagnosticInfo(level: .info, category: category, message: "Test")
            XCTAssertEqual(diagnostic.category, category)
        }
    }

    // MARK: - DecoderState Tests

    func testDecoderStateEquality() {
        XCTAssertEqual(DecoderState.idle, DecoderState.idle)
        XCTAssertEqual(DecoderState.detectingVIS, DecoderState.detectingVIS)
        XCTAssertEqual(DecoderState.searchingSync, DecoderState.searchingSync)
        XCTAssertEqual(DecoderState.complete, DecoderState.complete)

        XCTAssertEqual(DecoderState.syncLocked(confidence: 0.8), DecoderState.syncLocked(confidence: 0.8))
        XCTAssertNotEqual(DecoderState.syncLocked(confidence: 0.8), DecoderState.syncLocked(confidence: 0.9))

        XCTAssertEqual(DecoderState.decoding(line: 10, totalLines: 100), DecoderState.decoding(line: 10, totalLines: 100))
        XCTAssertNotEqual(DecoderState.decoding(line: 10, totalLines: 100), DecoderState.decoding(line: 11, totalLines: 100))

        XCTAssertEqual(DecoderState.syncLost(atLine: 50), DecoderState.syncLost(atLine: 50))
        XCTAssertNotEqual(DecoderState.syncLost(atLine: 50), DecoderState.syncLost(atLine: 51))
    }

    func testDecoderStateIdle() {
        let state = DecoderState.idle

        // Verify we can create idle state
        XCTAssertEqual(state, .idle)
    }

    func testDecoderStateSyncLocked() {
        let state = DecoderState.syncLocked(confidence: 0.75)

        if case .syncLocked(let confidence) = state {
            XCTAssertEqual(confidence, 0.75, accuracy: 0.001)
        } else {
            XCTFail("Expected syncLocked state")
        }
    }

    func testDecoderStateDecoding() {
        let state = DecoderState.decoding(line: 25, totalLines: 496)

        if case .decoding(let line, let totalLines) = state {
            XCTAssertEqual(line, 25)
            XCTAssertEqual(totalLines, 496)
        } else {
            XCTFail("Expected decoding state")
        }
    }

    func testDecoderStateSyncLost() {
        let state = DecoderState.syncLost(atLine: 100)

        if case .syncLost(let line) = state {
            XCTAssertEqual(line, 100)
        } else {
            XCTFail("Expected syncLost state")
        }
    }

    // MARK: - ModeParameters Tests

    func testPD120ParametersDefaultValues() {
        let params = PD120Parameters()

        // Verify dimensions
        XCTAssertEqual(params.width, 640)
        XCTAssertEqual(params.height, 496)
        XCTAssertEqual(params.linesPerFrame, 2)

        // Verify timing
        XCTAssertEqual(params.frameDurationMs, 508.48, accuracy: 0.01)
        XCTAssertEqual(params.syncPulseMs, 20.0, accuracy: 0.01)
        XCTAssertEqual(params.porchMs, 2.08, accuracy: 0.01)
        XCTAssertEqual(params.yDurationMs, 121.6, accuracy: 0.01)
        XCTAssertEqual(params.cbDurationMs, 121.6, accuracy: 0.01)
        XCTAssertEqual(params.crDurationMs, 121.6, accuracy: 0.01)

        // Verify frequencies
        XCTAssertEqual(params.syncFrequencyHz, 1200.0, accuracy: 0.1)
        XCTAssertEqual(params.blackFrequencyHz, 1500.0, accuracy: 0.1)
        XCTAssertEqual(params.whiteFrequencyHz, 2300.0, accuracy: 0.1)

        // Verify derived values
        XCTAssertEqual(params.frequencyRangeHz, 800.0, accuracy: 0.1)
        XCTAssertEqual(params.lineDurationMs, 254.24, accuracy: 0.01)
    }

    func testPD180ParametersDefaultValues() {
        let params = PD180Parameters()

        // Verify dimensions
        XCTAssertEqual(params.width, 640)
        XCTAssertEqual(params.height, 496)
        XCTAssertEqual(params.linesPerFrame, 2)

        // Verify timing - PD180 has longer frame duration
        XCTAssertEqual(params.frameDurationMs, 754.29, accuracy: 0.01)
        XCTAssertEqual(params.syncPulseMs, 20.0, accuracy: 0.01)
        XCTAssertEqual(params.porchMs, 2.0, accuracy: 0.01)

        // Verify frequencies (same as PD120)
        XCTAssertEqual(params.syncFrequencyHz, 1200.0, accuracy: 0.1)
        XCTAssertEqual(params.blackFrequencyHz, 1500.0, accuracy: 0.1)
        XCTAssertEqual(params.whiteFrequencyHz, 2300.0, accuracy: 0.1)
    }

    func testSSTVModeSelectionPD120() {
        let selection = SSTVModeSelection.pd120()

        XCTAssertEqual(selection.name, "PD120")
        XCTAssertEqual(selection.visCode, 0x5F)

        let params = selection.parameters
        XCTAssertEqual(params.width, 640)
        XCTAssertEqual(params.height, 496)
    }

    func testSSTVModeSelectionPD180() {
        let selection = SSTVModeSelection.pd180()

        XCTAssertEqual(selection.name, "PD180")
        XCTAssertEqual(selection.visCode, 0x60)

        let params = selection.parameters
        XCTAssertEqual(params.width, 640)
        XCTAssertEqual(params.height, 496)
    }

    func testSSTVModeSelectionFromVISCode() {
        let pd120 = SSTVModeSelection.from(visCode: 0x5F)
        XCTAssertNotNil(pd120)
        XCTAssertEqual(pd120?.name, "PD120")

        let pd180 = SSTVModeSelection.from(visCode: 0x60)
        XCTAssertNotNil(pd180)
        XCTAssertEqual(pd180?.name, "PD180")

        let unknown = SSTVModeSelection.from(visCode: 0xFF)
        XCTAssertNil(unknown)
    }

    func testSSTVModeSelectionFromName() {
        let pd120 = SSTVModeSelection.from(name: "PD120")
        XCTAssertNotNil(pd120)
        XCTAssertEqual(pd120?.visCode, 0x5F)

        let pd180 = SSTVModeSelection.from(name: "PD180")
        XCTAssertNotNil(pd180)
        XCTAssertEqual(pd180?.visCode, 0x60)

        let unknown = SSTVModeSelection.from(name: "UNKNOWN")
        XCTAssertNil(unknown)
    }

    func testCustomPD120Parameters() {
        let custom = PD120Parameters(
            frameDurationMs: 500.0,
            syncPulseMs: 25.0
        )

        XCTAssertEqual(custom.frameDurationMs, 500.0, accuracy: 0.01)
        XCTAssertEqual(custom.syncPulseMs, 25.0, accuracy: 0.01)
        // Other parameters should retain defaults
        XCTAssertEqual(custom.porchMs, 2.08, accuracy: 0.01)
        XCTAssertEqual(custom.yDurationMs, 121.6, accuracy: 0.01)
    }

    // MARK: - DecodingOptions Tests

    func testDecodingOptionsSyncRecoveryThreshold() {
        let defaultOptions = DecodingOptions()
        XCTAssertEqual(defaultOptions.syncRecoveryThreshold, 0.5, accuracy: 0.01)

        let customOptions = DecodingOptions(syncRecoveryThreshold: 0.75)
        XCTAssertEqual(customOptions.syncRecoveryThreshold, 0.75, accuracy: 0.01)

        // Test clamping to valid range
        let tooLow = DecodingOptions(syncRecoveryThreshold: -0.5)
        XCTAssertEqual(tooLow.syncRecoveryThreshold, 0.0, accuracy: 0.01)

        let tooHigh = DecodingOptions(syncRecoveryThreshold: 1.5)
        XCTAssertEqual(tooHigh.syncRecoveryThreshold, 1.0, accuracy: 0.01)
    }

    func testDecodingOptionsSyncRecoveryThresholdMutation() {
        var options = DecodingOptions()
        options.syncRecoveryThreshold = 0.25
        XCTAssertEqual(options.syncRecoveryThreshold, 0.25, accuracy: 0.01)

        // Test clamping on mutation
        options.syncRecoveryThreshold = -0.1
        XCTAssertEqual(options.syncRecoveryThreshold, 0.0, accuracy: 0.01)

        options.syncRecoveryThreshold = 1.5
        XCTAssertEqual(options.syncRecoveryThreshold, 1.0, accuracy: 0.01)
    }
}
