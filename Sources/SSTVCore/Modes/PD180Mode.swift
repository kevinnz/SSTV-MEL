/// PD180 SSTV Mode Implementation
///
/// PD180 is a color SSTV mode with the following characteristics:
/// - Resolution: 640 × 496 pixels
/// - Color encoding: YCbCr (luminance, then chrominance)
/// - Transmits TWO image lines per transmission frame (Y-even, Cb, Cr, Y-odd)
/// - Frequency range: 1500 Hz (black) to 2300 Hz (white)
/// - VIS code: 96 (0x60)
/// - Total duration: ~187 seconds
///
/// Frame structure (for 2 image lines):
/// - Sync pulse: 20ms @ 1200 Hz
/// - Porch: 2.08ms @ 1500 Hz
/// - Y0 (even line luminance): 183.04ms
/// - R-Y (Cr chrominance): 183.04ms
/// - B-Y (Cb chrominance): 183.04ms
/// - Y1 (odd line luminance): 183.04ms
///
/// References:
/// - SSTV Handbook Chapter 5
/// - Common amateur radio SSTV implementations
struct PD180Mode: SSTVMode {

    // MARK: - Mode Identification

    /// VIS code for PD180 mode
    let visCode: UInt8 = 0x60 // 96 in decimal

    /// Human-readable name
    let name: String = "PD180"

    // MARK: - Image Dimensions

    /// Image width in pixels
    let width: Int = 640

    /// Image height in pixels (number of lines)
    let height: Int = 496

    // MARK: - Timing Constants (in milliseconds)

    /// Number of image lines per transmission frame
    let linesPerFrame: Int = 2

    /// Total duration of one transmission frame (contains 2 image lines)
    /// QSSTV: 187.06450 seconds / 248 frames = 754.29ms per frame
    /// Frame = sync(20ms) + bp(2ms) + 4×visibleComponents
    let frameDurationMs: Double = 754.29

    /// Duration of sync pulse at start of each frame (in ms)
    /// QSSTV: 0.02000 seconds = 20ms
    let syncPulseMs: Double = 20.0

    /// Duration of porch/back porch after sync pulse (in ms)
    /// QSSTV: bp=0.00208 seconds = 2.08ms
    let porchMs: Double = 2.08

    /// Duration of each Y component (in ms) - one per image line
    /// QSSTV: visibleLineLength = (frameLength - fp - bp - syncDuration) / 4
    /// = (754.29 - 0 - 2.0 - 20) / 4 = 183.07ms
    let yDurationMs: Double = 183.07

    /// Duration of Cb (B-Y, blue chrominance) component (in ms)
    let cbDurationMs: Double = 183.07

    /// Duration of Cr (R-Y, red chrominance) component (in ms)
    let crDurationMs: Double = 183.07

    // MARK: - Frequency Constants (in Hz)

    /// Sync pulse frequency (in Hz)
    let syncFrequencyHz: Double = 1200.0

    /// Black level frequency (in Hz)
    let blackFrequencyHz: Double = 1500.0

    /// White level frequency (in Hz)
    let whiteFrequencyHz: Double = 2300.0

    // MARK: - Derived Values

    /// Frequency range for pixel values (white - black)
    var frequencyRangeHz: Double {
        whiteFrequencyHz - blackFrequencyHz
    }
}

// MARK: - Frame Decoding

extension PD180Mode {

    /// Decode a PD180 frame from frequency data using TIME-BASED decoding.
    ///
    /// This implementation treats SSTV as a continuous timeline, avoiding sample-count rounding
    /// that causes horizontal shear and vertical banding.
    ///
    /// PD180 transmits TWO image lines per frame with the structure:
    /// - Sync pulse: 20ms @ 1200 Hz (IGNORED - not part of image data)
    /// - Porch: 2.08ms @ 1500 Hz (IGNORED - timing reference only)
    /// - Y0 (even line luminance): 183.04ms (ACTIVE VIDEO)
    /// - R-Y (Cr chrominance, shared): 183.04ms (ACTIVE VIDEO)
    /// - B-Y (Cb chrominance, shared): 183.04ms (ACTIVE VIDEO)
    /// - Y1 (odd line luminance): 183.04ms (ACTIVE VIDEO)
    ///
    /// TIME-BASED DECODING STRATEGY:
    /// - Each pixel position maps to an EXACT time offset from component start
    /// - Sample indices are computed as fractional values (no rounding)
    /// - Linear interpolation reads between samples for sub-sample precision
    /// - Phase continuity is maintained across all components and lines
    /// - Sync/porch regions are explicitly excluded from pixel sampling
    ///
    /// PHASE AND SKEW ADJUSTMENT:
    /// - Phase offset shifts all sampling positions by a fixed amount (horizontal shift)
    /// - Skew adjustment adds a per-line offset to correct for timing drift (diagonal slant)
    /// - Combined offset for line N: phaseOffsetMs + (N * skewMsPerLine)
    ///
    /// - Parameters:
    ///   - frequencies: Array of detected frequencies in Hz, time-aligned to frame start
    ///   - sampleRate: Audio sample rate in Hz
    ///   - frameIndex: Index of the frame being decoded (0-based)
    ///   - options: Decoding options for phase and skew adjustment
    ///
    /// - Returns: Array of 2 pixel rows, each containing RGB triplets (width * 3)
    func decodeFrame(
        frequencies: [Double],
        sampleRate: Double,
        frameIndex: Int,
        options: DecodingOptions = .default
    ) -> [[Double]] {
        // Calculate the EXACT time (in seconds) when each component starts
        // These are derived from PD180's published spec timings
        let samplesPerSecond = sampleRate

        // Calculate phase/skew offset for each line in this frame
        // Frame contains 2 lines: even line (frameIndex * 2) and odd line (frameIndex * 2 + 1)
        let line0Index = frameIndex * linesPerFrame
        let line1Index = line0Index + 1

        // Get sample offsets for each line (phase + accumulated skew)
        let line0SampleOffset = options.sampleOffset(forLine: line0Index, sampleRate: sampleRate)
        let line1SampleOffset = options.sampleOffset(forLine: line1Index, sampleRate: sampleRate)

        // For shared chrominance (Cb, Cr), use average of the two line offsets
        let chromaSampleOffset = (line0SampleOffset + line1SampleOffset) / 2.0

        // Component start times in milliseconds (from frame start)
        let syncEndTimeMs = syncPulseMs
        let porchEndTimeMs = syncEndTimeMs + porchMs
        let y0StartTimeMs = porchEndTimeMs
        let y0EndTimeMs = y0StartTimeMs + yDurationMs
        let crStartTimeMs = y0EndTimeMs
        let crEndTimeMs = crStartTimeMs + crDurationMs
        let cbStartTimeMs = crEndTimeMs
        let cbEndTimeMs = cbStartTimeMs + cbDurationMs
        let y1StartTimeMs = cbEndTimeMs

        // Convert milliseconds to fractional sample indices
        // NOTE: These are CONTINUOUS fractional indices - no rounding!
        let msToSamples = samplesPerSecond / 1000.0

        // Apply per-line phase/skew offset to Y components
        let y0StartSample = y0StartTimeMs * msToSamples + line0SampleOffset
        let y0EndSample = y0EndTimeMs * msToSamples + line0SampleOffset

        // Apply averaged offset to shared chrominance components
        let crStartSample = crStartTimeMs * msToSamples + chromaSampleOffset
        let crEndSample = crEndTimeMs * msToSamples + chromaSampleOffset
        let cbStartSample = cbStartTimeMs * msToSamples + chromaSampleOffset
        let cbEndSample = cbEndTimeMs * msToSamples + chromaSampleOffset

        // Apply line 1's offset to Y1
        let y1StartSample = y1StartTimeMs * msToSamples + line1SampleOffset
        let y1EndSample = y1StartSample + (yDurationMs * msToSamples)

        // Decode all components using time-based continuous indexing
        // Each component spans from its start time to end time
        let y0Values = PDModeShared.decodeComponentTimeBased(
            frequencies: frequencies,
            startSample: y0StartSample,
            endSample: y0EndSample,
            pixelCount: width,
            blackFrequencyHz: blackFrequencyHz,
            frequencyRangeHz: frequencyRangeHz
        )

        let crValues = PDModeShared.decodeComponentTimeBased(
            frequencies: frequencies,
            startSample: crStartSample,
            endSample: crEndSample,
            pixelCount: width,
            blackFrequencyHz: blackFrequencyHz,
            frequencyRangeHz: frequencyRangeHz
        )

        let cbValues = PDModeShared.decodeComponentTimeBased(
            frequencies: frequencies,
            startSample: cbStartSample,
            endSample: cbEndSample,
            pixelCount: width,
            blackFrequencyHz: blackFrequencyHz,
            frequencyRangeHz: frequencyRangeHz
        )

        let y1Values = PDModeShared.decodeComponentTimeBased(
            frequencies: frequencies,
            startSample: y1StartSample,
            endSample: y1EndSample,
            pixelCount: width,
            blackFrequencyHz: blackFrequencyHz,
            frequencyRangeHz: frequencyRangeHz
        )

        // Convert to RGB for both lines
        var line0 = [Double](repeating: 0.0, count: width * 3)
        var line1 = [Double](repeating: 0.0, count: width * 3)

        for i in 0..<width {
            // Line 0 (even) uses Y0
            let (r0, g0, b0) = PDModeShared.ycbcrToRGB(
                y: y0Values[i],
                cb: cbValues[i],
                cr: crValues[i]
            )
            line0[i * 3] = r0
            line0[i * 3 + 1] = g0
            line0[i * 3 + 2] = b0

            // Line 1 (odd) uses Y1
            let (r1, g1, b1) = PDModeShared.ycbcrToRGB(
                y: y1Values[i],
                cb: cbValues[i],
                cr: crValues[i]
            )
            line1[i * 3] = r1
            line1[i * 3 + 1] = g1
            line1[i * 3 + 2] = b1
        }

        return [line0, line1]
    }

    /// Legacy single-line decode for compatibility
    /// For PD modes, use decodeFrame() instead
    func decodeLine(
        frequencies: [Double],
        sampleRate: Double,
        lineIndex: Int
    ) -> [Double] {
        // Decode the full frame and return the appropriate line
        let frame = decodeFrame(frequencies: frequencies, sampleRate: sampleRate, frameIndex: lineIndex / 2)
        return lineIndex % 2 == 0 ? frame[0] : frame[1]
    }

}
