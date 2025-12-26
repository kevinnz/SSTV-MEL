# Refactor SSTV Decoder to Library + CLI

## Goal
Restructure the SSTV decoder project to:
1. **Create a reusable Swift library** (`SSTVCore`) that can be used in UI applications
2. **Keep the existing CLI** functionality as a separate executable target
3. **Enable UI integration** with progress callbacks and async support

## Current Structure
```
Sources/sstv/
  main.swift
  Audio/, DSP/, Image/, Modes/, SSTV/, Util/
```

## Target Structure
```
Sources/
  SSTVCore/          # Library target (reusable)
    Audio/
      WAVReader.swift
    DSP/
      FMDemodulator.swift
      Goertzel.swift
    Image/
      ImageBuffer.swift
      ImageEncoder.swift     # Renamed from PNGWriter
    Modes/
      PD120Mode.swift
      PD180Mode.swift
    SSTV/
      DecodingOptions.swift
      SSTVDecoder.swift
      SSTVMode.swift
      VISDetector.swift
    Util/
      ImageComparison.swift
      
  sstv/              # CLI executable target
    main.swift       # Only CLI logic
```

## Step-by-Step Implementation

### 1. Update Package.swift
Replace the current package definition to have two targets:

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "sstv",
    platforms: [.macOS(.v13), .iOS(.v16)],
    products: [
        .library(
            name: "SSTVCore",
            targets: ["SSTVCore"]
        ),
        .executable(
            name: "sstv",
            targets: ["sstv"]
        )
    ],
    targets: [
        .target(
            name: "SSTVCore",
            path: "Sources/SSTVCore"
        ),
        .executableTarget(
            name: "sstv",
            dependencies: ["SSTVCore"],
            path: "Sources/sstv"
        ),
        .testTarget(
            name: "sstvTests",
            dependencies: ["SSTVCore"],
            path: "Tests/sstvTests"
        )
    ]
)
```

### 2. Move Files to SSTVCore
Create the `Sources/SSTVCore` directory and move all subdirectories **except main.swift**:
- Move `Sources/sstv/Audio/` → `Sources/SSTVCore/Audio/`
- Move `Sources/sstv/DSP/` → `Sources/SSTVCore/DSP/`
- Move `Sources/sstv/Image/` → `Sources/SSTVCore/Image/`
- Move `Sources/sstv/Modes/` → `Sources/SSTVCore/Modes/`
- Move `Sources/sstv/SSTV/` → `Sources/SSTVCore/SSTV/`
- Move `Sources/sstv/Util/` → `Sources/SSTVCore/Util/`

Keep only `main.swift` in `Sources/sstv/`.

### 3. Add Progress Callback Support
In `Sources/SSTVCore/SSTV/SSTVDecoder.swift`, add:

```swift
/// Progress information during decoding
public struct DecodingProgress {
    public let linesDecoded: Int
    public let totalLines: Int
    public let currentLine: Int
    public let elapsedSeconds: Double
    public let mode: String
    
    public var percentComplete: Double {
        guard totalLines > 0 else { return 0 }
        return Double(linesDecoded) / Double(totalLines) * 100
    }
}

/// Callback for progress updates
public typealias ProgressHandler = (DecodingProgress) -> Void
```

Update the `decode` method signature:
```swift
public func decode(
    audio: WAVFile,
    options: DecodingOptions = .default,
    progressHandler: ProgressHandler? = nil
) throws -> ImageBuffer
```

Inside the decoding loop (in PD120Mode/PD180Mode), call the progress handler:
```swift
if let progressHandler = progressHandler {
    let progress = DecodingProgress(
        linesDecoded: y,
        totalLines: height,
        currentLine: y,
        elapsedSeconds: currentTime - startTime,
        mode: "PD120"
    )
    progressHandler(progress)
}
```

### 4. Refactor PNGWriter to ImageEncoder
Rename `Sources/SSTVCore/Image/PNGWriter.swift` → `Sources/SSTVCore/Image/ImageEncoder.swift`

Change from file-writing to data-returning:
```swift
import Foundation

public enum ImageEncoder {
    /// Encode an ImageBuffer to PNG data
    public static func encodePNG(buffer: ImageBuffer) throws -> Data {
        // Existing PNG encoding logic
        // Return Data instead of writing to file
    }
    
    /// Write PNG data to a file (convenience for CLI)
    public static func writePNG(buffer: ImageBuffer, to path: String) throws {
        let data = try encodePNG(buffer: buffer)
        try data.write(to: URL(fileURLWithPath: path))
    }
}
```

### 5. Make All Public Types Accessible
Add `public` visibility to all types that should be used from the library:

- `public struct DecodingOptions`
- `public struct ImageBuffer`
- `public class SSTVDecoder`
- `public protocol SSTVMode`
- `public class PD120Mode`
- `public class PD180Mode`
- `public class WAVReader`
- `public struct WAVFile`
- All public methods and properties

### 6. Remove Console Output from Library
In `SSTVDecoder.swift` and mode files:
- Remove all `print()` statements
- Replace with `progressHandler` calls where appropriate
- Keep error throwing for error handling

### 7. Update main.swift (CLI)
Keep the CLI thin - just argument parsing and file I/O:

```swift
import Foundation
import SSTVCore

// Parse command line arguments
// Read WAV file using WAVReader
// Create DecodingOptions from CLI args
// Call SSTVDecoder.decode() with progress handler that prints to console
// Use ImageEncoder.writePNG() to save output
// Handle errors and print messages
```

### 8. Update Tests
Change imports in test files:
```swift
import XCTest
@testable import SSTVCore  // Changed from @testable import sstv
```

### 9. Add Library Documentation
Create a README or documentation showing how to use the library:

```swift
// iOS/macOS App Example
import SSTVCore

let decoder = SSTVDecoder()
let options = DecodingOptions(
    forcedMode: .PD120,
    phaseOffsetMs: 11.0,
    skewMsPerLine: 0.02
)

do {
    let buffer = try decoder.decode(
        audio: wavFile,
        options: options
    ) { progress in
        DispatchQueue.main.async {
            progressLabel.text = "\(Int(progress.percentComplete))%"
            progressBar.progress = Float(progress.percentComplete / 100)
        }
    }
    
    let pngData = try ImageEncoder.encodePNG(buffer: buffer)
    imageView.image = UIImage(data: pngData)
} catch {
    print("Decoding failed: \(error)")
}
```

## Testing Checklist
- [ ] `swift build` succeeds for both targets
- [ ] CLI still works: `.build/debug/sstv samples/PD120/*.wav -o test.png`
- [ ] Unit tests pass: `swift test`
- [ ] Library can be imported: `import SSTVCore`
- [ ] Progress callbacks work in CLI
- [ ] Image encoding returns Data correctly
- [ ] All public APIs are documented

## Benefits
1. **Reusable**: Import `SSTVCore` in any Swift project (iOS, macOS, tvOS, watchOS)
2. **Progress tracking**: UI apps can show real-time decoding progress
3. **Flexible**: Decode from any audio source, not just files
4. **Maintained CLI**: Command-line tool still works exactly as before
5. **Testable**: Library code can be unit tested independently

## Migration Notes
- Existing CLI users: No changes needed, same command-line interface
- New library users: `import SSTVCore` and use `SSTVDecoder` directly
- The CLI becomes a thin wrapper around the library
- Breaking change: This requires major version bump (2.0.0)
