import XCTest
@testable import SSTVCore

/// Tests for ImageBuffer
final class ImageBufferTests: XCTestCase {

    // MARK: - Initialization

    func testInitWithDimensions() {
        let buffer = ImageBuffer(width: 10, height: 5)

        XCTAssertEqual(buffer.width, 10)
        XCTAssertEqual(buffer.height, 5)
        XCTAssertEqual(buffer.linesWritten, 0)
        XCTAssertEqual(buffer.pixels.count, 10 * 5 * 3)
        XCTAssertFalse(buffer.isComplete)
        XCTAssertEqual(buffer.progress, 0.0)

        // All pixels should be initialized to black
        for pixel in buffer.pixels {
            XCTAssertEqual(pixel, 0.0)
        }
    }

    func testInitWithPixelData() {
        let pixels = [Double](repeating: 0.5, count: 4 * 2 * 3)
        let buffer = ImageBuffer(width: 4, height: 2, pixels: pixels)

        XCTAssertEqual(buffer.width, 4)
        XCTAssertEqual(buffer.height, 2)
        XCTAssertEqual(buffer.linesWritten, 2)
        XCTAssertTrue(buffer.isComplete)
        XCTAssertEqual(buffer.progress, 1.0)
    }

    // MARK: - Pixel Access

    func testSetAndGetPixel() {
        var buffer = ImageBuffer(width: 10, height: 10)

        buffer.setPixel(x: 5, y: 3, r: 1.0, g: 0.5, b: 0.25)

        let pixel = buffer.getPixel(x: 5, y: 3)
        XCTAssertNotNil(pixel)
        XCTAssertEqual(pixel!.r, 1.0, accuracy: 0.001)
        XCTAssertEqual(pixel!.g, 0.5, accuracy: 0.001)
        XCTAssertEqual(pixel!.b, 0.25, accuracy: 0.001)
    }

    func testSetPixelUpdatesLinesWritten() {
        var buffer = ImageBuffer(width: 10, height: 10)

        buffer.setPixel(x: 0, y: 0, r: 1.0, g: 0.0, b: 0.0)
        XCTAssertEqual(buffer.linesWritten, 1)

        buffer.setPixel(x: 0, y: 5, r: 0.0, g: 1.0, b: 0.0)
        XCTAssertEqual(buffer.linesWritten, 6)

        // Going backwards shouldn't decrease linesWritten
        buffer.setPixel(x: 0, y: 2, r: 0.0, g: 0.0, b: 1.0)
        XCTAssertEqual(buffer.linesWritten, 6)
    }

    func testSetPixelOutOfBounds() {
        var buffer = ImageBuffer(width: 10, height: 10)

        // These should be silently ignored
        buffer.setPixel(x: -1, y: 0, r: 1.0, g: 0.0, b: 0.0)
        buffer.setPixel(x: 0, y: -1, r: 1.0, g: 0.0, b: 0.0)
        buffer.setPixel(x: 10, y: 0, r: 1.0, g: 0.0, b: 0.0)
        buffer.setPixel(x: 0, y: 10, r: 1.0, g: 0.0, b: 0.0)

        XCTAssertEqual(buffer.linesWritten, 0)
    }

    func testGetPixelOutOfBounds() {
        let buffer = ImageBuffer(width: 10, height: 10)

        XCTAssertNil(buffer.getPixel(x: -1, y: 0))
        XCTAssertNil(buffer.getPixel(x: 0, y: -1))
        XCTAssertNil(buffer.getPixel(x: 10, y: 0))
        XCTAssertNil(buffer.getPixel(x: 0, y: 10))
    }

    // MARK: - Row Access

    func testSetAndGetRow() {
        var buffer = ImageBuffer(width: 3, height: 2)
        let rowPixels = [1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0] // R, G, B

        buffer.setRow(y: 0, rowPixels: rowPixels)

        let row = buffer.getRow(y: 0)
        XCTAssertNotNil(row)
        XCTAssertEqual(row!.count, 9)
        XCTAssertEqual(row!, rowPixels)
        XCTAssertEqual(buffer.linesWritten, 1)
    }

    func testSetRowOutOfBounds() {
        var buffer = ImageBuffer(width: 3, height: 2)
        let rowPixels = [Double](repeating: 1.0, count: 9)

        buffer.setRow(y: -1, rowPixels: rowPixels)
        buffer.setRow(y: 2, rowPixels: rowPixels)

        XCTAssertEqual(buffer.linesWritten, 0)
    }

    func testSetRowWrongSize() {
        var buffer = ImageBuffer(width: 3, height: 2)
        let wrongSizePixels = [Double](repeating: 1.0, count: 6) // Should be 9

        buffer.setRow(y: 0, rowPixels: wrongSizePixels)

        // Should be ignored, linesWritten stays 0
        XCTAssertEqual(buffer.linesWritten, 0)
    }

    func testGetRowOutOfBounds() {
        let buffer = ImageBuffer(width: 3, height: 2)

        XCTAssertNil(buffer.getRow(y: -1))
        XCTAssertNil(buffer.getRow(y: 2))
    }

    // MARK: - Progressive Rendering

    func testProgressTracking() {
        var buffer = ImageBuffer(width: 10, height: 4)

        XCTAssertEqual(buffer.progress, 0.0, accuracy: 0.001)
        XCTAssertFalse(buffer.isComplete)

        buffer.setPixel(x: 0, y: 0, r: 1.0, g: 0.0, b: 0.0)
        XCTAssertEqual(buffer.progress, 0.25, accuracy: 0.001)

        buffer.setPixel(x: 0, y: 1, r: 1.0, g: 0.0, b: 0.0)
        XCTAssertEqual(buffer.progress, 0.5, accuracy: 0.001)

        let row = [Double](repeating: 0.5, count: 30)
        buffer.setRow(y: 3, rowPixels: row)
        XCTAssertEqual(buffer.progress, 1.0, accuracy: 0.001)
        XCTAssertTrue(buffer.isComplete)
    }

    func testClear() {
        var buffer = ImageBuffer(width: 3, height: 2)
        buffer.setPixel(x: 1, y: 1, r: 1.0, g: 0.5, b: 0.25)
        XCTAssertEqual(buffer.linesWritten, 2)

        buffer.clear()

        XCTAssertEqual(buffer.linesWritten, 0)
        XCTAssertEqual(buffer.progress, 0.0)
        XCTAssertFalse(buffer.isComplete)

        // All pixels should be reset to black
        for pixel in buffer.pixels {
            XCTAssertEqual(pixel, 0.0)
        }
    }

    // MARK: - Conversion

    func testToRGB8() {
        var buffer = ImageBuffer(width: 2, height: 1)
        buffer.setPixel(x: 0, y: 0, r: 0.0, g: 0.5, b: 1.0)
        buffer.setPixel(x: 1, y: 0, r: 1.0, g: 0.0, b: 0.0)

        let rgb8 = buffer.toRGB8()
        XCTAssertEqual(rgb8.count, 6)
        XCTAssertEqual(rgb8[0], 0)               // R = 0.0 → 0
        XCTAssertEqual(rgb8[1], 127)              // G = 0.5 → 127
        XCTAssertEqual(rgb8[2], 255)              // B = 1.0 → 255
        XCTAssertEqual(rgb8[3], 255)              // R = 1.0 → 255
        XCTAssertEqual(rgb8[4], 0)                // G = 0.0 → 0
        XCTAssertEqual(rgb8[5], 0)                // B = 0.0 → 0
    }

    func testToRGBA8() {
        var buffer = ImageBuffer(width: 1, height: 1)
        buffer.setPixel(x: 0, y: 0, r: 0.5, g: 0.25, b: 0.75)

        let rgba8 = buffer.toRGBA8()
        XCTAssertEqual(rgba8.count, 4)
        XCTAssertEqual(rgba8[0], 127)              // R
        XCTAssertEqual(rgba8[1], 63)               // G
        XCTAssertEqual(rgba8[2], 191)              // B
        XCTAssertEqual(rgba8[3], 255)              // A - always 255
    }

    func testToRGB8Clamping() {
        // Values outside 0..1 should be clamped by UInt8(clamping:)
        let pixels = [-0.5, 0.5, 1.5] // Out of range R and B
        let buffer = ImageBuffer(width: 1, height: 1, pixels: pixels)

        let rgb8 = buffer.toRGB8()
        XCTAssertEqual(rgb8[0], 0)     // -0.5 * 255 = -127.5 → clamped to 0
        XCTAssertEqual(rgb8[1], 127)   // 0.5 * 255 = 127.5 → 127
        XCTAssertEqual(rgb8[2], 255)   // 1.5 * 255 = 382.5 → clamped to 255
    }
}
