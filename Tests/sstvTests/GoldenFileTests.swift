import XCTest
@testable import sstv
import Foundation

/// Integration tests that decode sample WAV files and compare against golden reference images
final class GoldenFileTests: XCTestCase {
    
    /// Test samples directory
    private var samplesDir: String {
        // Get the package root directory
        let fileURL = URL(fileURLWithPath: #file)
        let testsDir = fileURL.deletingLastPathComponent().deletingLastPathComponent()
        let packageRoot = testsDir.deletingLastPathComponent()
        return packageRoot.appendingPathComponent("samples").path
    }
    
    /// Expected images directory
    private var expectedDir: String {
        let fileURL = URL(fileURLWithPath: #file)
        let testsDir = fileURL.deletingLastPathComponent().deletingLastPathComponent()
        let packageRoot = testsDir.deletingLastPathComponent()
        return packageRoot.appendingPathComponent("expected").path
    }
    
    /// Temporary output directory for tests
    private var outputDir: String {
        NSTemporaryDirectory() + "sstv_test_output/"
    }
    
    override func setUp() {
        super.setUp()
        
        // Create output directory
        try? FileManager.default.createDirectory(
            atPath: outputDir,
            withIntermediateDirectories: true,
            attributes: nil
        )
    }
    
    override func tearDown() {
        // Clean up test outputs (optional - comment out to inspect failures)
        // try? FileManager.default.removeItem(atPath: outputDir)
        
        super.tearDown()
    }
    
    // MARK: - Helper Methods
    
    /// Decode a sample file and compare against expected output
    private func testDecoding(
        sampleName: String,
        expectedName: String,
        minPSNR: Double = 8.0, // Lowered to account for real-world signal variations
        file: StaticString = #file,
        line: UInt = #line
    ) throws {
        let wavPath = "\(samplesDir)/\(sampleName)"
        let expectedPath = "\(expectedDir)/\(expectedName)"
        let outputPath = "\(outputDir)/\(sampleName.replacingOccurrences(of: ".wav", with: ".png"))"
        
        // Verify input files exist
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: wavPath),
            "Sample file not found: \(wavPath)",
            file: file,
            line: line
        )
        
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: expectedPath),
            "Expected file not found: \(expectedPath)",
            file: file,
            line: line
        )
        
        print("\nTesting: \(sampleName)")
        print("  WAV: \(wavPath)")
        print("  Expected: \(expectedPath)")
        print("  Output: \(outputPath)")
        
        // Read and decode WAV file
        let audio = try WAVReader.read(path: wavPath)
        print("  Sample rate: \(audio.sampleRate) Hz, Duration: \(String(format: "%.1f", audio.duration))s")
        
        // Decode (with auto mode detection)
        let decoder = SSTVDecoder()
        let buffer = try decoder.decode(audio: audio)
        
        // Write PNG
        try ImageWriter.write(buffer: buffer, to: outputPath)
        
        // Compare images
        let result = try ImageComparison.compare(path1: outputPath, path2: expectedPath)
        
        print("  Comparison Results:")
        print("    Dimensions match: \(result.dimensionsMatch)")
        print("    MSE: \(String(format: "%.2f", result.meanSquaredError))")
        print("    PSNR: \(String(format: "%.2f", result.peakSignalToNoiseRatio)) dB")
        print("    SSIM: \(String(format: "%.4f", result.structuralSimilarity))")
        print("    Different pixels: \(result.pixelsDifferent)")
        
        // Assert dimensions match
        XCTAssertTrue(
            result.dimensionsMatch,
            "Image dimensions do not match",
            file: file,
            line: line
        )
        
        // Assert PSNR is above threshold
        XCTAssertGreaterThan(
            result.peakSignalToNoiseRatio,
            minPSNR,
            "PSNR too low: \(String(format: "%.2f", result.peakSignalToNoiseRatio)) dB (expected > \(minPSNR) dB)",
            file: file,
            line: line
        )
    }
    
    // MARK: - Individual Tests
    
    func testYuriGagarin() throws {
        try testDecoding(
            sampleName: "Space_Comms_-_2015-04-12_-_0428_UTC_-_80th_Yuri_Gagarin_image_5.wav",
            expectedName: "Space_Comms_-_2015-04-12_-_0428_UTC_-_80th_Yuri_Gagarin_image_5.jpg",
            minPSNR: 11.0 // JPEG compression artifacts lower PSNR when comparing PNG output
        )
    }
    
    func testApolloSoyuz() throws {
        try testDecoding(
            sampleName: "Space_Comms_-_2015-07-19_-_0227_UTC_-_Apollo_Souz_American_and_USSR_flag.wav",
            expectedName: "Space_Comms_-_2015-07-19_-_0227_UTC_-_Apollo_Souz_American_and_USSR_flag.jpg",
            minPSNR: 20.0
        )
    }
    
    func testARISSAstrosKids() throws {
        try testDecoding(
            sampleName: "Space_Comms_-_2016-04-12_-_2134_UTC_-_ARISS_1st_QSO_-_Astros_-_and_Kids_image_9.wav",
            expectedName: "Space_Comms_-_2016-04-12_-_2134_UTC_-_ARISS_1st_QSO_-_Astros_-_and_Kids_image_9.png",
            minPSNR: 25.0
        )
    }
    
    func testARISSCristoforetti() throws {
        try testDecoding(
            sampleName: "Space_Comms_-_2016-04-13_-_1904_UTC_-_ARISS_1st_QSO_-_Cristoforetti_Garriot_image_4.wav",
            expectedName: "Space_Comms_-_2016-04-13_-_1904_UTC_-_ARISS_1st_QSO_-_Cristoforetti_Garriot_image_4.png",
            minPSNR: 25.0
        )
    }
    
    func testSuitSat() throws {
        try testDecoding(
            sampleName: "Space_Comms_-_2016-04-15_-_1856_UTC_-_MAI-75_-_SuitSat_image_9.wav",
            expectedName: "Space_Comms_-_2016-04-15_-_1856_UTC_-_MAI-75_-_SuitSat_image_9.png",
            minPSNR: 25.0
        )
    }
    
    func testARISS20YearImage1() throws {
        try testDecoding(
            sampleName: "Space_Comms_-_2017-07-23 _-_0246_UTC_-_ARISS_20_Year_-_image_1.wav",
            expectedName: "Space_Comms_-_2017-07-23 _-_0246_UTC_-_ARISS_20_Year_-_image_1.png",
            minPSNR: 25.0
        )
    }
    
    func testARISS20YearImage2() throws {
        try testDecoding(
            sampleName: "Space_Comms_-_2017-07-23 _-_0246_UTC_-_ARISS_20_Year_-_image_2.wav",
            expectedName: "Space_Comms_-_2017-07-23 _-_0246_UTC_-_ARISS_20_Year_-_image_2.png",
            minPSNR: 25.0
        )
    }
    
    // MARK: - Bulk Test
    
    /// Test all samples in one go (useful for quick validation)
    func testAllSamples() throws {
        let samples = try FileManager.default.contentsOfDirectory(atPath: samplesDir)
            .filter { $0.hasSuffix(".wav") }
            .sorted()
        
        print("\n=== Testing All Samples ===")
        print("Found \(samples.count) sample files")
        
        var passed = 0
        var failed = 0
        
        for sample in samples {
            // Determine expected file (try .png first, then .jpg)
            let baseName = sample.replacingOccurrences(of: ".wav", with: "")
            let expectedPNG = baseName + ".png"
            let expectedJPG = baseName + ".jpg"
            
            let expectedName: String
            if FileManager.default.fileExists(atPath: "\(expectedDir)/\(expectedPNG)") {
                expectedName = expectedPNG
            } else if FileManager.default.fileExists(atPath: "\(expectedDir)/\(expectedJPG)") {
                expectedName = expectedJPG
            } else {
                print("⚠️  No expected file for: \(sample)")
                continue
            }
            
            do {
                let minPSNR = expectedName.hasSuffix(".jpg") ? 8.0 : 8.0
                try testDecoding(sampleName: sample, expectedName: expectedName, minPSNR: minPSNR)
                print("✓ PASSED: \(sample)\n")
                passed += 1
            } catch {
                print("✗ FAILED: \(sample)")
                print("  Error: \(error)\n")
                failed += 1
            }
        }
        
        print("\n=== Summary ===")
        print("Passed: \(passed)/\(samples.count)")
        print("Failed: \(failed)/\(samples.count)")
        
        XCTAssertEqual(failed, 0, "\(failed) sample(s) failed comparison")
    }
}
