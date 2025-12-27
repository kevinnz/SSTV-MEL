/// A simple image buffer for storing decoded SSTV image data.
///
/// This buffer stores pixel data in a flat array, with pixels arranged row-by-row.
/// Color space handling (RGB, YCbCr conversion) is performed by the caller.
///
/// ## Progressive Rendering Support
///
/// The buffer is designed to support line-by-line progressive rendering:
/// - Allocate the buffer at decode start with full dimensions
/// - Write rows incrementally as they are decoded
/// - Read access is safe at any time (partial images are valid)
/// - Use `linesWritten` to track decode progress
///
/// ## Thread Safety
///
/// ImageBuffer is a value type (struct) and is NOT thread-safe for concurrent
/// read/write access. The caller is responsible for synchronization if needed.
///
/// ## Usage Example
/// ```swift
/// var buffer = ImageBuffer(width: 640, height: 496)
///
/// // Write rows as they are decoded
/// for lineIndex in 0..<height {
///     let pixels = decodeRow(lineIndex)
///     buffer.setRow(y: lineIndex, rowPixels: pixels)
/// }
///
/// // Access pixel data at any time
/// let partialData = buffer.pixels
/// ```
public struct ImageBuffer: Sendable {
    
    // MARK: - Properties
    
    /// Image width in pixels
    public let width: Int
    
    /// Image height in pixels
    public let height: Int
    
    /// Number of lines that have been written
    ///
    /// This tracks the highest row index that has been written to,
    /// useful for progressive rendering in UI.
    public private(set) var linesWritten: Int = 0
    
    /// Pixel data stored as flat array (row-major order)
    /// Each pixel is represented as three consecutive values: R, G, B (0.0...1.0)
    public private(set) var pixels: [Double]
    
    // MARK: - Initialization
    
    /// Create a new image buffer with the given dimensions.
    ///
    /// The buffer is initialized with all pixels set to black (0.0).
    ///
    /// - Parameters:
    ///   - width: Image width in pixels
    ///   - height: Image height in pixels
    public init(width: Int, height: Int) {
        self.width = width
        self.height = height
        self.pixels = Array(repeating: 0.0, count: width * height * 3)
    }
    
    /// Create an image buffer with pre-existing pixel data
    ///
    /// - Parameters:
    ///   - width: Image width in pixels
    ///   - height: Image height in pixels
    ///   - pixels: Pixel data (must be exactly width * height * 3 elements)
    public init(width: Int, height: Int, pixels: [Double]) {
        precondition(pixels.count == width * height * 3, 
                     "Pixel array size must match width * height * 3")
        self.width = width
        self.height = height
        self.pixels = pixels
        self.linesWritten = height
    }
    
    // MARK: - Pixel Access
    
    /// Set a pixel value at the given coordinates.
    ///
    /// - Parameters:
    ///   - x: X coordinate (0-based)
    ///   - y: Y coordinate (0-based)
    ///   - r: Red component (0.0...1.0)
    ///   - g: Green component (0.0...1.0)
    ///   - b: Blue component (0.0...1.0)
    ///
    /// - Note: This method updates `linesWritten` based on the y coordinate.
    ///         For accurate progress reporting, pixels should be written in
    ///         sequential order (top to bottom, left to right). Writing pixels
    ///         out of order may cause `linesWritten` to report incorrect progress.
    ///         Consider using `setRow()` when writing complete lines.
    public mutating func setPixel(x: Int, y: Int, r: Double, g: Double, b: Double) {
        guard x >= 0 && x < width && y >= 0 && y < height else {
            return
        }
        
        let index = (y * width + x) * 3
        pixels[index] = r
        pixels[index + 1] = g
        pixels[index + 2] = b
        
        linesWritten = max(linesWritten, y + 1)
    }
    
    /// Get a pixel value at the given coordinates.
    ///
    /// - Parameters:
    ///   - x: X coordinate (0-based)
    ///   - y: Y coordinate (0-based)
    /// - Returns: RGB tuple, or nil if coordinates are out of bounds
    public func getPixel(x: Int, y: Int) -> (r: Double, g: Double, b: Double)? {
        guard x >= 0 && x < width && y >= 0 && y < height else {
            return nil
        }
        
        let index = (y * width + x) * 3
        return (pixels[index], pixels[index + 1], pixels[index + 2])
    }
    
    /// Set an entire row of pixels at once.
    ///
    /// This is the primary method for progressive rendering - call this
    /// as each line is decoded.
    ///
    /// - Parameters:
    ///   - y: Row index (0-based)
    ///   - rowPixels: Array of pixel values (R, G, B triplets). Must contain exactly width * 3 values.
    public mutating func setRow(y: Int, rowPixels: [Double]) {
        guard y >= 0 && y < height else {
            return
        }
        guard rowPixels.count == width * 3 else {
            return
        }
        
        let startIndex = y * width * 3
        for i in 0..<rowPixels.count {
            pixels[startIndex + i] = rowPixels[i]
        }
        
        linesWritten = max(linesWritten, y + 1)
    }
    
    /// Get an entire row of pixels.
    ///
    /// - Parameter y: Row index (0-based)
    /// - Returns: Array of RGB values for the row, or nil if out of bounds
    public func getRow(y: Int) -> [Double]? {
        guard y >= 0 && y < height else {
            return nil
        }
        
        let startIndex = y * width * 3
        let endIndex = startIndex + width * 3
        return Array(pixels[startIndex..<endIndex])
    }
    
    // MARK: - Progressive Rendering
    
    /// Progress of image completion (0.0...1.0)
    public var progress: Float {
        Float(linesWritten) / Float(height)
    }
    
    /// Whether the image is complete (all lines written)
    public var isComplete: Bool {
        linesWritten >= height
    }
    
    /// Reset the buffer to black and clear progress
    public mutating func clear() {
        pixels = Array(repeating: 0.0, count: width * height * 3)
        linesWritten = 0
    }
    
    // MARK: - Conversion
    
    /// Convert to 8-bit RGB data suitable for image creation
    ///
    /// - Returns: Array of UInt8 values (R, G, B for each pixel)
    public func toRGB8() -> [UInt8] {
        return pixels.map { value in
            UInt8(clamping: Int(value * 255.0))
        }
    }
    
    /// Convert to 8-bit RGBA data suitable for image creation
    ///
    /// - Returns: Array of UInt8 values (R, G, B, A for each pixel)
    public func toRGBA8() -> [UInt8] {
        let pixelCount = width * height
        var rgba = [UInt8]()
        rgba.reserveCapacity(pixelCount * 4)
        
        for i in stride(from: 0, to: pixels.count, by: 3) {
            rgba.append(UInt8(clamping: Int(pixels[i] * 255.0)))       // R
            rgba.append(UInt8(clamping: Int(pixels[i + 1] * 255.0)))   // G
            rgba.append(UInt8(clamping: Int(pixels[i + 2] * 255.0)))   // B
            rgba.append(255)                                           // A
        }
        
        return rgba
    }
}
