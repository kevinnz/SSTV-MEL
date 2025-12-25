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
    let outputPath = arguments.count >= 3 ? arguments[2] : "output.png"
    
    print("SSTV Decoder")
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    print("Input:  \(inputPath)")
    print("Output: \(outputPath)")
    print("")
    
    do {
        // Read WAV file
        print("Reading audio file...")
        let audio = try WAVReader.read(path: inputPath)
        
        // Create mode
        let mode = PD120Mode()
        
        // Decode
        let decoder = SSTVDecoder()
        let buffer = try decoder.decode(audio: audio, mode: mode)
        
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
    } catch {
        print("ERROR: Decoding failed")
        print("  \(error)")
        exit(1)
    }
}

func printUsage() {
    print("Usage: sstv <input.wav> [output.png]")
    print("")
    print("Decode SSTV audio (PD120 mode) into a PNG image")
    print("")
    print("Arguments:")
    print("  input.wav   - Input WAV file containing SSTV signal")
    print("  output.png  - Output PNG file (default: output.png)")
}

// Run main
main()
