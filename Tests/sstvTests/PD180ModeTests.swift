import XCTest
@testable import SSTVCore

/// Tests for PD180 mode implementation
final class PD180ModeTests: XCTestCase {

    func testPD180ModeConstants() {
        let mode = PD180Mode()

        // Verify mode identification
        XCTAssertEqual(mode.name, "PD180")
        XCTAssertEqual(mode.visCode, 0x60)  // VIS code 96 (0x60) per PD180 specification

        // Verify image dimensions (same as PD120)
        XCTAssertEqual(mode.width, 640)
        XCTAssertEqual(mode.height, 496)

        // Verify frame structure
        XCTAssertEqual(mode.linesPerFrame, 2)
        XCTAssertEqual(mode.frameDurationMs, 754.29, accuracy: 0.01)

        // Verify timing constants
        XCTAssertEqual(mode.syncPulseMs, 20.0, accuracy: 0.001)
        XCTAssertEqual(mode.porchMs, 2.0, accuracy: 0.001)
        XCTAssertEqual(mode.yDurationMs, 183.07, accuracy: 0.01)
        XCTAssertEqual(mode.cbDurationMs, 183.07, accuracy: 0.01)
        XCTAssertEqual(mode.crDurationMs, 183.07, accuracy: 0.01)

        // Verify frequency constants
        XCTAssertEqual(mode.syncFrequencyHz, 1200.0, accuracy: 0.1)
        XCTAssertEqual(mode.blackFrequencyHz, 1500.0, accuracy: 0.1)
        XCTAssertEqual(mode.whiteFrequencyHz, 2300.0, accuracy: 0.1)
        XCTAssertEqual(mode.frequencyRangeHz, 800.0, accuracy: 0.1)
    }

    func testPD180TimingDiffersFromPD120() {
        let pd120 = PD120Mode()
        let pd180 = PD180Mode()

        // Same dimensions
        XCTAssertEqual(pd120.width, pd180.width)
        XCTAssertEqual(pd120.height, pd180.height)

        // Same sync/frequency constants
        XCTAssertEqual(pd120.syncFrequencyHz, pd180.syncFrequencyHz)
        XCTAssertEqual(pd120.blackFrequencyHz, pd180.blackFrequencyHz)
        XCTAssertEqual(pd120.whiteFrequencyHz, pd180.whiteFrequencyHz)

        // PD180 has LONGER component durations than PD120
        // PD120 Y duration ~121.6ms vs PD180 ~183.07ms
        XCTAssertGreaterThan(pd180.yDurationMs, pd120.yDurationMs,
            "PD180 should have longer Y component duration than PD120")

        // PD180 should have a longer frame duration
        XCTAssertGreaterThan(pd180.frameDurationMs, pd120.frameDurationMs,
            "PD180 should have a longer frame duration than PD120")
    }

    func testLineDurationMs() {
        let mode = PD180Mode()

        // lineDurationMs should be frameDurationMs / linesPerFrame
        let expectedLineDuration = mode.frameDurationMs / Double(mode.linesPerFrame)
        XCTAssertEqual(mode.lineDurationMs, expectedLineDuration, accuracy: 0.01)
    }

    func testDecodeFrameWithSyntheticData() {
        let mode = PD180Mode()
        let sampleRate = 48000.0

        // Calculate expected frame length in samples
        let frameSamples = Int(mode.frameDurationMs * sampleRate / 1000.0)

        // Create synthetic frequency data
        // Use mid-gray (1900 Hz) for all components
        let midGrayFrequency = 1900.0
        var frequencies = [Double](repeating: midGrayFrequency, count: frameSamples)

        // Add sync pulse at the beginning (1200 Hz)
        let syncSamples = Int(mode.syncPulseMs * sampleRate / 1000.0)
        for i in 0..<syncSamples {
            frequencies[i] = mode.syncFrequencyHz
        }

        // Decode the frame
        let lines = mode.decodeFrame(
            frequencies: frequencies,
            sampleRate: sampleRate,
            frameIndex: 0
        )

        // Verify output structure — should return 2 lines
        XCTAssertEqual(lines.count, 2, "PD180 should decode 2 lines per frame")
        XCTAssertEqual(lines[0].count, mode.width * 3, "Even line should have width * 3 values")
        XCTAssertEqual(lines[1].count, mode.width * 3, "Odd line should have width * 3 values")

        // All pixels should be roughly mid-gray
        // With YCbCr at 0.5, we expect approximately RGB(0.5, 0.5, 0.5)
        for lineIndex in 0..<2 {
            let pixels = lines[lineIndex]
            for i in 0..<mode.width {
                let r = pixels[i * 3]
                let g = pixels[i * 3 + 1]
                let b = pixels[i * 3 + 2]

                XCTAssertGreaterThanOrEqual(r, 0.0, "R should be >= 0 (line \(lineIndex), pixel \(i))")
                XCTAssertLessThanOrEqual(r, 1.0, "R should be <= 1 (line \(lineIndex), pixel \(i))")
                XCTAssertGreaterThanOrEqual(g, 0.0, "G should be >= 0")
                XCTAssertLessThanOrEqual(g, 1.0, "G should be <= 1")
                XCTAssertGreaterThanOrEqual(b, 0.0, "B should be >= 0")
                XCTAssertLessThanOrEqual(b, 1.0, "B should be <= 1")
            }
        }
    }

    func testDecodeFrameWithBlackLuminance() {
        let mode = PD180Mode()
        let sampleRate = 48000.0

        // Calculate sample positions
        let frameSamples = Int(mode.frameDurationMs * sampleRate / 1000.0)
        let syncSamples = Int(mode.syncPulseMs * sampleRate / 1000.0)
        let porchSamples = Int(mode.porchMs * sampleRate / 1000.0)
        let yDurationSamples = Int(mode.yDurationMs * sampleRate / 1000.0)
        let crDurationSamples = Int(mode.crDurationMs * sampleRate / 1000.0)
        let cbDurationSamples = Int(mode.cbDurationMs * sampleRate / 1000.0)

        // Initialize with mid-gray (neutral chroma)
        var frequencies = [Double](repeating: 1900.0, count: frameSamples)

        // Sync pulse (1200 Hz)
        for i in 0..<syncSamples {
            frequencies[i] = mode.syncFrequencyHz
        }

        // Y0 (even line): set to black frequency (1500 Hz)
        let y0Start = syncSamples + porchSamples
        for i in y0Start..<(y0Start + yDurationSamples) {
            if i < frequencies.count {
                frequencies[i] = mode.blackFrequencyHz
            }
        }

        // Cr and Cb remain at 1900 Hz (neutral)

        // Y1 (odd line): also set to black frequency
        let y1Start = y0Start + yDurationSamples + crDurationSamples + cbDurationSamples
        for i in y1Start..<(y1Start + yDurationSamples) {
            if i < frequencies.count {
                frequencies[i] = mode.blackFrequencyHz
            }
        }

        // Decode the frame
        let lines = mode.decodeFrame(
            frequencies: frequencies,
            sampleRate: sampleRate,
            frameIndex: 0
        )

        // Both lines should have darker pixels due to black luminance
        for lineIndex in 0..<2 {
            let pixels = lines[lineIndex]
            let r = pixels[0]
            let g = pixels[1]
            let b = pixels[2]

            // With Y=0 and Cb/Cr=0.5, RGB values should be darker than 0.5
            XCTAssertLessThan(r, 0.5, "Expected darker R in line \(lineIndex) due to black luminance")
            XCTAssertLessThan(g, 0.5, "Expected darker G in line \(lineIndex) due to black luminance")
            XCTAssertLessThan(b, 0.5, "Expected darker B in line \(lineIndex) due to black luminance")
        }
    }

    func testDecodeLineWithSyntheticData() {
        let mode = PD180Mode()
        let sampleRate = 48000.0

        // Calculate expected frame length in samples (decodeLine needs full frame data)
        let frameSamples = Int(mode.frameDurationMs * sampleRate / 1000.0)

        // Create synthetic frequency data
        let midGrayFrequency = 1900.0
        var frequencies = [Double](repeating: midGrayFrequency, count: frameSamples)

        // Add sync pulse at the beginning (1200 Hz)
        let syncSamples = Int(mode.syncPulseMs * sampleRate / 1000.0)
        for i in 0..<syncSamples {
            frequencies[i] = mode.syncFrequencyHz
        }

        // Decode the even line via legacy interface
        let pixels = mode.decodeLine(
            frequencies: frequencies,
            sampleRate: sampleRate,
            lineIndex: 0
        )

        // Verify output structure
        XCTAssertEqual(pixels.count, mode.width * 3)

        // All pixels should be roughly mid-gray
        for i in 0..<mode.width {
            let r = pixels[i * 3]
            let g = pixels[i * 3 + 1]
            let b = pixels[i * 3 + 2]

            XCTAssertGreaterThanOrEqual(r, 0.0)
            XCTAssertLessThanOrEqual(r, 1.0)
            XCTAssertGreaterThanOrEqual(g, 0.0)
            XCTAssertLessThanOrEqual(g, 1.0)
            XCTAssertGreaterThanOrEqual(b, 0.0)
            XCTAssertLessThanOrEqual(b, 1.0)
        }
    }

    func testDecodeLineReturnsCorrectLineFromFrame() {
        let mode = PD180Mode()
        let sampleRate = 48000.0

        // Create frame data where Y0 = black, Y1 = white (distinguishable)
        let frameSamples = Int(mode.frameDurationMs * sampleRate / 1000.0)
        let syncSamples = Int(mode.syncPulseMs * sampleRate / 1000.0)
        let porchSamples = Int(mode.porchMs * sampleRate / 1000.0)
        let yDurationSamples = Int(mode.yDurationMs * sampleRate / 1000.0)
        let crDurationSamples = Int(mode.crDurationMs * sampleRate / 1000.0)
        let cbDurationSamples = Int(mode.cbDurationMs * sampleRate / 1000.0)

        var frequencies = [Double](repeating: 1900.0, count: frameSamples)

        // Sync
        for i in 0..<syncSamples {
            frequencies[i] = mode.syncFrequencyHz
        }

        // Y0: black (1500 Hz)
        let y0Start = syncSamples + porchSamples
        for i in y0Start..<(y0Start + yDurationSamples) {
            if i < frequencies.count { frequencies[i] = mode.blackFrequencyHz }
        }

        // Y1: white (2300 Hz)
        let y1Start = y0Start + yDurationSamples + crDurationSamples + cbDurationSamples
        for i in y1Start..<(y1Start + yDurationSamples) {
            if i < frequencies.count { frequencies[i] = mode.whiteFrequencyHz }
        }

        // decodeLine(lineIndex: 0) should return the even (dark) line
        let evenLine = mode.decodeLine(frequencies: frequencies, sampleRate: sampleRate, lineIndex: 0)
        let evenR = evenLine[0]

        // decodeLine(lineIndex: 1) should return the odd (bright) line
        let oddLine = mode.decodeLine(frequencies: frequencies, sampleRate: sampleRate, lineIndex: 1)
        let oddR = oddLine[0]

        // Odd line should be significantly brighter than even line
        XCTAssertGreaterThan(oddR, evenR,
            "Odd line (white Y) should be brighter than even line (black Y)")
    }

    func testDecodeFrameWithMultipleFrames() {
        let mode = PD180Mode()
        let sampleRate = 48000.0

        // Create synthetic data for a single frame
        let frameSamples = Int(mode.frameDurationMs * sampleRate / 1000.0)
        let frequencies = [Double](repeating: 1900.0, count: frameSamples)

        // Decode multiple frames to ensure no state corruption
        let frame0 = mode.decodeFrame(
            frequencies: frequencies,
            sampleRate: sampleRate,
            frameIndex: 0
        )

        let frame1 = mode.decodeFrame(
            frequencies: frequencies,
            sampleRate: sampleRate,
            frameIndex: 1
        )

        // Both frames should have valid structure
        XCTAssertEqual(frame0.count, 2)
        XCTAssertEqual(frame1.count, 2)
        XCTAssertEqual(frame0[0].count, mode.width * 3)
        XCTAssertEqual(frame1[0].count, mode.width * 3)
    }

    func testDecodeFrameWithDecodingOptions() {
        let mode = PD180Mode()
        let sampleRate = 48000.0

        let frameSamples = Int(mode.frameDurationMs * sampleRate / 1000.0)
        let frequencies = [Double](repeating: 1900.0, count: frameSamples)

        // Decode with default options
        let defaultResult = mode.decodeFrame(
            frequencies: frequencies,
            sampleRate: sampleRate,
            frameIndex: 0,
            options: .default
        )

        // Decode with custom phase offset
        let customOptions = DecodingOptions(phaseOffsetMs: 1.0, skewMsPerLine: 0.0)
        let shiftedResult = mode.decodeFrame(
            frequencies: frequencies,
            sampleRate: sampleRate,
            frameIndex: 0,
            options: customOptions
        )

        // Both should produce valid output
        XCTAssertEqual(defaultResult.count, 2)
        XCTAssertEqual(shiftedResult.count, 2)
        XCTAssertEqual(defaultResult[0].count, mode.width * 3)
        XCTAssertEqual(shiftedResult[0].count, mode.width * 3)
    }

    func testImageBufferIntegration() {
        let mode = PD180Mode()
        var buffer = ImageBuffer(width: mode.width, height: mode.height)

        // Create synthetic line data
        let linePixels = [Double](repeating: 0.5, count: mode.width * 3)

        // Set a row in the buffer
        buffer.setRow(y: 0, rowPixels: linePixels)

        // Verify buffer dimensions match mode
        XCTAssertEqual(buffer.width, mode.width)
        XCTAssertEqual(buffer.height, mode.height)
    }
}
