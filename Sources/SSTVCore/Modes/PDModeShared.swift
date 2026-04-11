/// Shared decoding utilities for PD-family SSTV modes
///
/// These functions are common to PD120, PD180, Robot36, and similar modes that use
/// YCbCr color encoding with the same frequency ranges and conversion math.
///
/// All functions are stateless and operate on normalized `Double` values.
/// No DSP, image buffer access, or audio reading is performed here.
enum PDModeShared {

    // MARK: - Component Decoding

    /// Decode a single component (Y, Cb, or Cr) using TIME-BASED fractional sample indexing.
    ///
    /// This is the core of the time-based decoding approach that eliminates horizontal shear
    /// and vertical banding. Key principles:
    ///
    /// 1. **No Integer Rounding**: Sample positions are computed as fractional Double values
    /// 2. **Linear Interpolation**: Sub-sample precision via interpolation between adjacent samples
    /// 3. **Time Continuity**: Each pixel maps to an exact time offset with no phase resets
    /// 4. **Strict Bounds**: Clamping ensures we never read outside the active video window
    ///
    /// TIMING MODEL:
    /// - A component spans from startSample to endSample (fractional indices)
    /// - Each of the `pixelCount` pixels occupies an equal time slice
    /// - Pixel i is centered at: startSample + (i + 0.5) * sampleSpan / pixelCount
    /// - We interpolate between floor(pos) and ceil(pos) to get the exact value
    ///
    /// - Parameters:
    ///   - frequencies: Full array of detected frequencies for the entire frame
    ///   - startSample: Fractional sample index where this component starts
    ///   - endSample: Fractional sample index where this component ends
    ///   - pixelCount: Number of pixels to decode (typically 640 or 320)
    ///   - blackFrequencyHz: Black level frequency in Hz (1500 Hz for standard modes)
    ///   - frequencyRangeHz: Frequency range for pixel values in Hz (800 Hz for standard modes)
    /// - Returns: Array of normalized pixel values (0.0...1.0), length = pixelCount
    static func decodeComponentTimeBased(
        frequencies: [Double],
        startSample: Double,
        endSample: Double,
        pixelCount: Int,
        blackFrequencyHz: Double,
        frequencyRangeHz: Double
    ) -> [Double] {
        var values = [Double](repeating: 0.0, count: pixelCount)

        // Calculate the time span of this component in samples (fractional)
        let componentDurationSamples = endSample - startSample

        // Each pixel occupies an equal fraction of the component's time span
        let samplesPerPixel = componentDurationSamples / Double(pixelCount)

        for pixelIndex in 0..<pixelCount {
            // Calculate the EXACT fractional sample position for this pixel's CENTER
            // Using center position (pixelIndex + 0.5) provides better sampling
            let pixelCenterPosition = startSample + (Double(pixelIndex) + 0.5) * samplesPerPixel

            // Clamp position strictly within the frequency array bounds
            // This prevents reading outside the active video window
            let clampedPosition = min(max(pixelCenterPosition, 0.0), Double(frequencies.count - 1))

            // Perform linear interpolation between adjacent samples
            let lowerIndex = Int(clampedPosition)
            let upperIndex = min(lowerIndex + 1, frequencies.count - 1)
            let fraction = clampedPosition - Double(lowerIndex)

            // Bounds check (defensive programming)
            guard lowerIndex >= 0 && lowerIndex < frequencies.count &&
                  upperIndex >= 0 && upperIndex < frequencies.count else {
                values[pixelIndex] = 0.5 // Fallback to mid-gray
                continue
            }

            // Linear interpolation: freq = (1-t)*f0 + t*f1
            let lowerFreq = frequencies[lowerIndex]
            let upperFreq = frequencies[upperIndex]
            let interpolatedFreq = lowerFreq * (1.0 - fraction) + upperFreq * fraction

            // Map interpolated frequency to normalized pixel value
            values[pixelIndex] = frequencyToValue(
                interpolatedFreq,
                blackFrequencyHz: blackFrequencyHz,
                frequencyRangeHz: frequencyRangeHz
            )
        }

        return values
    }

    // MARK: - Frequency Mapping

    /// Convert a detected frequency to a normalized pixel value.
    ///
    /// Maps the frequency range [blackFrequencyHz ... blackFrequencyHz + frequencyRangeHz]
    /// to the output range [0.0...1.0].
    ///
    /// - Parameters:
    ///   - frequency: Detected frequency in Hz
    ///   - blackFrequencyHz: Black level frequency in Hz (e.g. 1500 Hz)
    ///   - frequencyRangeHz: Frequency range in Hz (e.g. 800 Hz)
    /// - Returns: Normalized pixel value (0.0...1.0), clamped
    static func frequencyToValue(
        _ frequency: Double,
        blackFrequencyHz: Double,
        frequencyRangeHz: Double
    ) -> Double {
        let normalized = (frequency - blackFrequencyHz) / frequencyRangeHz
        return min(max(normalized, 0.0), 1.0)
    }

    // MARK: - Color Conversion

    /// Convert YCbCr color values to RGB using ITU-R BT.601.
    ///
    /// - Parameters:
    ///   - y: Luminance (0.0...1.0)
    ///   - cb: Blue chrominance (0.0...1.0, centered at 0.5)
    ///   - cr: Red chrominance (0.0...1.0, centered at 0.5)
    /// - Returns: RGB tuple, each component in range (0.0...1.0), clamped
    static func ycbcrToRGB(y: Double, cb: Double, cr: Double) -> (r: Double, g: Double, b: Double) {
        // Center Cb and Cr around 0.5
        let cbCentered = cb - 0.5
        let crCentered = cr - 0.5

        // ITU-R BT.601 conversion
        let r = y + 1.402 * crCentered
        let g = y - 0.344136 * cbCentered - 0.714136 * crCentered
        let b = y + 1.772 * cbCentered

        // Clamp to valid range
        return (
            r: min(max(r, 0.0), 1.0),
            g: min(max(g, 0.0), 1.0),
            b: min(max(b, 0.0), 1.0)
        )
    }
}
