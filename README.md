# SSTV — Swift Command-Line Decoder

A **command-line SSTV decoder written in Swift**, designed to convert recorded SSTV audio (WAV) into decoded images (PNG).

This project is intentionally **CLI-first**, **UI-agnostic**, and **test-driven**, with the long-term goal of reuse inside a native macOS application.

---

## ✨ Goals

- Decode SSTV audio recordings into images
- Support common modes (initially):
  - Robot36
  - PD120
  - PD180
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
DSP (tone detection, timing)
↓
SSTV Protocol (VIS, sync, modes)
↓
Image Buffer (pixels, color space)
↓
PNG Writer

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
│     ├─ CLI/
│     ├─ Audio/
│     ├─ DSP/
│     ├─ SSTV/
│     ├─ Modes/
│     ├─ Image/
│     └─ Util/
│
├─ Tests/
│  └─ sstvTests/
│
└─ Samples/
├─ *.wav
└─ expected/
└─ *.png

````

---

## 🚀 Building

Requirements:
- macOS 13+
- Swift 5.9+
- No Xcode required for CLI builds

Build the executable:

```bash
swift build
````

Run the decoder:

```bash
# Basic usage (auto-detects mode, defaults to PD120)
.build/release/sstv input.wav -o output.png

# Force a specific mode
.build/release/sstv input.wav -o output.png --mode PD120
.build/release/sstv input.wav -o output.png --mode PD180
```

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
.build/release/sstv input.wav -o output.png -p 11

# Correct skew of 0.02ms per line
.build/release/sstv input.wav -o output.png -s 0.02

# Combined adjustment (recommended for PD120)
.build/release/sstv input.wav -o output.png -p 11 -s 0.02

# Force PD180 mode with adjustments
.build/release/sstv input.wav -o output.png --mode PD180 -p 5 -s 0.01
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

Decoded images are compared against known-good reference output in `/Samples/expected`.

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

* [x] Robot36 (planned)
* [x] PD120 (planned)
* [x] PD180 (planned)
* [ ] Additional Robot modes
* [ ] Additional PD modes

Mode implementations live in `Sources/sstv/Modes/` and should read like specifications, not algorithms.

---

## 🛣 Roadmap

Near-term:

* WAV parsing and resampling
* VIS decoding
* Robot36 decode
* PD120 decode
* PD180 decode
* PNG output

Later:

* Mode auto-detection
* Improved sync tolerance
* Shared decoder package for macOS UI
* Optional live audio input

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

