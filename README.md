# SSTV — Swift Command-Line Decoder

A **command-line SSTV decoder written in Swift**, designed to convert recorded SSTV audio (WAV) into decoded images (PNG).

This project is intentionally **CLI-first**, **UI-agnostic**, and **test-driven**, with the long-term goal of reuse inside a native macOS application.

---

## ✨ Goals

- Decode SSTV audio recordings into images
- Support common modes:
  - **PD120** ✅ Implemented
  - **PD180** ✅ Implemented
  - Robot36 (planned)
- Produce deterministic, testable output
- Keep DSP, protocol logic, and image handling cleanly separated
- Avoid premature GUI decisions

Non-goals (for now):
- Live audio capture
- Real-time waterfall display
- Cross-platform UI

---

## 🧱 Architecture Overview

The project is structured as a **single Swift Package Manager executable**, with strong internal boundaries:

```
Audio (WAV parsing)
    ↓
DSP (FM demodulation, frequency tracking)
    ↓
SSTV Protocol (VIS detection, sync, modes)
    ↓
Image Buffer (pixels, YCbCr color space)
    ↓
Image Writer (PNG/JPEG output)
```

Key principles:
- DSP code is **mode-agnostic**
- SSTV modes define **structure and timing**, not math
- Image output is isolated behind a writer
- `main.swift` coordinates, nothing more

This layout is deliberate so the core decoder can later be reused by a macOS app without refactoring.

---

## 📁 Project Layout

```
sstv/
├─ Package.swift
├─ README.md
│
├─ Sources/
│  └─ sstv/
│     ├─ main.swift
│     ├─ Audio/
│     │  └─ WAVReader.swift
│     ├─ DSP/
│     │  ├─ FMDemodulator.swift
│     │  └─ Goertzel.swift
│     ├─ SSTV/
│     │  ├─ DecodingOptions.swift
│     │  ├─ SSTVDecoder.swift
│     │  ├─ SSTVMode.swift
│     │  └─ VISDetector.swift
│     ├─ Modes/
│     │  ├─ PD120Mode.swift
│     │  └─ PD180Mode.swift
│     ├─ Image/
│     │  ├─ ImageBuffer.swift
│     │  └─ ImageWriter.swift
│     └─ Util/
│        └─ ImageComparison.swift
│
├─ Tests/
│  └─ sstvTests/
│     ├─ GoldenFileTests.swift
│     └─ PD120ModeTests.swift
│
└─ samples/
   ├─ PD120/
   └─ PD180/
```

---

## 🚀 Building

Requirements:
- macOS 13+
- Swift 5.9+
- No Xcode required for CLI builds

Build the executable:

```bash
swift build
```

Run the decoder:

```bash
# Basic usage (auto-detects mode via VIS code, PNG output)
swift run sstv input.wav

# Output as JPEG (auto-detected from extension)
swift run sstv input.wav output.jpg

# Force JPEG format with custom quality
swift run sstv input.wav output.png --format jpeg --quality 0.95

# Custom output file
swift run sstv input.wav output.png

# Force a specific mode
swift run sstv input.wav --mode PD120
swift run sstv input.wav --mode PD180
```

---
## 🖼️ Output Formats

The decoder supports both **PNG** and **JPEG** output formats.

### Format Selection

The output format is automatically detected from the file extension:
- `.png` → PNG format
- `.jpg` or `.jpeg` → JPEG format

You can also explicitly specify the format using the `--format` or `-f` option:

```bash
# Force JPEG format even with .png extension
swift run sstv input.wav output.png --format jpeg

# Force PNG format with .jpg extension
swift run sstv input.wav output.jpg --format png
```

### JPEG Quality

When outputting JPEG, you can control the compression quality using `--quality` or `-q`:

```bash
# High quality JPEG (larger file)
swift run sstv input.wav output.jpg --quality 0.95

# Lower quality JPEG (smaller file)
swift run sstv input.wav output.jpg --quality 0.7

# Default quality is 0.9
swift run sstv input.wav output.jpg
```

**Quality values:**
- `0.0` = lowest quality, smallest file
- `1.0` = highest quality, largest file
- `0.9` = default (good balance)
- Recommended range: `0.85` - `0.95` for SSTV images

**Format recommendations:**
- **PNG**: Lossless compression, best for archival and analysis
- **JPEG**: Lossy compression, smaller files, good for sharing

---
## 🎛 Phase and Skew Adjustment

SSTV images often need fine-tuning due to timing variations in recordings. The decoder provides two adjustment options:

### Phase Offset (`-p`, `--phase`)

Corrects **horizontal alignment** issues caused by sync timing errors.

| Value | Effect |
|-------|--------|
| Positive | Shifts image content right |
| Negative | Shifts image content left |

- **Typical range**: -15 to +15 ms
- **Maximum**: ±50 ms
- **Good starting point for PD120**: `11` ms

### Skew Correction (`-s`, `--skew`)

Corrects **diagonal slanting** caused by sample rate mismatch between transmitter and receiver.

| Value | Effect |
|-------|--------|
| Positive | Corrects clockwise slant |
| Negative | Corrects counter-clockwise slant |

- **Typical range**: -0.05 to +0.05 ms/line
- **Maximum**: ±1.0 ms/line
- **Good starting point**: `0.02` ms/line

### Examples

```bash
# Shift image 11ms to the right (good for many PD120 recordings)
swift run sstv input.wav -p 11

# Output as JPEG with adjustments
swift run sstv input.wav output.jpg -p 11 -s 0.015

# High quality JPEG output
swift run sstv input.wav output.jpg -q 0.95 -p 11

# Correct skew of 0.015ms per line
swift run sstv input.wav -s 0.015

# Combined adjustment (recommended for PD120)
swift run sstv input.wav -p 11 -s 0.015

# Force PD180 mode with adjustments
swift run sstv input.wav --mode PD180 -p 5 -s 0.01
```

### Troubleshooting

| Problem | Solution |
|---------|----------|
| Image shifted horizontally | Adjust `-p` (try values between -15 and +15) |
| Vertical lines appear slanted | Adjust `-s` (try values between -0.05 and +0.05) |
| Wrong colors or stretched image | Force correct mode with `--mode PD120` or `--mode PD180` |
| Image looks compressed/expanded | You may be using wrong mode; try the other one |

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
* [ ] Robot36
* [ ] Additional Robot modes
* [ ] Additional PD modes (PD50, PD160, PD240)

Mode implementations live in `Sources/sstv/Modes/` and should read like specifications, not algorithms.

---

## 🛣 Roadmap

Completed:

* ✅ WAV parsing (mono/stereo)
* ✅ VIS code detection and auto-mode selection
* ✅ PD120 decode with YCbCr color space
* ✅ PD180 decode with YCbCr color space
* ✅ PNG output
* ✅ JPEG output with quality control
* ✅ FM demodulation for accurate frequency tracking
* ✅ Phase offset and skew correction

Near-term:

* Robot36 mode support
* Additional PD modes (PD50, PD160, PD240)
* Improved sync tolerance

Later:

* Shared decoder package for macOS UI
* Optional live audio input
* Real-time waterfall display

---

## 📜 License

TBD — assume “for experimentation and learning” until explicitly stated otherwise.

---

## 🧠 Philosophy

This project favours:

* Correctness over cleverness
* Determinism over convenience
* Boring code that survives time

If something feels “too easy” in DSP, it’s probably wrong.

