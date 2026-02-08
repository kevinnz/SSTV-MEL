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
/// Maximum allowed: ±50.0 ms (approximately half a line width).
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
/// Maximum allowed: ±1.0 ms/line (prevents extreme distortion).
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

    // MARK: - Limits

    /// Maximum allowed phase offset in milliseconds (±50ms, ~half a line)
    public static let maxPhaseOffsetMs: Double = 50.0

    /// Maximum allowed skew in milliseconds per line (±1.0ms/line)
    public static let maxSkewMsPerLine: Double = 1.0

    /// Default sync recovery threshold (as a fraction of total image lines)
    ///
    /// When sync is lost during decoding, the decoder will attempt recovery if
    /// less than this fraction of lines have been decoded; otherwise it will
    /// emit an error with a partial image.
    ///
    /// Default: 0.5 (50% - recover if sync lost in first half, error in second half)
    public static let defaultSyncRecoveryThreshold: Double = 0.5

    // MARK: - Phase Adjustment

    /// Horizontal phase offset in milliseconds.
    ///
    /// Shifts the entire image horizontally to correct for sync timing errors.
    /// - Positive values: Shift image content to the right (sample later)
    /// - Negative values: Shift image content to the left (sample earlier)
    /// - Default: 0.0 (no adjustment)
    /// - Typical range: -5.0 to +5.0 ms
    /// - Hard limit: ±50.0 ms
    public var phaseOffsetMs: Double {
        didSet {
            phaseOffsetMs = Self.clampPhase(phaseOffsetMs)
        }
    }

    // MARK: - Skew Adjustment

    /// Skew correction in milliseconds per line.
    ///
    /// Compensates for timing drift that accumulates over the image height,
    /// causing vertical lines to appear slanted.
    /// - Positive values: Correct clockwise slant (lines drift right going down)
    /// - Negative values: Correct counter-clockwise slant (lines drift left going down)
    /// - Default: 0.0 (no adjustment)
    /// - Typical range: -0.5 to +0.5 ms/line
    /// - Hard limit: ±1.0 ms/line
    ///
    /// The total adjustment for line N is: `phaseOffsetMs + (N * skewMsPerLine)`
    public var skewMsPerLine: Double {
        didSet {
            skewMsPerLine = Self.clampSkew(skewMsPerLine)
        }
    }

    // MARK: - Sync Recovery

    /// Sync recovery threshold (fraction of total image lines).
    ///
    /// When sync is lost during decoding, the decoder will:
    /// - Attempt to recover sync if `linesDecoded < totalLines * syncRecoveryThreshold`
    /// - Emit an error with partial image otherwise
    ///
    /// Range: 0.0 (never recover) to 1.0 (always try to recover)
    /// Default: 0.5 (50% - recover if lost in first half)
    ///
    /// Setting to 1.0 means always attempt recovery; 0.0 means always fail on sync loss.
    public var syncRecoveryThreshold: Double {
        didSet {
            syncRecoveryThreshold = min(max(syncRecoveryThreshold, 0.0), 1.0)
        }
    }

    // MARK: - Clamping Helpers

    /// Clamp phase offset to valid range
    private static func clampPhase(_ value: Double) -> Double {
        return min(max(value, -maxPhaseOffsetMs), maxPhaseOffsetMs)
    }

    /// Clamp skew to valid range
    private static func clampSkew(_ value: Double) -> Double {
        return min(max(value, -maxSkewMsPerLine), maxSkewMsPerLine)
    }

    // MARK: - Initialization

    /// Create decoding options with specified adjustments.
    ///
    /// Values are automatically clamped to valid ranges:
    /// - Phase: ±50.0 ms
    /// - Skew: ±1.0 ms/line
    ///
    /// - Parameters:
    ///   - phaseOffsetMs: Horizontal phase offset in milliseconds (default: 0.0)
    ///   - skewMsPerLine: Skew correction in milliseconds per line (default: 0.0)
    ///   - syncRecoveryThreshold: Sync recovery threshold as fraction (default: 0.5)
    public init(
        phaseOffsetMs: Double = 0.0,
        skewMsPerLine: Double = 0.0,
        syncRecoveryThreshold: Double = Self.defaultSyncRecoveryThreshold
    ) {
        self.phaseOffsetMs = phaseOffsetMs
        self.skewMsPerLine = skewMsPerLine
        self.syncRecoveryThreshold = min(max(syncRecoveryThreshold, 0.0), 1.0)
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
