import Foundation

/// VIS (Vertical Interval Signaling) code detector for SSTV modes
///
/// The VIS code is transmitted at the start of an SSTV transmission
/// to identify the mode being used. It consists of:
/// - Leader tone (1900 Hz, ~300ms)
/// - Break (1200 Hz, ~10ms)
/// - VIS start bit (1200 Hz, ~30ms)
/// - 8 data bits (1100 Hz = 0, 1300 Hz = 1, ~30ms each)
/// - Stop bit (1200 Hz, ~30ms)
struct VISDetector {

    /// VIS code detection result
    struct VISResult {
        let code: UInt8
        let mode: String
        let startSample: Int
    }

    /// Known SSTV modes and their VIS codes
    static let knownModes: [UInt8: String] = [
        0x60: "PD180",  // 96 decimal
        0x5F: "PD120",  // 95 decimal
        0x61: "PD240",  // 97 decimal
        0x5D: "PD50",   // 93 decimal
        0x62: "PD160",  // 98 decimal
        0x08: "Robot36"
    ]

    /// Detect VIS code in audio signal
    ///
    /// - Parameters:
    ///   - samples: Audio samples (mono)
    ///   - sampleRate: Sample rate in Hz
    ///   - progressHandler: Optional callback for progress updates (0.0...1.0)
    /// - Returns: VIS detection result, or nil if not found
    func detect(
        samples: [Double],
        sampleRate: Double,
        progressHandler: ((Double) -> Void)? = nil
    ) -> VISResult? {
        // Look for leader tone (1900 Hz for ~300ms)
        let leaderFreq = 1900.0
        let leaderDurationMs = 300.0
        let leaderSamples = Int(leaderDurationMs * sampleRate / 1000.0)

        // Search through signal for leader tone
        let windowSize = 512
        let stepSize = 256

        let tracker = FrequencyTracker(
            sampleRate: sampleRate,
            windowSize: windowSize,
            stepSize: stepSize,
            minFrequency: 1100.0,
            maxFrequency: 2000.0,
            binCount: 64
        )

        // Track first ~30 seconds (VIS might be later in the file)
        let searchSamples = min(samples.count, Int(30.0 * sampleRate))

        // Report initial progress
        progressHandler?(0.0)

        let searchFreqs = tracker.track(samples: Array(samples[0..<searchSamples]))

        // Report progress after tracking
        progressHandler?(0.5)

        // Look for sustained 1900 Hz tone
        let tolerance = 100.0 // Increased tolerance
        var leaderStart = -1
        var consecutiveLeader = 0
        let requiredLeaderSteps = leaderSamples / stepSize

        var attemptCount = 0

        for (index, freq) in searchFreqs.enumerated() {
            // Report progress periodically
            if index % 1000 == 0 {
                let progress = 0.5 + (Double(index) / Double(searchFreqs.count) * 0.5)
                progressHandler?(progress)
            }

            if abs(freq - leaderFreq) < tolerance {
                if leaderStart == -1 {
                    leaderStart = index
                }
                consecutiveLeader += 1

                if consecutiveLeader >= requiredLeaderSteps {
                    // Found leader tone, now look for VIS bits after it
                    let visStartStep = index + 1
                    attemptCount += 1

                    if let code = decodeVISBits(
                        frequencies: searchFreqs,
                        startStep: visStartStep,
                        stepSize: stepSize,
                        sampleRate: sampleRate
                    ) {
                        progressHandler?(1.0)
                        let startSample = visStartStep * stepSize
                        let modeName = Self.knownModes[code] ?? "Unknown"
                        return VISResult(code: code, mode: modeName, startSample: startSample)
                    } else if attemptCount < 5 {
                        // Reset and continue searching
                        leaderStart = -1
                        consecutiveLeader = 0
                    }
                }
            } else {
                leaderStart = -1
                consecutiveLeader = 0
            }
        }

        progressHandler?(1.0)
        return nil
    }

    /// Decode VIS data bits
    ///
    /// - Parameters:
    ///   - frequencies: Detected frequencies
    ///   - startStep: Step index where VIS bits start
    ///   - stepSize: Samples per step
    ///   - sampleRate: Sample rate
    /// - Returns: VIS code byte, or nil if decoding fails
    private func decodeVISBits(
        frequencies: [Double],
        startStep: Int,
        stepSize: Int,
        sampleRate: Double
    ) -> UInt8? {
        let bitDurationMs = 30.0
        let stepsPerBit = Int(bitDurationMs * sampleRate / 1000.0) / stepSize

        let freq0 = 1100.0 // Binary 0
        let freq1 = 1300.0 // Binary 1
        let tolerance = 50.0

        var bits: [Bool] = []
        var currentStep = startStep

        // Skip break and start bit (both 1200 Hz)
        currentStep += stepsPerBit * 2

        // Read 8 data bits
        for _ in 0..<8 {
            guard currentStep + stepsPerBit <= frequencies.count else {
                return nil
            }

            // Average frequency over bit duration
            let bitFreqs = frequencies[currentStep..<min(currentStep + stepsPerBit, frequencies.count)]
            let avgFreq = bitFreqs.reduce(0.0, +) / Double(bitFreqs.count)

            if abs(avgFreq - freq0) < tolerance {
                bits.append(false)
            } else if abs(avgFreq - freq1) < tolerance {
                bits.append(true)
            } else {
                // Unclear bit, assume noise
                return nil
            }

            currentStep += stepsPerBit
        }

        // Convert bits to byte (LSB first)
        var code: UInt8 = 0
        for (index, bit) in bits.enumerated() {
            if bit {
                code |= (1 << index)
            }
        }

        return code
    }
}
