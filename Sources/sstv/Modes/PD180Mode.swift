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
    /// Measured from actual signal: 260 steps × 128 samples / 44100 Hz ≈ 754.65ms
    /// Original calculation: 187 seconds / 248 frames = 754.03ms
    let frameDurationMs: Double = 754.65
    
    /// Duration of sync pulse at start of each frame (in ms)
    let syncPulseMs: Double = 20.0
    
    /// Duration of porch after sync pulse (in ms)
    /// Fine-tuned for horizontal alignment (original spec: 2.08ms)
    let porchMs: Double = 0.50
    
    /// Duration of each Y component (in ms) - one per image line
    /// Adjusted to match total frame duration
    let yDurationMs: Double = 183.14
    
    /// Duration of Cb (B-Y, blue chrominance) component (in ms)
    let cbDurationMs: Double = 183.14
    
    /// Duration of Cr (R-Y, red chrominance) component (in ms)
    let crDurationMs: Double = 183.14
    
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
    
    /// Decode a PD180 frame from frequency data.
    ///
    /// PD180 transmits TWO image lines per frame with the structure:
    /// - Sync pulse: 20ms @ 1200 Hz
    /// - Porch: 2.08ms @ 1500 Hz
    /// - Y0 (even line luminance): 183.04ms
    /// - R-Y (Cr chrominance, shared): 183.04ms
    /// - B-Y (Cb chrominance, shared): 183.04ms
    /// - Y1 (odd line luminance): 183.04ms
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
        // Calculate sample counts for each component
        let samplesPerMs = sampleRate / 1000.0
        
        let syncSamples = Int(syncPulseMs * samplesPerMs)
        let porchSamples = Int(porchMs * samplesPerMs)
        let ySamples = Int(yDurationMs * samplesPerMs)
        let crSamples = Int(crDurationMs * samplesPerMs)
        let cbSamples = Int(cbDurationMs * samplesPerMs)
        
        // Calculate starting indices for each component
        // Frame structure: Sync, Porch, Y0, Cr, Cb, Y1
        let y0StartIndex = syncSamples + porchSamples
        let crStartIndex = y0StartIndex + ySamples
        let cbStartIndex = crStartIndex + crSamples
        let y1StartIndex = cbStartIndex + cbSamples
        
        // Decode all components
        let y0Values = decodeComponent(
            frequencies: frequencies,
            startIndex: y0StartIndex,
            sampleCount: ySamples,
            pixelCount: width
        )
        
        let crValues = decodeComponent(
            frequencies: frequencies,
            startIndex: crStartIndex,
            sampleCount: crSamples,
            pixelCount: width
        )
        
        let cbValues = decodeComponent(
            frequencies: frequencies,
            startIndex: cbStartIndex,
            sampleCount: cbSamples,
            pixelCount: width
        )
        
        let y1Values = decodeComponent(
            frequencies: frequencies,
            startIndex: y1StartIndex,
            sampleCount: ySamples,
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
                values[pixelIndex] = 0.5 // Default to mid-value
                continue
            }
            
            // Average the frequencies in this pixel's sample range
            let pixelFrequencies = frequencies[sampleStart..<sampleEnd]
            guard !pixelFrequencies.isEmpty else {
                values[pixelIndex] = 0.5
                continue
            }
            
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
