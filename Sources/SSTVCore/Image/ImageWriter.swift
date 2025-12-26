import Foundation

#if os(macOS)
import CoreGraphics
import ImageIO
#endif

/// Image output format
public enum ImageFormat {
    case png
    case jpeg(quality: Double)  // quality: 0.0 (worst) to 1.0 (best)
    
    /// Get the file extension for this format
    public var fileExtension: String {
        switch self {
        case .png:
            return "png"
        case .jpeg:
            return "jpg"
        }
    }
    
    /// Get the UTI (Uniform Type Identifier) for this format
    public var uti: String {
        switch self {
        case .png:
            return "public.png"
        case .jpeg:
            return "public.jpeg"
        }
    }
    
    /// Detect format from file path extension
    public static func from(path: String) -> ImageFormat {
        let ext = (path as NSString).pathExtension.lowercased()
        switch ext {
        case "jpg", "jpeg":
            return .jpeg(quality: 0.9)
        default:
            return .png
        }
    }
}

/// Errors that can occur during image writing
public enum ImageWriteError: Error {
    case writeError(String)
    case invalidDimensions
    case unsupportedPlatform
}

/// Image writer for SSTV decoded images
///
/// Supports both PNG and JPEG output formats
public struct ImageWriter {
    
    /// Write an ImageBuffer to a file
    ///
    /// - Parameters:
    ///   - buffer: Image buffer to write
    ///   - path: Output file path
    ///   - format: Image format (PNG or JPEG). If nil, detected from file extension
    /// - Throws: ImageWriteError if writing fails
    public static func write(buffer: ImageBuffer, to path: String, format: ImageFormat? = nil) throws {
        guard buffer.width > 0 && buffer.height > 0 else {
            throw ImageWriteError.invalidDimensions
        }
        
        // Auto-detect format from extension if not specified
        let outputFormat = format ?? ImageFormat.from(path: path)
        
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
        
        // Use ImageIO to write image (macOS native)
        try writeUsingImageIO(
            width: buffer.width,
            height: buffer.height,
            rgbData: rgbData,
            path: path,
            format: outputFormat
        )
    }
    
    /// Write image using macOS ImageIO framework
    private static func writeUsingImageIO(
        width: Int,
        height: Int,
        rgbData: Data,
        path: String,
        format: ImageFormat
    ) throws {
        #if os(macOS) || os(iOS)
        // Use Core Graphics on Apple platforms
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue)
        
        guard let provider = CGDataProvider(data: rgbData as CFData) else {
            throw ImageWriteError.writeError("Failed to create data provider")
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
            throw ImageWriteError.writeError("Failed to create CGImage")
        }
        
        let url = URL(fileURLWithPath: path)
        guard let destination = CGImageDestinationCreateWithURL(
            url as CFURL,
            format.uti as CFString,
            1,
            nil
        ) else {
            throw ImageWriteError.writeError("Failed to create image destination")
        }
        
        // Set compression options for JPEG
        var properties: [CFString: Any] = [:]
        if case .jpeg(let quality) = format {
            properties[kCGImageDestinationLossyCompressionQuality] = quality
        }
        
        CGImageDestinationAddImage(destination, cgImage, properties as CFDictionary)
        
        guard CGImageDestinationFinalize(destination) else {
            throw ImageWriteError.writeError("Failed to write image file")
        }
        #else
        throw ImageWriteError.unsupportedPlatform
        #endif
    }
}
