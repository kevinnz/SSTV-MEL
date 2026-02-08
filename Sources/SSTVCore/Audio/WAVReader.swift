import Foundation

/// Errors that can occur during WAV file reading
public enum WAVError: Error {
    case fileNotFound
    case invalidFormat
    case unsupportedFormat(String)
    case readError(String)
}

/// Represents a WAV audio file with its samples
public struct WAVFile {
    /// Sample rate in Hz
    public let sampleRate: Double

    /// Number of audio channels
    public let channels: Int

    /// Bits per sample
    public let bitsPerSample: Int

    /// Audio samples (normalized to -1.0...1.0)
    /// For multi-channel audio, samples are interleaved
    public let samples: [Double]

    /// Duration in seconds
    public var duration: Double {
        Double(samples.count) / Double(channels) / sampleRate
    }

    /// Extract mono channel (averages all channels if multi-channel)
    public var monoSamples: [Double] {
        guard channels > 1 else {
            return samples
        }

        var mono = [Double]()
        mono.reserveCapacity(samples.count / channels)

        for i in stride(from: 0, to: samples.count, by: channels) {
            var sum = 0.0
            for ch in 0..<channels {
                sum += samples[i + ch]
            }
            mono.append(sum / Double(channels))
        }

        return mono
    }
}

/// Simple WAV file reader
/// Supports PCM format only (16-bit and 8-bit)
public struct WAVReader {

    /// Read a WAV file from the given path
    ///
    /// - Parameter path: Path to WAV file
    /// - Returns: WAVFile structure containing audio data
    /// - Throws: WAVError if file cannot be read or has unsupported format
    public static func read(path: String) throws -> WAVFile {
        let url = URL(fileURLWithPath: path)

        guard FileManager.default.fileExists(atPath: path) else {
            throw WAVError.fileNotFound
        }

        let data = try Data(contentsOf: url)

        // Verify RIFF header
        guard data.count >= 44 else {
            throw WAVError.invalidFormat
        }

        let riffID = String(data: data[0..<4], encoding: .ascii)
        guard riffID == "RIFF" else {
            throw WAVError.invalidFormat
        }

        let waveID = String(data: data[8..<12], encoding: .ascii)
        guard waveID == "WAVE" else {
            throw WAVError.invalidFormat
        }

        // Find fmt chunk
        guard let fmtChunk = findChunk(data: data, id: "fmt ") else {
            throw WAVError.invalidFormat
        }

        // Parse format
        let audioFormat = readUInt16(data, at: fmtChunk.offset)
        guard audioFormat == 1 || audioFormat == 3 else {
            throw WAVError.unsupportedFormat("Only PCM (format 1) and IEEE float (format 3) supported (got format \(audioFormat))")
        }

        let channels = Int(readUInt16(data, at: fmtChunk.offset + 2))
        let sampleRate = Int(readUInt32(data, at: fmtChunk.offset + 4))
        let bitsPerSample = Int(readUInt16(data, at: fmtChunk.offset + 14))

        if audioFormat == 1 {
            // PCM format
            guard bitsPerSample == 16 || bitsPerSample == 8 else {
                throw WAVError.unsupportedFormat("Only 8-bit and 16-bit PCM supported")
            }
        } else if audioFormat == 3 {
            // IEEE float format
            guard bitsPerSample == 32 || bitsPerSample == 64 else {
                throw WAVError.unsupportedFormat("Only 32-bit and 64-bit IEEE float supported")
            }
        }

        // Find data chunk
        guard let dataChunk = findChunk(data: data, id: "data") else {
            throw WAVError.invalidFormat
        }

        // Read samples
        let samples = try readSamples(
            data: data,
            offset: dataChunk.offset,
            length: dataChunk.size,
            audioFormat: audioFormat,
            bitsPerSample: bitsPerSample
        )

        return WAVFile(
            sampleRate: Double(sampleRate),
            channels: channels,
            bitsPerSample: bitsPerSample,
            samples: samples
        )
    }

    // MARK: - Private Helpers

    private struct Chunk {
        let offset: Int
        let size: Int
    }

    private static func findChunk(data: Data, id: String) -> Chunk? {
        var offset = 12 // Skip RIFF header

        while offset + 8 <= data.count {
            let chunkID = String(data: data[offset..<offset+4], encoding: .ascii)
            let chunkSize = Int(readUInt32(data, at: offset + 4))

            if chunkID == id {
                return Chunk(offset: offset + 8, size: chunkSize)
            }

            offset += 8 + chunkSize
            // Chunks are word-aligned
            if chunkSize % 2 != 0 {
                offset += 1
            }
        }

        return nil
    }

    private static func readUInt16(_ data: Data, at offset: Int) -> UInt16 {
        // Read bytes individually to avoid alignment issues
        return UInt16(data[offset]) | (UInt16(data[offset + 1]) << 8)
    }

    private static func readUInt32(_ data: Data, at offset: Int) -> UInt32 {
        // Read bytes individually to avoid alignment issues
        return UInt32(data[offset]) |
               (UInt32(data[offset + 1]) << 8) |
               (UInt32(data[offset + 2]) << 16) |
               (UInt32(data[offset + 3]) << 24)
    }

    private static func readInt16(_ data: Data, at offset: Int) -> Int16 {
        // Read bytes individually to avoid alignment issues
        let unsigned = UInt16(data[offset]) | (UInt16(data[offset + 1]) << 8)
        return Int16(bitPattern: unsigned)
    }

    private static func readSamples(
        data: Data,
        offset: Int,
        length: Int,
        audioFormat: UInt16,
        bitsPerSample: Int
    ) throws -> [Double] {
        var samples = [Double]()

        if audioFormat == 1 {
            // PCM format
            if bitsPerSample == 16 {
                let sampleCount = length / 2
                samples.reserveCapacity(sampleCount)

                for i in 0..<sampleCount {
                    let sampleOffset = offset + i * 2
                    guard sampleOffset + 2 <= data.count else { break }

                    let value = readInt16(data, at: sampleOffset)
                    // Normalize to -1.0...1.0
                    samples.append(Double(value) / 32768.0)
                }
            } else if bitsPerSample == 8 {
                samples.reserveCapacity(length)

                for i in 0..<length {
                    let sampleOffset = offset + i
                    guard sampleOffset < data.count else { break }

                    let value = data[sampleOffset]
                    // 8-bit samples are unsigned, normalize to -1.0...1.0
                    samples.append((Double(value) - 128.0) / 128.0)
                }
            }
        } else if audioFormat == 3 {
            // IEEE float format
            if bitsPerSample == 32 {
                let sampleCount = length / 4
                samples.reserveCapacity(sampleCount)

                for i in 0..<sampleCount {
                    let sampleOffset = offset + i * 4
                    guard sampleOffset + 4 <= data.count else { break }

                    let value = readFloat32(data, at: sampleOffset)
                    // Already normalized to -1.0...1.0
                    samples.append(Double(value))
                }
            } else if bitsPerSample == 64 {
                let sampleCount = length / 8
                samples.reserveCapacity(sampleCount)

                for i in 0..<sampleCount {
                    let sampleOffset = offset + i * 8
                    guard sampleOffset + 8 <= data.count else { break }

                    let value = readFloat64(data, at: sampleOffset)
                    samples.append(value)
                }
            }
        }

        return samples
    }

    private static func readFloat32(_ data: Data, at offset: Int) -> Float {
        // Read bytes individually to avoid alignment issues
        let bits = UInt32(data[offset]) |
                   (UInt32(data[offset + 1]) << 8) |
                   (UInt32(data[offset + 2]) << 16) |
                   (UInt32(data[offset + 3]) << 24)
        return Float(bitPattern: bits)
    }

    private static func readFloat64(_ data: Data, at offset: Int) -> Double {
        // Read bytes individually to avoid alignment issues
        let bits = UInt64(data[offset]) |
                   (UInt64(data[offset + 1]) << 8) |
                   (UInt64(data[offset + 2]) << 16) |
                   (UInt64(data[offset + 3]) << 24) |
                   (UInt64(data[offset + 4]) << 32) |
                   (UInt64(data[offset + 5]) << 40) |
                   (UInt64(data[offset + 6]) << 48) |
                   (UInt64(data[offset + 7]) << 56)
        return Double(bitPattern: bits)
    }
}
