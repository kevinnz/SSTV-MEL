import ArgumentParser
import Foundation
import SSTVCore

struct Info: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Inspect a WAV file and detect the SSTV mode without decoding.",
        discussion: """
        Reads a WAV file and reports audio metadata (sample rate, duration, \
        channels) and attempts to detect the SSTV mode via VIS code.

        Use '-' as the input path to read WAV data from stdin.
        """
    )

    @Argument(help: "Input WAV file path, or '-' for stdin.")
    var input: String

    @Flag(name: .long, help: "Output result as JSON to stdout.")
    var json = false

    @Flag(name: [.customShort("Q"), .long],
          help: "Suppress decorative output.")
    var quiet = false

    mutating func run() throws {
        do {
            try execute()
        } catch let error as SSTVCLIError {
            if json {
                exitWithJSONError(command: "info", error: error)
            }
            printToStderr("Error: \(error.message)")
            throw ExitCode(rawValue: error.exitCode)
        }
    }

    private func execute() throws {
        // Read audio
        let audio: WAVFile
        do {
            audio = try readInput()
        } catch let error as WAVError {
            switch error {
            case .fileNotFound:
                throw SSTVCLIError(exitCode: SSTVExitCode.inputNotFound,
                                   code: "file_not_found",
                                   message: "Input file not found: \(input)")
            default:
                throw SSTVCLIError(exitCode: SSTVExitCode.invalidWAV,
                                   code: "invalid_wav",
                                   message: "Failed to read WAV file: \(error)")
            }
        }

        // Attempt VIS detection by feeding first ~10 seconds
        let decoder = SSTVDecoderCore(sampleRate: audio.sampleRate)
        let delegate = CLIDecoderDelegate(quiet: true, jsonMode: true) // capture only, no output
        decoder.delegate = delegate

        let maxSamples = Int(audio.sampleRate * 10.0)
        let samples = Array(audio.monoSamples.prefix(maxSamples)).map { Float($0) }
        decoder.processSamples(samples)

        let detectedMode = delegate.detectedMode
        let visCode = delegate.detectedVISCode
        let dims: Dimensions?
        if let buf = decoder.imageBuffer {
            dims = Dimensions(width: buf.width, height: buf.height)
        } else {
            dims = nil
        }

        if json {
            let result = InfoResult(
                success: true,
                command: "info",
                input: input,
                sampleRate: audio.sampleRate,
                channels: audio.channels,
                bitsPerSample: audio.bitsPerSample,
                duration: audio.duration,
                detectedMode: detectedMode,
                visCode: visCode.map { "0x\(String(format: "%02X", $0))" },
                expectedDimensions: dims
            )
            printJSON(result)
        } else if !quiet {
            printToStderr("SSTV Info")
            printToStderr("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            printToStderr("Input:       \(input)")
            printToStderr("Sample rate: \(Int(audio.sampleRate)) Hz")
            printToStderr("Channels:    \(audio.channels)")
            printToStderr("Bit depth:   \(audio.bitsPerSample)")
            printToStderr("Duration:    \(String(format: "%.2f", audio.duration)) seconds")
            printToStderr("")
            if let code = visCode, let mode = detectedMode {
                printToStderr("VIS code:    0x\(String(format: "%02X", code)) → \(mode)")
            } else {
                printToStderr("VIS code:    not detected")
            }
            if let d = dims {
                printToStderr("Dimensions:  \(d.width) × \(d.height)")
            }
        }
    }

    private func readInput() throws -> WAVFile {
        if input == "-" {
            let tempDir = NSTemporaryDirectory()
            let tempPath = (tempDir as NSString).appendingPathComponent("sstv-stdin-\(ProcessInfo.processInfo.processIdentifier).wav")
            defer { try? FileManager.default.removeItem(atPath: tempPath) }

            let stdinData = FileHandle.standardInput.readDataToEndOfFile()
            guard !stdinData.isEmpty else {
                throw SSTVCLIError(exitCode: SSTVExitCode.invalidWAV,
                                   code: "empty_stdin",
                                   message: "No data received on stdin.")
            }
            FileManager.default.createFile(atPath: tempPath, contents: stdinData)
            return try WAVReader.read(path: tempPath)
        }
        return try WAVReader.read(path: input)
    }
}
