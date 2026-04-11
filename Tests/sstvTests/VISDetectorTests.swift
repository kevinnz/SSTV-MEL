import XCTest
@testable import SSTVCore

/// Tests for VIS (Vertical Interval Signaling) code detection
final class VISDetectorTests: XCTestCase {

    // MARK: - Constants

    private let sampleRate = 44100.0

    // MARK: - Helpers

    /// Generate a sine wave at a specific frequency
    private func generateSineWave(
        frequency: Double,
        sampleRate: Double,
        duration: Double,
        amplitude: Double = 1.0
    ) -> [Double] {
        let sampleCount = Int(sampleRate * duration)
        return (0..<sampleCount).map { i in
            amplitude * sin(2.0 * .pi * frequency * Double(i) / sampleRate)
        }
    }

    /// Generate a synthetic VIS code signal
    ///
    /// VIS structure:
    /// - Leader: 1900 Hz for 300ms
    /// - Break: 1200 Hz for 10ms
    /// - Start bit: 1200 Hz for 30ms
    /// - 8 data bits (LSB first): 1100 Hz = 0, 1300 Hz = 1, 30ms each
    /// - Stop bit: 1200 Hz for 30ms
    private func generateVISSignal(
        visCode: UInt8,
        sampleRate: Double
    ) -> [Double] {
        var samples: [Double] = []

        // Leader tone: 1900 Hz for 300ms
        samples.append(contentsOf: generateSineWave(
            frequency: 1900.0, sampleRate: sampleRate, duration: 0.3
        ))

        // Break: 1200 Hz for 10ms
        samples.append(contentsOf: generateSineWave(
            frequency: 1200.0, sampleRate: sampleRate, duration: 0.01
        ))

        // Start bit: 1200 Hz for 30ms
        samples.append(contentsOf: generateSineWave(
            frequency: 1200.0, sampleRate: sampleRate, duration: 0.03
        ))

        // 7 data bits from visCode + 1 even parity bit
        let parityBit = UInt8(visCode.nonzeroBitCount % 2)  // even parity
        let fullByte = visCode | (parityBit << 7)

        // 8 data bits (LSB first)
        for bitIndex in 0..<8 {
            let bit = (fullByte >> bitIndex) & 1
            let freq = bit == 1 ? 1300.0 : 1100.0
            samples.append(contentsOf: generateSineWave(
                frequency: freq, sampleRate: sampleRate, duration: 0.03
            ))
        }

        // Stop bit: 1200 Hz for 30ms
        samples.append(contentsOf: generateSineWave(
            frequency: 1200.0, sampleRate: sampleRate, duration: 0.03
        ))

        return samples
    }

    // MARK: - VIS Detection Tests

    func testDetectPD120VIS() {
        let detector = VISDetector()
        let visCode: UInt8 = 0x5F  // 95 decimal = PD120

        let signal = generateVISSignal(visCode: visCode, sampleRate: sampleRate)

        let result = detector.detect(samples: signal, sampleRate: sampleRate)

        XCTAssertNotNil(result, "VIS detector should detect PD120 VIS code")
        if let result = result {
            XCTAssertEqual(
                result.code, visCode,
                "Detected VIS code should be 0x5F (got 0x\(String(format: "%02X", result.code)))"
            )
            XCTAssertEqual(
                result.mode, "PD120",
                "Detected mode should be PD120 (got \(result.mode))"
            )
        }
    }

    func testDetectPD180VIS() {
        let detector = VISDetector()
        let visCode: UInt8 = 0x60  // 96 decimal = PD180

        let signal = generateVISSignal(visCode: visCode, sampleRate: sampleRate)

        let result = detector.detect(samples: signal, sampleRate: sampleRate)

        XCTAssertNotNil(result, "VIS detector should detect PD180 VIS code")
        if let result = result {
            XCTAssertEqual(
                result.code, visCode,
                "Detected VIS code should be 0x60 (got 0x\(String(format: "%02X", result.code)))"
            )
            XCTAssertEqual(
                result.mode, "PD180",
                "Detected mode should be PD180 (got \(result.mode))"
            )
        }
    }

    func testDetectRobot36VIS() {
        let detector = VISDetector()
        let visCode: UInt8 = 0x08  // 8 decimal = Robot36

        let signal = generateVISSignal(visCode: visCode, sampleRate: sampleRate)

        let result = detector.detect(samples: signal, sampleRate: sampleRate)

        XCTAssertNotNil(result, "VIS detector should detect Robot36 VIS code")
        if let result = result {
            XCTAssertEqual(
                result.code, visCode,
                "Detected VIS code should be 0x08 (got 0x\(String(format: "%02X", result.code)))"
            )
            XCTAssertEqual(
                result.mode, "Robot36",
                "Detected mode should be Robot36 (got \(result.mode))"
            )
        }
    }

    // MARK: - Negative Tests

    func testNoSignal() {
        let detector = VISDetector()

        // 1 second of silence
        let silence = [Double](repeating: 0.0, count: Int(sampleRate))

        let result = detector.detect(samples: silence, sampleRate: sampleRate)
        XCTAssertNil(result, "VIS detector should return nil for silence")
    }

    func testShortSignal() {
        let detector = VISDetector()

        // 100ms is far too short for a VIS signal (leader alone is 300ms)
        let shortSignal = generateSineWave(
            frequency: 1900.0,
            sampleRate: sampleRate,
            duration: 0.1
        )

        let result = detector.detect(samples: shortSignal, sampleRate: sampleRate)
        XCTAssertNil(result, "VIS detector should return nil for a signal too short to contain VIS")
    }

    // MARK: - Known Modes Table

    func testKnownModesTable() {
        let modes = VISDetector.knownModes

        // Verify expected entries exist
        XCTAssertEqual(modes[0x5F], "PD120", "VIS 0x5F should map to PD120")
        XCTAssertEqual(modes[0x60], "PD180", "VIS 0x60 should map to PD180")
        XCTAssertEqual(modes[0x08], "Robot36", "VIS 0x08 should map to Robot36")
        XCTAssertEqual(modes[0x61], "PD240", "VIS 0x61 should map to PD240")
        XCTAssertEqual(modes[0x5D], "PD50", "VIS 0x5D should map to PD50")
        XCTAssertEqual(modes[0x62], "PD160", "VIS 0x62 should map to PD160")

        // Verify there are at least 6 known modes
        XCTAssertGreaterThanOrEqual(
            modes.count, 6,
            "Known modes table should contain at least 6 entries"
        )
    }
}
