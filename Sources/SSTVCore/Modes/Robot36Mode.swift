/// ROBOT36 SSTV Mode Implementation
///
/// ROBOT36 is a color SSTV mode with the following characteristics:
/// - Resolution: 320 × 240 pixels
/// - Color encoding: YCbCr 4:2:0 (Y for every line, chrominance shared across pairs)
/// - Transmits TWO image lines per logical frame (even line with R-Y, odd line with B-Y)
/// - Frequency range: 1500 Hz (black) to 2300 Hz (white)
/// - VIS code: 8 (0x08)
/// - Total duration: ~36 seconds
///
/// Frame structure (for 2 image lines):
/// Even line:
/// - Sync pulse: 9.0ms @ 1200 Hz
/// - Sync porch: 3.0ms @ 1500 Hz
/// - Y scan: 88.0ms (luminance)
/// - Separator (R-Y): 4.5ms @ 1500 Hz
/// - Chroma porch: 1.5ms @ 1900 Hz
/// - R-Y scan: 44.0ms (red chrominance)
///
/// Odd line:
/// - Sync pulse: 9.0ms @ 1200 Hz
/// - Sync porch: 3.0ms @ 1500 Hz
/// - Y scan: 88.0ms (luminance)
/// - Separator (B-Y): 4.5ms @ 1500 Hz
/// - Chroma porch: 1.5ms @ 1900 Hz
/// - B-Y scan: 44.0ms (blue chrominance)
///
/// Total frame duration: 2 × 150.0ms = 300.0ms
///
/// References:
/// - SSTV Handbook
/// - JL Barber N7CXI SSTV specification
struct Robot36Mode: SSTVMode {
    
    // MARK: - Mode Identification
    
    /// VIS code for Robot36 mode (8 decimal = 0x08)
    let visCode: UInt8 = 0x08
    
    /// Human-readable name
    let name: String = "Robot36"
    
    // MARK: - Image Dimensions
    
    /// Image width in pixels
    let width: Int = 320
    
    /// Image height in pixels (number of lines)
    let height: Int = 240
    
    // MARK: - Timing Constants (in milliseconds)
    
    /// Number of image lines per transmission frame
    /// Robot36 transmits one even line (Y + R-Y) and one odd line (Y + B-Y) per frame
    let linesPerFrame: Int = 2
    
    /// Duration of one line (sync + porch + Y + separator + chroma porch + chroma)
    /// 9.0 + 3.0 + 88.0 + 4.5 + 1.5 + 44.0 = 150.0ms
    let lineDurationMs: Double = 150.0
    
    /// Total duration of one transmission frame (contains 2 image lines)
    /// 150.0ms × 2 = 300.0ms
    var frameDurationMs: Double { lineDurationMs * Double(linesPerFrame) }
    
    /// Duration of sync pulse at start of each line (in ms)
    let syncPulseMs: Double = 9.0
    
    /// Duration of sync porch after sync pulse (in ms)
    let syncPorchMs: Double = 3.0
    
    /// Duration of Y (luminance) scan (in ms)
    let yDurationMs: Double = 88.0
    
    /// Duration of separator before chrominance (in ms)
    let separatorMs: Double = 4.5
    
    /// Duration of chroma porch (in ms)
    let chromaPorchMs: Double = 1.5
    
    /// Duration of chrominance scan (R-Y or B-Y) (in ms)
    let chromaDurationMs: Double = 44.0
    
    // MARK: - Frequency Constants (in Hz)
    
    /// Sync pulse frequency (in Hz)
    let syncFrequencyHz: Double = 1200.0
    
    /// Black level frequency (in Hz)
    let blackFrequencyHz: Double = 1500.0
    
    /// White level frequency (in Hz)
    let whiteFrequencyHz: Double = 2300.0
    
    /// Chrominance zero reference frequency (in Hz)
    /// This is the neutral point for chrominance encoding
    let chromaZeroFrequencyHz: Double = 1900.0
    
    // MARK: - Derived Values
    
    /// Frequency range for pixel values (white - black)
    var frequencyRangeHz: Double {
        whiteFrequencyHz - blackFrequencyHz
    }
}

// MARK: - Frame Decoding

extension Robot36Mode {
    
    /// Decode a Robot36 frame from frequency data using TIME-BASED decoding.
    ///
    /// Robot36 transmits TWO image lines per frame:
    /// - Even line: Sync + Porch + Y + Separator + ChromaPorch + R-Y
    /// - Odd line: Sync + Porch + Y + Separator + ChromaPorch + B-Y
    ///
    /// The chrominance components are shared between the two lines in a 4:2:0 pattern:
    /// - R-Y from the even line applies to both lines
    /// - B-Y from the odd line applies to both lines
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
    ///   - options: Decoding options for phase and skew adjustment
    ///
    /// - Returns: Array of 2 pixel rows, each containing RGB triplets (width * 3)
    func decodeFrame(
        frequencies: [Double],
        sampleRate: Double,
        frameIndex: Int,
        options: DecodingOptions = .default
    ) -> [[Double]] {
        let samplesPerSecond = sampleRate
        let msToSamples = samplesPerSecond / 1000.0
        
        // Calculate phase/skew offset for each line in this frame
        // Frame contains 2 lines: even line (frameIndex * 2) and odd line (frameIndex * 2 + 1)
        let line0Index = frameIndex * linesPerFrame
        let line1Index = line0Index + 1
        
        // Get sample offsets for each line (phase + accumulated skew)
        let line0SampleOffset = options.sampleOffset(forLine: line0Index, sampleRate: sampleRate)
        let line1SampleOffset = options.sampleOffset(forLine: line1Index, sampleRate: sampleRate)
        
        // For shared chrominance, use average of the two line offsets
        let chromaSampleOffset = (line0SampleOffset + line1SampleOffset) / 2.0
        
        // ==========================================================
        // EVEN LINE (line 0): Sync + Porch + Y0 + Sep + ChromaPorch + R-Y
        // ==========================================================
        let evenLineStartMs = 0.0
        let evenSyncEndMs = evenLineStartMs + syncPulseMs
        let evenPorchEndMs = evenSyncEndMs + syncPorchMs
        let evenY0StartMs = evenPorchEndMs
        let evenY0EndMs = evenY0StartMs + yDurationMs
        let evenSeparatorEndMs = evenY0EndMs + separatorMs
        let evenChromaPorchEndMs = evenSeparatorEndMs + chromaPorchMs
        let evenCrStartMs = evenChromaPorchEndMs  // R-Y (Cr)
        let evenCrEndMs = evenCrStartMs + chromaDurationMs
        
        // ==========================================================
        // ODD LINE (line 1): Sync + Porch + Y1 + Sep + ChromaPorch + B-Y
        // ==========================================================
        let oddLineStartMs = lineDurationMs  // Starts after even line
        let oddSyncEndMs = oddLineStartMs + syncPulseMs
        let oddPorchEndMs = oddSyncEndMs + syncPorchMs
        let oddY1StartMs = oddPorchEndMs
        let oddY1EndMs = oddY1StartMs + yDurationMs
        let oddSeparatorEndMs = oddY1EndMs + separatorMs
        let oddChromaPorchEndMs = oddSeparatorEndMs + chromaPorchMs
        let oddCbStartMs = oddChromaPorchEndMs  // B-Y (Cb)
        let oddCbEndMs = oddCbStartMs + chromaDurationMs
        
        // Convert to sample positions with line-specific offsets
        // Y0 (even line luminance)
        let y0StartSample = evenY0StartMs * msToSamples + line0SampleOffset
        let y0EndSample = evenY0EndMs * msToSamples + line0SampleOffset
        
        // Cr (R-Y) from even line - uses averaged chroma offset
        let crStartSample = evenCrStartMs * msToSamples + chromaSampleOffset
        let crEndSample = evenCrEndMs * msToSamples + chromaSampleOffset
        
        // Y1 (odd line luminance)
        let y1StartSample = oddY1StartMs * msToSamples + line1SampleOffset
        let y1EndSample = oddY1EndMs * msToSamples + line1SampleOffset
        
        // Cb (B-Y) from odd line - uses averaged chroma offset
        let cbStartSample = oddCbStartMs * msToSamples + chromaSampleOffset
        let cbEndSample = oddCbEndMs * msToSamples + chromaSampleOffset
        
        // Decode all components
        let y0Values = decodeComponentTimeBased(
            frequencies: frequencies,
            startSample: y0StartSample,
            endSample: y0EndSample,
            pixelCount: width
        )
        
        let y1Values = decodeComponentTimeBased(
            frequencies: frequencies,
            startSample: y1StartSample,
            endSample: y1EndSample,
            pixelCount: width
        )
        
        let crValues = decodeChromaComponentTimeBased(
            frequencies: frequencies,
            startSample: crStartSample,
            endSample: crEndSample,
            pixelCount: width
        )
        
        let cbValues = decodeChromaComponentTimeBased(
            frequencies: frequencies,
            startSample: cbStartSample,
            endSample: cbEndSample,
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
        
        // Return lines in order: even, odd
        return [line0, line1]
    }
    
    /// Legacy single-line decode for compatibility
    /// For Robot36, use decodeFrame() instead
    func decodeLine(
        frequencies: [Double],
        sampleRate: Double,
        lineIndex: Int
    ) -> [Double] {
        let frame = decodeFrame(
            frequencies: frequencies,
            sampleRate: sampleRate,
            frameIndex: lineIndex / 2
        )
        return lineIndex % 2 == 0 ? frame[0] : frame[1]
    }
    
    /// Decode a luminance component (Y) using TIME-BASED fractional sample indexing.
    ///
    /// Maps frequency range [blackFrequencyHz...whiteFrequencyHz] to [0.0...1.0]
    ///
    /// - Parameters:
    ///   - frequencies: Full array of detected frequencies for the entire frame
    ///   - startSample: Fractional sample index where this component starts
    ///   - endSample: Fractional sample index where this component ends
    ///   - pixelCount: Number of pixels to decode (typically 320)
    ///
    /// - Returns: Array of normalized pixel values (0.0...1.0), length = pixelCount
    private func decodeComponentTimeBased(
        frequencies: [Double],
        startSample: Double,
        endSample: Double,
        pixelCount: Int
    ) -> [Double] {
        var values = [Double](repeating: 0.0, count: pixelCount)
        
        let componentDurationSamples = endSample - startSample
        let samplesPerPixel = componentDurationSamples / Double(pixelCount)
        
        for pixelIndex in 0..<pixelCount {
            // Calculate the EXACT fractional sample position for this pixel's CENTER
            let pixelCenterPosition = startSample + (Double(pixelIndex) + 0.5) * samplesPerPixel
            
            // Clamp position strictly within the frequency array bounds
            let clampedPosition = min(max(pixelCenterPosition, 0.0), Double(frequencies.count - 1))
            
            // Perform linear interpolation between adjacent samples
            let lowerIndex = Int(clampedPosition)
            let upperIndex = min(lowerIndex + 1, frequencies.count - 1)
            let fraction = clampedPosition - Double(lowerIndex)
            
            // Bounds check
            guard lowerIndex >= 0 && lowerIndex < frequencies.count &&
                  upperIndex >= 0 && upperIndex < frequencies.count else {
                values[pixelIndex] = 0.5
                continue
            }
            
            // Linear interpolation
            let lowerFreq = frequencies[lowerIndex]
            let upperFreq = frequencies[upperIndex]
            let interpolatedFreq = lowerFreq * (1.0 - fraction) + upperFreq * fraction
            
            // Map frequency to luminance value
            values[pixelIndex] = frequencyToLuminance(interpolatedFreq)
        }
        
        return values
    }
    
    /// Decode a chrominance component (Cb or Cr) using TIME-BASED fractional sample indexing.
    ///
    /// Chrominance is centered around 1900 Hz (neutral), with the range [1500...2300] Hz
    /// mapping to [-0.5...+0.5] chrominance deviation, then offset to [0.0...1.0].
    ///
    /// - Parameters:
    ///   - frequencies: Full array of detected frequencies for the entire frame
    ///   - startSample: Fractional sample index where this component starts
    ///   - endSample: Fractional sample index where this component ends
    ///   - pixelCount: Number of pixels to decode (typically 320)
    ///
    /// - Returns: Array of normalized chrominance values (0.0...1.0), length = pixelCount
    private func decodeChromaComponentTimeBased(
        frequencies: [Double],
        startSample: Double,
        endSample: Double,
        pixelCount: Int
    ) -> [Double] {
        var values = [Double](repeating: 0.5, count: pixelCount)
        
        let componentDurationSamples = endSample - startSample
        let samplesPerPixel = componentDurationSamples / Double(pixelCount)
        
        for pixelIndex in 0..<pixelCount {
            let pixelCenterPosition = startSample + (Double(pixelIndex) + 0.5) * samplesPerPixel
            let clampedPosition = min(max(pixelCenterPosition, 0.0), Double(frequencies.count - 1))
            
            let lowerIndex = Int(clampedPosition)
            let upperIndex = min(lowerIndex + 1, frequencies.count - 1)
            let fraction = clampedPosition - Double(lowerIndex)
            
            guard lowerIndex >= 0 && lowerIndex < frequencies.count &&
                  upperIndex >= 0 && upperIndex < frequencies.count else {
                values[pixelIndex] = 0.5
                continue
            }
            
            let lowerFreq = frequencies[lowerIndex]
            let upperFreq = frequencies[upperIndex]
            let interpolatedFreq = lowerFreq * (1.0 - fraction) + upperFreq * fraction
            
            // Map frequency to chrominance value
            values[pixelIndex] = frequencyToChroma(interpolatedFreq)
        }
        
        return values
    }
    
    /// Convert a detected frequency to a normalized luminance value.
    ///
    /// Maps the frequency range [blackFrequencyHz...whiteFrequencyHz]
    /// to the output range [0.0...1.0].
    ///
    /// - Parameter frequency: Detected frequency in Hz
    /// - Returns: Normalized luminance value (0.0...1.0), clamped
    internal func frequencyToLuminance(_ frequency: Double) -> Double {
        let normalized = (frequency - blackFrequencyHz) / frequencyRangeHz
        return min(max(normalized, 0.0), 1.0)
    }
    
    /// Convert a detected frequency to a normalized chrominance value.
    ///
    /// Robot36 uses chromaZeroFrequencyHz (1900 Hz) as the zero reference for chrominance.
    /// The range [1500...2300] Hz maps to [0.0...1.0] for compatibility
    /// with the YCbCr conversion that expects values centered at 0.5.
    ///
    /// The neutral point chromaZeroFrequencyHz maps to 0.5, calculated as:
    /// (chromaZeroFrequencyHz - blackFrequencyHz) / frequencyRangeHz = (1900 - 1500) / 800 = 0.5
    ///
    /// - Parameter frequency: Detected frequency in Hz
    /// - Returns: Normalized chrominance value (0.0...1.0), clamped
    internal func frequencyToChroma(_ frequency: Double) -> Double {
        // Map [1500...2300] to [0.0...1.0]
        // This places chromaZeroFrequencyHz (1900 Hz) at 0.5 (neutral chrominance)
        let normalized = (frequency - blackFrequencyHz) / frequencyRangeHz
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
    internal func ycbcrToRGB(y: Double, cb: Double, cr: Double) -> (r: Double, g: Double, b: Double) {
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
