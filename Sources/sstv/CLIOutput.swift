import Foundation

// MARK: - Stderr helpers

/// Write a line to stderr (used for all human-readable output).
func printToStderr(_ message: String) {
    FileHandle.standardError.write(Data((message + "\n").utf8))
}

/// Write to stderr without a trailing newline (for progress bars).
func writeToStderr(_ message: String) {
    FileHandle.standardError.write(Data(message.utf8))
}

// MARK: - JSON result types

struct DecodeResult: Codable {
    let success: Bool
    let command: String
    let input: String
    let output: String
    let mode: String
    let modeSource: String
    let dimensions: Dimensions
    let linesDecoded: Int
    let totalLines: Int
    let format: String
    let audioDuration: Double
    let sampleRate: Double
    let phaseOffsetMs: Double
    let skewMsPerLine: Double
    let partial: Bool
}

struct InfoResult: Codable {
    let success: Bool
    let command: String
    let input: String
    let sampleRate: Double
    let channels: Int
    let bitsPerSample: Int
    let duration: Double
    let detectedMode: String?
    let visCode: String?
    let expectedDimensions: Dimensions?
}

struct Dimensions: Codable {
    let width: Int
    let height: Int
}

struct ErrorResult: Codable {
    let success: Bool
    let command: String
    let error: ErrorDetail
}

struct ErrorDetail: Codable {
    let code: String
    let message: String
}

/// Encode a Codable value as pretty-printed JSON and print to stdout.
func printJSON<T: Codable>(_ value: T) {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    if let data = try? encoder.encode(value),
       let json = String(data: data, encoding: .utf8) {
        print(json)
    }
}

/// Print a JSON error result and exit with the given code.
func exitWithJSONError(command: String, error: SSTVCLIError) -> Never {
    let result = ErrorResult(
        success: false,
        command: command,
        error: ErrorDetail(code: error.code, message: error.message)
    )
    printJSON(result)
    Foundation.exit(error.exitCode)
}

// MARK: - Progress bar / time formatting

/// Create a progress bar string.
func makeProgressBar(progress: Double, width: Int) -> String {
    let filled = Int(progress * Double(width))
    let empty = width - filled
    return "[" + String(repeating: "█", count: filled)
         + String(repeating: "░", count: empty) + "]"
}

/// Format a time interval for display.
func formatTime(_ seconds: TimeInterval) -> String {
    let totalSeconds = Int(seconds)
    let minutes = totalSeconds / 60
    let secs = totalSeconds % 60
    if minutes > 0 {
        return "\(minutes)m \(secs)s"
    }
    return "\(secs)s"
}
