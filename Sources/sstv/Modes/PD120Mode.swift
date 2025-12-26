/// PD120 SSTV Mode Implementation
///
/// PD120 is a color SSTV mode with the following characteristics:
/// - Resolution: 640 × 496 pixels
/// - Color encoding: YCbCr (luminance, then chrominance)
/// - Transmits TWO image lines per transmission frame (Y-even, Cb, Cr, Y-odd)
/// - Frequency range: 1500 Hz (black) to 2300 Hz (white)
/// - VIS code: 95 (0x5F)
/// - Total duration: ~126 seconds
///
/// Frame structure (for 2 image lines):
/// - Sync pulse: 20ms @ 1200 Hz
/// - Porch: 2.08ms @ 1500 Hz
/// - Y0 (even line luminance): 121.6ms
/// - R-Y (Cr chrominance): 121.6ms
/// - B-Y (Cb chrominance): 121.6ms
/// - Y1 (odd line luminance): 121.6ms
///
/// References:
/// - SSTV Handbook Chapter 5
/// - Common amateur radio SSTV implementations
struct PD120Mode: SSTVMode {
    
    // MARK: - Mode Identification
    
    /// VIS code for PD120 mode (95 decimal = 0x5F)
    let visCode: UInt8 = 0x5F // 95 in decimal (was incorrectly 0x63)
    
    /// Human-readable name
    let name: String = "PD120"
    
    // MARK: - Image Dimensions
    
    /// Image width in pixels
    let width: Int = 640
    
    /// Image height in pixels (number of lines)
    let height: Int = 496
    
    // MARK: - Timing Constants (in milliseconds)
    
    /// Number of image lines per transmission frame
    let linesPerFrame: Int = 2
    
    /// Total duration of one transmission frame (contains 2 image lines)
    /// 126 seconds / 248 frames ≈ 508ms
    let frameDurationMs: Double = 508.48
    
    /// Duration of sync pulse at start of each frame (in ms)
    let syncPulseMs: Double = 20.0
    
    /// Duration of porch after sync pulse (in ms)
    let porchMs: Double = 2.08
    
    /// Duration of each Y component (in ms) - one per image line
    let yDurationMs: Double = 121.6
    
    /// Duration of Cb (B-Y, blue chrominance) component (in ms)
    let cbDurationMs: Double = 121.6
    
    /// Duration of Cr (R-Y, red chrominance) component (in ms)
    let crDurationMs: Double = 121.6
    
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

extension PD120Mode {
    
    /// Decode a PD120 frame from frequency data using TIME-BASED decoding.
    ///
    /// This implementation treats SSTV as a continuous timeline, avoiding sample-count rounding
    /// that causes horizontal shear and vertical banding.
    ///
    /// PD120 transmits TWO image lines per frame with the structure:
    /// - Sync pulse: 20ms @ 1200 Hz (IGNORED - not part of image data)
    /// - Porch: 2.08ms @ 1500 Hz (IGNORED - timing reference only)
    /// - Y0 (even line luminance): 121.6ms (ACTIVE VIDEO)
    /// - R-Y (Cr chrominance, shared): 121.6ms (ACTIVE VIDEO)
    /// - B-Y (Cb chrominance, shared): 121.6ms (ACTIVE VIDEO)
    /// - Y1 (odd line luminance): 121.6ms (ACTIVE VIDEO)
    ///
    /// TIME-BASED DECODING STRATEGY:
    /// - Each pixel position maps to an EXACT time offset from component start
    /// - Sample indices are computed as fractional values (no rounding)
    /// - Linear interpolation reads between samples for sub-sample precision
    /// - Phase continuity is maintained across all components and lines
    /// - Sync/porch regions are explicitly excluded from pixel sampling
    ///
    /// - Parameters:
    ///   - frequencies: Array of detected frequencies in Hz, time-aligned to frame start
    ///   - sampleRate: Audio sample rate in Hz
    ///   - frameIndex: Index of the frame being decoded (0-based)
    ///
    /// - Returns: Array of 2 pixel rows, each containing RGB triplets (width * 3)
    func decodeFrame(
        frequencies: [Double],
        sampleRate: Double,
        frameIndex: Int
    ) -> [[Double]] {
        // Calculate the EXACT time (in seconds) when each component starts
        // These are derived from PD120's published spec timings
        let samplesPerSecond = sampleRate
        
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
        let y0StartSample = y0StartTimeMs * msToSamples
        let y0EndSample = y0EndTimeMs * msToSamples
        let crStartSample = crStartTimeMs * msToSamples
        let crEndSample = crEndTimeMs * msToSamples
        let cbStartSample = cbStartTimeMs * msToSamples
        let cbEndSample = cbEndTimeMs * msToSamples
        let y1StartSample = y1StartTimeMs * msToSamples
        let y1EndSample = y1StartSample + (yDurationMs * msToSamples)
        
        // Decode all components using time-based continuous indexing
        // Each component spans from its start time to end time
        let y0Values = decodeComponentTimeBased(
            frequencies: frequencies,
            startSample: y0StartSample,
            endSample: y0EndSample,
            pixelCount: width
        )
        
        let crValues = decodeComponentTimeBased(
            frequencies: frequencies,
            startSample: crStartSample,
            endSample: crEndSample,
            pixelCount: width
        )
        
        let cbValues = decodeComponentTimeBased(
            frequencies: frequencies,
            startSample: cbStartSample,
            endSample: cbEndSample,
            pixelCount: width
        )
        
        let y1Values = decodeComponentTimeBased(
            frequencies: frequencies,
            startSample: y1StartSample,
            endSample: y1EndSample,
            pixelCount: width
        )
        
        // Convert to RGB for both lines
        var line0 = [Double](repeating: 0.0, count: width * 3)
        var line1 = [Double](repeating: 0.0, count: width * 3)
        
        for i in 0..<width {
            // Line 0 (even) uses Y0
            let (r0, g0, b0) = ycbcrToRGB(
                y: y0Values[i],
                cb: cbValues[i],
                cr: crValues[i]
            )
            line0[i * 3] = r0
            line0[i * 3 + 1] = g0
            line0[i * 3 + 2] = b0
            
            // Line 1 (odd) uses Y1
            let (r1, g1, b1) = ycbcrToRGB(
                y: y1Values[i],
                cb: cbValues[i],
                cr: crValues[i]
            )
            line1[i * 3] = r1
            line1[i * 3 + 1] = g1
            line1[i * 3 + 2] = b1
        }
        
        // Return lines in transmission order
        // Frame decodes: line0 from Y0, line1 from Y1
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
    ///   - pixelCount: Number of pixels to decode (typically 640)
    ///
    /// - Returns: Array of normalized pixel values (0.0...1.0), length = pixelCount
    private func decodeComponentTimeBased(
        frequencies: [Double],
        startSample: Double,
        endSample: Double,
        pixelCount: Int
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
            values[pixelIndex] = frequencyToValue(interpolatedFreq)
        }
        
        return values
    }
    
    /// Convert a detected frequency to a normalized pixel value.
    ///
    /// Maps the frequency range [blackFrequencyHz...whiteFrequencyHz]
    /// to the output range [0.0...1.0].
    ///
    /// - Parameter frequency: Detected frequency in Hz
    /// - Returns: Normalized pixel value (0.0...1.0), clamped
    private func frequencyToValue(_ frequency: Double) -> Double {
        // Map frequency linearly from [black...white] to [0.0...1.0]
        let normalized = (frequency - blackFrequencyHz) / frequencyRangeHz
        
        // Clamp to valid range
        return min(max(normalized, 0.0), 1.0)
    }
    
    /// Convert YCbCr color values to RGB.
    ///
    /// Uses ITU-R BT.601 conversion matrix commonly used in SSTV.
    ///
    /// - Parameters:
    ///   - y: Luminance (0.0...1.0)
    ///   - cb: Blue chrominance (0.0...1.0)
    ///   - cr: Red chrominance (0.0...1.0)
    ///
    /// - Returns: RGB tuple, each component in range (0.0...1.0), clamped
    private func ycbcrToRGB(y: Double, cb: Double, cr: Double) -> (r: Double, g: Double, b: Double) {
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
