import XCTest
@testable import SSTVCore

/// Tests for the FM demodulator and FM frequency tracker
final class FMDemodulatorTests: XCTestCase {

    // MARK: - Constants

    private let sampleRate = 44100.0
    private let altSampleRate = 48000.0

    /// The FMDemodulator uses a 127-tap FIR filter; skip this many samples
    /// at each edge for stable measurements
    private let filterSettlingSamples = 64

    /// Frequency tolerance for stable region measurements (Hz)
    private let frequencyTolerance = 50.0

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

    /// Extract the stable region of demodulated output (skipping filter edges)
    private func stableRegion(of output: [Double]) -> ArraySlice<Double> {
        let start = filterSettlingSamples
        let end = output.count - filterSettlingSamples
        guard start < end else { return output[0..<0] }
        return output[start..<end]
    }

    /// Compute the median of a collection of Doubles
    private func median(_ values: ArraySlice<Double>) -> Double {
        let sorted = values.sorted()
        guard !sorted.isEmpty else { return 0.0 }
        let mid = sorted.count / 2
        if sorted.count % 2 == 0 {
            return (sorted[mid - 1] + sorted[mid]) / 2.0
        }
        return sorted[mid]
    }

    // MARK: - Constant Frequency Tests

    func testConstantFrequency() {
        let demod = FMDemodulator(sampleRate: sampleRate)
        let samples = generateSineWave(
            frequency: 1900.0,
            sampleRate: sampleRate,
            duration: 0.1
        )

        let output = demod.demodulate(samples: samples)
        XCTAssertEqual(output.count, samples.count, "Output length should match input length")

        let stable = stableRegion(of: output)
        let med = median(stable)

        XCTAssertEqual(
            med, 1900.0, accuracy: frequencyTolerance,
            "Demodulated center frequency should be ~1900 Hz (got \(med))"
        )
    }

    func testBlackFrequency() {
        let demod = FMDemodulator(sampleRate: sampleRate)
        let samples = generateSineWave(
            frequency: 1500.0,
            sampleRate: sampleRate,
            duration: 0.1
        )

        let output = demod.demodulate(samples: samples)
        let stable = stableRegion(of: output)
        let med = median(stable)

        XCTAssertEqual(
            med, 1500.0, accuracy: frequencyTolerance,
            "Demodulated black frequency should be ~1500 Hz (got \(med))"
        )
    }

    func testWhiteFrequency() {
        let demod = FMDemodulator(sampleRate: sampleRate)
        let samples = generateSineWave(
            frequency: 2300.0,
            sampleRate: sampleRate,
            duration: 0.1
        )

        let output = demod.demodulate(samples: samples)
        let stable = stableRegion(of: output)
        let med = median(stable)

        XCTAssertEqual(
            med, 2300.0, accuracy: frequencyTolerance,
            "Demodulated white frequency should be ~2300 Hz (got \(med))"
        )
    }

    func testSyncFrequency() {
        let demod = FMDemodulator(sampleRate: sampleRate)
        let samples = generateSineWave(
            frequency: 1200.0,
            sampleRate: sampleRate,
            duration: 0.1
        )

        let output = demod.demodulate(samples: samples)
        let stable = stableRegion(of: output)
        let med = median(stable)

        XCTAssertEqual(
            med, 1200.0, accuracy: frequencyTolerance,
            "Demodulated sync frequency should be ~1200 Hz (got \(med))"
        )
    }

    // MARK: - Transition Test

    func testFrequencyTransition() {
        let demod = FMDemodulator(sampleRate: sampleRate)

        // 100ms of 1500 Hz (black) followed by 100ms of 2300 Hz (white)
        let black = generateSineWave(
            frequency: 1500.0,
            sampleRate: sampleRate,
            duration: 0.1
        )
        let white = generateSineWave(
            frequency: 2300.0,
            sampleRate: sampleRate,
            duration: 0.1
        )
        let combined = black + white

        let output = demod.demodulate(samples: combined)
        XCTAssertEqual(output.count, combined.count)

        // Measure the early stable region (skip first 64 and avoid transition area)
        let earlyStart = filterSettlingSamples
        let earlyEnd = black.count - filterSettlingSamples
        guard earlyStart < earlyEnd else {
            XCTFail("Not enough samples in early region")
            return
        }
        let earlyMed = median(output[earlyStart..<earlyEnd])

        // Measure the late stable region
        let lateStart = black.count + filterSettlingSamples
        let lateEnd = output.count - filterSettlingSamples
        guard lateStart < lateEnd else {
            XCTFail("Not enough samples in late region")
            return
        }
        let lateMed = median(output[lateStart..<lateEnd])

        XCTAssertEqual(
            earlyMed, 1500.0, accuracy: frequencyTolerance,
            "Early region should be ~1500 Hz (got \(earlyMed))"
        )
        XCTAssertEqual(
            lateMed, 2300.0, accuracy: frequencyTolerance,
            "Late region should be ~2300 Hz (got \(lateMed))"
        )
    }

    // MARK: - FMFrequencyTracker Test

    func testFMTrackerMatchesDemodulator() {
        let demod = FMDemodulator(sampleRate: sampleRate)
        let tracker = FMFrequencyTracker(sampleRate: sampleRate)

        let samples = generateSineWave(
            frequency: 1900.0,
            sampleRate: sampleRate,
            duration: 0.1
        )

        let demodOutput = demod.demodulate(samples: samples)
        let trackerOutput = tracker.track(samples: samples)

        XCTAssertEqual(
            demodOutput.count, trackerOutput.count,
            "Tracker and demodulator should produce the same number of samples"
        )

        // They should be bitwise identical (same code path)
        for i in 0..<demodOutput.count {
            XCTAssertEqual(
                demodOutput[i], trackerOutput[i],
                "Sample \(i) differs: demod=\(demodOutput[i]), tracker=\(trackerOutput[i])"
            )
        }
    }

    // MARK: - Determinism Test

    func testDeterminism() {
        let demod = FMDemodulator(sampleRate: sampleRate)
        let samples = generateSineWave(
            frequency: 1900.0,
            sampleRate: sampleRate,
            duration: 0.1
        )

        let output1 = demod.demodulate(samples: samples)
        let output2 = demod.demodulate(samples: samples)

        XCTAssertEqual(output1.count, output2.count)

        for i in 0..<output1.count {
            XCTAssertEqual(
                output1[i], output2[i],
                "Demodulation should be deterministic: sample \(i) differs (\(output1[i]) vs \(output2[i]))"
            )
        }
    }

    // MARK: - Sample Rate Independence Test

    func testSampleRateIndependence() {
        let demod44 = FMDemodulator(sampleRate: sampleRate)
        let demod48 = FMDemodulator(sampleRate: altSampleRate)

        let samples44 = generateSineWave(
            frequency: 1900.0,
            sampleRate: sampleRate,
            duration: 0.1
        )
        let samples48 = generateSineWave(
            frequency: 1900.0,
            sampleRate: altSampleRate,
            duration: 0.1
        )

        let output44 = demod44.demodulate(samples: samples44)
        let output48 = demod48.demodulate(samples: samples48)

        let stable44 = stableRegion(of: output44)
        let stable48 = stableRegion(of: output48)

        let med44 = median(stable44)
        let med48 = median(stable48)

        XCTAssertEqual(
            med44, 1900.0, accuracy: frequencyTolerance,
            "44100 Hz sample rate should report ~1900 Hz (got \(med44))"
        )
        XCTAssertEqual(
            med48, 1900.0, accuracy: frequencyTolerance,
            "48000 Hz sample rate should report ~1900 Hz (got \(med48))"
        )
    }
}
