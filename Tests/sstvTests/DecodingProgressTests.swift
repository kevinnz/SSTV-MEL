import XCTest
@testable import SSTVCore

/// Tests for DecodingProgress
final class DecodingProgressTests: XCTestCase {

    // MARK: - Phase Descriptions

    func testVisDetectionPhaseDescription() {
        let phase = DecodingProgress.Phase.visDetection(progress: 0.5)
        XCTAssertEqual(phase.description, "Detecting VIS code (50%)")
    }

    func testFMDemodulationPhaseDescription() {
        let phase = DecodingProgress.Phase.fmDemodulation(progress: 0.75)
        XCTAssertEqual(phase.description, "Demodulating FM signal (75%)")
    }

    func testSignalSearchPhaseDescription() {
        let phase = DecodingProgress.Phase.signalSearch
        XCTAssertEqual(phase.description, "Searching for SSTV signal start")
    }

    func testFrameDecodingPhaseDescription() {
        let phase = DecodingProgress.Phase.frameDecoding(linesDecoded: 100, totalLines: 496)
        XCTAssertEqual(phase.description, "Decoding frames (100/496 lines)")
    }

    func testWritingPhaseDescription() {
        let phase = DecodingProgress.Phase.writing
        XCTAssertEqual(phase.description, "Writing output file")
    }

    // MARK: - DecodingProgress Properties

    func testPercentComplete() {
        let progress = DecodingProgress(
            phase: .signalSearch,
            overallProgress: 0.5,
            elapsedSeconds: 10.0
        )
        XCTAssertEqual(progress.percentComplete, 50.0, accuracy: 0.001)
    }

    func testPercentCompleteZero() {
        let progress = DecodingProgress(
            phase: .visDetection(progress: 0.0),
            overallProgress: 0.0,
            elapsedSeconds: 0.0
        )
        XCTAssertEqual(progress.percentComplete, 0.0, accuracy: 0.001)
    }

    func testPercentCompleteFull() {
        let progress = DecodingProgress(
            phase: .writing,
            overallProgress: 1.0,
            elapsedSeconds: 60.0
        )
        XCTAssertEqual(progress.percentComplete, 100.0, accuracy: 0.001)
    }

    func testProgressInit() {
        let progress = DecodingProgress(
            phase: .frameDecoding(linesDecoded: 50, totalLines: 100),
            overallProgress: 0.65,
            elapsedSeconds: 30.0,
            estimatedSecondsRemaining: 15.0,
            modeName: "PD120"
        )

        XCTAssertEqual(progress.overallProgress, 0.65, accuracy: 0.001)
        XCTAssertEqual(progress.elapsedSeconds, 30.0, accuracy: 0.001)
        XCTAssertEqual(progress.estimatedSecondsRemaining, 15.0)
        XCTAssertEqual(progress.modeName, "PD120")
    }

    func testProgressInitWithoutOptionals() {
        let progress = DecodingProgress(
            phase: .signalSearch,
            overallProgress: 0.3,
            elapsedSeconds: 5.0
        )

        XCTAssertNil(progress.estimatedSecondsRemaining)
        XCTAssertNil(progress.modeName)
    }
}
