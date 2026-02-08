import Foundation

#if os(macOS)
import CoreGraphics
import ImageIO
#endif

/// Image comparison utilities for testing
struct ImageComparison {

    /// Load image data from file (supports PNG and JPEG)
    ///
    /// - Parameter path: Path to image file
    /// - Returns: Tuple of (width, height, RGB pixel data)
    /// - Throws: Error if image cannot be loaded
    static func loadImage(path: String) throws -> (width: Int, height: Int, pixels: [UInt8]) {
        #if os(macOS)
        let url = URL(fileURLWithPath: path)

        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            throw ImageComparisonError.cannotLoadImage(path)
        }

        guard let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
            throw ImageComparisonError.cannotLoadImage(path)
        }

        let width = cgImage.width
        let height = cgImage.height
        let bytesPerPixel = 4 // RGBA
        let bytesPerRow = width * bytesPerPixel
        let totalBytes = height * bytesPerRow

        var pixelData = [UInt8](repeating: 0, count: totalBytes)

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)

        guard let context = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else {
            throw ImageComparisonError.cannotCreateContext
        }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        // Convert RGBA to RGB
        var rgbPixels = [UInt8]()
        rgbPixels.reserveCapacity(width * height * 3)

        for i in stride(from: 0, to: totalBytes, by: 4) {
            rgbPixels.append(pixelData[i])     // R
            rgbPixels.append(pixelData[i + 1]) // G
            rgbPixels.append(pixelData[i + 2]) // B
            // Skip alpha
        }

        return (width, height, rgbPixels)
        #else
        throw ImageComparisonError.unsupportedPlatform
        #endif
    }

    /// Compare two images and calculate similarity metrics
    ///
    /// - Parameters:
    ///   - path1: Path to first image
    ///   - path2: Path to second image
    /// - Returns: ComparisonResult with similarity metrics
    /// - Throws: Error if images cannot be compared
    static func compare(path1: String, path2: String) throws -> ComparisonResult {
        let (width1, height1, pixels1) = try loadImage(path: path1)
        let (width2, height2, pixels2) = try loadImage(path: path2)

        // Images must have same dimensions
        guard width1 == width2 && height1 == height2 else {
            return ComparisonResult(
                dimensionsMatch: false,
                meanSquaredError: Double.infinity,
                peakSignalToNoiseRatio: 0.0,
                structuralSimilarity: 0.0,
                pixelsDifferent: width1 * height1 * 3
            )
        }

        // Calculate MSE (Mean Squared Error)
        var sumSquaredError = 0.0
        var differentPixels = 0

        for i in 0..<pixels1.count {
            let diff = Double(pixels1[i]) - Double(pixels2[i])
            sumSquaredError += diff * diff

            if abs(Int(pixels1[i]) - Int(pixels2[i])) > 5 { // Tolerance of 5
                differentPixels += 1
            }
        }

        let mse = sumSquaredError / Double(pixels1.count)

        // Calculate PSNR (Peak Signal-to-Noise Ratio)
        let maxPixelValue = 255.0
        let psnr = mse > 0 ? 20.0 * log10(maxPixelValue / sqrt(mse)) : Double.infinity

        // Simple structural similarity approximation
        // (A more complete SSIM would require windowing and more complex calculations)
        let ssim = 1.0 / (1.0 + mse / 10000.0)

        return ComparisonResult(
            dimensionsMatch: true,
            meanSquaredError: mse,
            peakSignalToNoiseRatio: psnr,
            structuralSimilarity: ssim,
            pixelsDifferent: differentPixels
        )
    }
}

/// Result of image comparison
struct ComparisonResult {
    /// Whether dimensions match
    let dimensionsMatch: Bool

    /// Mean Squared Error (lower is better)
    let meanSquaredError: Double

    /// Peak Signal-to-Noise Ratio in dB (higher is better)
    let peakSignalToNoiseRatio: Double

    /// Structural Similarity Index (0.0 to 1.0, higher is better)
    let structuralSimilarity: Double

    /// Number of pixels that differ beyond tolerance
    let pixelsDifferent: Int

    /// Whether images are considered similar (PSNR > 30 dB typically indicates good quality)
    var areSimilar: Bool {
        return dimensionsMatch && peakSignalToNoiseRatio > 30.0
    }

    /// Whether images are nearly identical (PSNR > 40 dB)
    var areNearlyIdentical: Bool {
        return dimensionsMatch && peakSignalToNoiseRatio > 40.0
    }
}

/// Errors that can occur during image comparison
enum ImageComparisonError: Error {
    case cannotLoadImage(String)
    case cannotCreateContext
    case unsupportedPlatform
    case dimensionMismatch
}
