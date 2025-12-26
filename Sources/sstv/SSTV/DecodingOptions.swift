/// Decoding options for SSTV image adjustment
///
/// These options allow fine-tuning of the decoded image to compensate for:
/// - **Phase offset**: Horizontal shift caused by timing drift or sync detection errors
/// - **Skew**: Gradual timing drift that causes the image to slant diagonally
///
/// ## Phase Adjustment
/// Phase adjustment shifts the entire image horizontally. This compensates for:
/// - Inaccurate sync pulse detection
/// - Fixed timing offsets in the transmitter
/// - Audio processing delays
///
/// Positive values shift the image right, negative values shift left.
/// The value is in milliseconds (typical range: -5.0 to +5.0 ms).
///
/// ## Skew Adjustment
/// Skew adjustment compensates for timing drift between transmitter and receiver.
/// This manifests as a diagonal slant in the image - vertical lines appear tilted.
///
/// The skew value represents the cumulative timing error per line in milliseconds.
/// Common causes:
/// - Sample rate mismatch between transmitter and receiver
/// - Crystal oscillator drift
/// - Resampling artifacts in audio processing
///
/// Positive values correct for clockwise slant, negative for counter-clockwise.
/// The value is in milliseconds per line (typical range: -0.5 to +0.5 ms/line).
///
/// ## Usage Example
/// ```swift
/// // Create options with phase and skew correction
/// let options = DecodingOptions(
///     phaseOffsetMs: 1.5,    // Shift image 1.5ms to the right
///     skewMsPerLine: 0.02    // Compensate for 0.02ms drift per line
/// )
///
/// // Decode with options
/// let buffer = try decoder.decode(audio: audio, options: options)
/// ```
public struct DecodingOptions {
    
    // MARK: - Phase Adjustment
    
    /// Horizontal phase offset in milliseconds.
    ///
    /// Shifts the entire image horizontally to correct for sync timing errors.
    /// - Positive values: Shift image content to the right (sample later)
    /// - Negative values: Shift image content to the left (sample earlier)
    /// - Default: 0.0 (no adjustment)
    /// - Typical range: -5.0 to +5.0 ms
    public var phaseOffsetMs: Double
    
    // MARK: - Skew Adjustment
    
    /// Skew correction in milliseconds per line.
    ///
    /// Compensates for timing drift that accumulates over the image height,
    /// causing vertical lines to appear slanted.
    /// - Positive values: Correct clockwise slant (lines drift right going down)
    /// - Negative values: Correct counter-clockwise slant (lines drift left going down)
    /// - Default: 0.0 (no adjustment)
    /// - Typical range: -0.5 to +0.5 ms/line
    ///
    /// The total adjustment for line N is: `phaseOffsetMs + (N * skewMsPerLine)`
    public var skewMsPerLine: Double
    
    // MARK: - Debug Options
    
    /// Enable debug output during decoding
    public var debug: Bool
    
    // MARK: - Initialization
    
    /// Create decoding options with specified adjustments.
    ///
    /// - Parameters:
    ///   - phaseOffsetMs: Horizontal phase offset in milliseconds (default: 0.0)
    ///   - skewMsPerLine: Skew correction in milliseconds per line (default: 0.0)
    ///   - debug: Enable debug output (default: false)
    public init(
        phaseOffsetMs: Double = 0.0,
        skewMsPerLine: Double = 0.0,
        debug: Bool = false
    ) {
        self.phaseOffsetMs = phaseOffsetMs
        self.skewMsPerLine = skewMsPerLine
        self.debug = debug
    }
    
    /// Default options with no adjustments
    public static let `default` = DecodingOptions()
    
    // MARK: - Computed Properties
    
    /// Calculate the total phase offset for a specific line.
    ///
    /// - Parameter lineIndex: The 0-based line index
    /// - Returns: Total phase offset in milliseconds for this line
    public func totalPhaseOffsetMs(forLine lineIndex: Int) -> Double {
        return phaseOffsetMs + (Double(lineIndex) * skewMsPerLine)
    }
    
    /// Convert phase offset to sample offset for a given sample rate.
    ///
    /// - Parameters:
    ///   - lineIndex: The 0-based line index
    ///   - sampleRate: Audio sample rate in Hz
    /// - Returns: Sample offset (can be fractional for sub-sample precision)
    public func sampleOffset(forLine lineIndex: Int, sampleRate: Double) -> Double {
        let msOffset = totalPhaseOffsetMs(forLine: lineIndex)
        return msOffset * sampleRate / 1000.0
    }
}

// MARK: - CustomStringConvertible

extension DecodingOptions: CustomStringConvertible {
    public var description: String {
        var parts: [String] = []
        
        if phaseOffsetMs != 0.0 {
            parts.append(String(format: "phase: %.2fms", phaseOffsetMs))
        }
        
        if skewMsPerLine != 0.0 {
            parts.append(String(format: "skew: %.4fms/line", skewMsPerLine))
        }
        
        if parts.isEmpty {
            return "DecodingOptions(default)"
        }
        
        return "DecodingOptions(\(parts.joined(separator: ", ")))"
    }
}
