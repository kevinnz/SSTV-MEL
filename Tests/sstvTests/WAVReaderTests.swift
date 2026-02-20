import XCTest
@testable import SSTVCore

/// Tests for WAVReader and WAVFile
final class WAVReaderTests: XCTestCase {

    // MARK: - Helper: Build a valid WAV file in memory

    /// Build a minimal 16-bit PCM WAV file from raw samples
    private func buildWAV16(
        sampleRate: UInt32 = 44100,
        channels: UInt16 = 1,
        samples: [Int16]
    ) -> Data {
        let bitsPerSample: UInt16 = 16
        let blockAlign = channels * (bitsPerSample / 8)
        let byteRate = sampleRate * UInt32(blockAlign)
        let dataSize = UInt32(samples.count * 2)
        let fileSize = 36 + dataSize

        var data = Data()
        data.append(contentsOf: "RIFF".utf8)
        data.append(contentsOf: withUnsafeBytes(of: fileSize.littleEndian) { Array($0) })
        data.append(contentsOf: "WAVE".utf8)

        // fmt chunk
        data.append(contentsOf: "fmt ".utf8)
        data.append(contentsOf: withUnsafeBytes(of: UInt32(16).littleEndian) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: UInt16(1).littleEndian) { Array($0) }) // PCM
        data.append(contentsOf: withUnsafeBytes(of: channels.littleEndian) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: sampleRate.littleEndian) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: byteRate.littleEndian) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: blockAlign.littleEndian) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: bitsPerSample.littleEndian) { Array($0) })

        // data chunk
        data.append(contentsOf: "data".utf8)
        data.append(contentsOf: withUnsafeBytes(of: dataSize.littleEndian) { Array($0) })
        for sample in samples {
            data.append(contentsOf: withUnsafeBytes(of: sample.littleEndian) { Array($0) })
        }

        return data
    }

    /// Build a minimal 8-bit PCM WAV file
    private func buildWAV8(
        sampleRate: UInt32 = 44100,
        channels: UInt16 = 1,
        samples: [UInt8]
    ) -> Data {
        let bitsPerSample: UInt16 = 8
        let blockAlign = channels * (bitsPerSample / 8)
        let byteRate = sampleRate * UInt32(blockAlign)
        let dataSize = UInt32(samples.count)
        let fileSize = 36 + dataSize

        var data = Data()
        data.append(contentsOf: "RIFF".utf8)
        data.append(contentsOf: withUnsafeBytes(of: fileSize.littleEndian) { Array($0) })
        data.append(contentsOf: "WAVE".utf8)

        // fmt chunk
        data.append(contentsOf: "fmt ".utf8)
        data.append(contentsOf: withUnsafeBytes(of: UInt32(16).littleEndian) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: UInt16(1).littleEndian) { Array($0) }) // PCM
        data.append(contentsOf: withUnsafeBytes(of: channels.littleEndian) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: sampleRate.littleEndian) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: byteRate.littleEndian) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: blockAlign.littleEndian) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: bitsPerSample.littleEndian) { Array($0) })

        // data chunk
        data.append(contentsOf: "data".utf8)
        data.append(contentsOf: withUnsafeBytes(of: dataSize.littleEndian) { Array($0) })
        data.append(contentsOf: samples)

        return data
    }

    /// Build a 32-bit float WAV file
    private func buildWAVFloat32(
        sampleRate: UInt32 = 44100,
        channels: UInt16 = 1,
        samples: [Float]
    ) -> Data {
        let bitsPerSample: UInt16 = 32
        let blockAlign = channels * (bitsPerSample / 8)
        let byteRate = sampleRate * UInt32(blockAlign)
        let dataSize = UInt32(samples.count * 4)
        let fileSize = 36 + dataSize

        var data = Data()
        data.append(contentsOf: "RIFF".utf8)
        data.append(contentsOf: withUnsafeBytes(of: fileSize.littleEndian) { Array($0) })
        data.append(contentsOf: "WAVE".utf8)

        // fmt chunk
        data.append(contentsOf: "fmt ".utf8)
        data.append(contentsOf: withUnsafeBytes(of: UInt32(16).littleEndian) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: UInt16(3).littleEndian) { Array($0) }) // IEEE float
        data.append(contentsOf: withUnsafeBytes(of: channels.littleEndian) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: sampleRate.littleEndian) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: byteRate.littleEndian) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: blockAlign.littleEndian) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: bitsPerSample.littleEndian) { Array($0) })

        // data chunk
        data.append(contentsOf: "data".utf8)
        data.append(contentsOf: withUnsafeBytes(of: dataSize.littleEndian) { Array($0) })
        for sample in samples {
            data.append(contentsOf: withUnsafeBytes(of: sample.bitPattern.littleEndian) { Array($0) })
        }

        return data
    }

    /// Write data to a temp file and return the path
    private func writeTempFile(_ data: Data, name: String) throws -> String {
        let uniqueName = UUID().uuidString + "-" + name
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(uniqueName)
        try data.write(to: fileURL)
        return fileURL.path
    }

    // MARK: - Successful Read Tests

    func testRead16BitMonoWAV() throws {
        let samples: [Int16] = [0, 16384, 32767, -32768, -16384, 0]
        let wavData = buildWAV16(sampleRate: 44100, channels: 1, samples: samples)
        let path = try writeTempFile(wavData, name: "test16mono.wav")
        defer { try? FileManager.default.removeItem(atPath: path) }

        let wav = try WAVReader.read(path: path)

        XCTAssertEqual(wav.sampleRate, 44100.0)
        XCTAssertEqual(wav.channels, 1)
        XCTAssertEqual(wav.bitsPerSample, 16)
        XCTAssertEqual(wav.samples.count, 6)

        // Verify normalization
        XCTAssertEqual(wav.samples[0], 0.0, accuracy: 0.001)
        XCTAssertEqual(wav.samples[1], 0.5, accuracy: 0.001)
        XCTAssertEqual(wav.samples[2], 32767.0 / 32768.0, accuracy: 0.001)
        XCTAssertEqual(wav.samples[3], -1.0, accuracy: 0.001)
        XCTAssertEqual(wav.samples[4], -0.5, accuracy: 0.001)
    }

    func testRead8BitMonoWAV() throws {
        // 8-bit samples are unsigned: 128 = center (0.0), 0 = min (-1.0), 255 = max (~1.0)
        let samples: [UInt8] = [128, 0, 255]
        let wavData = buildWAV8(sampleRate: 22050, channels: 1, samples: samples)
        let path = try writeTempFile(wavData, name: "test8mono.wav")
        defer { try? FileManager.default.removeItem(atPath: path) }

        let wav = try WAVReader.read(path: path)

        XCTAssertEqual(wav.sampleRate, 22050.0)
        XCTAssertEqual(wav.channels, 1)
        XCTAssertEqual(wav.bitsPerSample, 8)
        XCTAssertEqual(wav.samples.count, 3)

        XCTAssertEqual(wav.samples[0], 0.0, accuracy: 0.01) // 128 - center
        XCTAssertEqual(wav.samples[1], -1.0, accuracy: 0.01) // 0 - min
        XCTAssertEqual(wav.samples[2], 127.0 / 128.0, accuracy: 0.01) // 255 - near max
    }

    func testRead32BitFloatWAV() throws {
        let samples: [Float] = [0.0, 0.5, 1.0, -1.0, -0.5]
        let wavData = buildWAVFloat32(sampleRate: 48000, channels: 1, samples: samples)
        let path = try writeTempFile(wavData, name: "testFloat32.wav")
        defer { try? FileManager.default.removeItem(atPath: path) }

        let wav = try WAVReader.read(path: path)

        XCTAssertEqual(wav.sampleRate, 48000.0)
        XCTAssertEqual(wav.channels, 1)
        XCTAssertEqual(wav.bitsPerSample, 32)
        XCTAssertEqual(wav.samples.count, 5)

        XCTAssertEqual(wav.samples[0], 0.0, accuracy: 0.001)
        XCTAssertEqual(wav.samples[1], 0.5, accuracy: 0.001)
        XCTAssertEqual(wav.samples[2], 1.0, accuracy: 0.001)
        XCTAssertEqual(wav.samples[3], -1.0, accuracy: 0.001)
    }

    // MARK: - WAVFile Properties

    func testWAVFileDuration() throws {
        // 44100 samples at 44100 Hz = 1.0 second
        let samples = [Int16](repeating: 0, count: 44100)
        let wavData = buildWAV16(sampleRate: 44100, channels: 1, samples: samples)
        let path = try writeTempFile(wavData, name: "testDuration.wav")
        defer { try? FileManager.default.removeItem(atPath: path) }

        let wav = try WAVReader.read(path: path)
        XCTAssertEqual(wav.duration, 1.0, accuracy: 0.001)
    }

    func testWAVFileMonoSamplesPassthrough() throws {
        let samples: [Int16] = [0, 16384, -16384]
        let wavData = buildWAV16(sampleRate: 44100, channels: 1, samples: samples)
        let path = try writeTempFile(wavData, name: "testMonoPassthrough.wav")
        defer { try? FileManager.default.removeItem(atPath: path) }

        let wav = try WAVReader.read(path: path)
        let mono = wav.monoSamples

        // For mono, monoSamples should be identical to samples
        XCTAssertEqual(mono.count, wav.samples.count)
        for i in 0..<mono.count {
            XCTAssertEqual(mono[i], wav.samples[i], accuracy: 0.001)
        }
    }

    func testWAVFileStereoToMono() throws {
        // Stereo: L=16384, R=0 → mono = 8192
        let samples: [Int16] = [16384, 0, -16384, 0]
        let wavData = buildWAV16(sampleRate: 44100, channels: 2, samples: samples)
        let path = try writeTempFile(wavData, name: "testStereoMono.wav")
        defer { try? FileManager.default.removeItem(atPath: path) }

        let wav = try WAVReader.read(path: path)
        XCTAssertEqual(wav.channels, 2)

        let mono = wav.monoSamples
        XCTAssertEqual(mono.count, 2) // 4 stereo samples → 2 mono samples

        // Average of (16384/32768, 0/32768) = 0.25
        XCTAssertEqual(mono[0], 0.25, accuracy: 0.001)
        // Average of (-16384/32768, 0/32768) = -0.25
        XCTAssertEqual(mono[1], -0.25, accuracy: 0.001)
    }

    func testWAVFileStereoDuration() throws {
        // 2 channels, 44100 total samples → 22050 per channel → 0.5 seconds
        let samples = [Int16](repeating: 0, count: 44100)
        let wavData = buildWAV16(sampleRate: 44100, channels: 2, samples: samples)
        let path = try writeTempFile(wavData, name: "testStereoDuration.wav")
        defer { try? FileManager.default.removeItem(atPath: path) }

        let wav = try WAVReader.read(path: path)
        XCTAssertEqual(wav.duration, 0.5, accuracy: 0.001)
    }

    // MARK: - Error Handling Tests

    func testReadFileNotFound() {
        XCTAssertThrowsError(try WAVReader.read(path: "/nonexistent/path/file.wav")) { error in
            guard case WAVError.fileNotFound = error else {
                XCTFail("Expected WAVError.fileNotFound but got \(error)")
                return
            }
        }
    }

    func testReadTooShortFile() throws {
        let data = Data(repeating: 0, count: 10) // Too short for WAV header
        let path = try writeTempFile(data, name: "tooShort.wav")
        defer { try? FileManager.default.removeItem(atPath: path) }

        XCTAssertThrowsError(try WAVReader.read(path: path)) { error in
            guard case WAVError.invalidFormat = error else {
                XCTFail("Expected WAVError.invalidFormat but got \(error)")
                return
            }
        }
    }

    func testReadInvalidRIFFHeader() throws {
        var data = Data(repeating: 0, count: 44)
        // Write "XXXX" instead of "RIFF"
        data.replaceSubrange(0..<4, with: "XXXX".utf8)
        let path = try writeTempFile(data, name: "badRIFF.wav")
        defer { try? FileManager.default.removeItem(atPath: path) }

        XCTAssertThrowsError(try WAVReader.read(path: path)) { error in
            guard case WAVError.invalidFormat = error else {
                XCTFail("Expected WAVError.invalidFormat but got \(error)")
                return
            }
        }
    }

    func testReadInvalidWAVEHeader() throws {
        var data = Data(repeating: 0, count: 44)
        // Valid RIFF but invalid WAVE
        data.replaceSubrange(0..<4, with: "RIFF".utf8)
        data.replaceSubrange(8..<12, with: "XXXX".utf8)
        let path = try writeTempFile(data, name: "badWAVE.wav")
        defer { try? FileManager.default.removeItem(atPath: path) }

        XCTAssertThrowsError(try WAVReader.read(path: path)) { error in
            guard case WAVError.invalidFormat = error else {
                XCTFail("Expected WAVError.invalidFormat but got \(error)")
                return
            }
        }
    }

    func testReadUnsupportedFormat() throws {
        // Build a WAV with audioFormat = 2 (Microsoft ADPCM) instead of 1 (PCM)
        let samples: [Int16] = [0]
        var wavData = buildWAV16(sampleRate: 44100, channels: 1, samples: samples)
        // Patch audioFormat from 1 to 2 at offset 20
        wavData[20] = 2
        wavData[21] = 0
        let path = try writeTempFile(wavData, name: "unsupported.wav")
        defer { try? FileManager.default.removeItem(atPath: path) }

        XCTAssertThrowsError(try WAVReader.read(path: path)) { error in
            guard case WAVError.unsupportedFormat = error else {
                XCTFail("Expected WAVError.unsupportedFormat but got \(error)")
                return
            }
        }
    }

    func testReadMissingDataChunk() throws {
        // Build a WAV with RIFF/WAVE header + fmt chunk + a "junk" chunk (no "data" chunk)
        // Total must be >= 44 bytes to pass the size check and reach chunk scanning
        var data = Data()
        data.append(contentsOf: "RIFF".utf8)
        data.append(contentsOf: withUnsafeBytes(of: UInt32(36).littleEndian) { Array($0) })
        data.append(contentsOf: "WAVE".utf8)
        // fmt chunk (24 bytes)
        data.append(contentsOf: "fmt ".utf8)
        data.append(contentsOf: withUnsafeBytes(of: UInt32(16).littleEndian) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: UInt16(1).littleEndian) { Array($0) }) // PCM
        data.append(contentsOf: withUnsafeBytes(of: UInt16(1).littleEndian) { Array($0) }) // mono
        data.append(contentsOf: withUnsafeBytes(of: UInt32(44100).littleEndian) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: UInt32(88200).littleEndian) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: UInt16(2).littleEndian) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: UInt16(16).littleEndian) { Array($0) })
        // A "junk" chunk instead of "data" (8 bytes, brings total to 44)
        data.append(contentsOf: "junk".utf8)
        data.append(contentsOf: withUnsafeBytes(of: UInt32(0).littleEndian) { Array($0) })
        // NO data chunk

        let path = try writeTempFile(data, name: "noData.wav")
        defer { try? FileManager.default.removeItem(atPath: path) }

        XCTAssertThrowsError(try WAVReader.read(path: path)) { error in
            guard case WAVError.invalidFormat = error else {
                XCTFail("Expected WAVError.invalidFormat but got \(error)")
                return
            }
        }
    }
}
