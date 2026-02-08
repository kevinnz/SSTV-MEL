import Foundation

/// Progress information during SSTV decoding
public struct DecodingProgress {
    /// Current decoding phase
    public enum Phase {
        case visDetection(progress: Double)
        case fmDemodulation(progress: Double)
        case signalSearch
        case frameDecoding(linesDecoded: Int, totalLines: Int)
        case writing

        /// User-friendly description of the phase
        public var description: String {
            switch self {
            case .visDetection(let progress):
                return "Detecting VIS code (\(Int(progress * 100))%)"
            case .fmDemodulation(let progress):
                return "Demodulating FM signal (\(Int(progress * 100))%)"
            case .signalSearch:
                return "Searching for SSTV signal start"
            case .frameDecoding(let linesDecoded, let totalLines):
                return "Decoding frames (\(linesDecoded)/\(totalLines) lines)"
            case .writing:
                return "Writing output file"
            }
        }
    }

    /// Current decoding phase
    public let phase: Phase

    /// Overall progress (0.0...1.0)
    public let overallProgress: Double

    /// Elapsed time since decoding started
    public let elapsedSeconds: Double

    /// Estimated time remaining (nil if unknown)
    public let estimatedSecondsRemaining: Double?

    /// Detected mode name (nil if not yet detected)
    public let modeName: String?

    /// Percentage complete (0...100)
    public var percentComplete: Double {
        overallProgress * 100
    }

    /// Create a progress update
    ///
    /// - Parameters:
    ///   - phase: Current decoding phase
    ///   - overallProgress: Overall progress (0.0...1.0)
    ///   - elapsedSeconds: Elapsed time since start
    ///   - estimatedSecondsRemaining: Estimated time remaining
    ///   - modeName: Detected mode name
    public init(
        phase: Phase,
        overallProgress: Double,
        elapsedSeconds: Double,
        estimatedSecondsRemaining: Double? = nil,
        modeName: String? = nil
    ) {
        self.phase = phase
        self.overallProgress = overallProgress
        self.elapsedSeconds = elapsedSeconds
        self.estimatedSecondsRemaining = estimatedSecondsRemaining
        self.modeName = modeName
    }
}

/// Callback for progress updates during decoding
///
/// This allows UI applications to update progress indicators in real-time.
/// The callback is called on the same thread as the decode operation.
///
/// Example usage:
/// ```swift
/// let decoder = SSTVDecoder()
/// let buffer = try decoder.decode(audio: audio) { progress in
///     DispatchQueue.main.async {
///         progressBar.doubleValue = progress.percentComplete
///         statusLabel.stringValue = progress.phase.description
///     }
/// }
/// ```
public typealias ProgressHandler = (DecodingProgress) -> Void
