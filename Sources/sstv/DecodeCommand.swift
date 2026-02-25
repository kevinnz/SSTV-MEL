import ArgumentParser
import Foundation
import SSTVCore

struct Decode: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Decode an SSTV audio signal into an image.",
        discussion: """
        Reads a WAV file containing an SSTV signal, detects the transmission \
        mode via VIS code, and decodes it into a PNG or JPEG image.

        Use '-' as the input path to read WAV data from stdin.
        """
    )

    @Argument(help: "Input WAV file path, or '-' for stdin.")
    var input: String

    @Argument(help: "Output image file path.")
    var output: String = "output.png"

    @Option(name: [.customShort("m"), .long],
            help: "Force SSTV mode instead of auto-detecting via VIS code.")
    var mode: SSTVMode?

    @Option(name: [.customShort("f"), .long],
            help: "Output image format. Overrides file extension detection.")
    var format: OutputImageFormat?

    @Option(name: [.customShort("q"), .long],
            help: "JPEG quality from 0.0 (smallest) to 1.0 (best).")
    var quality: Double = 0.9

    @Option(name: [.customShort("p"), .long],
            help: "Horizontal phase offset in milliseconds (range: ±50.0).")
    var phase: Double = 0.0

    @Option(name: [.customShort("s"), .long],
            help: "Skew correction in milliseconds per line (range: ±1.0).")
    var skew: Double = 0.0

    @Flag(name: .long, help: "Output result as JSON to stdout.")
    var json = false

    @Flag(name: [.customShort("Q"), .long],
          help: "Suppress progress and decorative output. Errors still appear on stderr.")
    var quiet = false

    @Flag(name: [.customShort("V"), .long],
          help: "Show detailed diagnostic output from the decoder.")
    var verbose = false

    func validate() throws {
        if quiet && verbose {
            throw ValidationError("--quiet and --verbose cannot be used together.")
        }
        if quality < 0.0 || quality > 1.0 {
            throw ValidationError("--quality must be between 0.0 and 1.0.")
        }
    }

    mutating func run() throws {
        do {
            try execute()
        } catch let error as SSTVCLIError {
            if json {
                exitWithJSONError(command: "decode", error: error)
            }
            printToStderr("Error: \(error.message)")
            throw ExitCode(rawValue: error.exitCode)
        }
    }

    private func execute() throws {
        // Resolve output format
        let outputFormat: ImageFormat
        if let fmt = format {
            outputFormat = fmt.toImageFormat(quality: quality)
        } else {
            let detected = ImageFormat.from(path: output)
            if case .jpeg = detected {
                outputFormat = .jpeg(quality: quality)
            } else {
                outputFormat = detected
            }
        }

        let options = DecodingOptions(
            phaseOffsetMs: phase,
            skewMsPerLine: skew
        )

        // Print header
        if !quiet && !json {
            printToStderr("SSTV Decoder")
            printToStderr("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            printToStderr("Input:  \(input)")
            printToStderr("Output: \(output)")
            switch outputFormat {
            case .png:
                printToStderr("Format: PNG")
            case .jpeg(let q):
                printToStderr("Format: JPEG (quality: \(String(format: "%.2f", q)))")
            }
            if let m = mode {
                printToStderr("Mode:   \(m.rawValue) (forced)")
            }
            if phase != 0.0 || options.phaseOffsetMs != 0.0 {
                if options.phaseOffsetMs != phase {
                    printToStderr("Phase:  \(String(format: "%.2f", options.phaseOffsetMs)) ms (clamped from \(String(format: "%.2f", phase)))")
                } else {
                    printToStderr("Phase:  \(String(format: "%.2f", phase)) ms")
                }
            }
            if skew != 0.0 || options.skewMsPerLine != 0.0 {
                if options.skewMsPerLine != skew {
                    printToStderr("Skew:   \(String(format: "%.4f", options.skewMsPerLine)) ms/line (clamped from \(String(format: "%.4f", skew)))")
                } else {
                    printToStderr("Skew:   \(String(format: "%.4f", skew)) ms/line")
                }
            }
            printToStderr("")
        }

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

        if !quiet && !json {
            printToStderr("Reading audio file...")
            printToStderr("Decoding SSTV signal...")
            printToStderr("  Sample rate: \(Int(audio.sampleRate)) Hz")
            printToStderr("  Duration: \(String(format: "%.2f", audio.duration)) seconds")
        }

        // Set up decoder
        let decoder = SSTVDecoderCore(sampleRate: audio.sampleRate)
        decoder.options = options

        let delegate = CLIDecoderDelegate(quiet: quiet, verbose: verbose, jsonMode: json)
        decoder.delegate = delegate

        if let m = mode {
            if !decoder.setMode(named: m.rawValue) {
                throw SSTVCLIError(exitCode: SSTVExitCode.generalError,
                                   code: "unknown_mode",
                                   message: "Unknown mode '\(m.rawValue)'. Supported: PD120, PD180, Robot36")
            }
        }

        // Decode
        let samples = audio.monoSamples.map { Float($0) }
        decoder.processSamples(samples)

        // Check result
        let buffer: ImageBuffer
        let isPartial: Bool

        switch decoder.state {
        case .complete:
            guard let decodedBuffer = decoder.imageBuffer else {
                throw SSTVCLIError(exitCode: SSTVExitCode.generalError,
                                   code: "no_image_buffer",
                                   message: "Decoding completed but no image buffer available.")
            }
            buffer = decodedBuffer
            isPartial = false

        case .error(let error):
            if let partialBuffer = decoder.imageBuffer, decoder.linesDecoded > 0 {
                if !quiet && !json {
                    printToStderr("  ⚠ Partial image: \(decoder.linesDecoded) lines decoded")
                }
                buffer = partialBuffer
                isPartial = true
            } else {
                let cliError: SSTVCLIError
                switch error {
                case .syncNotFound:
                    cliError = SSTVCLIError(exitCode: SSTVExitCode.syncNotFound,
                                            code: "sync_not_found",
                                            message: "No sync pattern found in audio.")
                case .syncLost(let atLine):
                    cliError = SSTVCLIError(exitCode: SSTVExitCode.syncLost,
                                            code: "sync_lost",
                                            message: "Sync lost at line \(atLine), no lines decoded.")
                case .unknownMode(let m):
                    cliError = SSTVCLIError(exitCode: SSTVExitCode.visDetectionFailed,
                                            code: "vis_detection_failed",
                                            message: "Could not detect SSTV mode (unknown VIS: \(m)).")
                default:
                    cliError = SSTVCLIError(exitCode: SSTVExitCode.generalError,
                                            code: "decode_error",
                                            message: error.description)
                }
                throw cliError
            }

        default:
            if let partialBuffer = decoder.imageBuffer, decoder.linesDecoded > 0 {
                if !quiet && !json {
                    printToStderr("  ⚠ Incomplete decode: \(decoder.linesDecoded) lines")
                }
                buffer = partialBuffer
                isPartial = true
            } else {
                throw SSTVCLIError(exitCode: SSTVExitCode.generalError,
                                   code: "insufficient_samples",
                                   message: "Insufficient audio samples for decoding.")
            }
        }

        // Write image
        let formatName: String
        switch outputFormat {
        case .png: formatName = "png"
        case .jpeg: formatName = "jpeg"
        }

        if !quiet && !json {
            printToStderr("Writing \(formatName.uppercased())...")
        }

        do {
            try ImageWriter.write(buffer: buffer, to: output, format: outputFormat)
        } catch {
            throw SSTVCLIError(exitCode: SSTVExitCode.outputWriteFailed,
                               code: "output_write_failed",
                               message: "Failed to write image: \(error)")
        }

        // Determine total lines from buffer height
        let totalLines = buffer.height
        let modeSource = (mode != nil) ? "forced" : "vis-detected"
        let detectedModeName = mode?.rawValue ?? delegate.detectedMode ?? "unknown"

        if json {
            let result = DecodeResult(
                success: true,
                command: "decode",
                input: input,
                output: output,
                mode: detectedModeName,
                modeSource: modeSource,
                dimensions: Dimensions(width: buffer.width, height: buffer.height),
                linesDecoded: decoder.linesDecoded,
                totalLines: totalLines,
                format: formatName,
                audioDuration: audio.duration,
                sampleRate: audio.sampleRate,
                phaseOffsetMs: options.phaseOffsetMs,
                skewMsPerLine: options.skewMsPerLine,
                partial: isPartial
            )
            printJSON(result)
        } else if !quiet {
            printToStderr("")
            printToStderr("✓ Successfully decoded SSTV image!")
            printToStderr("  Saved to: \(output)")
        }

        if isPartial {
            throw ExitCode(rawValue: SSTVExitCode.syncLost)
        }
    }

    /// Read WAV from file or stdin.
    private func readInput() throws -> WAVFile {
        if input == "-" {
            // Read stdin to a temporary file, then parse
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

// MARK: - Argument types

enum SSTVMode: String, ExpressibleByArgument, CaseIterable {
    case pd120 = "PD120"
    case pd180 = "PD180"
    case robot36 = "Robot36"

    init?(argument: String) {
        for m in SSTVMode.allCases {
            if argument.caseInsensitiveCompare(m.rawValue) == .orderedSame {
                self = m
                return
            }
        }
        return nil
    }

    static var allValueStrings: [String] {
        allCases.map(\.rawValue)
    }
}

enum OutputImageFormat: String, ExpressibleByArgument, CaseIterable {
    case png
    case jpeg
    case jpg

    init?(argument: String) {
        switch argument.lowercased() {
        case "png": self = .png
        case "jpeg": self = .jpeg
        case "jpg": self = .jpg
        default: return nil
        }
    }

    func toImageFormat(quality: Double) -> ImageFormat {
        switch self {
        case .png: return .png
        case .jpeg, .jpg: return .jpeg(quality: quality)
        }
    }
}
