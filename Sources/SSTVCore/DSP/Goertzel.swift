import Foundation

/// Goertzel algorithm implementation for single-frequency detection
///
/// The Goertzel algorithm is an efficient method for detecting the magnitude
/// of a specific frequency in a signal. It's particularly useful for SSTV
/// decoding where we need to detect specific tones.
///
/// Reference: https://en.wikipedia.org/wiki/Goertzel_algorithm
struct Goertzel {
    /// Target frequency to detect (in Hz)
    let targetFrequency: Double

    /// Sample rate of the input signal (in Hz)
    let sampleRate: Double

    /// Number of samples in the analysis window
    let windowSize: Int

    /// Precomputed coefficient for the Goertzel algorithm
    private let coefficient: Double

    /// Precomputed constant for magnitude calculation
    private let cosine: Double
    private let sine: Double

    /// Initialize Goertzel detector for a specific frequency
    ///
    /// - Parameters:
    ///   - frequency: Target frequency in Hz
    ///   - sampleRate: Sample rate in Hz
    ///   - windowSize: Number of samples to analyze
    init(frequency: Double, sampleRate: Double, windowSize: Int) {
        self.targetFrequency = frequency
        self.sampleRate = sampleRate
        self.windowSize = windowSize

        // Normalized frequency (0...1)
        let normalizedFrequency = frequency / sampleRate

        // Goertzel coefficient
        let omega = 2.0 * .pi * normalizedFrequency
        self.coefficient = 2.0 * cos(omega)
        self.cosine = cos(omega)
        self.sine = sin(omega)
    }

    /// Detect the magnitude of the target frequency in the given samples
    ///
    /// - Parameter samples: Audio samples to analyze
    /// - Returns: Magnitude of the target frequency
    func detect(samples: [Double]) -> Double {
        guard samples.count >= windowSize else {
            return 0.0
        }

        var s0 = 0.0
        var s1 = 0.0
        var s2 = 0.0

        // Process each sample
        for i in 0..<windowSize {
            s0 = samples[i] + coefficient * s1 - s2
            s2 = s1
            s1 = s0
        }

        // Calculate magnitude
        let real = s1 - s2 * cosine
        let imag = s2 * sine
        let magnitude = sqrt(real * real + imag * imag)

        return magnitude
    }
}

/// Multi-frequency tone detector using multiple Goertzel filters
///
/// This class efficiently detects multiple frequencies simultaneously,
/// which is useful for SSTV decoding where we need to track which
/// frequency is currently present.
struct ToneDetector {
    /// Frequencies to detect (in Hz)
    let frequencies: [Double]

    /// Sample rate (in Hz)
    let sampleRate: Double

    /// Window size for detection (in samples)
    let windowSize: Int

    /// Individual Goertzel detectors for each frequency
    private let detectors: [Goertzel]

    /// Frequency step between bins (for interpolation)
    private let frequencyStep: Double

    /// Initialize tone detector for multiple frequencies
    ///
    /// - Parameters:
    ///   - frequencies: Array of frequencies to detect (in Hz)
    ///   - sampleRate: Sample rate in Hz
    ///   - windowSize: Number of samples per detection window
    init(frequencies: [Double], sampleRate: Double, windowSize: Int) {
        self.frequencies = frequencies
        self.sampleRate = sampleRate
        self.windowSize = windowSize

        // Calculate frequency step for interpolation
        if frequencies.count >= 2 {
            self.frequencyStep = frequencies[1] - frequencies[0]
        } else {
            self.frequencyStep = 1.0
        }

        self.detectors = frequencies.map { freq in
            Goertzel(frequency: freq, sampleRate: sampleRate, windowSize: windowSize)
        }
    }

    /// Detect which frequency has the highest magnitude
    ///
    /// - Parameter samples: Audio samples to analyze
    /// - Returns: Tuple of (frequency, magnitude) for the strongest detected tone
    func detectStrongest(samples: [Double]) -> (frequency: Double, magnitude: Double) {
        var maxMagnitude = 0.0
        var maxIndex = 0

        for (index, detector) in detectors.enumerated() {
            let magnitude = detector.detect(samples: samples)
            if magnitude > maxMagnitude {
                maxMagnitude = magnitude
                maxIndex = index
            }
        }

        return (frequencies[maxIndex], maxMagnitude)
    }

    /// Detect the frequency with parabolic interpolation for sub-bin accuracy
    ///
    /// Uses the magnitudes of the peak bin and its neighbors to estimate
    /// the true frequency with much higher precision than bin width allows.
    /// This is essential for accurate SSTV pixel decoding.
    ///
    /// - Parameter samples: Audio samples to analyze
    /// - Returns: Interpolated frequency with sub-bin precision
    func detectInterpolated(samples: [Double]) -> Double {
        // Get all magnitudes
        let magnitudes = detectAll(samples: samples)

        // Find peak bin
        var maxMagnitude = 0.0
        var maxIndex = 0
        for (index, magnitude) in magnitudes.enumerated() {
            if magnitude > maxMagnitude {
                maxMagnitude = magnitude
                maxIndex = index
            }
        }

        // If at edge or single bin, return bin frequency
        guard maxIndex > 0 && maxIndex < magnitudes.count - 1 else {
            return frequencies[maxIndex]
        }

        // Parabolic interpolation using the three points around the peak
        // The peak of the parabola is at offset p from the center bin:
        // p = 0.5 * (left - right) / (left - 2*center + right)
        let left = magnitudes[maxIndex - 1]
        let center = magnitudes[maxIndex]
        let right = magnitudes[maxIndex + 1]

        // Guard against division by zero
        let denominator = left - 2.0 * center + right
        guard abs(denominator) > 1e-10 else {
            return frequencies[maxIndex]
        }

        let offset = 0.5 * (left - right) / denominator

        // Clamp offset to reasonable range (-0.5 to 0.5)
        let clampedOffset = max(-0.5, min(0.5, offset))

        // Interpolated frequency
        return frequencies[maxIndex] + clampedOffset * frequencyStep
    }

    /// Detect magnitudes for all frequencies
    ///
    /// - Parameter samples: Audio samples to analyze
    /// - Returns: Array of magnitudes corresponding to each frequency
    func detectAll(samples: [Double]) -> [Double] {
        return detectors.map { $0.detect(samples: samples) }
    }
}

/// Sliding window frequency detector for continuous SSTV decoding
///
/// This processes audio samples in a sliding window fashion, detecting
/// the dominant frequency at regular intervals using parabolic interpolation
/// for sub-bin accuracy.
struct FrequencyTracker {
    /// Sample rate (in Hz)
    let sampleRate: Double

    /// Window size for each detection (in samples)
    let windowSize: Int

    /// Step size between detections (in samples)
    let stepSize: Int

    /// Minimum frequency to detect (in Hz)
    let minFrequency: Double

    /// Maximum frequency to detect (in Hz)
    let maxFrequency: Double

    /// Number of frequency bins
    let binCount: Int

    /// Tone detector
    private let detector: ToneDetector

    /// Initialize frequency tracker
    ///
    /// - Parameters:
    ///   - sampleRate: Sample rate in Hz
    ///   - windowSize: Detection window size in samples
    ///   - stepSize: Step between detections in samples
    ///   - minFrequency: Minimum frequency to detect in Hz
    ///   - maxFrequency: Maximum frequency to detect in Hz
    ///   - binCount: Number of frequency bins to use (higher = more accurate but slower)
    init(
        sampleRate: Double,
        windowSize: Int = 512,
        stepSize: Int = 128,
        minFrequency: Double = 1100.0,
        maxFrequency: Double = 2400.0,
        binCount: Int = 256  // Increased from 128 for better resolution
    ) {
        self.sampleRate = sampleRate
        self.windowSize = windowSize
        self.stepSize = stepSize
        self.minFrequency = minFrequency
        self.maxFrequency = maxFrequency
        self.binCount = binCount

        // Generate frequency bins
        let frequencyStep = (maxFrequency - minFrequency) / Double(binCount - 1)
        let frequencies = (0..<binCount).map { i in
            minFrequency + Double(i) * frequencyStep
        }

        self.detector = ToneDetector(
            frequencies: frequencies,
            sampleRate: sampleRate,
            windowSize: windowSize
        )
    }

    /// Track frequencies across the entire audio signal using parabolic interpolation
    ///
    /// - Parameter samples: Complete audio signal (mono)
    /// - Returns: Array of detected frequencies (interpolated), one per step
    func track(samples: [Double]) -> [Double] {
        var frequencies = [Double]()

        let totalSteps = (samples.count - windowSize) / stepSize
        frequencies.reserveCapacity(totalSteps)

        let startTime = Date()
        var lastUpdateTime = startTime
        let updateIntervalSeconds: TimeInterval = 15.0 // Update every 15 seconds

        for step in 0..<totalSteps {
            let offset = step * stepSize
            let windowSamples = Array(samples[offset..<offset + windowSize])

            // Use interpolated detection for sub-bin accuracy
            let freq = detector.detectInterpolated(samples: windowSamples)
            frequencies.append(freq)

            // Update progress every 15 seconds or on first/last step
            let currentTime = Date()
            let timeSinceLastUpdate = currentTime.timeIntervalSince(lastUpdateTime)

            if timeSinceLastUpdate >= updateIntervalSeconds || step == 0 || step == totalSteps - 1 {
                lastUpdateTime = currentTime
            }
        }

        return frequencies
    }

    // MARK: - Progress Helper Methods

    /// Create a progress bar string
    private func makeProgressBar(progress: Double, width: Int) -> String {
        let filled = Int(progress * Double(width))
        let empty = width - filled
        return "[" + String(repeating: "█", count: filled) + String(repeating: "░", count: empty) + "]"
    }

    /// Format time interval in human-readable format
    private func formatTime(_ seconds: TimeInterval) -> String {
        let totalSeconds = Int(seconds)
        let minutes = totalSeconds / 60
        let secs = totalSeconds % 60

        if minutes > 0 {
            return "\(minutes)m \(secs)s"
        } else {
            return "\(secs)s"
        }
    }
}
