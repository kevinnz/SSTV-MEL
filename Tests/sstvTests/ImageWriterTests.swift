import XCTest
@testable import SSTVCore

/// Tests for ImageWriter and ImageFormat
final class ImageWriterTests: XCTestCase {

    // MARK: - ImageFormat Tests

    func testImageFormatFileExtensions() {
        XCTAssertEqual(ImageFormat.png.fileExtension, "png")
        XCTAssertEqual(ImageFormat.jpeg(quality: 0.9).fileExtension, "jpg")
    }

    func testImageFormatUTI() {
        XCTAssertEqual(ImageFormat.png.uti, "public.png")
        XCTAssertEqual(ImageFormat.jpeg(quality: 0.5).uti, "public.jpeg")
    }

    func testImageFormatFromPathPNG() {
        let format = ImageFormat.from(path: "/tmp/image.png")
        if case .png = format {
            // Expected
        } else {
            XCTFail("Expected PNG format")
        }
    }

    func testImageFormatFromPathJPG() {
        let format = ImageFormat.from(path: "/tmp/image.jpg")
        if case .jpeg(let quality) = format {
            XCTAssertEqual(quality, 0.9, accuracy: 0.001)
        } else {
            XCTFail("Expected JPEG format")
        }
    }

    func testImageFormatFromPathJPEG() {
        let format = ImageFormat.from(path: "/tmp/image.jpeg")
        if case .jpeg(let quality) = format {
            XCTAssertEqual(quality, 0.9, accuracy: 0.001)
        } else {
            XCTFail("Expected JPEG format")
        }
    }

    func testImageFormatFromPathUnknown() {
        // Unknown extensions default to PNG
        let format = ImageFormat.from(path: "/tmp/image.bmp")
        if case .png = format {
            // Expected
        } else {
            XCTFail("Expected PNG format for unknown extension")
        }
    }

    func testImageFormatFromPathNoExtension() {
        let format = ImageFormat.from(path: "/tmp/image")
        if case .png = format {
            // Expected - default is PNG
        } else {
            XCTFail("Expected PNG format when no extension")
        }
    }

    // MARK: - Encoding Tests

    func testEncodeSimpleBufferPNG() throws {
        var buffer = ImageBuffer(width: 2, height: 2)
        buffer.setPixel(x: 0, y: 0, r: 1.0, g: 0.0, b: 0.0)
        buffer.setPixel(x: 1, y: 0, r: 0.0, g: 1.0, b: 0.0)
        buffer.setPixel(x: 0, y: 1, r: 0.0, g: 0.0, b: 1.0)
        buffer.setPixel(x: 1, y: 1, r: 1.0, g: 1.0, b: 1.0)

        let data = try ImageWriter.encode(buffer: buffer, format: .png)
        XCTAssertGreaterThan(data.count, 0)

        // PNG files start with the PNG signature
        let pngSignature: [UInt8] = [0x89, 0x50, 0x4E, 0x47]
        let header = Array(data.prefix(4))
        XCTAssertEqual(header, pngSignature)
    }

    func testEncodeSimpleBufferJPEG() throws {
        var buffer = ImageBuffer(width: 2, height: 2)
        buffer.setPixel(x: 0, y: 0, r: 0.5, g: 0.5, b: 0.5)
        buffer.setPixel(x: 1, y: 0, r: 0.5, g: 0.5, b: 0.5)
        buffer.setPixel(x: 0, y: 1, r: 0.5, g: 0.5, b: 0.5)
        buffer.setPixel(x: 1, y: 1, r: 0.5, g: 0.5, b: 0.5)

        let data = try ImageWriter.encode(buffer: buffer, format: .jpeg(quality: 0.9))
        XCTAssertGreaterThan(data.count, 0)

        // JPEG files start with 0xFF 0xD8
        let jpegSignature: [UInt8] = [0xFF, 0xD8]
        let header = Array(data.prefix(2))
        XCTAssertEqual(header, jpegSignature)
    }

    func testEncodeInvalidDimensions() {
        let buffer = ImageBuffer(width: 0, height: 0)

        XCTAssertThrowsError(try ImageWriter.encode(buffer: buffer, format: .png)) { error in
            guard case ImageWriteError.invalidDimensions = error else {
                XCTFail("Expected ImageWriteError.invalidDimensions but got \(error)")
                return
            }
        }
    }

    func testEncodeHandlesNaNValues() throws {
        let pixels = [Double.nan, 0.5, Double.infinity] // NaN and Infinity
        let buffer = ImageBuffer(width: 1, height: 1, pixels: pixels)

        // Should not crash - NaN/Inf should be treated as 0.0
        let data = try ImageWriter.encode(buffer: buffer, format: .png)
        XCTAssertGreaterThan(data.count, 0)
    }

    // MARK: - Write Tests

    func testWritePNG() throws {
        var buffer = ImageBuffer(width: 4, height: 4)
        for y in 0..<4 {
            let row = [Double](repeating: Double(y) / 3.0, count: 4 * 3)
            buffer.setRow(y: y, rowPixels: row)
        }

        let tempDir = NSTemporaryDirectory()
        let path = (tempDir as NSString).appendingPathComponent("testWrite.png")
        defer { try? FileManager.default.removeItem(atPath: path) }

        try ImageWriter.write(buffer: buffer, to: path)

        XCTAssertTrue(FileManager.default.fileExists(atPath: path))
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        XCTAssertGreaterThan(data.count, 0)
    }

    func testWriteJPEG() throws {
        var buffer = ImageBuffer(width: 4, height: 4)
        for y in 0..<4 {
            let row = [Double](repeating: 0.5, count: 4 * 3)
            buffer.setRow(y: y, rowPixels: row)
        }

        let tempDir = NSTemporaryDirectory()
        let path = (tempDir as NSString).appendingPathComponent("testWrite.jpg")
        defer { try? FileManager.default.removeItem(atPath: path) }

        try ImageWriter.write(buffer: buffer, to: path)

        XCTAssertTrue(FileManager.default.fileExists(atPath: path))
    }

    func testWriteAutoDetectsFormat() throws {
        var buffer = ImageBuffer(width: 4, height: 4)
        let row = [Double](repeating: 0.5, count: 4 * 3)
        for y in 0..<4 { buffer.setRow(y: y, rowPixels: row) }

        let tempDir = NSTemporaryDirectory()

        // Write with .png extension, no explicit format
        let pngPath = (tempDir as NSString).appendingPathComponent("autoDetect.png")
        defer { try? FileManager.default.removeItem(atPath: pngPath) }
        try ImageWriter.write(buffer: buffer, to: pngPath)

        let pngData = try Data(contentsOf: URL(fileURLWithPath: pngPath))
        let pngSignature: [UInt8] = [0x89, 0x50, 0x4E, 0x47]
        XCTAssertEqual(Array(pngData.prefix(4)), pngSignature)

        // Write with .jpg extension, no explicit format
        let jpgPath = (tempDir as NSString).appendingPathComponent("autoDetect.jpg")
        defer { try? FileManager.default.removeItem(atPath: jpgPath) }
        try ImageWriter.write(buffer: buffer, to: jpgPath)

        let jpgData = try Data(contentsOf: URL(fileURLWithPath: jpgPath))
        let jpegSignature: [UInt8] = [0xFF, 0xD8]
        XCTAssertEqual(Array(jpgData.prefix(2)), jpegSignature)
    }
}
