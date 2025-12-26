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
swift run sstv input.wav --mode PD120 --out output.png
swift run sstv input.wav --mode PD180 --out output.png
```

(Exact CLI flags may evolve — see `--help`.)

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

