/// PD120 SSTV Mode Implementation
///
/// PD120 is a color SSTV mode with the following characteristics:
/// - Resolution: 640 × 496 pixels
/// - Color encoding: YCbCr (luminance, then chrominance)
/// - Line structure: Y (luminance), Cb, Cr components transmitted sequentially
/// - Frequency range: 1500 Hz (black) to 2300 Hz (white)
///
/// References:
/// - SSTV specification documents
/// - Common amateur radio SSTV implementations
struct PD120Mode: SSTVMode {
    
    // MARK: - Mode Identification
    
    /// VIS code for PD120 mode
    let visCode: UInt8 = 0x63 // 99 in decimal
    
    /// Human-readable name
    let name: String = "PD120"
    
    // MARK: - Image Dimensions
    
    /// Image width in pixels
    let width: Int = 640
    
    /// Image height in pixels (number of lines)
    let height: Int = 496
    
    // MARK: - Timing Constants (in milliseconds)
    
    /// Total duration of one complete line (all components)
    let lineDurationMs: Double = 126.432
    
    /// Duration of sync pulse at start of each line (in ms)
    let syncPulseMs: Double = 20.0
    
    /// Duration of porch after sync pulse (in ms)
    let porchMs: Double = 2.08
    
    /// Duration of Y (luminance) component (in ms)
    let yDurationMs: Double = 66.0
    
    /// Duration of Cb (blue chrominance) component (in ms)
    let cbDurationMs: Double = 66.0
    
    /// Duration of Cr (red chrominance) component (in ms)
    let crDurationMs: Double = 66.0
    
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

// MARK: - Line Decoding

extension PD120Mode {
    
    /// Decode a single PD120 line from frequency data.
    ///
    /// This function takes a time-aligned sequence of detected frequencies
    /// and decodes them into pixel values for one complete image line.
    ///
    /// The line structure is:
    /// 1. Sync pulse (ignored here, handled upstream)
    /// 2. Porch (ignored)
    /// 3. Y (luminance) - 640 pixels
    /// 4. Cb (blue chrominance) - 640 pixels (horizontally subsampled conceptually, but transmitted at full width)
    /// 5. Cr (red chrominance) - 640 pixels (horizontally subsampled conceptually, but transmitted at full width)
    ///
    /// - Parameters:
    ///   - frequencies: Array of detected frequencies in Hz, time-aligned to line start
    ///   - sampleRate: Audio sample rate in Hz
    ///   - lineIndex: Index of the line being decoded (0-based)
    ///
    /// - Returns: Array of pixel values as RGB triplets (0.0...1.0), length = width * 3
    ///
    /// - Note: Caller must ensure frequencies array covers the entire line duration
    func decodeLine(
        frequencies: [Double],
        sampleRate: Double,
        lineIndex: Int
    ) -> [Double] {
        // Calculate sample counts for each component
        let samplesPerMs = sampleRate / 1000.0
        
        let syncSamples = Int(syncPulseMs * samplesPerMs)
        let porchSamples = Int(porchMs * samplesPerMs)
        let ySamples = Int(yDurationMs * samplesPerMs)
        let cbSamples = Int(cbDurationMs * samplesPerMs)
        let crSamples = Int(crDurationMs * samplesPerMs)
        
        // Calculate starting indices for each component
        let yStartIndex = syncSamples + porchSamples
        let cbStartIndex = yStartIndex + ySamples
        let crStartIndex = cbStartIndex + cbSamples
        
        // Preallocate output buffer (RGB triplets)
        var pixels = [Double](repeating: 0.0, count: width * 3)
        
        // Decode Y (luminance) component
        let yValues = decodeComponent(
            frequencies: frequencies,
            startIndex: yStartIndex,
            sampleCount: ySamples,
            pixelCount: width
        )
        
        // Decode Cb (blue chrominance) component
        let cbValues = decodeComponent(
            frequencies: frequencies,
            startIndex: cbStartIndex,
            sampleCount: cbSamples,
            pixelCount: width
        )
        
        // Decode Cr (red chrominance) component
        let crValues = decodeComponent(
            frequencies: frequencies,
            startIndex: crStartIndex,
            sampleCount: crSamples,
            pixelCount: width
        )
        
        // Convert YCbCr to RGB and store in pixel buffer
        for i in 0..<width {
            let (r, g, b) = ycbcrToRGB(
                y: yValues[i],
                cb: cbValues[i],
                cr: crValues[i]
            )
            
            pixels[i * 3] = r
            pixels[i * 3 + 1] = g
            pixels[i * 3 + 2] = b
        }
        
        return pixels
    }
    
    /// Decode a single component (Y, Cb, or Cr) from frequency data.
    ///
    /// Maps frequencies to normalized pixel values (0.0...1.0).
    ///
    /// - Parameters:
    ///   - frequencies: Full array of detected frequencies for the entire line
    ///   - startIndex: Index in frequencies array where this component starts
    ///   - sampleCount: Number of samples covering this component
    ///   - pixelCount: Number of pixels to decode (typically 640)
    ///
    /// - Returns: Array of normalized pixel values (0.0...1.0), length = pixelCount
    private func decodeComponent(
        frequencies: [Double],
        startIndex: Int,
        sampleCount: Int,
        pixelCount: Int
    ) -> [Double] {
        var values = [Double](repeating: 0.0, count: pixelCount)
        
        // Calculate how many samples per pixel
        let samplesPerPixel = Double(sampleCount) / Double(pixelCount)
        
        for pixelIndex in 0..<pixelCount {
            // Calculate sample range for this pixel
            let sampleStart = startIndex + Int(Double(pixelIndex) * samplesPerPixel)
            let sampleEnd = startIndex + Int(Double(pixelIndex + 1) * samplesPerPixel)
            
            // Ensure we don't go out of bounds
            guard sampleStart < frequencies.count && sampleEnd <= frequencies.count else {
                values[pixelIndex] = 0.0
                continue
            }
            
            // Average the frequencies in this pixel's sample range
            let pixelFrequencies = frequencies[sampleStart..<sampleEnd]
            let avgFrequency = pixelFrequencies.reduce(0.0, +) / Double(pixelFrequencies.count)
            
            // Map frequency to normalized value (0.0...1.0)
            values[pixelIndex] = frequencyToValue(avgFrequency)
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
