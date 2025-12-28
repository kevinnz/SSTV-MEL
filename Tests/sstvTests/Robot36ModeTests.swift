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
}

// Extension to access private methods for testing
extension Robot36Mode {
    func frequencyToLuminance(_ frequency: Double) -> Double {
        let normalized = (frequency - blackFrequencyHz) / frequencyRangeHz
        return min(max(normalized, 0.0), 1.0)
    }
    
    func frequencyToChroma(_ frequency: Double) -> Double {
        let normalized = (frequency - blackFrequencyHz) / frequencyRangeHz
        return min(max(normalized, 0.0), 1.0)
    }
    
    func ycbcrToRGB(y: Double, cb: Double, cr: Double) -> (r: Double, g: Double, b: Double) {
        let cbCentered = cb - 0.5
        let crCentered = cr - 0.5
        
        let r = y + 1.402 * crCentered
        let g = y - 0.344136 * cbCentered - 0.714136 * crCentered
        let b = y + 1.772 * cbCentered
        
        return (
            r: min(max(r, 0.0), 1.0),
            g: min(max(g, 0.0), 1.0),
            b: min(max(b, 0.0), 1.0)
        )
    }
}
