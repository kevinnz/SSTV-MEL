# SSTV-MEL — Copilot Instructions

## Project Overview

SSTV-MEL is a native Swift CLI tool that decodes SSTV (Slow Scan Television) audio signals into images. It reads WAV files and produces PNG or JPEG output.

- **Language**: Swift 5.9+, macOS 13+
- **Build system**: Swift Package Manager
- **Entry point**: `Sources/sstv/SSTVCommand.swift` (`@main` using swift-argument-parser)
- **Dependencies**: [swift-argument-parser](https://github.com/apple/swift-argument-parser) 1.3.0+ (CLI only)
- **Supported modes**: PD120 (640×496), PD180 (640×496)
- **Output formats**: PNG, JPEG

## Architecture

```
Sources/
  SSTVCore/       ← Library: decoder, DSP, modes, image output
    DSP/          ← Tone detection, Goertzel, windowing (mode-agnostic)
    Modes/        ← SSTV mode definitions (stateless, no DSP)
    Image/        ← ImageBuffer, ImageWriter (PNG/JPEG)
    SSTV/         ← SSTVDecoderCore (owns decoding state)
  sstv/           ← CLI: argument parsing, I/O, exit codes
Tests/            ← XCTest: unit, integration, golden-file (PSNR/SSIM)
```

- `SSTVDecoderCore` is the single owner of decoding state
- SSTV modes are stateless types conforming to `SSTVMode` — they define timing and structure, not DSP
- DSP layer is mode-agnostic — handles tone detection, energy measurement, filtering
- `ImageWriter` handles PNG and JPEG encoding behind a writer abstraction
- CLI delegates all decoding to `SSTVCore` — no decode logic in CLI

## Hard Constraints

- **Correct over fast** — correctness and clarity always beat performance
- **Pure Swift** — no C, C++, Python, or external DSP libraries
- No SwiftUI or AppKit in core logic (UI-agnostic, reusable in future apps)
- No global state, no singletons
- No async unless explicitly requested
- Single-threaded decoder — no locks in decoding logic
- Do NOT refactor unrelated code

## Timing Model

- SSTV decoding is **time-based**, not sample-count-based
- All pixel extraction uses **fractional sample interpolation**
- Never assume integer samples-per-pixel

## Swift Style

- Prefer structs over classes, prefer immutability
- Use `throws` with explicit error enums — never `fatalError`
- Types: PascalCase. Functions/vars: camelCase
- Public types and functions must have doc comments
- DSP functions must include units (Hz, ms, samples)
- No force unwraps, no magic numbers (use named constants)
- Avoid unnecessary allocations in inner DSP loops

## CLI Design

The CLI uses swift-argument-parser with subcommands (`decode`, `info`). It supports `--json` for structured output, `--quiet`/`--verbose` flags, stdin via `-`, and granular exit codes (0, 1, 2, 10, 11, 20, 21, 22, 30). All human-readable output goes to stderr; stdout is reserved for JSON.
