/// SSTV Mode Parameters
///
/// This file contains parameter structs for each SSTV mode. These structs
/// group mode-specific timing constants and allow injection at decoder
/// initialization or reset.
///
/// USAGE:
/// Parameters are immutable after creation to prevent mid-decode mutation.
/// Create a new parameter set if you need different values.
///
/// ```swift
/// let params = PD120Parameters()
/// let decoder = SSTVDecoderCore(sampleRate: 44100)
/// decoder.setMode(.pd120(params))
/// ```

import Foundation

// MARK: - Base Mode Parameters Protocol

/// Common properties for all SSTV mode parameters
public protocol SSTVModeParameters: Sendable {
    /// VIS code identifying this mode
    var visCode: UInt8 { get }

    /// Human-readable mode name
    var name: String { get }

    /// Image width in pixels
    var width: Int { get }

    /// Image height in pixels
    var height: Int { get }

    /// Number of image lines per transmission frame
    var linesPerFrame: Int { get }

    /// Total duration of one transmission frame in milliseconds
    var frameDurationMs: Double { get }

    /// Duration of sync pulse in milliseconds
    var syncPulseMs: Double { get }

    /// Duration of porch after sync pulse in milliseconds
    var porchMs: Double { get }

    /// Sync pulse frequency in Hz
    var syncFrequencyHz: Double { get }

    /// Black level frequency in Hz
    var blackFrequencyHz: Double { get }

    /// White level frequency in Hz
    var whiteFrequencyHz: Double { get }
}

// MARK: - PD120 Parameters

/// Parameters for PD120 SSTV mode
///
/// PD120 is a color SSTV mode with YCbCr encoding:
/// - Resolution: 640 × 496 pixels
/// - Duration: ~126 seconds
/// - VIS code: 95 (0x5F)
///
/// All timing values are in milliseconds unless otherwise noted.
public struct PD120Parameters: SSTVModeParameters, Sendable {

    // MARK: - Identification

    public let visCode: UInt8 = 0x5F  // 95 decimal
    public let name: String = "PD120"

    // MARK: - Image Dimensions

    public let width: Int = 640
    public let height: Int = 496
    public let linesPerFrame: Int = 2

    // MARK: - Timing (milliseconds)

    /// Total frame duration (contains 2 image lines)
    /// Per PD120 specification: 508.48ms per frame
    public let frameDurationMs: Double

    /// Sync pulse duration
    public let syncPulseMs: Double

    /// Porch duration after sync
    public let porchMs: Double

    /// Y component duration (one per image line)
    public let yDurationMs: Double

    /// Cb (B-Y, blue chrominance) duration
    public let cbDurationMs: Double

    /// Cr (R-Y, red chrominance) duration
    public let crDurationMs: Double

    // MARK: - Frequencies (Hz)

    public let syncFrequencyHz: Double
    public let blackFrequencyHz: Double
    public let whiteFrequencyHz: Double

    // MARK: - Derived

    /// Frequency range for pixel values (white - black)
    public var frequencyRangeHz: Double {
        whiteFrequencyHz - blackFrequencyHz
    }

    /// Duration of one image line in milliseconds
    public var lineDurationMs: Double {
        frameDurationMs / Double(linesPerFrame)
    }

    // MARK: - Initialization

    /// Create PD120 parameters with default timing values
    public init() {
        self.frameDurationMs = 508.48
        self.syncPulseMs = 20.0
        self.porchMs = 2.08
        self.yDurationMs = 121.6
        self.cbDurationMs = 121.6
        self.crDurationMs = 121.6
        self.syncFrequencyHz = 1200.0
        self.blackFrequencyHz = 1500.0
        self.whiteFrequencyHz = 2300.0
    }

    /// Create PD120 parameters with custom timing values
    ///
    /// Use this for fine-tuning or experimentation.
    ///
    /// - Parameters:
    ///   - frameDurationMs: Total frame duration
    ///   - syncPulseMs: Sync pulse duration
    ///   - porchMs: Porch duration
    ///   - yDurationMs: Y component duration
    ///   - cbDurationMs: Cb component duration
    ///   - crDurationMs: Cr component duration
    ///   - syncFrequencyHz: Sync frequency
    ///   - blackFrequencyHz: Black level frequency
    ///   - whiteFrequencyHz: White level frequency
    public init(
        frameDurationMs: Double = 508.48,
        syncPulseMs: Double = 20.0,
        porchMs: Double = 2.08,
        yDurationMs: Double = 121.6,
        cbDurationMs: Double = 121.6,
        crDurationMs: Double = 121.6,
        syncFrequencyHz: Double = 1200.0,
        blackFrequencyHz: Double = 1500.0,
        whiteFrequencyHz: Double = 2300.0
    ) {
        self.frameDurationMs = frameDurationMs
        self.syncPulseMs = syncPulseMs
        self.porchMs = porchMs
        self.yDurationMs = yDurationMs
        self.cbDurationMs = cbDurationMs
        self.crDurationMs = crDurationMs
        self.syncFrequencyHz = syncFrequencyHz
        self.blackFrequencyHz = blackFrequencyHz
        self.whiteFrequencyHz = whiteFrequencyHz
    }
}

// MARK: - PD180 Parameters

/// Parameters for PD180 SSTV mode
///
/// PD180 is a color SSTV mode with YCbCr encoding:
/// - Resolution: 640 × 496 pixels
/// - Duration: ~187 seconds
/// - VIS code: 96 (0x60)
///
/// PD180 has longer component durations than PD120, resulting in
/// higher quality images at the cost of longer transmission time.
public struct PD180Parameters: SSTVModeParameters, Sendable {

    // MARK: - Identification

    public let visCode: UInt8 = 0x60  // 96 decimal
    public let name: String = "PD180"

    // MARK: - Image Dimensions

    public let width: Int = 640
    public let height: Int = 496
    public let linesPerFrame: Int = 2

    // MARK: - Timing (milliseconds)

    /// Total frame duration (contains 2 image lines)
    /// QSSTV: 187.06450 seconds / 248 frames = 754.29ms
    public let frameDurationMs: Double

    /// Sync pulse duration
    public let syncPulseMs: Double

    /// Porch/back porch duration after sync
    public let porchMs: Double

    /// Y component duration (one per image line)
    public let yDurationMs: Double

    /// Cb (B-Y, blue chrominance) duration
    public let cbDurationMs: Double

    /// Cr (R-Y, red chrominance) duration
    public let crDurationMs: Double

    // MARK: - Frequencies (Hz)

    public let syncFrequencyHz: Double
    public let blackFrequencyHz: Double
    public let whiteFrequencyHz: Double

    // MARK: - Derived

    /// Frequency range for pixel values (white - black)
    public var frequencyRangeHz: Double {
        whiteFrequencyHz - blackFrequencyHz
    }

    /// Duration of one image line in milliseconds
    public var lineDurationMs: Double {
        frameDurationMs / Double(linesPerFrame)
    }

    // MARK: - Initialization

    /// Create PD180 parameters with default timing values
    public init() {
        self.frameDurationMs = 754.29
        self.syncPulseMs = 20.0
        self.porchMs = 2.0
        self.yDurationMs = 183.07
        self.cbDurationMs = 183.07
        self.crDurationMs = 183.07
        self.syncFrequencyHz = 1200.0
        self.blackFrequencyHz = 1500.0
        self.whiteFrequencyHz = 2300.0
    }

    /// Create PD180 parameters with custom timing values
    ///
    /// Use this for fine-tuning or experimentation.
    public init(
        frameDurationMs: Double = 754.29,
        syncPulseMs: Double = 20.0,
        porchMs: Double = 2.0,
        yDurationMs: Double = 183.07,
        cbDurationMs: Double = 183.07,
        crDurationMs: Double = 183.07,
        syncFrequencyHz: Double = 1200.0,
        blackFrequencyHz: Double = 1500.0,
        whiteFrequencyHz: Double = 2300.0
    ) {
        self.frameDurationMs = frameDurationMs
        self.syncPulseMs = syncPulseMs
        self.porchMs = porchMs
        self.yDurationMs = yDurationMs
        self.cbDurationMs = cbDurationMs
        self.crDurationMs = crDurationMs
        self.syncFrequencyHz = syncFrequencyHz
        self.blackFrequencyHz = blackFrequencyHz
        self.whiteFrequencyHz = whiteFrequencyHz
    }
}

// MARK: - Mode Selection Enum

/// Enumeration of supported SSTV modes with their parameters
///
/// This enum allows type-safe mode selection with optional custom parameters.
public enum SSTVModeSelection: Sendable {
    /// PD120 mode with optional custom parameters
    case pd120(PD120Parameters = PD120Parameters())

    /// PD180 mode with optional custom parameters
    case pd180(PD180Parameters = PD180Parameters())

    /// Get the parameters for this mode selection
    ///
    /// Note: This property returns an existential type (`any SSTVModeParameters`)
    /// which uses dynamic dispatch. For performance-critical code paths, consider
    /// pattern-matching on the enum cases directly to access concrete types.
    /// This API is provided for convenience in non-performance-critical contexts.
    public var parameters: any SSTVModeParameters {
        switch self {
        case .pd120(let params): return params
        case .pd180(let params): return params
        }
    }

    /// Get the mode name
    public var name: String {
        switch self {
        case .pd120: return "PD120"
        case .pd180: return "PD180"
        }
    }

    /// Get the VIS code for this mode
    public var visCode: UInt8 {
        switch self {
        case .pd120(let params): return params.visCode
        case .pd180(let params): return params.visCode
        }
    }

    /// Create mode selection from VIS code
    ///
    /// - Parameter visCode: VIS code value
    /// - Returns: Mode selection, or nil if unknown VIS code
    public static func from(visCode: UInt8) -> SSTVModeSelection? {
        switch visCode {
        case 0x5F: return .pd120()
        case 0x60: return .pd180()
        default: return nil
        }
    }

    /// Create mode selection from mode name
    ///
    /// - Parameter name: Mode name (case-insensitive)
    /// - Returns: Mode selection, or nil if unknown name
    public static func from(name: String) -> SSTVModeSelection? {
        switch name.uppercased() {
        case "PD120": return .pd120()
        case "PD180": return .pd180()
        default: return nil
        }
    }
}
