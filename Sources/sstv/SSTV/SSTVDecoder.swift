import Foundation

/// SSTV Decoder - coordinates the complete decoding process
///
/// This ties together:
/// - Audio input
/// - Frequency tracking (DSP)
/// - Mode detection
/// - Line-by-line decoding
/// - Image output
struct SSTVDecoder {
    
    /// Decode SSTV audio into an image
    ///
    /// - Parameters:
    ///   - audio: WAV audio file containing SSTV signal
    ///   - mode: SSTV mode to use for decoding
    /// - Returns: Decoded image buffer
    /// - Throws: DecodingError if decoding fails
    func decode(audio: WAVFile, mode: PD120Mode) throws -> ImageBuffer {
        print("Decoding SSTV signal...")
        print("  Sample rate: \(audio.sampleRate) Hz")
        print("  Duration: \(String(format: "%.2f", audio.duration)) seconds")
        print("  Mode: \(mode.name)")
        print("  Resolution: \(mode.width)×\(mode.height)")
        
        // Extract mono signal
        let samples = audio.monoSamples
        
        // Track frequencies across the entire signal
        print("Tracking frequencies...")
        let tracker = FrequencyTracker(
            sampleRate: audio.sampleRate,
            windowSize: 512,
            stepSize: 128
        )
        let frequencies = tracker.track(samples: samples)
        
        print("  Detected \(frequencies.count) frequency measurements")
        
        // Calculate samples per line
        let samplesPerLine = Int(mode.lineDurationMs * audio.sampleRate / 1000.0)
        let stepsPerLine = samplesPerLine / tracker.stepSize
        
        print("  Samples per line: \(samplesPerLine)")
        print("  Steps per line: \(stepsPerLine)")
        
        // Find start of SSTV signal (look for sync tone patterns)
        print("Searching for SSTV signal start...")
        let startIndex = findSignalStart(frequencies: frequencies, mode: mode)
        print("  Signal starts at step \(startIndex)")
        
        // Create image buffer
        var buffer = ImageBuffer(width: mode.width, height: mode.height)
        
        // Decode each line
        print("Decoding lines...")
        let maxLines = min(mode.height, (frequencies.count - startIndex) / stepsPerLine)
        
        let startTime = Date()
        var lastUpdateTime = startTime
        let updateIntervalSeconds: TimeInterval = 15.0 // Update every 15 seconds
        
        for lineIndex in 0..<maxLines {
            let lineStart = startIndex + lineIndex * stepsPerLine
            let lineEnd = min(lineStart + stepsPerLine, frequencies.count)
            
            guard lineEnd <= frequencies.count else {
                print("\n  Warning: Insufficient data for line \(lineIndex)")
                break
            }
            
            // Extract frequencies for this line
            let lineFrequencies = Array(frequencies[lineStart..<lineEnd])
            
            // Upsample to match expected sample count
            let upsampledFrequencies = upsampleFrequencies(
                lineFrequencies,
                targetCount: samplesPerLine
            )
            
            // Decode the line
            let pixels = mode.decodeLine(
                frequencies: upsampledFrequencies,
                sampleRate: audio.sampleRate,
                lineIndex: lineIndex
            )
            
            // Store in buffer
            buffer.setRow(y: lineIndex, rowPixels: pixels)
            
            // Update progress every 15 seconds or on last line
            let currentTime = Date()
            let timeSinceLastUpdate = currentTime.timeIntervalSince(lastUpdateTime)
            
            if timeSinceLastUpdate >= updateIntervalSeconds || lineIndex == 0 || lineIndex == maxLines - 1 {
                lastUpdateTime = currentTime
                
                let progress = Double(lineIndex + 1) / Double(maxLines)
                let elapsed = currentTime.timeIntervalSince(startTime)
                let estimated = elapsed / progress
                let remaining = estimated - elapsed
                
                let progressBar = makeProgressBar(progress: progress, width: 30)
                let progressPercent = Int(progress * 100)
                
                // Clear line and print progress
                print("\r  \(progressBar) \(progressPercent)% (\(lineIndex + 1)/\(maxLines)) | Elapsed: \(formatTime(elapsed)) | ETA: \(formatTime(remaining))", terminator: "")
                fflush(stdout)
            }
        }
        
        print("") // New line after progress
        
        print("Decoding complete!")
        return buffer
    }
    
    /// Find the approximate start of the SSTV signal
    ///
    /// Looks for a pattern of sync pulses (1200 Hz) which indicate line starts.
    /// For simplicity, we look for the first significant occurrence of sync-like frequencies.
    ///
    /// - Parameters:
    ///   - frequencies: Detected frequencies
    ///   - mode: SSTV mode
    /// - Returns: Index where signal likely starts
    private func findSignalStart(frequencies: [Double], mode: PD120Mode) -> Int {
        let syncFreq = mode.syncFrequencyHz
        let tolerance = 50.0 // Hz
        
        // Look for first sustained sync-like signal
        var syncCount = 0
        let requiredSyncCount = 3
        
        for (index, freq) in frequencies.enumerated() {
            if abs(freq - syncFreq) < tolerance {
                syncCount += 1
                if syncCount >= requiredSyncCount {
                    // Back up to start of sync sequence
                    return max(0, index - requiredSyncCount)
                }
            } else {
                syncCount = 0
            }
        }
        
        // If no clear sync found, start from beginning
        return 0
    }
    
    /// Upsample frequency array to target count using linear interpolation
    ///
    /// - Parameters:
    ///   - frequencies: Source frequency array
    ///   - targetCount: Desired output count
    /// - Returns: Upsampled frequency array
    private func upsampleFrequencies(_ frequencies: [Double], targetCount: Int) -> [Double] {
        guard frequencies.count < targetCount else {
            return Array(frequencies.prefix(targetCount))
        }
        
        var result = [Double]()
        result.reserveCapacity(targetCount)
        
        let scale = Double(frequencies.count - 1) / Double(targetCount - 1)
        
        for i in 0..<targetCount {
            let pos = Double(i) * scale
            let index = Int(pos)
            let frac = pos - Double(index)
            
            if index + 1 < frequencies.count {
                let interpolated = frequencies[index] * (1.0 - frac) + frequencies[index + 1] * frac
                result.append(interpolated)
            } else {
                result.append(frequencies[index])
            }
        }
        
        return result
    }
    
    /// Create a progress bar string
    ///
    /// - Parameters:
    ///   - progress: Progress value (0.0...1.0)
    ///   - width: Width of the progress bar in characters
    /// - Returns: Progress bar string
    private func makeProgressBar(progress: Double, width: Int) -> String {
        let filled = Int(progress * Double(width))
        let empty = width - filled
        return "[" + String(repeating: "█", count: filled) + String(repeating: "░", count: empty) + "]"
    }
    
    /// Format time interval in human-readable format
    ///
    /// - Parameter seconds: Time interval in seconds
    /// - Returns: Formatted string (e.g., "1m 23s")
    private func formatTime(_ seconds: TimeInterval) -> String {
        let totalSeconds = Int(seconds)
        let minutes = totalSeconds / 60
        let secs = totalSeconds % 60
        
        if minutes > 0 {
            return "\(minutes)m \(secs)s"
        } else {
            return "\(secs)s"
        }
    }
}
