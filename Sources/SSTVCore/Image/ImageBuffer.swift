/// A simple image buffer for storing decoded SSTV image data.
///
/// This buffer stores pixel data in a flat array, with pixels arranged row-by-row.
/// Color space handling (RGB, YCbCr conversion) is performed by the caller.
public struct ImageBuffer {
    /// Image width in pixels
    public let width: Int
    
    /// Image height in pixels
    public let height: Int
    
    /// Pixel data stored as flat array (row-major order)
    /// Each pixel is represented as three consecutive values: R, G, B (0.0...1.0)
    public private(set) var pixels: [Double]
    
    /// Create a new image buffer with the given dimensions.
    ///
    /// - Parameters:
    ///   - width: Image width in pixels
    ///   - height: Image height in pixels
    public init(width: Int, height: Int) {
        self.width = width
        self.height = height
        self.pixels = Array(repeating: 0.0, count: width * height * 3)
    }
    
    /// Set a pixel value at the given coordinates.
    ///
    /// - Parameters:
    ///   - x: X coordinate (0-based)
    ///   - y: Y coordinate (0-based)
    ///   - r: Red component (0.0...1.0)
    ///   - g: Green component (0.0...1.0)
    ///   - b: Blue component (0.0...1.0)
    public mutating func setPixel(x: Int, y: Int, r: Double, g: Double, b: Double) {
        guard x >= 0 && x < width && y >= 0 && y < height else {
            return
        }
        
        let index = (y * width + x) * 3
        pixels[index] = r
        pixels[index + 1] = g
        pixels[index + 2] = b
    }
    
    /// Set an entire row of pixels at once.
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
    }
}
