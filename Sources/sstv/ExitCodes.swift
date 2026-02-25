import Foundation

/// Exit codes for the SSTV CLI.
///
/// Machine consumers can use these codes to determine the category of failure
/// without parsing error messages.
enum SSTVExitCode {
    static let success: Int32 = 0
    static let generalError: Int32 = 1
    // 2 reserved for ArgumentParser validation errors
    static let inputNotFound: Int32 = 10
    static let invalidWAV: Int32 = 11
    static let visDetectionFailed: Int32 = 20
    static let syncNotFound: Int32 = 21
    static let syncLost: Int32 = 22
    static let outputWriteFailed: Int32 = 30
}

/// Typed CLI error that carries an exit code and a machine-readable error key.
struct SSTVCLIError: Error, CustomStringConvertible {
    let exitCode: Int32
    let code: String
    let message: String

    var description: String { message }
}
