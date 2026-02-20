import XCTest
@testable import SSTVCore

/// Extended tests for DecoderState and DecoderError - descriptions, isActive, isTerminal
final class DecoderStateBehaviorTests: XCTestCase {

    // MARK: - DecoderState.description

    func testIdleDescription() {
        XCTAssertEqual(DecoderState.idle.description, "Idle")
    }

    func testDetectingVISDescription() {
        XCTAssertEqual(DecoderState.detectingVIS.description, "Detecting VIS code")
    }

    func testSearchingSyncDescription() {
        XCTAssertEqual(DecoderState.searchingSync.description, "Searching for sync")
    }

    func testSyncLockedDescription() {
        let state = DecoderState.syncLocked(confidence: 0.85)
        XCTAssertEqual(state.description, "Sync locked (85%)")
    }

    func testDecodingDescription() {
        let state = DecoderState.decoding(line: 99, totalLines: 496)
        XCTAssertEqual(state.description, "Decoding line 100/496")
    }

    func testSyncLostDescription() {
        let state = DecoderState.syncLost(atLine: 50)
        XCTAssertEqual(state.description, "Sync lost at line 50")
    }

    func testCompleteDescription() {
        XCTAssertEqual(DecoderState.complete.description, "Complete")
    }

    func testErrorDescription() {
        let state = DecoderState.error(.syncNotFound)
        XCTAssertTrue(state.description.contains("Error"))
    }

    // MARK: - DecoderState.isActive

    func testIsActiveForActiveStates() {
        XCTAssertTrue(DecoderState.detectingVIS.isActive)
        XCTAssertTrue(DecoderState.searchingSync.isActive)
        XCTAssertTrue(DecoderState.syncLocked(confidence: 0.5).isActive)
        XCTAssertTrue(DecoderState.decoding(line: 0, totalLines: 100).isActive)
        XCTAssertTrue(DecoderState.syncLost(atLine: 10).isActive)
    }

    func testIsActiveForInactiveStates() {
        XCTAssertFalse(DecoderState.idle.isActive)
        XCTAssertFalse(DecoderState.complete.isActive)
        XCTAssertFalse(DecoderState.error(.syncNotFound).isActive)
    }

    // MARK: - DecoderState.isTerminal

    func testIsTerminalForTerminalStates() {
        XCTAssertTrue(DecoderState.complete.isTerminal)
        XCTAssertTrue(DecoderState.error(.syncNotFound).isTerminal)
    }

    func testIsTerminalForNonTerminalStates() {
        XCTAssertFalse(DecoderState.idle.isTerminal)
        XCTAssertFalse(DecoderState.detectingVIS.isTerminal)
        XCTAssertFalse(DecoderState.searchingSync.isTerminal)
        XCTAssertFalse(DecoderState.syncLocked(confidence: 0.5).isTerminal)
        XCTAssertFalse(DecoderState.decoding(line: 0, totalLines: 100).isTerminal)
        XCTAssertFalse(DecoderState.syncLost(atLine: 10).isTerminal)
    }

    // MARK: - DecoderError.description

    func testErrorSyncNotFoundDescription() {
        XCTAssertEqual(DecoderError.syncNotFound.description, "No sync pattern found in signal")
    }

    func testErrorSyncLostDescription() {
        let error = DecoderError.syncLost(atLine: 42)
        XCTAssertEqual(error.description, "Sync lost at line 42")
    }

    func testEndOfStreamDescription() {
        let error = DecoderError.endOfStream(linesDecoded: 100, totalLines: 496)
        XCTAssertEqual(error.description, "End of stream: decoded 100/496 lines")
    }

    func testUnknownModeDescription() {
        let error = DecoderError.unknownMode("BLAH")
        XCTAssertEqual(error.description, "Unknown SSTV mode: BLAH")
    }

    func testInvalidSampleRateDescription() {
        let error = DecoderError.invalidSampleRate(100.0)
        XCTAssertEqual(error.description, "Invalid sample rate: 100.0 Hz")
    }

    func testInsufficientSamplesDescription() {
        XCTAssertEqual(DecoderError.insufficientSamples.description, "Insufficient samples for decoding")
    }

    // MARK: - DecoderError Equatable

    func testDecoderErrorEquatable() {
        XCTAssertEqual(DecoderError.syncNotFound, DecoderError.syncNotFound)
        XCTAssertEqual(DecoderError.syncLost(atLine: 10), DecoderError.syncLost(atLine: 10))
        XCTAssertNotEqual(DecoderError.syncLost(atLine: 10), DecoderError.syncLost(atLine: 20))
        XCTAssertEqual(
            DecoderError.endOfStream(linesDecoded: 10, totalLines: 100),
            DecoderError.endOfStream(linesDecoded: 10, totalLines: 100)
        )
        XCTAssertNotEqual(DecoderError.syncNotFound, DecoderError.insufficientSamples)
    }

    // MARK: - DecoderDelegate Default Implementations

    func testDefaultDelegateImplementations() {
        // Verify that a class implementing only the protocol doesn't crash
        // when default methods are called
        class TestDelegate: DecoderDelegate {}

        let delegate = TestDelegate()
        // All of these should be no-ops (default implementations)
        delegate.didLockSync(confidence: 0.5)
        delegate.didLoseSync()
        delegate.didBeginVISDetection()
        delegate.didDetectVISCode(0x5F, mode: "PD120")
        delegate.didFailVISDetection()
        delegate.didDecodeLine(lineNumber: 0, totalLines: 100)
        delegate.didUpdateProgress(0.5)
        delegate.didCompleteImage(ImageBuffer(width: 10, height: 10))
        delegate.didChangeState(.idle)
        delegate.didEncounterError(.syncNotFound)
        delegate.didEmitDiagnostic(DiagnosticInfo(level: .info, category: .general, message: "test"))
    }
}
