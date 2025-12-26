import Foundation

// MARK: - Decoder Delegate Protocol
//
// This protocol defines the events emitted by SSTVDecoderCore during decoding.
// The decoder operates independently of UI concerns - it simply emits events
// when significant decode milestones occur.
//
// Events are emitted synchronously on the same thread that calls processSamples().
// UI code should dispatch to main thread as needed.

/// Events emitted during SSTV decoding
///
/// Implement this protocol to receive real-time decode events.
/// All methods have default empty implementations, so you only need
/// to implement the events you care about.
public protocol DecoderDelegate: AnyObject {
    
    // MARK: - Sync Events
    
    /// Called when the decoder locks onto a sync pattern
    ///
    /// - Parameter confidence: Confidence level of sync lock (0.0...1.0)
    func didLockSync(confidence: Float)
    
    /// Called when the decoder loses sync
    ///
    /// This may happen due to noise, signal dropout, or end of transmission.
    func didLoseSync()
    
    // MARK: - VIS Code Events
    
    /// Called when VIS code detection begins
    func didBeginVISDetection()
    
    /// Called when a VIS code is successfully detected
    ///
    /// - Parameters:
    ///   - code: The detected VIS code value
    ///   - mode: The SSTV mode name (e.g., "PD120", "PD180")
    func didDetectVISCode(_ code: UInt8, mode: String)
    
    /// Called when VIS code detection fails
    ///
    /// The decoder will fall back to the configured default mode.
    func didFailVISDetection()
    
    // MARK: - Decoding Events
    
    /// Called when a complete image line has been decoded
    ///
    /// - Parameters:
    ///   - lineNumber: The 0-based line index that was decoded
    ///   - totalLines: Total number of lines in the image
    func didDecodeLine(lineNumber: Int, totalLines: Int)
    
    /// Called periodically with overall decode progress
    ///
    /// - Parameter progress: Progress value (0.0...1.0)
    func didUpdateProgress(_ progress: Float)
    
    /// Called when a complete image has been decoded
    ///
    /// - Parameter imageBuffer: The completed image buffer
    func didCompleteImage(_ imageBuffer: ImageBuffer)
    
    // MARK: - State Events
    
    /// Called when the decoder state changes
    ///
    /// - Parameter state: The new decoder state
    func didChangeState(_ state: DecoderState)
    
    /// Called when an error occurs during decoding
    ///
    /// Errors during decoding are non-fatal state transitions, not exceptions.
    ///
    /// - Parameter error: Description of the error
    func didEncounterError(_ error: DecoderError)
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
}

// MARK: - Decoder State
//
// Explicit state machine for decoder lifecycle.
// The decoder always exists in exactly one of these states.

/// Decoder state machine states
public enum DecoderState: Equatable, Sendable {
    /// Decoder is idle, waiting for samples
    case idle
    
    /// Searching for VIS code
    case detectingVIS
    
    /// Searching for sync pattern to begin image decode
    case searchingSync
    
    /// Actively decoding image lines
    case decoding(line: Int, totalLines: Int)
    
    /// Image decode complete
    case complete
    
    /// Decoder encountered an unrecoverable error
    case error(DecoderError)
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
