# Copilot Instructions — SSTV Swift CLI Project

## Project Goal
This project implements a **command-line SSTV decoder in Swift**.
It converts **WAV audio files** into **PNG images** for SSTV modes such as:
- Robot36
- PD120

The decoder must be:
- Deterministic
- Testable
- UI-agnostic
- Suitable for reuse in a future macOS app

## Hard Constraints
- Swift Package Manager only
- No SwiftUI or AppKit in core logic
- No global state
- No async unless explicitly requested
- No external dependencies unless approved

## Architectural Rules
- `main.swift` must only coordinate execution
- DSP logic must be mode-agnostic
- SSTV modes define timing and structure, not DSP math
- Image output must be isolated behind a writer abstraction

## Output Expectations
- Decoding produces a complete image buffer
- Output is saved as a PNG file
- Errors are explicit and typed

## Testing Philosophy
- Prefer unit tests over manual inspection
- Use golden-file testing for image output
- DSP functions should be testable with synthetic signals

Do not introduce UI concepts, live audio capture, or platform-specific APIs unless explicitly instructed.
