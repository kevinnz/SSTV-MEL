import XCTest
@testable import SSTVCore

/// Tests for PD120 mode implementation
final class PD120ModeTests: XCTestCase {
    
    func testPD120ModeConstants() {
        let mode = PD120Mode()
        
        // Verify mode identification
        XCTAssertEqual(mode.name, "PD120")
        XCTAssertEqual(mode.visCode, 0x63)
        
        // Verify image dimensions
        XCTAssertEqual(mode.width, 640)
        XCTAssertEqual(mode.height, 496)
        
        // Verify timing constants
        XCTAssertEqual(mode.lineDurationMs, 126.432, accuracy: 0.001)
        XCTAssertEqual(mode.syncPulseMs, 20.0, accuracy: 0.001)
        XCTAssertEqual(mode.porchMs, 2.08, accuracy: 0.001)
        
        // Verify frequency constants
        XCTAssertEqual(mode.syncFrequencyHz, 1200.0, accuracy: 0.1)
        XCTAssertEqual(mode.blackFrequencyHz, 1500.0, accuracy: 0.1)
        XCTAssertEqual(mode.whiteFrequencyHz, 2300.0, accuracy: 0.1)
        XCTAssertEqual(mode.frequencyRangeHz, 800.0, accuracy: 0.1)
    }
    
    func testDecodeLineWithSyntheticData() {
        let mode = PD120Mode()
        let sampleRate = 48000.0
        
        // Calculate expected line length in samples
        let lineSamples = Int(mode.lineDurationMs * sampleRate / 1000.0)
        
        // Create synthetic frequency data
        // For simplicity, use mid-gray (1900 Hz) for all components
        let midGrayFrequency = 1900.0
        var frequencies = [Double](repeating: midGrayFrequency, count: lineSamples)
        
        // Add sync pulse at the beginning (1200 Hz)
        let syncSamples = Int(mode.syncPulseMs * sampleRate / 1000.0)
        for i in 0..<syncSamples {
            frequencies[i] = mode.syncFrequencyHz
        }
        
        // Decode the line
        let pixels = mode.decodeLine(
            frequencies: frequencies,
            sampleRate: sampleRate,
            lineIndex: 0
        )
        
        // Verify output structure
        XCTAssertEqual(pixels.count, mode.width * 3)
        
        // All pixels should be roughly mid-gray
        // With YCbCr at 0.5, we should get approximately RGB(0.5, 0.5, 0.5)
        for i in 0..<mode.width {
            let r = pixels[i * 3]
            let g = pixels[i * 3 + 1]
            let b = pixels[i * 3 + 2]
            
            // Values should be in valid range
            XCTAssertGreaterThanOrEqual(r, 0.0)
            XCTAssertLessThanOrEqual(r, 1.0)
            XCTAssertGreaterThanOrEqual(g, 0.0)
            XCTAssertLessThanOrEqual(g, 1.0)
            XCTAssertGreaterThanOrEqual(b, 0.0)
            XCTAssertLessThanOrEqual(b, 1.0)
        }
    }
    
    func testDecodeLineWithBlackAndWhite() {
        let mode = PD120Mode()
        let sampleRate = 48000.0
        
        // Calculate sample counts
        let lineSamples = Int(mode.lineDurationMs * sampleRate / 1000.0)
        let syncSamples = Int(mode.syncPulseMs * sampleRate / 1000.0)
        let porchSamples = Int(mode.porchMs * sampleRate / 1000.0)
        let ySamples = Int(mode.yDurationMs * sampleRate / 1000.0)
        
        var frequencies = [Double](repeating: 1900.0, count: lineSamples)
        
        // Sync pulse
        for i in 0..<syncSamples {
            frequencies[i] = mode.syncFrequencyHz
        }
        
        // Y component: black (1500 Hz)
        let yStart = syncSamples + porchSamples
        for i in yStart..<(yStart + ySamples) {
            frequencies[i] = mode.blackFrequencyHz
        }
        
        // Cb and Cr: mid-value (1900 Hz) for neutral color
        
        // Decode the line
        let pixels = mode.decodeLine(
            frequencies: frequencies,
            sampleRate: sampleRate,
            lineIndex: 0
        )
        
        // First pixel should be darker than mid-gray due to black luminance
        let r0 = pixels[0]
        let g0 = pixels[1]
        let b0 = pixels[2]
        
        // With Y=0 and Cb/Cr=0.5, RGB values should be darker than 0.5
        XCTAssertLessThan(r0, 0.5, "Expected darker pixel due to black luminance")
        XCTAssertLessThan(g0, 0.5, "Expected darker pixel due to black luminance")
        XCTAssertLessThan(b0, 0.5, "Expected darker pixel due to black luminance")
    }
    
    func testImageBufferIntegration() {
        let mode = PD120Mode()
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
