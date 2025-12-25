import Foundation

#if os(macOS)
import CoreGraphics
import ImageIO
#endif

/// Errors that can occur during PNG writing
enum PNGError: Error {
    case writeError(String)
    case invalidDimensions
}

/// Simple PNG writer for SSTV decoded images
///
/// This writer creates uncompressed PNG files from ImageBuffer data.
/// Uses raw PNG format with minimal dependencies.
struct PNGWriter {
    
    /// Write an ImageBuffer to a PNG file
    ///
    /// - Parameters:
    ///   - buffer: Image buffer to write
    ///   - path: Output file path
    /// - Throws: PNGError if writing fails
    static func write(buffer: ImageBuffer, to path: String) throws {
        guard buffer.width > 0 && buffer.height > 0 else {
            throw PNGError.invalidDimensions
        }
        
        // Convert normalized pixel values (0.0...1.0) to 8-bit (0...255)
        var rgbData = Data()
        rgbData.reserveCapacity(buffer.width * buffer.height * 3)
        
        for value in buffer.pixels {
            // Handle NaN and infinite values
            let safeValue = value.isNaN || value.isInfinite ? 0.0 : value
            let clamped = min(max(safeValue * 255.0, 0.0), 255.0)
            let byte = UInt8(clamped)
            rgbData.append(byte)
        }
        
        // Use ImageIO to write PNG (macOS native)
        try writeUsingImageIO(
            width: buffer.width,
            height: buffer.height,
            rgbData: rgbData,
            path: path
        )
    }
    
    /// Write PNG using macOS ImageIO framework
    private static func writeUsingImageIO(
        width: Int,
        height: Int,
        rgbData: Data,
        path: String
    ) throws {
        #if os(macOS) || os(iOS)
        // Use Core Graphics on Apple platforms
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue)
        
        guard let provider = CGDataProvider(data: rgbData as CFData) else {
            throw PNGError.writeError("Failed to create data provider")
        }
        
        guard let cgImage = CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 24,
            bytesPerRow: width * 3,
            space: colorSpace,
            bitmapInfo: bitmapInfo,
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        ) else {
            throw PNGError.writeError("Failed to create CGImage")
        }
        
        let url = URL(fileURLWithPath: path)
        guard let destination = CGImageDestinationCreateWithURL(
            url as CFURL,
            "public.png" as CFString,
            1,
            nil
        ) else {
            throw PNGError.writeError("Failed to create image destination")
        }
        
        CGImageDestinationAddImage(destination, cgImage, nil)
        
        guard CGImageDestinationFinalize(destination) else {
            throw PNGError.writeError("Failed to write PNG file")
        }
        #else
        throw PNGError.writeError("PNG writing only supported on macOS")
        #endif
    }
}
