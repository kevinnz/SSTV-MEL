/// Protocol defining the interface for SSTV mode implementations.
///
/// Each SSTV mode defines timing constants, image dimensions, and decoding logic.
/// Modes should not perform DSP directly or handle audio I/O.
protocol SSTVMode {
    /// The VIS code identifying this mode
    var visCode: UInt8 { get }
    
    /// Image width in pixels
    var width: Int { get }
    
    /// Image height in pixels (number of lines)
    var height: Int { get }
    
    /// Total duration of one transmission frame in milliseconds
    /// For modes like PD that transmit 2 image lines per frame, this is the
    /// duration of the complete frame (both lines together)
    var frameDurationMs: Double { get }
    
    /// Number of image lines transmitted per frame
    /// Most modes transmit 1 line per frame, but PD modes transmit 2
    var linesPerFrame: Int { get }
    
    /// Total duration of one image line in milliseconds (derived)
    var lineDurationMs: Double { get }
    
    /// Human-readable name of the mode
    var name: String { get }
}

/// Default implementation for single-line-per-frame modes
extension SSTVMode {
    var linesPerFrame: Int { 1 }
    var lineDurationMs: Double { frameDurationMs / Double(linesPerFrame) }
}
