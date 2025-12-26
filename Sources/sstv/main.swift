import Foundation
import SSTVCore

/// Command-line SSTV decoder
func main() {
    let arguments = CommandLine.arguments
    
    // Simple argument parsing
    guard arguments.count >= 2 else {
        printUsage()
        exit(1)
    }
    
    let inputPath = arguments[1]
    var outputPath = "output.png"
    var forcedMode: String? = nil
    var phaseOffsetMs: Double = 0.0
    var skewMsPerLine: Double = 0.0
    var formatType: String? = nil  // Track format type separately
    var jpegQuality: Double = 0.9
    
    // Parse optional arguments
    var i = 2
    while i < arguments.count {
        let arg = arguments[i]
        if arg == "--mode" || arg == "-m" {
            if i + 1 < arguments.count {
                forcedMode = arguments[i + 1]
                i += 2
            } else {
                print("Error: --mode requires a value")
                exit(1)
            }
        } else if arg == "--phase" || arg == "-p" {
            if i + 1 < arguments.count, let value = Double(arguments[i + 1]) {
                phaseOffsetMs = value
                i += 2
            } else {
                print("Error: --phase requires a numeric value (milliseconds)")
                exit(1)
            }
        } else if arg == "--skew" || arg == "-s" {
            if i + 1 < arguments.count, let value = Double(arguments[i + 1]) {
                skewMsPerLine = value
                i += 2
            } else {
                print("Error: --skew requires a numeric value (milliseconds per line)")
                exit(1)
            }
        } else if arg == "--format" || arg == "-f" {
            if i + 1 < arguments.count {
                let formatStr = arguments[i + 1].lowercased()
                if formatStr == "png" {
                    formatType = "png"
                } else if formatStr == "jpeg" || formatStr == "jpg" {
                    formatType = "jpeg"
                } else {
                    print("Error: --format must be 'png' or 'jpeg'")
                    exit(1)
                }
                i += 2
            } else {
                print("Error: --format requires a value (png or jpeg)")
                exit(1)
            }
        } else if arg == "--quality" || arg == "-q" {
            if i + 1 < arguments.count, let value = Double(arguments[i + 1]) {
                jpegQuality = min(max(value, 0.0), 1.0)
                i += 2
            } else {
                print("Error: --quality requires a numeric value (0.0 to 1.0)")
                exit(1)
            }
        } else {
            outputPath = arg
            i += 1
        }
    }
    
    // Construct final ImageFormat after all arguments are parsed
    let outputFormat: ImageFormat
    if let formatType = formatType {
        // Format explicitly specified via --format
        if formatType == "png" {
            outputFormat = .png
        } else {
            outputFormat = .jpeg(quality: jpegQuality)
        }
    } else {
        // Auto-detect format from extension
        let detectedFormat = ImageFormat.from(path: outputPath)
        // Apply custom quality if it's JPEG
        if case .jpeg = detectedFormat {
            outputFormat = .jpeg(quality: jpegQuality)
        } else {
            outputFormat = detectedFormat
        }
    }
    
    print("SSTV Decoder")
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    print("Input:  \(inputPath)")
    print("Output: \(outputPath)")
    switch outputFormat {
    case .png:
        print("Format: PNG")
    case .jpeg(let quality):
        print("Format: JPEG (quality: \(String(format: "%.2f", quality)))")
    }
    if let mode = forcedMode {
        print("Mode:   \(mode) (forced)")
    }
    
    // Create decoding options (values will be clamped automatically)
    let options = DecodingOptions(
        phaseOffsetMs: phaseOffsetMs,
        skewMsPerLine: skewMsPerLine
    )
    
    // Show phase/skew values and warn if clamped
    if phaseOffsetMs != 0.0 || options.phaseOffsetMs != 0.0 {
        if options.phaseOffsetMs != phaseOffsetMs {
            print("Phase:  \(String(format: "%.2f", options.phaseOffsetMs)) ms (clamped from \(String(format: "%.2f", phaseOffsetMs)))")
        } else {
            print("Phase:  \(String(format: "%.2f", phaseOffsetMs)) ms")
        }
    }
    if skewMsPerLine != 0.0 || options.skewMsPerLine != 0.0 {
        if options.skewMsPerLine != skewMsPerLine {
            print("Skew:   \(String(format: "%.4f", options.skewMsPerLine)) ms/line (clamped from \(String(format: "%.4f", skewMsPerLine)))")
        } else {
            print("Skew:   \(String(format: "%.4f", skewMsPerLine)) ms/line")
        }
    }
    print("")
    
    do {
        // Read WAV file
        print("Reading audio file...")
        let audio = try WAVReader.read(path: inputPath)
        
        // Decode with auto mode detection or forced mode
        let decoder = SSTVDecoder()
        let buffer: ImageBuffer
        
        if let modeStr = forcedMode {
            buffer = try decoder.decode(audio: audio, forcedMode: modeStr, options: options)
        } else {
            buffer = try decoder.decode(audio: audio, options: options)
        }
        
        // Write image file
        let formatName = switch outputFormat {
        case .png: "PNG"
        case .jpeg: "JPEG"
        }
        print("Writing \(formatName)...")
        try ImageWriter.write(buffer: buffer, to: outputPath, format: outputFormat)
        
        print("")
        print("✓ Successfully decoded SSTV image!")
        print("  Saved to: \(outputPath)")
        
    } catch let error as WAVError {
        print("ERROR: Failed to read WAV file")
        print("  \(error)")
        exit(1)
    } catch let error as ImageWriteError {
        print("ERROR: Failed to write image file")
        print("  \(error)")
        exit(1)
    } catch let error as DecodingError {
        print("ERROR: Decoding failed")
        print("  \(error)")
        exit(1)
    } catch {
        print("ERROR: Unexpected error")
        print("  \(error)")
        exit(1)
    }
}

func printUsage() {
    print("Usage: sstv <input.wav> [output.png] [options]")
    print("")
    print("Decode SSTV audio into a PNG or JPEG image")
    print("")
    print("Arguments:")
    print("  input.wav   - Input WAV file containing SSTV signal")
    print("  output.png  - Output image file (default: output.png)")
    print("                Format auto-detected from extension (.png, .jpg, .jpeg)")
    print("")
    print("Options:")
    print("  --mode, -m <MODE>     Force SSTV mode (PD120, PD180)")
    print("                        If not specified, mode is auto-detected via VIS code")
    print("")
    print("  --format, -f <FORMAT> Output format: 'png' or 'jpeg'")
    print("                        Overrides format detected from file extension")
    print("                        Default: png")
    print("")
    print("  --quality, -q <NUM>   JPEG quality (0.0 to 1.0, default: 0.9)")
    print("                        Only applies to JPEG output")
    print("                        Higher values = better quality, larger files")
    print("")
    print("  --phase, -p <MS>      Horizontal phase offset in milliseconds")
    print("                        Positive values shift image right, negative shift left")
    print("                        Use to correct horizontal alignment issues")
    print("                        Typical range: -5.0 to +5.0, max: ±50.0")
    print("")
    print("  --skew, -s <MS/LINE>  Skew correction in milliseconds per line")
    print("                        Corrects diagonal slanting caused by timing drift")
    print("                        Positive values correct clockwise slant")
    print("                        Typical range: -0.5 to +0.5, max: ±1.0")
    print("")
    print("Examples:")
    print("  sstv input.wav                         # Auto-detect mode, PNG output")
    print("  sstv input.wav output.jpg              # Auto-detect mode, JPEG output")
    print("  sstv input.wav output.png -f jpeg      # Force JPEG format")
    print("  sstv input.wav output.jpg -q 0.95      # JPEG with high quality")
    print("  sstv input.wav --mode PD180            # Force PD180 mode")
    print("  sstv input.wav -p 1.5                  # Shift image 1.5ms right")
    print("  sstv input.wav -s 0.02                 # Correct 0.02ms/line skew")
    print("  sstv input.wav -p 1.0 -s -0.01         # Combined phase and skew")
}

// Run main
main()
