import Foundation

/// Decoding errors
enum DecodingError: Error {
    case unknownMode(String)
}

/// Protocol for mode-agnostic SSTV decoding
protocol SSTVModeDecoder {
    /// Decode a frame of frequency data into pixel rows
    /// For modes that transmit 2 lines per frame (like PD modes), this returns 2 rows
    /// - Parameters:
    ///   - frequencies: Frequency data for one transmission frame
    ///   - sampleRate: Audio sample rate
    ///   - frameIndex: Index of the frame being decoded
    /// - Returns: Array of pixel rows, where each row is RGB triplets (length = width * 3)
    func decodeFrame(frequencies: [Double], sampleRate: Double, frameIndex: Int) -> [[Double]]
    
    var width: Int { get }
    var height: Int { get }
    var frameDurationMs: Double { get }
    var linesPerFrame: Int { get }
    var lineDurationMs: Double { get }
    var syncFrequencyHz: Double { get }
    var name: String { get }
}

// Make both modes conform to the decoder protocol
extension PD120Mode: SSTVModeDecoder {}
extension PD180Mode: SSTVModeDecoder {}

/// SSTV Decoder - coordinates the complete decoding process
///
/// This ties together:
/// - Audio input
/// - VIS code detection
/// - Frequency tracking (DSP)
/// - Mode detection
/// - Line-by-line decoding
/// - Image output
struct SSTVDecoder {
    
    /// Decode SSTV audio into an image with auto mode detection
    ///
    /// - Parameters:
    ///   - audio: WAV audio file containing SSTV signal
    ///   - debug: Enable debug output
    /// - Returns: Decoded image buffer
    /// - Throws: DecodingError if decoding fails
    func decode(audio: WAVFile, debug: Bool = false) throws -> ImageBuffer {
        print("Decoding SSTV signal...")
        print("  Sample rate: \(audio.sampleRate) Hz")
        print("  Duration: \(String(format: "%.2f", audio.duration)) seconds")
        
        // Extract mono signal
        let samples = audio.monoSamples
        
        // Detect VIS code to determine mode
        print("Detecting VIS code...")
        let visDetector = VISDetector()
        
        let mode: SSTVModeDecoder
        if let visResult = visDetector.detect(samples: samples, sampleRate: audio.sampleRate) {
            print("  VIS Code: 0x\(String(visResult.code, radix: 16))")
            print("  Detected Mode: \(visResult.mode)")
            
            switch visResult.code {
            case 0x60:  // 96 decimal
                mode = PD180Mode()
            case 0x5F:  // 95 decimal
                mode = PD120Mode()
            default:
                print("  Warning: Unsupported mode, defaulting to PD180")
                mode = PD180Mode()
            }
        } else {
            print("  VIS code not detected, defaulting to PD180")
            mode = PD180Mode()
        }
        
        print("  Resolution: \(mode.width)×\(mode.height)")
        
        return try decodeWithMode(audio: audio, samples: samples, mode: mode, debug: debug)
    }
    
    /// Decode SSTV audio with a forced mode
    ///
    /// - Parameters:
    ///   - audio: WAV audio file containing SSTV signal
    ///   - forcedMode: Mode name to force (e.g., "PD120", "PD180")
    ///   - debug: Enable debug output
    /// - Returns: Decoded image buffer
    /// - Throws: DecodingError if decoding fails or mode is unknown
    func decode(audio: WAVFile, forcedMode: String, debug: Bool = false) throws -> ImageBuffer {
        print("Decoding SSTV signal...")
        print("  Sample rate: \(audio.sampleRate) Hz")
        print("  Duration: \(String(format: "%.2f", audio.duration)) seconds")
        print("  Forced Mode: \(forcedMode)")
        
        let mode: SSTVModeDecoder
        switch forcedMode.uppercased() {
        case "PD120":
            mode = PD120Mode()
        case "PD180":
            mode = PD180Mode()
        default:
            print("  Error: Unknown mode '\(forcedMode)'")
            print("  Supported modes: PD120, PD180")
            throw DecodingError.unknownMode(forcedMode)
        }
        
        print("  Resolution: \(mode.width)×\(mode.height)")
        
        let samples = audio.monoSamples
        
        return try decodeWithMode(audio: audio, samples: samples, mode: mode, debug: debug)
    }
    
    /// Decode with a specific mode
    private func decodeWithMode(
        audio: WAVFile,
        samples: [Double],
        mode: SSTVModeDecoder,
        debug: Bool = false
    ) throws -> ImageBuffer {
        print("Tracking frequencies...")
        let windowSize = 512
        let stepSize = 128
        
        let tracker = FrequencyTracker(
            sampleRate: audio.sampleRate,
            windowSize: windowSize,
            stepSize: stepSize
        )
        let frequencies = tracker.track(samples: samples)
        
        print("  Detected \(frequencies.count) frequency measurements")
        
        // Calculate samples per frame (each frame contains linesPerFrame image lines)
        let samplesPerFrame = Int(mode.frameDurationMs * audio.sampleRate / 1000.0)
        let stepsPerFrame = samplesPerFrame / stepSize
        
        print("  Samples per frame: \(samplesPerFrame)")
        print("  Steps per frame: \(stepsPerFrame)")
        print("  Lines per frame: \(mode.linesPerFrame)")
        
        // Find start of SSTV signal (look for sync tone patterns)
        print("Searching for SSTV signal start...")
        let startIndex = findSignalStart(
            frequencies: frequencies,
            mode: mode,
            sampleRate: audio.sampleRate,
            stepSize: stepSize
        )
        print("  Signal starts at step \(startIndex)")
        
        // Debug: Export frequency data
        if debug {
            print("\nDEBUG: Exporting frequency data...")
            exportFrequencyDebug(
                frequencies: frequencies,
                startIndex: startIndex,
                stepsPerFrame: stepsPerFrame,
                mode: mode,
                sampleRate: audio.sampleRate
            )
        }
        
        // Create image buffer
        var buffer = ImageBuffer(width: mode.width, height: mode.height)
        
        // Calculate number of frames to decode
        let numFrames = mode.height / mode.linesPerFrame
        let maxFrames = min(numFrames, (frequencies.count - startIndex) / stepsPerFrame)
        
        // Decode each frame with per-frame sync tracking
        print("Decoding frames...")
        
        let startTime = Date()
        var lastUpdateTime = startTime
        let updateIntervalSeconds: TimeInterval = 15.0 // Update every 15 seconds
        
        let syncFreq = mode.syncFrequencyHz
        let syncTolerance = 50.0
        var currentFrameStart = startIndex
        
        for frameIndex in 0..<maxFrames {
            // Find exact sync position for this frame (search within ±5 steps of expected)
            let expectedStart = startIndex + frameIndex * stepsPerFrame
            var actualStart = expectedStart
            var bestSyncScore = 0
            
            let searchRange = max(0, expectedStart - 5)..<min(frequencies.count - 10, expectedStart + 6)
            for pos in searchRange {
                var syncScore = 0
                for s in 0..<6 {
                    if pos + s < frequencies.count && abs(frequencies[pos + s] - syncFreq) < syncTolerance {
                        syncScore += 1
                    }
                }
                if syncScore > bestSyncScore {
                    bestSyncScore = syncScore
                    actualStart = pos
                }
            }
            
            // Use the found sync position
            currentFrameStart = actualStart
            let frameEnd = min(currentFrameStart + stepsPerFrame, frequencies.count)
            
            guard frameEnd <= frequencies.count else {
                print("\n  Warning: Insufficient data for frame \(frameIndex)")
                break
            }
            
            // Extract frequencies for this frame
            let frameFrequencies = Array(frequencies[currentFrameStart..<frameEnd])
            
            // Upsample to match expected sample count
            let upsampledFrequencies = upsampleFrequencies(
                frameFrequencies,
                targetCount: samplesPerFrame
            )
            
            // Decode the frame (returns linesPerFrame rows)
            let rows = mode.decodeFrame(
                frequencies: upsampledFrequencies,
                sampleRate: audio.sampleRate,
                frameIndex: frameIndex
            )
            
            // Store each row in buffer
            for (rowOffset, pixels) in rows.enumerated() {
                let lineIndex = frameIndex * mode.linesPerFrame + rowOffset
                if lineIndex < mode.height {
                    buffer.setRow(y: lineIndex, rowPixels: pixels)
                }
            }
            
            // Update progress every 15 seconds or on first/last frame
            let currentTime = Date()
            let timeSinceLastUpdate = currentTime.timeIntervalSince(lastUpdateTime)
            
            if timeSinceLastUpdate >= updateIntervalSeconds || frameIndex == 0 || frameIndex == maxFrames - 1 {
                lastUpdateTime = currentTime
                
                let progress = Double(frameIndex + 1) / Double(maxFrames)
                let elapsed = currentTime.timeIntervalSince(startTime)
                let estimated = elapsed / progress
                let remaining = estimated - elapsed
                
                let progressBar = makeProgressBar(progress: progress, width: 30)
                let progressPercent = Int(progress * 100)
                let linesDecoded = (frameIndex + 1) * mode.linesPerFrame
                
                // Clear line and print progress
                print("\r  \(progressBar) \(progressPercent)% (\(linesDecoded)/\(mode.height)) | Elapsed: \(formatTime(elapsed)) | ETA: \(formatTime(remaining))", terminator: "")
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
    ///   - sampleRate: Sample rate in Hz
    ///   - stepSize: Step size used in frequency tracking
    /// - Returns: Index where signal likely starts
    /// Find the start of image data by looking for stable sync patterns
    ///
    /// The VIS code uses 1100Hz and 1300Hz for bits, with 1200Hz for start/stop.
    /// Image frames use 1200Hz sync pulses for ~20ms followed by image data.
    /// We look for sustained 1200Hz sync followed by frequencies in the image range.
    private func findSignalStart(
        frequencies: [Double],
        mode: SSTVModeDecoder,
        sampleRate: Double,
        stepSize: Int
    ) -> Int {
        let syncFreq = mode.syncFrequencyHz  // 1200 Hz
        let syncTolerance = 50.0  // Tighter tolerance for sync
        
        // Calculate expected steps per frame
        let samplesPerFrame = Int(mode.frameDurationMs * sampleRate / 1000.0)
        let stepsPerFrame = samplesPerFrame / stepSize
        
        // Sync pulse is 20ms, which is approximately:
        let syncDurationMs = 20.0
        let stepsPerSync = max(2, Int(syncDurationMs * sampleRate / 1000.0 / Double(stepSize)))
        
        print("  Looking for sync patterns (stepsPerFrame: \(stepsPerFrame), stepsPerSync: \(stepsPerSync))...")
        
        // Search for a location where we see:
        // 1. A sustained sync pulse (~20ms of 1200Hz)
        // 2. Followed by image data (1500-2300Hz)
        // 3. Then another sync pulse one frame later
        
        var bestScore = 0
        var bestIndex = 0
        
        // Skip first ~500ms which contains the VIS header
        let skipSteps = Int(500.0 * sampleRate / 1000.0 / Double(stepSize))
        let searchLimit = min(frequencies.count - stepsPerFrame * 10, frequencies.count / 2)
        
        for startIndex in skipSteps..<searchLimit {
            var score = 0
            
            // Check multiple frames starting from this point
            for frameNum in 0..<10 {
                let frameStart = startIndex + frameNum * stepsPerFrame
                if frameStart + stepsPerFrame >= frequencies.count { break }
                
                // Check for sync pulse at start of frame
                var syncCount = 0
                for s in 0..<stepsPerSync {
                    if frameStart + s < frequencies.count {
                        let freq = frequencies[frameStart + s]
                        if abs(freq - syncFreq) < syncTolerance {
                            syncCount += 1
                        }
                    }
                }
                
                // Also check that after sync, we have image data (not more sync)
                var imageCount = 0
                let imageCheckStart = frameStart + stepsPerSync + 2
                for s in 0..<5 {
                    if imageCheckStart + s < frequencies.count {
                        let freq = frequencies[imageCheckStart + s]
                        if freq >= 1450 && freq <= 2350 {
                            imageCount += 1
                        }
                    }
                }
                
                // Score based on sync quality and image data presence
                if syncCount >= stepsPerSync / 2 && imageCount >= 2 {
                    score += syncCount + imageCount
                }
            }
            
            if score > bestScore {
                bestScore = score
                bestIndex = startIndex
            }
        }
        
        // Fine-tune to find exact sync start
        // Look backward from bestIndex to find where sync starts
        var adjustedIndex = bestIndex
        for i in stride(from: bestIndex, through: max(0, bestIndex - stepsPerSync * 2), by: -1) {
            let freq = frequencies[i]
            if abs(freq - syncFreq) < syncTolerance {
                adjustedIndex = i
            } else {
                break
            }
        }
        
        print("  Found sync pattern at step \(adjustedIndex) (score: \(bestScore))")
        return adjustedIndex
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
    
    /// Export frequency debug information to files
    private func exportFrequencyDebug(
        frequencies: [Double],
        startIndex: Int,
        stepsPerFrame: Int,
        mode: SSTVModeDecoder,
        sampleRate: Double
    ) {
        // Export first 5 frames of frequency data
        var csv = "step,time_ms,frequency,is_sync,frame,position_in_frame\n"
        
        let syncFreq = mode.syncFrequencyHz
        let syncTolerance = 100.0
        
        let numFrames = mode.height / mode.linesPerFrame
        for frameNum in 0..<min(5, numFrames) {
            let frameStart = startIndex + frameNum * stepsPerFrame
            
            for stepInFrame in 0..<stepsPerFrame {
                let globalStep = frameStart + stepInFrame
                guard globalStep < frequencies.count else { break }
                
                let freq = frequencies[globalStep]
                let isSync = abs(freq - syncFreq) < syncTolerance ? 1 : 0
                let timeMs = Double(globalStep * 128) / sampleRate * 1000.0
                
                csv += "\(globalStep),\(String(format: "%.2f", timeMs)),\(String(format: "%.1f", freq)),\(isSync),\(frameNum),\(stepInFrame)\n"
            }
        }
        
        // Write CSV file
        let csvPath = "debug_frequencies.csv"
        try? csv.write(toFile: csvPath, atomically: true, encoding: .utf8)
        print("  Saved frequency data to \(csvPath)")
        
        // Print sync pulse analysis
        print("\nDEBUG: Sync pulse analysis for first 5 frames:")
        for frameNum in 0..<min(5, numFrames) {
            let frameStart = startIndex + frameNum * stepsPerFrame
            var syncSteps: [Int] = []
            
            for stepInFrame in 0..<stepsPerFrame {
                let globalStep = frameStart + stepInFrame
                guard globalStep < frequencies.count else { break }
                
                let freq = frequencies[globalStep]
                if abs(freq - syncFreq) < syncTolerance {
                    syncSteps.append(stepInFrame)
                }
            }
            
            let syncRange = syncSteps.isEmpty ? "none" : "\(syncSteps.first!)...\(syncSteps.last!)"
            print("  Frame \(frameNum): sync pulses at steps \(syncRange) (count: \(syncSteps.count))")
        }
        
        // Print frequency distribution for frame 0
        print("\nDEBUG: Frequency distribution for frame 0:")
        let frameStart = startIndex
        var freqBins: [String: Int] = [
            "1100-1250 (sync)": 0,
            "1250-1400 (porch)": 0,
            "1400-1600 (black)": 0,
            "1600-1900 (gray)": 0,
            "1900-2300 (white)": 0,
            "other": 0
        ]
        
        for stepInFrame in 0..<stepsPerFrame {
            let globalStep = frameStart + stepInFrame
            guard globalStep < frequencies.count else { break }
            
            let freq = frequencies[globalStep]
            if freq >= 1100 && freq < 1250 {
                freqBins["1100-1250 (sync)"]! += 1
            } else if freq >= 1250 && freq < 1400 {
                freqBins["1250-1400 (porch)"]! += 1
            } else if freq >= 1400 && freq < 1600 {
                freqBins["1400-1600 (black)"]! += 1
            } else if freq >= 1600 && freq < 1900 {
                freqBins["1600-1900 (gray)"]! += 1
            } else if freq >= 1900 && freq <= 2300 {
                freqBins["1900-2300 (white)"]! += 1
            } else {
                freqBins["other"]! += 1
            }
        }
        
        for (range, count) in freqBins.sorted(by: { $0.key < $1.key }) {
            let pct = Double(count) / Double(stepsPerFrame) * 100
            print("  \(range): \(count) (\(String(format: "%.1f", pct))%)")
        }
        print("")
    }
}
