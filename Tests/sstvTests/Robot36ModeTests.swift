import XCTest
@testable import SSTVCore

/// Tests for Robot36 mode implementation
final class Robot36ModeTests: XCTestCase {

    func testRobot36ModeConstants() {
        let mode = Robot36Mode()

        // Verify mode identification
        XCTAssertEqual(mode.name, "Robot36")
        XCTAssertEqual(mode.visCode, 0x08)  // VIS code 8 (0x08) per Robot36 specification

        // Verify image dimensions
        XCTAssertEqual(mode.width, 320)
        XCTAssertEqual(mode.height, 240)

        // Verify timing constants
        // Robot36 transmits 2 lines per frame, line duration is 150.0ms
        XCTAssertEqual(mode.lineDurationMs, 150.0, accuracy: 0.001)
        XCTAssertEqual(mode.linesPerFrame, 2)
        XCTAssertEqual(mode.frameDurationMs, 300.0, accuracy: 0.001)
        XCTAssertEqual(mode.syncPulseMs, 9.0, accuracy: 0.001)
        XCTAssertEqual(mode.syncPorchMs, 3.0, accuracy: 0.001)
        XCTAssertEqual(mode.yDurationMs, 88.0, accuracy: 0.001)
        XCTAssertEqual(mode.separatorMs, 4.5, accuracy: 0.001)
        XCTAssertEqual(mode.chromaPorchMs, 1.5, accuracy: 0.001)
        XCTAssertEqual(mode.chromaDurationMs, 44.0, accuracy: 0.001)

        // Verify frequency constants
        XCTAssertEqual(mode.syncFrequencyHz, 1200.0, accuracy: 0.1)
        XCTAssertEqual(mode.blackFrequencyHz, 1500.0, accuracy: 0.1)
        XCTAssertEqual(mode.whiteFrequencyHz, 2300.0, accuracy: 0.1)
        XCTAssertEqual(mode.chromaZeroFrequencyHz, 1900.0, accuracy: 0.1)
        XCTAssertEqual(mode.frequencyRangeHz, 800.0, accuracy: 0.1)
    }

    func testFrequencyToLuminanceConversion() {
        let mode = Robot36Mode()

        // Test black frequency (1500 Hz) -> 0.0
        let blackFreq = mode.blackFrequencyHz
        let blackValue = mode.frequencyToLuminance(blackFreq)
        XCTAssertEqual(blackValue, 0.0, accuracy: 0.001, "Black frequency should map to 0.0")

        // Test white frequency (2300 Hz) -> 1.0
        let whiteFreq = mode.whiteFrequencyHz
        let whiteValue = mode.frequencyToLuminance(whiteFreq)
        XCTAssertEqual(whiteValue, 1.0, accuracy: 0.001, "White frequency should map to 1.0")

        // Test mid-gray (1900 Hz) -> 0.5
        let midGrayFreq = 1900.0
        let midGrayValue = mode.frequencyToLuminance(midGrayFreq)
        XCTAssertEqual(midGrayValue, 0.5, accuracy: 0.001, "Mid-gray frequency should map to 0.5")

        // Test clamping below range
        let belowBlackValue = mode.frequencyToLuminance(1000.0)
        XCTAssertEqual(belowBlackValue, 0.0, accuracy: 0.001, "Frequency below black should clamp to 0.0")

        // Test clamping above range
        let aboveWhiteValue = mode.frequencyToLuminance(3000.0)
        XCTAssertEqual(aboveWhiteValue, 1.0, accuracy: 0.001, "Frequency above white should clamp to 1.0")
    }

    func testFrequencyToChromaConversion() {
        let mode = Robot36Mode()

        // Test black frequency (1500 Hz) -> 0.0
        let blackFreq = mode.blackFrequencyHz
        let blackValue = mode.frequencyToChroma(blackFreq)
        XCTAssertEqual(blackValue, 0.0, accuracy: 0.001, "Black frequency should map to 0.0")

        // Test white frequency (2300 Hz) -> 1.0
        let whiteFreq = mode.whiteFrequencyHz
        let whiteValue = mode.frequencyToChroma(whiteFreq)
        XCTAssertEqual(whiteValue, 1.0, accuracy: 0.001, "White frequency should map to 1.0")

        // Test neutral chroma frequency (1900 Hz) -> 0.5
        let neutralFreq = mode.chromaZeroFrequencyHz
        let neutralValue = mode.frequencyToChroma(neutralFreq)
        XCTAssertEqual(neutralValue, 0.5, accuracy: 0.001, "Neutral frequency should map to 0.5")

        // Test clamping
        let belowValue = mode.frequencyToChroma(1000.0)
        XCTAssertEqual(belowValue, 0.0, accuracy: 0.001)

        let aboveValue = mode.frequencyToChroma(3000.0)
        XCTAssertEqual(aboveValue, 1.0, accuracy: 0.001)
    }

    func testYCbCrToRGBConversion() {
        let mode = Robot36Mode()

        // Test neutral gray (Y=0.5, Cb=0.5, Cr=0.5) -> RGB(0.5, 0.5, 0.5)
        let (r1, g1, b1) = mode.ycbcrToRGB(y: 0.5, cb: 0.5, cr: 0.5)
        XCTAssertEqual(r1, 0.5, accuracy: 0.01, "Neutral gray should produce R=0.5")
        XCTAssertEqual(g1, 0.5, accuracy: 0.01, "Neutral gray should produce G=0.5")
        XCTAssertEqual(b1, 0.5, accuracy: 0.01, "Neutral gray should produce B=0.5")

        // Test black (Y=0, Cb=0.5, Cr=0.5) -> RGB(0, 0, 0)
        let (r2, g2, b2) = mode.ycbcrToRGB(y: 0.0, cb: 0.5, cr: 0.5)
        XCTAssertEqual(r2, 0.0, accuracy: 0.01, "Black should produce R=0")
        XCTAssertEqual(g2, 0.0, accuracy: 0.01, "Black should produce G=0")
        XCTAssertEqual(b2, 0.0, accuracy: 0.01, "Black should produce B=0")

        // Test white (Y=1, Cb=0.5, Cr=0.5) -> RGB(1, 1, 1)
        let (r3, g3, b3) = mode.ycbcrToRGB(y: 1.0, cb: 0.5, cr: 0.5)
        XCTAssertEqual(r3, 1.0, accuracy: 0.01, "White should produce R=1")
        XCTAssertEqual(g3, 1.0, accuracy: 0.01, "White should produce G=1")
        XCTAssertEqual(b3, 1.0, accuracy: 0.01, "White should produce B=1")

        // Test red bias (Y=0.5, Cb=0.5, Cr=1.0) -> R should be higher
        let (r4, g4, b4) = mode.ycbcrToRGB(y: 0.5, cb: 0.5, cr: 1.0)
        XCTAssertGreaterThan(r4, g4, "Red chrominance should increase red component")
        XCTAssertGreaterThan(r4, b4, "Red chrominance should increase red component")

        // Test blue bias (Y=0.5, Cb=1.0, Cr=0.5) -> B should be higher
        let (r5, g5, b5) = mode.ycbcrToRGB(y: 0.5, cb: 1.0, cr: 0.5)
        XCTAssertGreaterThan(b5, r5, "Blue chrominance should increase blue component")
        XCTAssertGreaterThan(b5, g5, "Blue chrominance should increase blue component")

        // Test clamping - values should stay in [0, 1] range
        let (r6, g6, b6) = mode.ycbcrToRGB(y: 1.5, cb: 1.5, cr: 1.5)
        XCTAssertLessThanOrEqual(r6, 1.0, "RGB values should be clamped to 1.0")
        XCTAssertLessThanOrEqual(g6, 1.0, "RGB values should be clamped to 1.0")
        XCTAssertLessThanOrEqual(b6, 1.0, "RGB values should be clamped to 1.0")
    }

    func testDecodeFrameWithSyntheticData() {
        let mode = Robot36Mode()
        let sampleRate = 48000.0

        // Calculate expected frame length in samples
        let frameSamples = Int(mode.frameDurationMs * sampleRate / 1000.0)

        // Create synthetic frequency data
        // For simplicity, use mid-gray (1900 Hz) for all components
        let midGrayFrequency = 1900.0
        var frequencies = [Double](repeating: midGrayFrequency, count: frameSamples)

        // Add sync pulses at the beginning of each line (1200 Hz)
        let syncSamples = Int(mode.syncPulseMs * sampleRate / 1000.0)
        for i in 0..<syncSamples {
            frequencies[i] = mode.syncFrequencyHz
        }

        // Second line sync (after line duration)
        let secondLineSamples = Int(mode.lineDurationMs * sampleRate / 1000.0)
        for i in secondLineSamples..<(secondLineSamples + syncSamples) {
            if i < frequencies.count {
                frequencies[i] = mode.syncFrequencyHz
            }
        }

        // Decode the frame
        let lines = mode.decodeFrame(
            frequencies: frequencies,
            sampleRate: sampleRate,
            frameIndex: 0
        )

        // Verify output structure - should return 2 lines
        XCTAssertEqual(lines.count, 2, "Robot36 should decode 2 lines per frame")
        XCTAssertEqual(lines[0].count, mode.width * 3, "Each line should have width * 3 pixels")
        XCTAssertEqual(lines[1].count, mode.width * 3, "Each line should have width * 3 pixels")

        // All pixels should be roughly mid-gray
        // With YCbCr at 0.5, we should get approximately RGB(0.5, 0.5, 0.5)
        for lineIndex in 0..<2 {
            let pixels = lines[lineIndex]
            for i in 0..<mode.width {
                let r = pixels[i * 3]
                let g = pixels[i * 3 + 1]
                let b = pixels[i * 3 + 2]

                // Values should be in valid range
                XCTAssertGreaterThanOrEqual(r, 0.0, "R should be >= 0")
                XCTAssertLessThanOrEqual(r, 1.0, "R should be <= 1")
                XCTAssertGreaterThanOrEqual(g, 0.0, "G should be >= 0")
                XCTAssertLessThanOrEqual(g, 1.0, "G should be <= 1")
                XCTAssertGreaterThanOrEqual(b, 0.0, "B should be >= 0")
                XCTAssertLessThanOrEqual(b, 1.0, "B should be <= 1")
            }
        }
    }

    func testDecodeFrameWithBlackLuminance() {
        let mode = Robot36Mode()
        let sampleRate = 48000.0

        // Calculate sample positions
        let frameSamples = Int(mode.frameDurationMs * sampleRate / 1000.0)
        let syncSamples = Int(mode.syncPulseMs * sampleRate / 1000.0)
        let porchSamples = Int(mode.syncPorchMs * sampleRate / 1000.0)
        let yDurationSamples = Int(mode.yDurationMs * sampleRate / 1000.0)

        // Initialize with mid-gray
        var frequencies = [Double](repeating: 1900.0, count: frameSamples)

        // First line (even) - Y component to black
        let evenYStart = syncSamples + porchSamples
        for i in evenYStart..<(evenYStart + yDurationSamples) {
            if i < frequencies.count {
                frequencies[i] = mode.blackFrequencyHz
            }
        }

        // Second line (odd) - Y component to black
        let lineSamples = Int(mode.lineDurationMs * sampleRate / 1000.0)
        let oddYStart = lineSamples + syncSamples + porchSamples
        for i in oddYStart..<(oddYStart + yDurationSamples) {
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
            XCTAssertLessThan(r, 0.5, "Expected darker pixel in line \(lineIndex) due to black luminance")
            XCTAssertLessThan(g, 0.5, "Expected darker pixel in line \(lineIndex) due to black luminance")
            XCTAssertLessThan(b, 0.5, "Expected darker pixel in line \(lineIndex) due to black luminance")
        }
    }

    func testDecodeLineBackwardCompatibility() {
        let mode = Robot36Mode()
        let sampleRate = 48000.0

        // Create synthetic data for a full frame
        let frameSamples = Int(mode.frameDurationMs * sampleRate / 1000.0)
        let frequencies = [Double](repeating: 1900.0, count: frameSamples)

        // Test that decodeLine() works for both even and odd lines
        let evenLinePixels = mode.decodeLine(
            frequencies: frequencies,
            sampleRate: sampleRate,
            lineIndex: 0
        )
        XCTAssertEqual(evenLinePixels.count, mode.width * 3)

        let oddLinePixels = mode.decodeLine(
            frequencies: frequencies,
            sampleRate: sampleRate,
            lineIndex: 1
        )
        XCTAssertEqual(oddLinePixels.count, mode.width * 3)
    }

    func testImageBufferIntegration() {
        let mode = Robot36Mode()
        var buffer = ImageBuffer(width: mode.width, height: mode.height)

        // Create synthetic line data
        let linePixels = [Double](repeating: 0.5, count: mode.width * 3)

        // Set a row in the buffer
        buffer.setRow(y: 0, rowPixels: linePixels)

        // Verify buffer dimensions match mode
        XCTAssertEqual(buffer.width, mode.width)
        XCTAssertEqual(buffer.height, mode.height)
    }

    func testDecodeFrameWithMultipleFrames() {
        let mode = Robot36Mode()
        let sampleRate = 48000.0

        // Create synthetic data
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

    // MARK: - C5 Extended Tests

    func testDecodeFrameWithWhiteLuminance() {
        let mode = Robot36Mode()
        let sampleRate = 48000.0

        let frameSamples = Int(mode.frameDurationMs * sampleRate / 1000.0)
        let syncSamples = Int(mode.syncPulseMs * sampleRate / 1000.0)
        let porchSamples = Int(mode.syncPorchMs * sampleRate / 1000.0)
        let yDurationSamples = Int(mode.yDurationMs * sampleRate / 1000.0)

        // Initialize with mid-gray (1900 Hz for chroma = neutral)
        var frequencies = [Double](repeating: 1900.0, count: frameSamples)

        // Even line: set Y component to white (2300 Hz)
        let evenYStart = syncSamples + porchSamples
        for i in evenYStart..<(evenYStart + yDurationSamples) {
            if i < frequencies.count {
                frequencies[i] = mode.whiteFrequencyHz
            }
        }

        // Odd line: set Y component to white (2300 Hz)
        let lineSamples = Int(mode.lineDurationMs * sampleRate / 1000.0)
        let oddYStart = lineSamples + syncSamples + porchSamples
        for i in oddYStart..<(oddYStart + yDurationSamples) {
            if i < frequencies.count {
                frequencies[i] = mode.whiteFrequencyHz
            }
        }

        let lines = mode.decodeFrame(
            frequencies: frequencies,
            sampleRate: sampleRate,
            frameIndex: 0
        )

        XCTAssertEqual(lines.count, 2, "Should decode 2 lines per frame")

        // Both lines should have brighter pixels due to white luminance
        for lineIndex in 0..<2 {
            let pixels = lines[lineIndex]
            let r = pixels[0]
            let g = pixels[1]
            let b = pixels[2]

            // With Y=1.0 and Cb/Cr=0.5 (neutral chroma), RGB should be ~1.0
            XCTAssertGreaterThan(r, 0.5, "Expected bright pixel R in line \(lineIndex) due to white luminance")
            XCTAssertGreaterThan(g, 0.5, "Expected bright pixel G in line \(lineIndex) due to white luminance")
            XCTAssertGreaterThan(b, 0.5, "Expected bright pixel B in line \(lineIndex) due to white luminance")
        }
    }

    func testChromaLineHandling() {
        let mode = Robot36Mode()
        let sampleRate = 48000.0

        let frameSamples = Int(mode.frameDurationMs * sampleRate / 1000.0)
        let syncSamples = Int(mode.syncPulseMs * sampleRate / 1000.0)
        let porchSamples = Int(mode.syncPorchMs * sampleRate / 1000.0)
        let yDurationSamples = Int(mode.yDurationMs * sampleRate / 1000.0)
        let separatorSamples = Int(mode.separatorMs * sampleRate / 1000.0)
        let chromaPorchSamples = Int(mode.chromaPorchMs * sampleRate / 1000.0)
        let chromaDurationSamples = Int(mode.chromaDurationMs * sampleRate / 1000.0)
        let lineSamples = Int(mode.lineDurationMs * sampleRate / 1000.0)

        // Start with mid-gray luminance (1900 Hz) everywhere
        var frequencies = [Double](repeating: 1900.0, count: frameSamples)

        // Add sync pulses
        for i in 0..<syncSamples {
            frequencies[i] = mode.syncFrequencyHz
        }
        for i in lineSamples..<(lineSamples + syncSamples) {
            if i < frequencies.count {
                frequencies[i] = mode.syncFrequencyHz
            }
        }

        // Even line R-Y chroma → max (2300 Hz) for red bias
        let evenCrStart = syncSamples + porchSamples + yDurationSamples + separatorSamples + chromaPorchSamples
        for i in evenCrStart..<(evenCrStart + chromaDurationSamples) {
            if i < frequencies.count {
                frequencies[i] = mode.whiteFrequencyHz  // 2300 Hz = max Cr
            }
        }

        // Odd line B-Y chroma → max (2300 Hz) for blue bias
        let oddCbStart = lineSamples + syncSamples + porchSamples + yDurationSamples + separatorSamples + chromaPorchSamples
        for i in oddCbStart..<(oddCbStart + chromaDurationSamples) {
            if i < frequencies.count {
                frequencies[i] = mode.whiteFrequencyHz  // 2300 Hz = max Cb
            }
        }

        let lines = mode.decodeFrame(
            frequencies: frequencies,
            sampleRate: sampleRate,
            frameIndex: 0
        )

        XCTAssertEqual(lines.count, 2)

        // Both lines see Cr=1.0 (max red chroma) and Cb=1.0 (max blue chroma)
        // With Y=0.5, Cr=1.0, Cb=1.0:
        //   R = 0.5 + 1.402 * 0.5 = 1.201 → clamped to 1.0
        //   G = 0.5 - 0.344136 * 0.5 - 0.714136 * 0.5 = -0.029 → clamped to 0.0
        //   B = 0.5 + 1.772 * 0.5 = 1.386 → clamped to 1.0
        // So both lines should have high R, low G, high B
        for lineIndex in 0..<2 {
            let pixels = lines[lineIndex]
            let r = pixels[0]
            let g = pixels[1]
            let b = pixels[2]

            XCTAssertGreaterThan(r, 0.5, "Line \(lineIndex) should have elevated red due to Cr=1.0")
            XCTAssertGreaterThan(b, 0.5, "Line \(lineIndex) should have elevated blue due to Cb=1.0")
            XCTAssertLessThan(g, 0.5, "Line \(lineIndex) green should be reduced with both chroma maxed")
        }
    }

    func testSeparatorFrequencies() {
        let mode = Robot36Mode()
        let sampleRate = 48000.0

        // Verify separator timing constant
        XCTAssertEqual(mode.separatorMs, 4.5, accuracy: 0.001,
                       "Separator duration should be 4.5ms")

        // Create a frame with correct separator placement at 1500 Hz
        let frameSamples = Int(mode.frameDurationMs * sampleRate / 1000.0)
        let syncSamples = Int(mode.syncPulseMs * sampleRate / 1000.0)
        let porchSamples = Int(mode.syncPorchMs * sampleRate / 1000.0)
        let yDurationSamples = Int(mode.yDurationMs * sampleRate / 1000.0)
        let separatorSamples = Int(mode.separatorMs * sampleRate / 1000.0)
        let lineSamples = Int(mode.lineDurationMs * sampleRate / 1000.0)

        var frequencies = [Double](repeating: 1900.0, count: frameSamples)

        // Place separators at the correct position (1500 Hz)
        let evenSepStart = syncSamples + porchSamples + yDurationSamples
        for i in evenSepStart..<(evenSepStart + separatorSamples) {
            if i < frequencies.count {
                frequencies[i] = mode.blackFrequencyHz  // 1500 Hz separator
            }
        }

        let oddSepStart = lineSamples + syncSamples + porchSamples + yDurationSamples
        for i in oddSepStart..<(oddSepStart + separatorSamples) {
            if i < frequencies.count {
                frequencies[i] = mode.blackFrequencyHz  // 1500 Hz separator
            }
        }

        // Decode should still work correctly with separators in place
        let lines = mode.decodeFrame(
            frequencies: frequencies,
            sampleRate: sampleRate,
            frameIndex: 0
        )

        XCTAssertEqual(lines.count, 2, "Should decode 2 lines even with separators present")
        XCTAssertEqual(lines[0].count, mode.width * 3, "Line 0 pixel count should be correct")
        XCTAssertEqual(lines[1].count, mode.width * 3, "Line 1 pixel count should be correct")

        // Pixels should be in valid range
        for lineIndex in 0..<2 {
            for i in 0..<(mode.width * 3) {
                XCTAssertGreaterThanOrEqual(lines[lineIndex][i], 0.0,
                    "Pixel values should be >= 0 in line \(lineIndex)")
                XCTAssertLessThanOrEqual(lines[lineIndex][i], 1.0,
                    "Pixel values should be <= 1 in line \(lineIndex)")
            }
        }
    }

    func testChromaZeroFrequency() {
        let mode = Robot36Mode()
        let sampleRate = 48000.0

        // Verify the chroma zero frequency
        XCTAssertEqual(mode.chromaZeroFrequencyHz, 1900.0, accuracy: 0.1,
                       "Chroma zero reference should be 1900 Hz")

        // When all chroma is at 1900 Hz (neutral), colors should be gray
        let frameSamples = Int(mode.frameDurationMs * sampleRate / 1000.0)
        let frequencies = [Double](repeating: 1900.0, count: frameSamples)

        let lines = mode.decodeFrame(
            frequencies: frequencies,
            sampleRate: sampleRate,
            frameIndex: 0
        )

        // With Y=0.5 (from 1900 Hz luminance) and Cb=Cr=0.5 (neutral chroma),
        // RGB should all be approximately 0.5 (neutral gray)
        for lineIndex in 0..<2 {
            let pixels = lines[lineIndex]
            // Sample multiple pixels to verify consistency
            for pixelIndex in stride(from: 0, to: min(30, mode.width), by: 10) {
                let r = pixels[pixelIndex * 3]
                let g = pixels[pixelIndex * 3 + 1]
                let b = pixels[pixelIndex * 3 + 2]

                XCTAssertEqual(r, 0.5, accuracy: 0.05,
                    "Neutral chroma should produce gray R≈0.5 at pixel \(pixelIndex) line \(lineIndex) (got \(r))")
                XCTAssertEqual(g, 0.5, accuracy: 0.05,
                    "Neutral chroma should produce gray G≈0.5 at pixel \(pixelIndex) line \(lineIndex) (got \(g))")
                XCTAssertEqual(b, 0.5, accuracy: 0.05,
                    "Neutral chroma should produce gray B≈0.5 at pixel \(pixelIndex) line \(lineIndex) (got \(b))")
            }
        }
    }

    func testDecodeFrameWithOptions() {
        let mode = Robot36Mode()
        let sampleRate = 48000.0

        let frameSamples = Int(mode.frameDurationMs * sampleRate / 1000.0)

        // Create a gradient from black to white across the luminance region
        let syncSamples = Int(mode.syncPulseMs * sampleRate / 1000.0)
        let porchSamples = Int(mode.syncPorchMs * sampleRate / 1000.0)
        let yDurationSamples = Int(mode.yDurationMs * sampleRate / 1000.0)

        var frequencies = [Double](repeating: 1900.0, count: frameSamples)

        // Even line: create a gradient in Y region (black→white)
        let evenYStart = syncSamples + porchSamples
        for i in 0..<yDurationSamples {
            let t = Double(i) / Double(yDurationSamples)
            let freq = mode.blackFrequencyHz + t * mode.frequencyRangeHz
            if evenYStart + i < frequencies.count {
                frequencies[evenYStart + i] = freq
            }
        }

        // Decode with default options
        let defaultResult = mode.decodeFrame(
            frequencies: frequencies,
            sampleRate: sampleRate,
            frameIndex: 0,
            options: .default
        )

        // Decode with non-zero phase offset
        let shiftedOptions = DecodingOptions(phaseOffsetMs: 5.0)
        let shiftedResult = mode.decodeFrame(
            frequencies: frequencies,
            sampleRate: sampleRate,
            frameIndex: 0,
            options: shiftedOptions
        )

        // The shifted result should differ from the default
        XCTAssertEqual(defaultResult.count, 2)
        XCTAssertEqual(shiftedResult.count, 2)

        // Compare even-line pixels - with a gradient, phase shift means different pixel values
        var differenceFound = false
        for i in 0..<(mode.width * 3) {
            if abs(defaultResult[0][i] - shiftedResult[0][i]) > 0.001 {
                differenceFound = true
                break
            }
        }

        XCTAssertTrue(
            differenceFound,
            "Phase-shifted decode should produce different pixel values from default"
        )
    }

    func testFrameTimingAccuracy() {
        let mode = Robot36Mode()

        // Verify individual line timing components sum correctly
        let expectedLineDurationMs =
            mode.syncPulseMs +       // 9.0
            mode.syncPorchMs +       // 3.0
            mode.yDurationMs +       // 88.0
            mode.separatorMs +       // 4.5
            mode.chromaPorchMs +     // 1.5
            mode.chromaDurationMs    // 44.0

        XCTAssertEqual(
            expectedLineDurationMs, 150.0, accuracy: 0.001,
            "Line timing components should sum to 150.0ms (got \(expectedLineDurationMs))"
        )

        XCTAssertEqual(
            mode.lineDurationMs, expectedLineDurationMs, accuracy: 0.001,
            "lineDurationMs should match the sum of timing components"
        )

        // Verify frame = 2 × line
        let expectedFrameDurationMs = mode.lineDurationMs * Double(mode.linesPerFrame)
        XCTAssertEqual(
            mode.frameDurationMs, expectedFrameDurationMs, accuracy: 0.001,
            "Frame duration should be 2 × line duration = 300.0ms (got \(mode.frameDurationMs))"
        )

        XCTAssertEqual(
            mode.frameDurationMs, 300.0, accuracy: 0.001,
            "Frame duration should be 300.0ms"
        )

        // Verify lines per frame
        XCTAssertEqual(mode.linesPerFrame, 2, "Robot36 transmits 2 lines per frame")
    }
}
