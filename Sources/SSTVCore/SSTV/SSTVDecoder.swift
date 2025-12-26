import Foundation

/// Decoding errors
public enum DecodingError: Error {
    case unknownMode(String)
}

/// Protocol for mode-agnostic SSTV decoding
public protocol SSTVModeDecoder {
    /// Decode a frame of frequency data into pixel rows
    /// For modes that transmit 2 lines per frame (like PD modes), this returns 2 rows
    /// - Parameters:
    ///   - frequencies: Frequency data for one transmission frame
    ///   - sampleRate: Audio sample rate
    ///   - frameIndex: Index of the frame being decoded
    ///   - options: Decoding options for phase and skew adjustment
    /// - Returns: Array of pixel rows, where each row is RGB triplets (length = width * 3)
    func decodeFrame(frequencies: [Double], sampleRate: Double, frameIndex: Int, options: DecodingOptions) -> [[Double]]
    
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
public struct SSTVDecoder {
    
    public init() {}
    
    /// Decode SSTV audio into an image with auto mode detection
    ///
    /// - Parameters:
    ///   - audio: WAV audio file containing SSTV signal
    ///   - options: Decoding options for phase and skew adjustment
    ///   - progressHandler: Optional callback for progress updates
    /// - Returns: Decoded image buffer
    /// - Throws: DecodingError if decoding fails
    public func decode(
        audio: WAVFile,
        options: DecodingOptions = .default,
        progressHandler: ProgressHandler? = nil
    ) throws -> ImageBuffer {
        let startTime = Date()
        
        // Extract mono signal
        let samples = audio.monoSamples
        
        // Detect VIS code to determine mode
        let visDetector = VISDetector()
        
        let mode: SSTVModeDecoder
        if let visResult = visDetector.detect(
            samples: samples,
            sampleRate: audio.sampleRate,
            progressHandler: { visProgress in
                let elapsed = Date().timeIntervalSince(startTime)
                let progress = DecodingProgress(
                    phase: .visDetection(progress: visProgress),
                    overallProgress: visProgress * 0.1,  // VIS is ~10% of total
                    elapsedSeconds: elapsed
                )
                progressHandler?(progress)
            }
        ) {
            switch visResult.code {
            case 0x60:  // 96 decimal
                mode = PD180Mode()
            case 0x5F:  // 95 decimal
                mode = PD120Mode()
            default:
                mode = PD120Mode()
            }
        } else {
            mode = PD120Mode()
        }
        
        return try decodeWithMode(
            audio: audio,
            samples: samples,
            mode: mode,
            options: options,
            startTime: startTime,
            progressHandler: progressHandler
        )
    }
    
    /// Decode SSTV audio with a forced mode
    ///
    /// - Parameters:
    ///   - audio: WAV audio file containing SSTV signal
    ///   - forcedMode: Mode name to force (e.g., "PD120", "PD180")
    ///   - options: Decoding options for phase and skew adjustment
    ///   - progressHandler: Optional callback for progress updates
    /// - Returns: Decoded image buffer
    /// - Throws: DecodingError if decoding fails or mode is unknown
    public func decode(
        audio: WAVFile,
        forcedMode: String,
        options: DecodingOptions = .default,
        progressHandler: ProgressHandler? = nil
    ) throws -> ImageBuffer {
        let startTime = Date()
        
        let mode: SSTVModeDecoder
        switch forcedMode.uppercased() {
        case "PD120":
            mode = PD120Mode()
        case "PD180":
            mode = PD180Mode()
        default:
            throw DecodingError.unknownMode(forcedMode)
        }
        
        let samples = audio.monoSamples
        
        return try decodeWithMode(
            audio: audio,
            samples: samples,
            mode: mode,
            options: options,
            startTime: startTime,
            progressHandler: progressHandler
        )
    }
    
    /// Decode with a specific mode using FM demodulation
    ///
    /// This approach uses true FM demodulation (Hilbert transform + phase difference)
    /// instead of Goertzel-based frequency binning. This provides:
    /// - Sample-level frequency resolution (not window-level)
    /// - Continuous phase tracking (no binning artifacts)
    /// - Much more accurate pixel values
    private func decodeWithMode(
        audio: WAVFile,
        samples: [Double],
        mode: SSTVModeDecoder,
        options: DecodingOptions = .default,
        startTime: Date,
        progressHandler: ProgressHandler?
    ) throws -> ImageBuffer {
        // Use FM demodulation for accurate frequency tracking
        let fmTracker = FMFrequencyTracker(sampleRate: audio.sampleRate)
        let frequencies = fmTracker.track(samples: samples) { fmProgress in
            let elapsed = Date().timeIntervalSince(startTime)
            let progress = DecodingProgress(
                phase: .fmDemodulation(progress: fmProgress),
                overallProgress: 0.1 + (fmProgress * 0.2),  // FM demod is ~20%, starts after VIS (10%)
                elapsedSeconds: elapsed
            )
            progressHandler?(progress)
        }
        
        // Calculate samples per frame (each frame contains linesPerFrame image lines)
        let samplesPerFrame = Int(mode.frameDurationMs * audio.sampleRate / 1000.0)
        
        // Find start of SSTV signal (look for sync tone patterns)
        
        // Report progress for signal search
        let elapsed = Date().timeIntervalSince(startTime)
        let searchProgress = DecodingProgress(
            phase: .signalSearch,
            overallProgress: 0.3,  // 30% after VIS and FM demod
            elapsedSeconds: elapsed,
            modeName: mode.name
        )
        progressHandler?(searchProgress)
        
        let startSample = findSignalStartFM(
            frequencies: frequencies,
            mode: mode,
            sampleRate: audio.sampleRate
        )
        
        // Create image buffer
        var buffer = ImageBuffer(width: mode.width, height: mode.height)
        
        // Calculate number of frames to decode
        let numFrames = mode.height / mode.linesPerFrame
        let maxFrames = min(numFrames, (frequencies.count - startSample) / samplesPerFrame)
        
        // CONTINUOUS DECODING with sample-level precision
        let decodeStartTime = Date()
        var lastUpdateTime = decodeStartTime
        let updateIntervalSeconds: TimeInterval = 15.0
        
        for frameIndex in 0..<maxFrames {
            // Extract frame at sample-level precision
            let frameStartSample = startSample + frameIndex * samplesPerFrame
            let frameEndSample = min(frameStartSample + samplesPerFrame, frequencies.count)
            
            guard frameEndSample <= frequencies.count else {
                break
            }
            
            // Extract frequencies for this frame (now at sample rate!)
            let frameFrequencies = Array(frequencies[frameStartSample..<frameEndSample])
            
            // Decode the frame - pass the actual sample rate since we have per-sample data
            let rows = mode.decodeFrame(
                frequencies: frameFrequencies,
                sampleRate: audio.sampleRate,  // Now using actual sample rate!
                frameIndex: frameIndex,
                options: options
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
                
                let frameProgress = Double(frameIndex + 1) / Double(maxFrames)
                let elapsed = currentTime.timeIntervalSince(decodeStartTime)
                let estimated = elapsed / frameProgress
                let remaining = estimated - elapsed
                
                // Call progress handler
                let linesDecoded = (frameIndex + 1) * mode.linesPerFrame
                let totalElapsed = currentTime.timeIntervalSince(startTime)
                let decodeProgress = DecodingProgress(
                    phase: .frameDecoding(linesDecoded: linesDecoded, totalLines: mode.height),
                    overallProgress: 0.3 + (frameProgress * 0.7),  // Decoding is remaining 70%
                    elapsedSeconds: totalElapsed,
                    estimatedSecondsRemaining: remaining,
                    modeName: mode.name
                )
                progressHandler?(decodeProgress)
            }
        }
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
    /// Find the start of the SSTV signal using FM-demodulated frequency data
    ///
    /// This version works with sample-rate frequency data from FM demodulation.
    /// We look for the characteristic 1200 Hz sync pulses that mark frame starts.
    /// Strategy: Find the EARLIEST position that has valid sync patterns for multiple frames.
    private func findSignalStartFM(
        frequencies: [Double],
        mode: SSTVModeDecoder,
        sampleRate: Double
    ) -> Int {
        let syncFreq = mode.syncFrequencyHz  // 1200 Hz
        let syncTolerance = 150.0  // Wider tolerance for FM demod noise; ~12.5% of 1200 Hz, chosen empirically from FM-demod test captures to absorb drift/quantization while still reliably isolating sync pulses (see ADR-001 for tuning guidance).
        
        // Calculate expected samples per frame
        let samplesPerFrame = Int(mode.frameDurationMs * sampleRate / 1000.0)
        
        // Sync pulse is 20ms
        let syncDurationMs = 20.0
        let samplesPerSync = Int(syncDurationMs * sampleRate / 1000.0)
        
        // Minimum score threshold for a valid sync pattern.
        // Score is based on (syncCount + imageCount); a value of 100 was chosen empirically
        // to require multiple consistent frame syncs while still tolerating FM demodulation
        // noise. Adjust with care, as lowering this can introduce false positives and raising
        // it can cause valid images to be missed.
        let minValidScore = 100
        
        // Sync density threshold for determining sync boundaries.
        // A value of 0.4 (40%) was chosen to reliably detect sync pulses while tolerating
        // FM demodulation noise and minor frequency drift.
        let syncDensityThreshold = 0.4
        
        // Strategy: Find EARLIEST valid sync pattern, not highest scoring
        // VIS code and leader tone can extend ~3 seconds into the file
        // So skip past that to find the actual image data
        let skipSamples = Int(3.0 * sampleRate)
        
        // We need enough room for a full image
        let requiredSamples = samplesPerFrame * (mode.height / mode.linesPerFrame)
        let searchLimit = frequencies.count - requiredSamples
        
        // Search step - check every ~1ms for fine detection
        let searchStep = Int(sampleRate / 1000)
        
        for startIndex in stride(from: skipSamples, to: searchLimit, by: searchStep) {
            var score = 0
            var validFrames = 0
            
            // Check up to 10 consecutive frames starting from this point.
            // Elsewhere we require that at least a subset of these (e.g. 6) are valid;
            // using a larger window with a high validity threshold reduces VIS code
            // false positives while still allowing a few noisy frames.
            for frameNum in 0..<10 {
                let frameStart = startIndex + frameNum * samplesPerFrame
                if frameStart + samplesPerFrame >= frequencies.count { break }
                
                // Check for sync pulse at start of frame (1200 Hz for ~20ms)
                var syncCount = 0
                var totalChecks = 0
                for s in stride(from: 0, to: samplesPerSync, by: 20) {
                    if frameStart + s < frequencies.count {
                        let freq = frequencies[frameStart + s]
                        if abs(freq - syncFreq) < syncTolerance {
                            syncCount += 1
                        }
                        totalChecks += 1
                    }
                }
                
                // Also check that after sync we have image frequencies (1500-2300 Hz)
                let imageStart = frameStart + samplesPerSync + 50
                var imageCount = 0
                for s in stride(from: 0, to: 1000, by: 100) {
                    if imageStart + s < frequencies.count {
                        let freq = frequencies[imageStart + s]
                        if freq >= 1400 && freq <= 2400 {
                            imageCount += 1
                        }
                    }
                }
                
                // Frame is valid if we have good sync (≥40%) and good image data
                if totalChecks > 0 && syncCount >= totalChecks * 4 / 10 && imageCount >= 5 {
                    validFrames += 1
                    score += syncCount + imageCount
                }
            }
            
            // Accept the FIRST position with at least 6 valid consecutive frames
            if validFrames >= 6 && score >= minValidScore {
                // Fine-tune: find the START of the sync pulse (transition from non-sync to sync)
                let adjustedIndex = fineTuneSyncStart(
                    startIndex: startIndex,
                    frequencies: frequencies,
                    syncFreq: syncFreq,
                    syncTolerance: syncTolerance,
                    samplesPerSync: samplesPerSync,
                    syncDensityThreshold: syncDensityThreshold
                )
                
                return adjustedIndex
            }
        }
        
        // Fallback: no valid pattern found, start from beginning
        return skipSamples
    }
    
    /// Fine-tune sync detection by finding the precise start of the sync pulse
    ///
    /// - Parameters:
    ///   - startIndex: Approximate position of sync pattern
    ///   - frequencies: Array of demodulated frequencies
    ///   - syncFreq: Expected sync frequency (typically 1200 Hz)
    ///   - syncTolerance: Tolerance for sync frequency matching
    ///   - samplesPerSync: Number of samples in a sync pulse
    ///   - syncDensityThreshold: Minimum sync density to consider valid (e.g., 0.4 = 40%)
    /// - Returns: Adjusted index pointing to the start of the sync pulse
    private func fineTuneSyncStart(
        startIndex: Int,
        frequencies: [Double],
        syncFreq: Double,
        syncTolerance: Double,
        samplesPerSync: Int,
        syncDensityThreshold: Double
    ) -> Int {
        // First, find a position with good sync density (center of sync)
        var bestCenterIndex = startIndex
        var bestSyncDensity = 0.0
        
        for offset in stride(from: -500, to: 500, by: 10) {
            let testIndex = startIndex + offset
            if testIndex < 0 || testIndex + samplesPerSync >= frequencies.count { continue }
            
            var syncCount = 0
            var totalCount = 0
            for s in stride(from: 0, to: samplesPerSync, by: 5) {
                let freq = frequencies[testIndex + s]
                if abs(freq - syncFreq) < syncTolerance {
                    syncCount += 1
                }
                totalCount += 1
            }
            
            let density = Double(syncCount) / Double(max(1, totalCount))
            if density > bestSyncDensity {
                bestSyncDensity = density
                bestCenterIndex = testIndex
            }
        }
        
        // Now find the START of sync by scanning backwards from center
        // Look for where sync density drops (indicates we're before the sync pulse)
        var adjustedIndex = bestCenterIndex
        let checkWindow = 50  // Check 50 samples at a time
        
        for offset in stride(from: 0, through: samplesPerSync, by: checkWindow) {
            let testIndex = bestCenterIndex - offset
            if testIndex < 0 { break }
            
            // Check if this position is still within the sync pulse
            var syncCount = 0
            for s in 0..<checkWindow {
                if testIndex + s < frequencies.count {
                    let freq = frequencies[testIndex + s]
                    if abs(freq - syncFreq) < syncTolerance {
                        syncCount += 1
                    }
                }
            }
            
            let density = Double(syncCount) / Double(checkWindow)
            if density >= syncDensityThreshold {
                // Still in sync region, this could be the start
                adjustedIndex = testIndex
            } else {
                // Left the sync region, previous position was the start
                break
            }
        }
        
        return adjustedIndex
    }
    
    /// Find the approximate start of the SSTV signal (Goertzel version - legacy)
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
    }
}
