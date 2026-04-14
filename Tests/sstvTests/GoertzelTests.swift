import XCTest
@testable import SSTVCore

/// Tests for the Goertzel algorithm, ToneDetector, and FrequencyTracker
final class GoertzelTests: XCTestCase {

    // MARK: - Constants

    private let sampleRate = 44100.0
    private let defaultWindowSize = 512

    // SSTV-relevant frequencies (Hz)
    private let syncFrequency = 1200.0
    private let blackFrequency = 1500.0
    private let centerFrequency = 1900.0
    private let whiteFrequency = 2300.0

    // MARK: - Helpers

    /// Generate a sine wave at a specific frequency
    /// - Parameters:
    ///   - frequency: Frequency in Hz
    ///   - sampleRate: Sample rate in Hz
    ///   - duration: Duration in seconds
    ///   - amplitude: Peak amplitude (default 1.0)
    /// - Returns: Array of samples
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

    // MARK: - Goertzel Single Frequency Tests

    func testSingleFrequencyDetection() {
        let goertzel = Goertzel(
            frequency: syncFrequency,
            sampleRate: sampleRate,
            windowSize: defaultWindowSize
        )

        let samples = generateSineWave(
            frequency: syncFrequency,
            sampleRate: sampleRate,
            duration: 0.05
        )

        let magnitude = goertzel.detect(samples: samples)
        XCTAssertGreaterThan(
            magnitude, 0.0,
            "Goertzel should detect significant energy at the target frequency"
        )
        // A full-amplitude sine in a 512-sample window produces substantial magnitude
        XCTAssertGreaterThan(
            magnitude, 10.0,
            "Magnitude for a unit-amplitude sine at the target frequency should be large"
        )
    }

    func testFrequencyDiscrimination() {
        let goertzelTarget = Goertzel(
            frequency: syncFrequency,
            sampleRate: sampleRate,
            windowSize: defaultWindowSize
        )
        let goertzelOff = Goertzel(
            frequency: 1800.0,
            sampleRate: sampleRate,
            windowSize: defaultWindowSize
        )

        let samples = generateSineWave(
            frequency: syncFrequency,
            sampleRate: sampleRate,
            duration: 0.05
        )

        let magnitudeTarget = goertzelTarget.detect(samples: samples)
        let magnitudeOff = goertzelOff.detect(samples: samples)

        XCTAssertGreaterThan(
            magnitudeTarget, magnitudeOff * 10.0,
            "Target frequency magnitude (\(magnitudeTarget)) should be at least 10× the off-frequency magnitude (\(magnitudeOff))"
        )
    }

    func testMultipleFrequencies() {
        let frequencies = [syncFrequency, blackFrequency, centerFrequency, whiteFrequency]

        for targetFreq in frequencies {
            let goertzel = Goertzel(
                frequency: targetFreq,
                sampleRate: sampleRate,
                windowSize: defaultWindowSize
            )

            let samples = generateSineWave(
                frequency: targetFreq,
                sampleRate: sampleRate,
                duration: 0.05
            )

            let magnitude = goertzel.detect(samples: samples)
            XCTAssertGreaterThan(
                magnitude, 10.0,
                "Goertzel should detect significant energy at \(targetFreq) Hz"
            )
        }
    }

    func testZeroSignal() {
        let goertzel = Goertzel(
            frequency: syncFrequency,
            sampleRate: sampleRate,
            windowSize: defaultWindowSize
        )

        let samples = [Double](repeating: 0.0, count: defaultWindowSize)
        let magnitude = goertzel.detect(samples: samples)

        XCTAssertEqual(
            magnitude, 0.0, accuracy: 1e-10,
            "Zero signal should produce zero (or near-zero) magnitude"
        )
    }

    func testDCOffset() {
        let sstvFrequencies = [syncFrequency, blackFrequency, centerFrequency, whiteFrequency]

        // DC offset = constant value of 1.0
        let samples = [Double](repeating: 1.0, count: defaultWindowSize)

        for freq in sstvFrequencies {
            let goertzel = Goertzel(
                frequency: freq,
                sampleRate: sampleRate,
                windowSize: defaultWindowSize
            )

            let magnitude = goertzel.detect(samples: samples)

            // DC should produce minimal energy at any SSTV frequency (which are all > 1kHz)
            // A unit sine generates magnitude ~windowSize/2 ≈ 256; DC leakage should be far less
            XCTAssertLessThan(
                magnitude, 10.0,
                "DC offset should not produce significant energy at \(freq) Hz (got \(magnitude))"
            )
        }
    }

    // MARK: - ToneDetector Tests

    func testToneDetectorStrongest() {
        let sstvFrequencies = [syncFrequency, blackFrequency, centerFrequency, whiteFrequency]

        let detector = ToneDetector(
            frequencies: sstvFrequencies,
            sampleRate: sampleRate,
            windowSize: defaultWindowSize
        )

        let samples = generateSineWave(
            frequency: centerFrequency,
            sampleRate: sampleRate,
            duration: 0.05
        )

        let (detectedFreq, magnitude) = detector.detectStrongest(samples: samples)

        XCTAssertEqual(
            detectedFreq, centerFrequency, accuracy: 0.001,
            "Strongest frequency should be the center frequency (1900 Hz)"
        )
        XCTAssertGreaterThan(
            magnitude, 0.0,
            "Detected magnitude should be positive"
        )
    }

    func testToneDetectorInterpolated() {
        // Create a dense frequency grid around the SSTV range for interpolation
        let step = 10.0  // 10 Hz steps
        let freqBins = stride(from: 1100.0, through: 2400.0, by: step).map { $0 }

        let detector = ToneDetector(
            frequencies: freqBins,
            sampleRate: sampleRate,
            windowSize: defaultWindowSize
        )

        // Test with a frequency between bins (1850 Hz is not on the 10 Hz grid edge)
        let testFrequency = 1850.0
        let samples = generateSineWave(
            frequency: testFrequency,
            sampleRate: sampleRate,
            duration: 0.05
        )

        let interpolated = detector.detectInterpolated(samples: samples)

        // With 10 Hz bins and parabolic interpolation, should be within a few Hz
        XCTAssertEqual(
            interpolated, testFrequency, accuracy: 15.0,
            "Interpolated frequency (\(interpolated)) should be close to \(testFrequency) Hz"
        )
    }

    func testFrequencyTracker() {
        let tracker = FrequencyTracker(
            sampleRate: sampleRate,
            windowSize: defaultWindowSize,
            stepSize: 128,
            minFrequency: 1100.0,
            maxFrequency: 2400.0,
            binCount: 256
        )

        // 300ms of 1200 Hz followed by 300ms of 1900 Hz
        let part1 = generateSineWave(
            frequency: syncFrequency,
            sampleRate: sampleRate,
            duration: 0.3
        )
        let part2 = generateSineWave(
            frequency: centerFrequency,
            sampleRate: sampleRate,
            duration: 0.3
        )
        let combined = part1 + part2

        let frequencies = tracker.track(samples: combined)

        XCTAssertGreaterThan(
            frequencies.count, 0,
            "Tracker should produce frequency estimates"
        )

        // Early samples (first third) should be near 1200 Hz
        let earlyCount = frequencies.count / 3
        let earlyAvg = frequencies[0..<earlyCount].reduce(0, +) / Double(earlyCount)
        XCTAssertEqual(
            earlyAvg, syncFrequency, accuracy: 100.0,
            "Early frequencies should be near \(syncFrequency) Hz (got \(earlyAvg))"
        )

        // Late samples (last third) should be near 1900 Hz
        let lateStart = frequencies.count * 2 / 3
        let lateSlice = frequencies[lateStart..<frequencies.count]
        let lateAvg = lateSlice.reduce(0, +) / Double(lateSlice.count)
        XCTAssertEqual(
            lateAvg, centerFrequency, accuracy: 100.0,
            "Late frequencies should be near \(centerFrequency) Hz (got \(lateAvg))"
        )
    }

    func testShortWindowBehavior() {
        let shortWindowSize = 64

        let goertzel = Goertzel(
            frequency: centerFrequency,
            sampleRate: sampleRate,
            windowSize: shortWindowSize
        )

        let samples = generateSineWave(
            frequency: centerFrequency,
            sampleRate: sampleRate,
            duration: 0.05
        )

        let magnitude = goertzel.detect(samples: samples)

        // Even with a short window, should detect the frequency
        XCTAssertGreaterThan(
            magnitude, 0.0,
            "Short window should still produce a valid (non-zero) magnitude"
        )

        // Also verify discrimination is still present, though less precise
        let goertzelOff = Goertzel(
            frequency: syncFrequency,
            sampleRate: sampleRate,
            windowSize: shortWindowSize
        )
        let magnitudeOff = goertzelOff.detect(samples: samples)

        XCTAssertGreaterThan(
            magnitude, magnitudeOff,
            "Even with a short window, target frequency should have higher magnitude than off-frequency"
        )
    }
}
