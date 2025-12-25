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
            buffer = try decoder.decode(audio: audio, forcedMode: modeStr, debug: debugMode)
        } else {
            buffer = try decoder.decode(audio: audio, debug: debugMode)
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
    print("Usage: sstv <input.wav> [output.png] [--mode MODE]")
    print("")
    print("Decode SSTV audio into a PNG image")
    print("")
    print("Arguments:")
    print("  input.wav   - Input WAV file containing SSTV signal")
    print("  output.png  - Output PNG file (default: output.png)")
    print("")
    print("  --debug, -d - Enable debug output (frequency analysis)")
    print("Options:")
    print("  --mode, -m  - Force SSTV mode (PD120, PD180)")
    print("                If not specified, mode is auto-detected via VIS code")
    print("")
    print("Examples:")
    print("  sstv input.wav                         # Auto-detect mode")
    print("  sstv input.wav output.png              # Auto-detect mode, custom output")
    print("  sstv input.wav --mode PD180            # Force PD180 mode")
    print("  sstv input.wav output.png -m PD120     # Force PD120 mode")
}

// Run main
main()
