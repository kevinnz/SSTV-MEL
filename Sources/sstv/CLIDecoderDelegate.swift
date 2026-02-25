import Foundation
import SSTVCore

/// Decoder delegate that writes progress to stderr.
///
/// Respects `--quiet`, `--verbose`, and `--json` flags:
/// - In JSON mode, all text output is suppressed.
/// - In quiet mode, only errors are shown.
/// - In verbose mode, diagnostics are shown.
final class CLIDecoderDelegate: DecoderDelegate {
    private let startTime = Date()
    private var lastProgressUpdate = Date()
    private let updateInterval: TimeInterval = 1.0

    let quiet: Bool
    let verbose: Bool
    let jsonMode: Bool

    private(set) var detectedMode: String?
    private(set) var detectedVISCode: UInt8?

    init(quiet: Bool = false, verbose: Bool = false, jsonMode: Bool = false) {
        self.quiet = quiet
        self.verbose = verbose
        self.jsonMode = jsonMode
    }

    private func status(_ message: String) {
        guard !quiet && !jsonMode else { return }
        printToStderr(message)
    }

    func didBeginVISDetection() {
        status("  Detecting VIS code...")
    }

    func didDetectVISCode(_ code: UInt8, mode: String) {
        detectedVISCode = code
        detectedMode = mode
        status("  VIS code: 0x\(String(format: "%02X", code)) → \(mode)")
    }

    func didFailVISDetection() {
        detectedMode = "PD120"
        status("  VIS detection failed, defaulting to PD120")
    }

    func didLockSync(confidence: Float) {
        status("  Sync locked (\(Int(confidence * 100))% confidence)")
    }

    func didLoseSync() {
        status("\n  ⚠ Sync lost, attempting recovery...")
    }

    func didDecodeLine(lineNumber: Int, totalLines: Int) {
        guard !quiet && !jsonMode else { return }
        let now = Date()
        if now.timeIntervalSince(lastProgressUpdate) >= updateInterval {
            lastProgressUpdate = now
            printLineProgress(lineNumber: lineNumber, totalLines: totalLines)
        }
    }

    func didUpdateProgress(_ progress: Float) {
        // Handled by didDecodeLine for line-level granularity
    }

    func didCompleteImage(_ imageBuffer: ImageBuffer) {
        if !quiet && !jsonMode {
            printToStderr("")
        }
    }

    func didChangeState(_ state: DecoderState) {
        // State changes are implicit in other delegate events
    }

    func didEncounterError(_ error: DecoderError) {
        printToStderr("  ⚠ Decoder error: \(error.description)")
    }

    func didEmitDiagnostic(_ info: DiagnosticInfo) {
        guard verbose && !jsonMode else { return }
        printToStderr("  [\(info.category)] \(info.message)")
    }

    private func printLineProgress(lineNumber: Int, totalLines: Int) {
        let elapsed = Date().timeIntervalSince(startTime)
        let progress = Double(lineNumber + 1) / Double(totalLines)
        let estimated = elapsed / progress
        let remaining = estimated - elapsed

        let bar = makeProgressBar(progress: progress, width: 30)
        let percent = Int(progress * 100)

        var line = "\r  \(bar) \(percent)% | Decoding: \(lineNumber + 1)/\(totalLines) lines"
        line += " | ETA: \(formatTime(remaining))"

        writeToStderr(line)
        fflush(stderr)
    }
}
