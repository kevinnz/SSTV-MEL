# SSTV — Swift Command-Line Decoder & Library

**By Kevin Alcock (ZL3XA)**

A **Swift SSTV decoder** providing both a command-line tool and a reusable library (`SSTVCore`) for decoding SSTV audio (WAV) into images (PNG/JPEG).

This project is **library-first**, with a CLI built on top, designed for easy integration into macOS, iOS, and iPadOS applications.

---

## ✨ Goals

- Decode SSTV audio recordings into images
- Support common modes:
  - **PD120** ✅ Implemented
  - **PD180** ✅ Implemented
  - **Robot36** ✅ Implemented
- Produce deterministic, testable output
- Keep DSP, protocol logic, and image handling cleanly separated
- Avoid premature GUI decisions

Non-goals (for now):
- Live audio capture
- Real-time waterfall display
- Cross-platform UI

---

## 🧱 Architecture Overview

The project consists of two targets:
- **SSTVCore**: Reusable Swift library for SSTV decoding
- **sstv**: Command-line executable built on SSTVCore

The library is structured with clear internal boundaries:

```
Audio Source (WAV file or live stream)
    ↓
Sample Provider (push samples to decoder)
    ↓
SSTVDecoderCore (streaming decoder engine)
    ↓
DecoderDelegate (event callbacks)
    ↓
ImageBuffer (incrementally updated)
    ↓
ImageWriter (PNG/JPEG output)
```

Key principles:
- DSP code is **mode-agnostic**
- SSTV modes define **structure and timing**, not math
- Image output is isolated behind a writer
- Decoder emits events via delegate for UI integration
- Streaming API accepts samples incrementally
- CLI coordinates using `swift-argument-parser`, nothing more

This layout is deliberate so the core decoder can later be reused by a macOS app without refactoring.

---

## 📁 Project Layout

```
sstv/
├─ Package.swift
├─ README.md
├─ LICENSE
├─ CONTRIBUTING.md
├─ CODE_OF_CONDUCT.md
├─ SECURITY.md
├─ .gitattributes                 # Git LFS tracking for *.wav
│
├─ .github/
│  ├─ copilot/                    # AI coding assistant instructions
│  ├─ workflows/
│  │  └─ ci.yml                   # GitHub Actions CI (build + test)
│  ├─ ISSUE_TEMPLATE/
│  │  ├─ bug_report.md
│  │  └─ feature_request.md
│  └─ pull_request_template.md
│
├─ Sources/
│  ├─ SSTVCore/                   # Library target (reusable)
│  │  ├─ Audio/
│  │  │  └─ WAVReader.swift
│  │  ├─ DSP/
│  │  │  ├─ FMDemodulator.swift
│  │  │  └─ Goertzel.swift
│  │  ├─ SSTV/
│  │  │  ├─ DecoderDelegate.swift     # Event protocol for UI integration
│  │  │  ├─ DecodingOptions.swift
│  │  │  ├─ DecodingProgress.swift
│  │  │  ├─ SSTVDecoder.swift         # Batch decoder (legacy)
│  │  │  ├─ SSTVDecoderCore.swift     # Streaming decoder engine
│  │  │  ├─ SSTVMode.swift
│  │  │  └─ VISDetector.swift
│  │  ├─ Modes/
│  │  │  ├─ ModeParameters.swift
│  │  │  ├─ PD120Mode.swift
│  │  │  ├─ PD180Mode.swift
│  │  │  └─ Robot36Mode.swift
│  │  ├─ Image/
│  │  │  ├─ ImageBuffer.swift
│  │  │  └─ ImageWriter.swift
│  │  └─ Util/
│  │     └─ ImageComparison.swift
│  │
│  └─ sstv/                       # CLI executable target
│     ├─ SSTVCommand.swift          # Root command (@main entry point)
│     ├─ DecodeCommand.swift        # `decode` subcommand (default)
│     ├─ InfoCommand.swift          # `info` subcommand
│     ├─ CLIDecoderDelegate.swift   # Decoder delegate (stderr-aware)
│     ├─ CLIOutput.swift            # JSON result types & output helpers
│     └─ ExitCodes.swift            # Exit code constants
│
├─ Tests/
│  └─ sstvTests/
│     ├─ DecoderStateTests.swift
│     ├─ GoldenFileTests.swift
│     ├─ PD120ModeTests.swift
│     └─ Robot36ModeTests.swift
│
├─ audio/                         # Ad-hoc test files (see audio/README.md)
│
├─ samples/                       # SSTV recordings for testing (Git LFS)
│  ├─ README.md                   # Source attribution and licensing
│  ├─ PD120/
│  ├─ PD180/
│  └─ Robot36/
│
├─ expected/                      # Golden-file reference images
│  ├─ PD120/
│  └─ PD180/
│
├─ scripts/                       # Python analysis/comparison utilities
│
└─ docs/
   ├─ NEXT-STEPS.md
   ├─ PD120-Implementation.md
   ├─ REFERENCES.md               # External references and attribution
   ├─ sstv_05.pdf                 # SSTV Handbook spec (see REFERENCES.md)
   ├─ adr/                        # Architecture Decision Records
   ├─ modes/                      # Mode-specific documentation
   └─ internal/                   # Historical development artifacts
```

---

## 📚 Using as a Library

SSTVCore can be integrated into your Swift projects:

### Adding as a Dependency

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/kevinnz/SSTV-MEL.git", from: "0.6.0")
],
targets: [
    .target(
        name: "YourTarget",
        dependencies: ["SSTVCore"])
]
```

### Basic Usage

#### Decode and Save to File

```swift
import SSTVCore

// Read audio file
let audio = try WAVReader.read(path: "signal.wav")

// Decode with options
let options = DecodingOptions(
    phaseOffsetMs: 11.0,
    skewMsPerLine: 0.015
)
let decoder = SSTVDecoder()
let buffer = try decoder.decode(audio: audio, options: options)

// Save as PNG or JPEG
try ImageWriter.write(buffer: buffer, to: "output.png")
try ImageWriter.write(buffer: buffer, to: "output.jpg", format: .jpeg(quality: 0.95))
```

#### Encode to Data (for UI Integration)

```swift
import SSTVCore

// Decode as above...
let buffer = try decoder.decode(audio: audio, options: options)

// Encode to PNG data
let pngData = try ImageWriter.encode(buffer: buffer, format: .png)

// Encode to JPEG data with custom quality
let jpegData = try ImageWriter.encode(buffer: buffer, format: .jpeg(quality: 0.9))

// Use data with macOS/iOS UI
#if os(macOS)
imageView.image = NSImage(data: pngData)
#elseif os(iOS)
imageView.image = UIImage(data: pngData)
#endif
```

#### Progress Callbacks (for UI Progress Indicators)

```swift
import SSTVCore

let decoder = SSTVDecoder()
let buffer = try decoder.decode(audio: audio, options: options) { progress in
    // Progress callback is called on the same thread as decode()
    // Dispatch to main thread for UI updates
    DispatchQueue.main.async {
        // Update progress bar (0.0...1.0)
        progressBar.doubleValue = progress.overallProgress
        
        // Update status label
        statusLabel.stringValue = progress.phase.description
        
        // Show time remaining
        if let remaining = progress.estimatedSecondsRemaining {
            timeLabel.stringValue = "Time remaining: \(Int(remaining))s"
        }
    }
}
```

Progress phases include:
- **VIS Detection**: Detecting the mode identifier code
- **FM Demodulation**: Converting audio to frequency data
- **Signal Search**: Finding the start of the image data
- **Frame Decoding**: Decoding image lines (reports lines completed)
- **Writing**: Saving output file (CLI only)

#### Streaming Decoder (for UI Applications)

For real-time UI integration with progressive rendering, use `SSTVDecoderCore`:

```swift
import SSTVCore

// Create decoder with sample rate
let decoder = SSTVDecoderCore(sampleRate: 44100.0)

// Set up delegate to receive events
class MyDecoderDelegate: DecoderDelegate {
    func didLockSync(confidence: Float) {
        print("Sync locked with \(Int(confidence * 100))% confidence")
    }
    
    func didDetectVISCode(_ code: UInt8, mode: String) {
        print("Detected mode: \(mode)")
    }
    
    func didDecodeLine(lineNumber: Int, totalLines: Int) {
        // Update UI with each line decoded
        DispatchQueue.main.async {
            self.updateProgressiveImage(decoder.imageBuffer)
        }
    }
    
    func didCompleteImage(_ imageBuffer: ImageBuffer) {
        DispatchQueue.main.async {
            self.displayFinalImage(imageBuffer)
        }
    }
    
    func didChangeState(_ state: DecoderState) {
        print("State: \(state)")
    }
}

decoder.delegate = MyDecoderDelegate()

// Feed samples incrementally (from audio capture, file, etc.)
decoder.processSamples(audioChunk1)
decoder.processSamples(audioChunk2)
// ... continue feeding samples

// Read partial image at any time
if let partialImage = decoder.imageBuffer {
    let data = try ImageWriter.encode(buffer: partialImage, format: .png)
    // Display partial image in UI
}

// Reset for next decode
decoder.reset()
```

**Decoder States:**
- `idle` - Waiting for samples
- `detectingVIS` - Searching for VIS code
- `searchingSync` - Looking for sync pattern
- `decoding(line:totalLines:)` - Actively decoding
- `complete` - Image decode finished
- `error(DecoderError)` - Decode failed

**Available Events:**
- `didLockSync(confidence:)` - Sync pattern found
- `didLoseSync()` - Sync lost during decode
- `didBeginVISDetection()` - Started VIS search
- `didDetectVISCode(_:mode:)` - VIS code identified
- `didFailVISDetection()` - VIS detection failed
- `didDecodeLine(lineNumber:totalLines:)` - Line complete
- `didUpdateProgress(_:)` - Overall progress update
- `didCompleteImage(_:)` - Full image decoded
- `didChangeState(_:)` - State machine transition
- `didEncounterError(_:)` - Error occurred

### Platform Support

- **macOS**: 13.0+
- **iOS/iPadOS**: 16.0+

---

## 🚀 Building & Usage

Requirements:
- macOS 13+
- Swift 5.9+
- No Xcode required for CLI builds

Build the executable:

```bash
swift build
```

### Subcommands

The CLI has two subcommands. `decode` is the default when no subcommand is specified.

| Subcommand | Description |
|------------|-------------|
| `sstv decode` | Decode an SSTV audio signal into an image (default) |
| `sstv info`   | Inspect a WAV file and detect the SSTV mode |

### Quick Start

```bash
# Basic usage (auto-detects mode, PNG output)
swift run sstv input.wav

# These are equivalent — decode is the default subcommand
swift run sstv decode input.wav
swift run sstv input.wav

# Output as JPEG
swift run sstv input.wav output.jpg

# Force JPEG format with custom quality
swift run sstv input.wav output.png --format jpeg --quality 0.95

# Force a specific mode
swift run sstv input.wav --mode PD120

# Inspect audio metadata and detect mode
swift run sstv info input.wav

# Read from stdin
cat input.wav | swift run sstv decode - output.png
```

### Decode Options

```
USAGE: sstv decode <input> [<output>] [--mode <mode>] [--format <format>]
                   [--quality <quality>] [--phase <phase>] [--skew <skew>]
                   [--json] [--quiet] [--verbose]
```

| Option | Short | Description |
|--------|-------|-------------|
| `<input>` | | WAV file path, or `-` for stdin |
| `<output>` | | Output image path (default: `output.png`) |
| `--mode` | `-m` | Force SSTV mode: `PD120`, `PD180`, `Robot36` |
| `--format` | `-f` | Output format: `png`, `jpeg`, `jpg` |
| `--quality` | `-q` | JPEG quality 0.0–1.0 (default: 0.9) |
| `--phase` | `-p` | Horizontal phase offset in ms (±50.0) |
| `--skew` | `-s` | Skew correction in ms/line (±1.0) |
| `--json` | | Output structured JSON result to stdout |
| `--quiet` | `-Q` | Suppress progress output (errors still on stderr) |
| `--verbose` | `-V` | Show detailed diagnostic output |
| `--version` | | Show version number |

### Info Options

```
USAGE: sstv info <input> [--json] [--quiet]
```

| Option | Short | Description |
|--------|-------|-------------|
| `<input>` | | WAV file path, or `-` for stdin |
| `--json` | | Output structured JSON result to stdout |
| `--quiet` | `-Q` | Suppress decorative output |

---

## 🖼️ Output Formats

The output format is automatically detected from the file extension (`.png`, `.jpg`, `.jpeg`), or set explicitly with `--format`.

```bash
# Force JPEG format even with .png extension
swift run sstv input.wav output.png --format jpeg

# JPEG with custom quality (0.0–1.0, default: 0.9)
swift run sstv input.wav output.jpg --quality 0.95
```

**Format recommendations:**
- **PNG**: Lossless, best for archival and analysis
- **JPEG**: Lossy, smaller files, good for sharing (recommended quality: `0.85`–`0.95`)

---

## 🎛 Phase and Skew Adjustment

### Phase Offset (`-p`, `--phase`)

Corrects **horizontal alignment** — shifts the image left or right.

- **Typical range**: -15 to +15 ms — **Maximum**: ±50 ms
- **Good starting point for PD120**: `11` ms

### Skew Correction (`-s`, `--skew`)

Corrects **diagonal slanting** caused by sample rate mismatch.

- **Typical range**: -0.05 to +0.05 ms/line — **Maximum**: ±1.0 ms/line
- **Good starting point**: `0.02` ms/line

### Examples

```bash
swift run sstv input.wav -p 11                   # Shift 11ms right (PD120)
swift run sstv input.wav -s 0.015                # Correct skew
swift run sstv input.wav -p 11 -s 0.015          # Combined (PD120 default)
swift run sstv input.wav output.jpg -q 0.95 -p 11
swift run sstv input.wav --mode PD180 -p 5 -s 0.01
```

### Troubleshooting

| Problem | Solution |
|---------|----------|
| Image shifted horizontally | Adjust `-p` (try -15 to +15) |
| Vertical lines appear slanted | Adjust `-s` (try -0.05 to +0.05) |
| Wrong colors or stretched image | Force correct mode with `--mode` |

---

## 🤖 Machine & AI Agent Integration

The CLI is designed to work well with AI coding assistants (GitHub Copilot, Claude Code, etc.) and automated pipelines.

### JSON Output (`--json`)

Use `--json` on any subcommand to get structured, parseable output on stdout. All human-readable text (progress, banners) goes to stderr and won't interfere.

**Successful decode:**

```bash
swift run sstv decode input.wav output.png --json
```

```json
{
  "audioDuration": 133.49,
  "command": "decode",
  "dimensions": { "height": 496, "width": 640 },
  "format": "png",
  "input": "input.wav",
  "linesDecoded": 496,
  "mode": "PD120",
  "modeSource": "vis-detected",
  "output": "output.png",
  "partial": false,
  "phaseOffsetMs": 0,
  "sampleRate": 44100,
  "skewMsPerLine": 0,
  "success": true,
  "totalLines": 496
}
```

**Error output:**

```json
{
  "command": "decode",
  "error": {
    "code": "sync_not_found",
    "message": "No sync pattern found in audio."
  },
  "success": false
}
```

**Inspect metadata:**

```bash
swift run sstv info input.wav --json
```

```json
{
  "bitsPerSample": 16,
  "channels": 1,
  "command": "info",
  "detectedMode": "PD120",
  "duration": 133.49,
  "expectedDimensions": { "height": 496, "width": 640 },
  "input": "input.wav",
  "sampleRate": 44100,
  "success": true,
  "visCode": "0x5F"
}
```

> **Note:** `detectedMode`, `visCode`, and `expectedDimensions` are omitted from the JSON when detection fails (the field is absent, not null).

### Exit Codes

| Code | Meaning |
|------|---------|
| `0`  | Success |
| `1`  | General error |
| `2`  | Invalid arguments |
| `10` | Input file not found |
| `11` | Invalid WAV format |
| `20` | VIS detection failed |
| `21` | Sync not found |
| `22` | Sync lost (partial image written) |
| `30` | Output write failed |

### Quiet Mode

Use `--quiet` (`-Q`) to suppress all decorative output. Pairs well with exit code checking:

```bash
swift run sstv decode input.wav output.png --quiet
echo $?  # 0 = success
```

### Stdin Support

Read WAV data from a pipe using `-` as the input:

```bash
cat input.wav | swift run sstv decode - output.png --json
curl -s https://example.com/signal.wav | swift run sstv decode - output.png
```

---

## 🧪 Testing

Tests are first-class citizens in this project.

Test strategy includes:

* Unit tests for DSP primitives (e.g. Goertzel)
* VIS and sync detection tests
* Full decode integration tests
* Golden-file image comparisons

Run tests:

```bash
swift test
```

Decoded images are compared against known-good reference output in `samples/` and `expected/` directories.

---

## 🤖 AI Coding Assistants (Important)

This project uses **GitHub Copilot custom instructions** to enforce architectural and DSP constraints.

These live in:

```
.github/copilot/
```

They define:

* Architectural boundaries
* Swift style rules
* DSP guardrails
* SSTV mode responsibilities
* Testing expectations

**Do not bypass these instructions when generating or modifying code.**
They exist to prevent subtle DSP breakage and architectural drift.

---

## 📡 Supported / Planned SSTV Modes

* [x] **PD120** - Implemented and tested
* [x] **PD180** - Implemented and tested
* [x] **Robot36** - Implemented and tested
* [ ] Additional Robot modes (Robot72)
* [ ] Additional PD modes (PD50, PD160, PD240)

Mode implementations live in `Sources/SSTVCore/Modes/` and should read like specifications, not algorithms.

---

## 🛣 Roadmap

Completed:

* ✅ WAV parsing (mono/stereo)
* ✅ VIS code detection and auto-mode selection
* ✅ PD120 decode with YCbCr color space
* ✅ PD180 decode with YCbCr color space
* ✅ Robot36 decode with YCbCr 4:2:0 color space
* ✅ PNG output
* ✅ JPEG output with quality control
* ✅ FM demodulation for accurate frequency tracking
* ✅ Phase offset and skew correction

Near-term:

* Additional Robot modes (Robot72)
* Additional PD modes (PD50, PD160, PD240)
* Improved sync tolerance

Later:

* Shared decoder package for macOS UI
* Optional live audio input
* Real-time waterfall display

---

## 📜 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 🧠 Philosophy

This project favours:

* Correctness over cleverness
* Determinism over convenience
* Boring code that survives time

If something feels “too easy” in DSP, it’s probably wrong.

