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
    
    /// Total duration of one complete line in milliseconds
    var lineDurationMs: Double { get }
    
    /// Human-readable name of the mode
    var name: String { get }
}
