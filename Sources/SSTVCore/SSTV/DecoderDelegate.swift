import Foundation

// MARK: - Decoder Delegate Protocol
//
// This protocol defines the events emitted by SSTVDecoderCore during decoding.
// The decoder operates independently of UI concerns - it simply emits events
// when significant decode milestones occur.
//
// Events are emitted synchronously on the same thread that calls processSamples().
// UI code should dispatch to main thread as needed.
//
// EVENT EMISSION POINTS:
// - Sync locked: When a valid sync pattern is detected
// - Sync lost: When sync is lost during decoding
// - Line decoded: After each complete line is written to the buffer
// - Progress updated: Periodically during decoding
// - Image complete: When all lines are decoded
// - State change: On any state machine transition
//
// Events are emitted IMMEDIATELY when they occur - no batching or delay.

/// Events emitted during SSTV decoding
///
/// Implement this protocol to receive real-time decode events.
/// All methods have default empty implementations, so you only need
/// to implement the events you care about.
///
/// ## Thread Safety
/// All delegate methods are called synchronously on the thread that
/// invokes `processSamples()`. If your delegate updates UI, dispatch
/// to the main thread:
/// ```swift
/// func didDecodeLine(lineNumber: Int, totalLines: Int) {
///     DispatchQueue.main.async {
///         self.updateProgressIndicator(line: lineNumber, total: totalLines)
///     }
/// }
/// ```
public protocol DecoderDelegate: AnyObject {
    
    // MARK: - Sync Events
    
    /// Called when the decoder locks onto a sync pattern
    ///
    /// This indicates the decoder has found a valid SSTV signal and is
    /// ready to begin decoding image data.
    ///
    /// - Parameter confidence: Confidence level of sync lock (0.0...1.0)
    ///   - 0.0-0.3: Low confidence, signal may be noisy
    ///   - 0.4-0.7: Medium confidence, acceptable signal quality
    ///   - 0.8-1.0: High confidence, strong sync pattern detected
    func didLockSync(confidence: Float)
    
    /// Called when the decoder loses sync
    ///
    /// This may happen due to:
    /// - Noise or interference in the signal
    /// - Signal dropout or fading
    /// - End of transmission
    /// - Misaligned sync detection
    ///
    /// The decoder may attempt to recover, or may transition to error state.
    func didLoseSync()
    
    // MARK: - VIS Code Events
    
    /// Called when VIS code detection begins
    ///
    /// The VIS (Vertical Interval Signaling) code is a header that
    /// identifies the SSTV mode being transmitted.
    func didBeginVISDetection()
    
    /// Called when a VIS code is successfully detected
    ///
    /// - Parameters:
    ///   - code: The detected VIS code value (0-255)
    ///   - mode: The SSTV mode name (e.g., "PD120", "PD180")
    func didDetectVISCode(_ code: UInt8, mode: String)
    
    /// Called when VIS code detection fails
    ///
    /// The decoder will fall back to the configured default mode.
    /// This is not necessarily an error - some signals may not include
    /// a VIS code, or it may be corrupted.
    func didFailVISDetection()
    
    // MARK: - Decoding Events
    
    /// Called when a complete image line has been decoded
    ///
    /// This is the primary event for progressive rendering. Each call
    /// indicates that the specified line is now available in the image buffer.
    ///
    /// - Parameters:
    ///   - lineNumber: The 0-based line index that was decoded
    ///   - totalLines: Total number of lines in the image
    func didDecodeLine(lineNumber: Int, totalLines: Int)
    
    /// Called periodically with overall decode progress
    ///
    /// This event is throttled to avoid overwhelming the UI with updates.
    /// For line-level granularity, use `didDecodeLine`.
    ///
    /// - Parameter progress: Progress value (0.0...1.0)
    func didUpdateProgress(_ progress: Float)
    
    /// Called when a complete image has been decoded
    ///
    /// The provided buffer contains the fully decoded image and can be
    /// used for display or saving.
    ///
    /// - Parameter imageBuffer: The completed image buffer
    func didCompleteImage(_ imageBuffer: ImageBuffer)
    
    // MARK: - State Events
    
    /// Called when the decoder state changes
    ///
    /// This provides visibility into the decoder's state machine for
    /// UI status indicators.
    ///
    /// - Parameter state: The new decoder state
    func didChangeState(_ state: DecoderState)
    
    /// Called when an error occurs during decoding
    ///
    /// Errors during decoding are non-fatal state transitions, not exceptions.
    /// The decoder may still have produced a partial image that can be used.
    ///
    /// - Parameter error: Description of the error
    func didEncounterError(_ error: DecoderError)
    
    // MARK: - Diagnostic Events (Optional)
    
    /// Called with diagnostic information during decoding
    ///
    /// This is intended for debugging and development. In production,
    /// this method can be left unimplemented.
    ///
    /// - Parameter info: Diagnostic information
    func didEmitDiagnostic(_ info: DiagnosticInfo)
}

// MARK: - Default Implementations
//
// All delegate methods are optional. Provide empty default implementations
// so consumers only need to implement the events they care about.

public extension DecoderDelegate {
    func didLockSync(confidence: Float) {}
    func didLoseSync() {}
    func didBeginVISDetection() {}
    func didDetectVISCode(_ code: UInt8, mode: String) {}
    func didFailVISDetection() {}
    func didDecodeLine(lineNumber: Int, totalLines: Int) {}
    func didUpdateProgress(_ progress: Float) {}
    func didCompleteImage(_ imageBuffer: ImageBuffer) {}
    func didChangeState(_ state: DecoderState) {}
    func didEncounterError(_ error: DecoderError) {}
    func didEmitDiagnostic(_ info: DiagnosticInfo) {}
}

// MARK: - Diagnostic Info
//
// Structured diagnostic information for debugging and development.

/// Diagnostic information emitted during decoding
///
/// This replaces printf-style logging with structured data that UI
/// code can choose to display or log as appropriate.
public struct DiagnosticInfo: Sendable {
    /// Severity level of the diagnostic
    public enum Level: Sendable {
        case debug
        case info
        case warning
        case error
    }
    
    /// Category of the diagnostic
    public enum Category: Sendable {
        case sync
        case demodulation
        case decoding
        case timing
        case general
    }
    
    /// Diagnostic severity
    public let level: Level
    
    /// Diagnostic category
    public let category: Category
    
    /// Human-readable message
    public let message: String
    
    /// Optional key-value data
    public let data: [String: String]
    
    /// Timestamp when diagnostic was created
    ///
    /// Note: The timestamp is for display and logging purposes only.
    /// DiagnosticInfo instances are not intended to be compared for equality
    /// or stored in sets/dictionaries. Each diagnostic emission creates a
    /// new instance with a unique timestamp.
    public let timestamp: Date
    
    public init(
        level: Level,
        category: Category,
        message: String,
        data: [String: String] = [:]
    ) {
        self.level = level
        self.category = category
        self.message = message
        self.data = data
        self.timestamp = Date()
    }
}

// MARK: - Decoder State
//
// Explicit state machine for decoder lifecycle.
// The decoder always exists in exactly one of these states.
//
// STATE TRANSITIONS (high-level):
//   idle → detectingVIS → searchingSync → syncLocked → decoding → complete
//                                       ↓              ↑           │
//                                (early) syncLost ─────┘           │
//                                       │                          │
//                                       └────────────→ error ◀─────┘
//
// Note: The syncLost → searchingSync transition only occurs on early sync loss
// (before half the image is decoded); otherwise syncLost transitions to error.
//
// The state machine is designed to support UI feedback at each phase.

/// Decoder state machine states
///
/// These states map directly to the decoder lifecycle phases:
/// - `idle`: Initial state, waiting for audio samples
/// - `detectingVIS`: Analyzing audio for VIS code to identify mode
/// - `searchingSync`: Looking for sync pulse pattern to begin decoding
/// - `syncLocked`: Successfully locked onto sync pattern, ready to decode
/// - `decoding`: Actively decoding image lines
/// - `syncLost`: Sync was lost during decoding (can recover or fail)
/// - `complete`: Image decode completed successfully
/// - `error`: Unrecoverable error occurred
public enum DecoderState: Equatable, Sendable {
    /// Decoder is idle, waiting for samples
    case idle
    
    /// Searching for VIS code to identify SSTV mode
    case detectingVIS
    
    /// Searching for sync pattern to begin image decode
    case searchingSync
    
    /// Successfully locked onto sync pattern
    case syncLocked(confidence: Float)
    
    /// Actively decoding image lines
    case decoding(line: Int, totalLines: Int)
    
    /// Sync was lost during decoding
    /// Contains the line number where sync was lost
    case syncLost(atLine: Int)
    
    /// Image decode complete
    case complete
    
    /// Decoder encountered an unrecoverable error
    case error(DecoderError)
    
    /// Human-readable description of the current state
    public var description: String {
        switch self {
        case .idle:
            return "Idle"
        case .detectingVIS:
            return "Detecting VIS code"
        case .searchingSync:
            return "Searching for sync"
        case .syncLocked(let confidence):
            return "Sync locked (\(Int(confidence * 100))%)"
        case .decoding(let line, let total):
            return "Decoding line \(line + 1)/\(total)"
        case .syncLost(let line):
            return "Sync lost at line \(line)"
        case .complete:
            return "Complete"
        case .error(let error):
            return "Error: \(error.description)"
        }
    }
    
    /// Whether the decoder is in an active (non-terminal) state
    public var isActive: Bool {
        switch self {
        case .idle, .complete, .error:
            return false
        case .detectingVIS, .searchingSync, .syncLocked, .decoding, .syncLost:
            return true
        }
    }
    
    /// Whether the decoder has finished (successfully or with error)
    public var isTerminal: Bool {
        switch self {
        case .complete, .error:
            return true
        default:
            return false
        }
    }
}

// MARK: - Decoder Errors
//
// Errors are explicit state transitions, not exceptions.
// They represent conditions the decoder cannot recover from automatically.

/// Errors that can occur during decoding
public enum DecoderError: Error, Equatable, Sendable {
    /// No sync pattern found in the signal
    case syncNotFound
    
    /// Sync was lost during decoding
    case syncLost(atLine: Int)
    
    /// End of samples reached before image complete
    case endOfStream(linesDecoded: Int, totalLines: Int)
    
    /// Unknown or unsupported SSTV mode
    case unknownMode(String)
    
    /// Invalid sample rate for SSTV decoding
    case invalidSampleRate(Double)
    
    /// Insufficient samples for decoding
    case insufficientSamples
    
    /// Human-readable description
    public var description: String {
        switch self {
        case .syncNotFound:
            return "No sync pattern found in signal"
        case .syncLost(let line):
            return "Sync lost at line \(line)"
        case .endOfStream(let decoded, let total):
            return "End of stream: decoded \(decoded)/\(total) lines"
        case .unknownMode(let mode):
            return "Unknown SSTV mode: \(mode)"
        case .invalidSampleRate(let rate):
            return "Invalid sample rate: \(rate) Hz"
        case .insufficientSamples:
            return "Insufficient samples for decoding"
        }
    }
}
