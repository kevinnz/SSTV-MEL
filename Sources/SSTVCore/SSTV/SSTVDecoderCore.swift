import Foundation

// MARK: - SSTV Decoder Core
//
// This is the primary decoder engine for SSTV signals. It is designed to be:
// - Streaming: Accepts samples incrementally via processSamples()
// - Event-driven: Emits events via DecoderDelegate for UI integration
// - Stateful: Maintains explicit decoder state machine
// - Resettable: Can be reset and reused for multiple decodes
// - Thread-safe: No global or static mutable state
//
// LIFECYCLE:
//   1. Create with init(sampleRate:) or init(mode:sampleRate:)
//   2. Set delegate to receive events
//   3. Call processSamples() repeatedly with audio data
//   4. Decoder emits events as lines are decoded
//   5. Call reset() to decode another image
//
// LIFECYCLE SAFETY:
//   - reset() is idempotent (safe to call multiple times)
//   - Decoder can be reused after reset()
//   - One instance == one decode session at a time
//   - No static/global mutable state
//
// ARCHITECTURE:
//   Audio Source → processSamples() → SSTVDecoderCore → DecoderDelegate → UI
//                                           ↓
//                                     ImageBuffer (readable anytime)

/// SSTV Decoder Core - streaming decoder engine for SSTV signals
///
/// This class provides a clean API for decoding SSTV signals incrementally.
/// It is independent of file I/O, UI, and platform-specific concerns.
///
/// ## Thread Safety
/// This class is NOT thread-safe. All calls to `processSamples()`, `reset()`,
/// and property access should be made from the same thread or synchronized
/// externally. The delegate is called synchronously on the calling thread.
///
/// ## Usage Example
/// ```swift
/// let decoder = SSTVDecoderCore(sampleRate: 44100.0)
/// decoder.delegate = self
/// decoder.processSamples(audioSamples)
/// let partialImage = decoder.imageBuffer
/// ```
///
/// ## Reuse Pattern
/// ```swift
/// // First decode
/// decoder.processSamples(audio1)
/// saveImage(decoder.imageBuffer)
///
/// // Reset and decode another
/// decoder.reset()
/// decoder.processSamples(audio2)
/// saveImage(decoder.imageBuffer)
/// ```
public final class SSTVDecoderCore {
    
    // MARK: - Configuration
    
    /// Audio sample rate in Hz
    ///
    /// This is fixed at initialization and cannot be changed.
    /// Create a new decoder instance for a different sample rate.
    public let sampleRate: Double
    
    /// Current SSTV mode (nil until detected or set)
    public private(set) var mode: SSTVModeDecoder?
    
    /// Decoding options (phase, skew adjustments)
    ///
    /// Can be modified before calling processSamples().
    /// Changes during decoding take effect on subsequent lines.
    public var options: DecodingOptions = .default
    
    // MARK: - Delegate
    
    /// Delegate for receiving decode events
    ///
    /// Events are emitted synchronously on the calling thread.
    /// UI code should dispatch to main thread as needed.
    public weak var delegate: DecoderDelegate?
    
    // MARK: - State (Read-Only from External)
    
    /// Current decoder state
    ///
    /// Observe state changes via the delegate's `didChangeState` callback.
    public private(set) var state: DecoderState = .idle {
        didSet {
            if state != oldValue {
                delegate?.didChangeState(state)
            }
        }
    }
    
    /// Image buffer containing decoded pixels
    ///
    /// This buffer is updated incrementally as lines are decoded.
    /// It is safe to read at any time; partial images are valid.
    /// Returns nil until mode is detected and decoding begins.
    public private(set) var imageBuffer: ImageBuffer?
    
    /// Number of lines decoded so far
    public private(set) var linesDecoded: Int = 0
    
    /// Whether the decoder has been reset and is ready for new input
    public var isReady: Bool {
        state == .idle && sampleBuffer.isEmpty
    }
    
    /// Whether the decoder is currently processing samples
    public var isDecoding: Bool {
        state.isActive
    }
    
    /// Whether decoding has completed (successfully or with error)
    public var isFinished: Bool {
        state.isTerminal
    }
    
    // MARK: - Internal State (NOT shared, NOT static)
    
    /// Accumulated samples for decoding
    private var sampleBuffer: [Float] = []
    
    /// Demodulated frequencies (sample-rate resolution)
    private var frequencies: [Double] = []
    
    /// VIS detector for mode auto-detection
    /// Note: VISDetector is a struct (value type) with no shared state
    private var visDetector = VISDetector()
    
    /// FM frequency tracker for demodulation
    /// Note: Created fresh on init/reset, no shared state
    private var fmTracker: FMFrequencyTracker?
    
    /// Sample index where image data starts
    private var imageStartSample: Int = 0
    
    /// Whether we've completed VIS detection
    private var visDetectionComplete: Bool = false
    
    /// Whether we've found the signal start
    private var signalStartFound: Bool = false
    
    /// Current frame being decoded
    private var currentFrameIndex: Int = 0
    
    /// Samples needed for current decode phase
    private var samplesNeededForPhase: Int = 0
    
    // MARK: - Constants
    
    /// Minimum samples needed to attempt VIS detection (~2 seconds at 44.1kHz)
    private static let minSamplesForVIS: Int = 88200
    
    /// Samples to skip for VIS code/leader tone (~3 seconds)
    private static let skipSecondsForVIS: Double = 3.0
    
    // MARK: - Initialization
    
    /// Create a decoder with auto mode detection
    ///
    /// The mode will be detected from the VIS code in the audio signal.
    /// If VIS detection fails, defaults to PD120.
    ///
    /// - Parameter sampleRate: Audio sample rate in Hz (e.g., 44100.0)
    /// - Precondition: sampleRate must be between 8000 and 192000 Hz
    public init(sampleRate: Double) {
        precondition(sampleRate >= 8000 && sampleRate <= 192000,
                     "Sample rate must be between 8000 and 192000 Hz")
        self.sampleRate = sampleRate
        self.fmTracker = FMFrequencyTracker(sampleRate: sampleRate)
    }
    
    /// Create a decoder with a forced mode
    ///
    /// VIS detection is skipped and the specified mode is used directly.
    ///
    /// - Parameters:
    ///   - mode: SSTV mode to use for decoding
    ///   - sampleRate: Audio sample rate in Hz (e.g., 44100.0)
    /// - Precondition: sampleRate must be between 8000 and 192000 Hz
    public init(mode: SSTVModeDecoder, sampleRate: Double) {
        precondition(sampleRate >= 8000 && sampleRate <= 192000,
                     "Sample rate must be between 8000 and 192000 Hz")
        self.sampleRate = sampleRate
        self.mode = mode
        self.visDetectionComplete = true
        self.fmTracker = FMFrequencyTracker(sampleRate: sampleRate)
    }
    
    // MARK: - Public API
    
    /// Set the SSTV mode explicitly
    ///
    /// Use this to force a specific mode, bypassing VIS detection.
    /// This also resets the decoder state.
    ///
    /// - Parameter mode: The mode to use for decoding
    public func setMode(_ mode: SSTVModeDecoder) {
        self.mode = mode
        self.visDetectionComplete = true
        resetState()
    }
    
    /// Set mode by name
    ///
    /// - Parameter modeName: Mode name (e.g., "PD120", "PD180")
    /// - Returns: true if mode was set, false if unknown mode
    @discardableResult
    public func setMode(named modeName: String) -> Bool {
        switch modeName.uppercased() {
        case "PD120":
            setMode(PD120Mode())
            return true
        case "PD180":
            setMode(PD180Mode())
            return true
        default:
            delegate?.didEncounterError(.unknownMode(modeName))
            return false
        }
    }
    
    /// Process incoming audio samples
    ///
    /// Samples are accumulated and decoded incrementally. Events are emitted
    /// via the delegate as decode milestones are reached.
    ///
    /// This method can be called repeatedly with chunks of audio data.
    /// The decoder maintains internal state between calls.
    ///
    /// - Parameter samples: Array of audio samples (mono, normalized -1.0...1.0)
    public func processSamples(_ samples: [Float]) {
        guard !samples.isEmpty else { return }
        
        // Validate sample rate (should be caught at init, but check anyway)
        guard sampleRate >= 8000 && sampleRate <= 192000 else {
            state = .error(.invalidSampleRate(sampleRate))
            delegate?.didEncounterError(.invalidSampleRate(sampleRate))
            return
        }
        
        // Accumulate samples
        sampleBuffer.append(contentsOf: samples)
        
        // Process based on current state
        switch state {
        case .idle:
            // Start processing
            if !visDetectionComplete {
                state = .detectingVIS
                delegate?.didBeginVISDetection()
            } else {
                state = .searchingSync
            }
            processAccumulatedSamples()
            
        case .detectingVIS:
            processVISDetection()
            
        case .searchingSync:
            processSignalSearch()
            
        case .syncLocked:
            // Sync locked, transition to decoding.
            // Note: This state is transient and primarily exists for event emission
            // and UI observability. The transition to decoding happens immediately
            // in the same processSamples() call, but the syncLocked state is
            // observable by delegates via didLockSync() callback.
            if let mode = mode {
                state = .decoding(line: 0, totalLines: mode.height)
            }
            processFrameDecoding()
            
        case .decoding:
            processFrameDecoding()
            
        case .syncLost(let line):
            // Attempt to recover sync based on configurable threshold
            let totalLines = mode?.height ?? 0
            let recoveryThreshold = Int(Double(totalLines) * options.syncRecoveryThreshold)
            
            if linesDecoded < recoveryThreshold {
                // Lost sync early (before threshold), try to find it again
                signalStartFound = false
                state = .searchingSync
                processSignalSearch()
            } else {
                // Lost sync late (after threshold), emit partial image
                state = .error(.syncLost(atLine: line))
                delegate?.didEncounterError(.syncLost(atLine: line))
            }
            
        case .complete, .error:
            // Already finished; ignore additional samples
            break
        }
    }
    
    /// Reset the decoder for a new decode
    ///
    /// Clears all accumulated samples and state. After reset, the decoder
    /// is in the same state as a freshly created instance.
    ///
    /// This method is idempotent - calling it multiple times has the same
    /// effect as calling it once.
    ///
    /// Configuration preserved after reset:
    /// - Sample rate (immutable)
    /// - Delegate reference
    /// - Decoding options
    ///
    /// Configuration cleared:
    /// - Mode (will be re-detected from VIS)
    /// - Image buffer
    /// - All accumulated samples and frequencies
    public func reset() {
        resetState()
        self.mode = nil
        self.visDetectionComplete = false
    }
    
    /// Reset while preserving the current mode
    ///
    /// Use this when you want to decode another image using the same mode
    /// without VIS detection.
    ///
    /// This method is idempotent - calling it multiple times has the same
    /// effect as calling it once.
    public func resetKeepingMode() {
        let currentMode = self.mode
        resetState()
        self.mode = currentMode
        self.visDetectionComplete = currentMode != nil
    }
    
    /// Get overall decode progress (0.0...1.0)
    public var progress: Float {
        guard let mode = mode else {
            return visDetectionComplete ? 0.0 : 0.05
        }
        
        switch state {
        case .idle:
            return 0.0
        case .detectingVIS:
            return 0.05
        case .searchingSync:
            return 0.1
        case .syncLocked:
            return 0.15
        case .decoding:
            let lineProgress = Float(linesDecoded) / Float(mode.height)
            return 0.15 + lineProgress * 0.85
        case .syncLost:
            // Return progress at point of sync loss
            return 0.15 + Float(linesDecoded) / Float(mode.height) * 0.85
        case .complete:
            return 1.0
        case .error:
            return Float(linesDecoded) / Float(mode.height)
        }
    }
    
    // MARK: - Internal Processing
    
    /// Reset internal state to initial values
    ///
    /// This method is idempotent - calling multiple times has same effect.
    /// All instance state is cleared; no global/static state is modified.
    private func resetState() {
        // Clear accumulated audio data (preserve buffer capacity for reuse)
        sampleBuffer.removeAll(keepingCapacity: true)
        frequencies.removeAll(keepingCapacity: true)
        
        // Clear image state
        imageBuffer = nil
        linesDecoded = 0
        
        // Clear sync/frame tracking
        imageStartSample = 0
        signalStartFound = false
        currentFrameIndex = 0
        samplesNeededForPhase = 0
        
        // Reset state machine to idle
        state = .idle
        
        // Create fresh FM tracker (no shared state from previous decode)
        fmTracker = FMFrequencyTracker(sampleRate: sampleRate)
        
        // VISDetector is a stateless struct, no reset needed
        // (keeping this line for clarity in resetState method)
    }
    
    // MARK: - Diagnostic Helpers
    
    /// Emit a diagnostic message to the delegate
    ///
    /// Use this instead of print/printf for all debugging output.
    /// The delegate can choose to display, log, or ignore diagnostics.
    ///
    /// Performance note: This method checks for a delegate before creating
    /// the DiagnosticInfo struct to avoid overhead when diagnostics aren't consumed.
    private func emitDiagnostic(
        _ level: DiagnosticInfo.Level,
        category: DiagnosticInfo.Category,
        message: String,
        data: [String: String] = [:]
    ) {
        guard delegate != nil else { return }
        
        let info = DiagnosticInfo(
            level: level,
            category: category,
            message: message,
            data: data
        )
        delegate?.didEmitDiagnostic(info)
    }
    
    /// Process accumulated samples based on current state
    private func processAccumulatedSamples() {
        switch state {
        case .detectingVIS:
            processVISDetection()
        case .searchingSync:
            processSignalSearch()
        case .decoding:
            processFrameDecoding()
        default:
            break
        }
    }
    
    /// Process VIS detection phase
    private func processVISDetection() {
        // Need minimum samples for VIS detection
        guard sampleBuffer.count >= Self.minSamplesForVIS else {
            emitDiagnostic(.debug, category: .general,
                message: "Waiting for samples for VIS detection",
                data: ["samples": "\(sampleBuffer.count)", "required": "\(Self.minSamplesForVIS)"])
            return
        }
        
        // Convert to Double for VIS detector
        let samples = sampleBuffer.map { Double($0) }
        
        // Attempt VIS detection
        if let visResult = visDetector.detect(samples: samples, sampleRate: sampleRate) {
            emitDiagnostic(.info, category: .sync,
                message: "VIS code detected",
                data: ["code": "0x\(String(format: "%02X", visResult.code))", "mode": visResult.mode])
            
            // VIS code detected
            switch visResult.code {
            case 0x60:  // 96 decimal - PD180
                mode = PD180Mode()
                delegate?.didDetectVISCode(visResult.code, mode: "PD180")
            case 0x5F:  // 95 decimal - PD120
                mode = PD120Mode()
                delegate?.didDetectVISCode(visResult.code, mode: "PD120")
            default:
                // Unknown VIS code, default to PD120
                mode = PD120Mode()
                delegate?.didDetectVISCode(visResult.code, mode: "PD120 (fallback)")
                emitDiagnostic(.warning, category: .sync,
                    message: "Unknown VIS code, defaulting to PD120",
                    data: ["code": "0x\(String(format: "%02X", visResult.code))"])
            }
        } else {
            // VIS detection failed, default to PD120
            mode = PD120Mode()
            delegate?.didFailVISDetection()
            emitDiagnostic(.warning, category: .sync,
                message: "VIS detection failed, defaulting to PD120")
        }
        
        visDetectionComplete = true
        
        // Create image buffer
        if let mode = mode {
            imageBuffer = ImageBuffer(width: mode.width, height: mode.height)
        }
        
        // Transition to signal search
        state = .searchingSync
        processSignalSearch()
    }
    
    /// Process signal search phase
    private func processSignalSearch() {
        guard let mode = mode else { return }
        
        // Need enough samples for FM demodulation and signal search
        let minSamplesForSearch = Int(Self.skipSecondsForVIS * sampleRate) + 
                                  Int(mode.frameDurationMs * sampleRate / 1000.0) * 10
        
        guard sampleBuffer.count >= minSamplesForSearch else {
            return
        }
        
        // Demodulate accumulated samples
        let samples = sampleBuffer.map { Double($0) }
        if let tracker = fmTracker {
            frequencies = tracker.track(samples: samples)
        }
        
        // Find signal start
        let (startSample, confidence) = findSignalStartWithConfidence(
            frequencies: frequencies,
            mode: mode,
            sampleRate: sampleRate
        )
        
        // Check if signal search failed (confidence near zero)
        // Using epsilon for floating-point comparison
        if confidence < 1e-9 {
            delegate?.didLoseSync()
            state = .syncLost(atLine: 0)
            return
        }
        
        imageStartSample = startSample
        signalStartFound = true
        
        // Report sync lock with confidence
        delegate?.didLockSync(confidence: confidence)
        
        // Transition to syncLocked state first, then to decoding
        state = .syncLocked(confidence: confidence)
        
        // Immediately transition to decoding
        state = .decoding(line: 0, totalLines: mode.height)
        processFrameDecoding()
    }
    
    /// Process frame decoding phase
    private func processFrameDecoding() {
        guard let mode = mode,
              var buffer = imageBuffer,
              signalStartFound else { return }
        
        let samplesPerFrame = Int(mode.frameDurationMs * sampleRate / 1000.0)
        let numFrames = mode.height / mode.linesPerFrame
        
        // Continue decoding frames until we run out of data
        while currentFrameIndex < numFrames {
            let frameStartSample = imageStartSample + currentFrameIndex * samplesPerFrame
            let frameEndSample = frameStartSample + samplesPerFrame
            
            // Check if we have enough samples for this frame
            guard frameEndSample <= frequencies.count else {
                // Not enough samples yet, wait for more
                return
            }
            
            // Extract frequencies for this frame
            let frameFrequencies = Array(frequencies[frameStartSample..<frameEndSample])
            
            // Decode the frame
            let rows = mode.decodeFrame(
                frequencies: frameFrequencies,
                sampleRate: sampleRate,
                frameIndex: currentFrameIndex,
                options: options
            )
            
            // Store each row in buffer
            for (rowOffset, pixels) in rows.enumerated() {
                let lineIndex = currentFrameIndex * mode.linesPerFrame + rowOffset
                if lineIndex < mode.height {
                    buffer.setRow(y: lineIndex, rowPixels: pixels)
                    linesDecoded = lineIndex + 1
                    
                    // Emit line decoded event
                    delegate?.didDecodeLine(lineNumber: lineIndex, totalLines: mode.height)
                    
                    // Update progress periodically
                    if lineIndex % 10 == 0 || lineIndex == mode.height - 1 {
                        delegate?.didUpdateProgress(progress)
                    }
                }
            }
            
            // Update state
            state = .decoding(line: linesDecoded, totalLines: mode.height)
            imageBuffer = buffer
            
            currentFrameIndex += 1
        }
        
        // All frames decoded
        if linesDecoded >= mode.height {
            state = .complete
            if let finalBuffer = imageBuffer {
                delegate?.didCompleteImage(finalBuffer)
            }
            delegate?.didUpdateProgress(1.0)
        }
    }
    
    // MARK: - Signal Detection
    
    /// Find the start of the SSTV signal in frequency data with confidence score
    ///
    /// This looks for the characteristic sync pulse pattern that marks the
    /// beginning of each frame. We search for a position where multiple
    /// consecutive frames have valid sync patterns.
    ///
    /// - Parameters:
    ///   - frequencies: Demodulated frequency data
    ///   - mode: SSTV mode being decoded
    ///   - sampleRate: Audio sample rate
    /// - Returns: Tuple of (start sample index, confidence 0.0...1.0)
    private func findSignalStartWithConfidence(
        frequencies: [Double],
        mode: SSTVModeDecoder,
        sampleRate: Double
    ) -> (startSample: Int, confidence: Float) {
        let syncFreq = mode.syncFrequencyHz
        let syncTolerance = 150.0
        let samplesPerFrame = Int(mode.frameDurationMs * sampleRate / 1000.0)
        let samplesPerSync = Int(20.0 * sampleRate / 1000.0)  // 20ms sync pulse
        
        // Skip past VIS code and leader tone
        let skipSamples = Int(Self.skipSecondsForVIS * sampleRate)
        
        // Need enough room for a full image
        let requiredSamples = samplesPerFrame * (mode.height / mode.linesPerFrame)
        let searchLimit = frequencies.count - requiredSamples
        
        guard searchLimit > skipSamples else {
            // Not enough samples to search - return failure
            return (skipSamples, 0.0)
        }
        
        // Search step - check every ~1ms
        let searchStep = Int(sampleRate / 1000)
        
        var bestStartIndex = skipSamples
        var bestValidFrames = 0
        var bestScore = 0
        
        for startIndex in stride(from: skipSamples, to: searchLimit, by: searchStep) {
            var validFrames = 0
            var totalScore = 0
            
            // Check up to 10 consecutive frames
            for frameNum in 0..<10 {
                let frameStart = startIndex + frameNum * samplesPerFrame
                if frameStart + samplesPerFrame >= frequencies.count { break }
                
                // Check for sync pulse at start of frame
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
                
                // Check for image frequencies after sync
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
                
                // Frame is valid if sync and image data look good
                if totalChecks > 0 && syncCount >= totalChecks * 4 / 10 && imageCount >= 5 {
                    validFrames += 1
                    totalScore += syncCount + imageCount
                }
            }
            
            // Track best match
            if validFrames > bestValidFrames || (validFrames == bestValidFrames && totalScore > bestScore) {
                bestValidFrames = validFrames
                bestScore = totalScore
                bestStartIndex = startIndex
            }
            
            // Accept if we have at least 6 valid consecutive frames (early exit)
            if validFrames >= 6 {
                let confidence = Float(validFrames) / 10.0
                let fineTuned = fineTuneSyncStart(
                    startIndex: startIndex,
                    frequencies: frequencies,
                    syncFreq: syncFreq,
                    syncTolerance: syncTolerance,
                    samplesPerSync: samplesPerSync
                )
                return (fineTuned, confidence)
            }
        }
        
        // Use best match found, even if not ideal
        if bestValidFrames >= 3 {
            let confidence = Float(bestValidFrames) / 10.0
            let fineTuned = fineTuneSyncStart(
                startIndex: bestStartIndex,
                frequencies: frequencies,
                syncFreq: syncFreq,
                syncTolerance: syncTolerance,
                samplesPerSync: samplesPerSync
            )
            return (fineTuned, confidence)
        }
        
        // Fallback: no valid pattern found
        return (skipSamples, 0.0)
    }
    
    /// Fine-tune the sync start position
    private func fineTuneSyncStart(
        startIndex: Int,
        frequencies: [Double],
        syncFreq: Double,
        syncTolerance: Double,
        samplesPerSync: Int
    ) -> Int {
        // Find position with best sync density
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
        
        // Scan backwards to find start of sync pulse
        var adjustedIndex = bestCenterIndex
        let checkWindow = 50
        
        for offset in stride(from: 0, through: samplesPerSync, by: checkWindow) {
            let testIndex = bestCenterIndex - offset
            if testIndex < 0 { break }
            
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
            if density >= 0.4 {
                adjustedIndex = testIndex
            } else {
                break
            }
        }
        
        return adjustedIndex
    }
}

// MARK: - Convenience Extensions

public extension SSTVDecoderCore {
    
    /// Process samples from a Double array
    ///
    /// Convenience method for when audio is already in Double format.
    func processSamples(_ samples: [Double]) {
        processSamples(samples.map { Float($0) })
    }
    
    /// Decode an entire WAV file at once
    ///
    /// This is a convenience method for batch processing. For streaming/UI use,
    /// prefer the incremental processSamples() approach.
    ///
    /// - Parameters:
    ///   - audio: WAV file to decode
    ///   - progressHandler: Optional callback for progress updates (legacy API)
    /// - Returns: Decoded image buffer
    /// - Throws: Error if decoding fails
    func decode(audio: WAVFile, progressHandler: ProgressHandler? = nil) throws -> ImageBuffer {
        // Reset state for fresh decode
        reset()
        
        // Bridge progress handler to delegate
        let bridgeDelegate = ProgressBridgeDelegate(handler: progressHandler)
        let originalDelegate = self.delegate
        self.delegate = bridgeDelegate
        
        // Process all samples at once
        processSamples(audio.monoSamples.map { Float($0) })
        
        // Restore original delegate
        self.delegate = originalDelegate
        
        // Check result
        switch state {
        case .complete:
            guard let buffer = imageBuffer else {
                throw DecoderError.insufficientSamples
            }
            return buffer
            
        case .error(let error):
            throw error
            
        default:
            // Still need more samples
            if let buffer = imageBuffer, linesDecoded > 0 {
                // Return partial image
                return buffer
            }
            throw DecoderError.insufficientSamples
        }
    }
}

// MARK: - Progress Bridge Delegate

/// Internal delegate that bridges the old ProgressHandler API to DecoderDelegate
private final class ProgressBridgeDelegate: DecoderDelegate {
    let handler: ProgressHandler?
    private let startTime = Date()
    private var modeName: String?
    
    init(handler: ProgressHandler?) {
        self.handler = handler
    }
    
    func didDetectVISCode(_ code: UInt8, mode: String) {
        modeName = mode
    }
    
    func didDecodeLine(lineNumber: Int, totalLines: Int) {
        guard let handler = handler else { return }
        
        let elapsed = Date().timeIntervalSince(startTime)
        let lineProgress = Double(lineNumber + 1) / Double(totalLines)
        let estimated = elapsed / lineProgress
        let remaining = estimated - elapsed
        
        let progress = DecodingProgress(
            phase: .frameDecoding(linesDecoded: lineNumber + 1, totalLines: totalLines),
            overallProgress: 0.3 + lineProgress * 0.7,
            elapsedSeconds: elapsed,
            estimatedSecondsRemaining: remaining,
            modeName: modeName
        )
        handler(progress)
    }
    
    func didChangeState(_ state: DecoderState) {
        guard let handler = handler else { return }
        
        let elapsed = Date().timeIntervalSince(startTime)
        
        switch state {
        case .detectingVIS:
            handler(DecodingProgress(
                phase: .visDetection(progress: 0.5),
                overallProgress: 0.05,
                elapsedSeconds: elapsed
            ))
        case .searchingSync:
            handler(DecodingProgress(
                phase: .signalSearch,
                overallProgress: 0.1,
                elapsedSeconds: elapsed,
                modeName: modeName
            ))
        case .complete:
            handler(DecodingProgress(
                phase: .writing,  // Using .writing as completion indicator
                overallProgress: 1.0,
                elapsedSeconds: elapsed,
                modeName: modeName
            ))
        default:
            break
        }
    }
}
