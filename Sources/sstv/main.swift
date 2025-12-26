import Foundation

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
    var debugMode = false
    var phaseOffsetMs: Double = 0.0
    var skewMsPerLine: Double = 0.0
    
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
        } else if arg == "--debug" || arg == "-d" {
            debugMode = true
            i += 1
        } else {
            outputPath = arg
            i += 1
        }
    }
    
    print("SSTV Decoder")
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    print("Input:  \(inputPath)")
    print("Output: \(outputPath)")
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
    if debugMode {
        print("Debug:  enabled")
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
        
        // Write PNG
        print("Writing PNG...")
        try PNGWriter.write(buffer: buffer, to: outputPath)
        
        print("")
        print("✓ Successfully decoded SSTV image!")
        print("  Saved to: \(outputPath)")
        
    } catch let error as WAVError {
        print("ERROR: Failed to read WAV file")
        print("  \(error)")
        exit(1)
    } catch let error as PNGError {
        print("ERROR: Failed to write PNG file")
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
    print("Decode SSTV audio into a PNG image")
    print("")
    print("Arguments:")
    print("  input.wav   - Input WAV file containing SSTV signal")
    print("  output.png  - Output PNG file (default: output.png)")
    print("")
    print("Options:")
    print("  --mode, -m <MODE>     Force SSTV mode (PD120, PD180)")
    print("                        If not specified, mode is auto-detected via VIS code")
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
    print("  --debug, -d           Enable debug output (frequency analysis)")
    print("")
    print("Examples:")
    print("  sstv input.wav                         # Auto-detect mode")
    print("  sstv input.wav output.png              # Auto-detect mode, custom output")
    print("  sstv input.wav --mode PD180            # Force PD180 mode")
    print("  sstv input.wav -p 1.5                  # Shift image 1.5ms right")
    print("  sstv input.wav -s 0.02                 # Correct 0.02ms/line skew")
    print("  sstv input.wav -p 1.0 -s -0.01         # Combined phase and skew")
}

// Run main
main()
