# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.7.0] — 2026-04-12

### Performance

- Fix O(n²) redundant FM demodulation in streaming decoder — track last demodulated count to avoid reprocessing the entire sample buffer on each `processSamples` call
- Convert `sampleBuffer` from `[Float]` to `[Double]` throughout `SSTVDecoderCore`, eliminating repeated Float→Double conversions in VIS detection, signal search, and frame decoding
- Optimise `ImageBuffer.setRow()` to use `replaceSubrange` instead of element-by-element copy
- Optimise `ImageBuffer.toRGB8()` and `toRGBA8()` with pre-allocated arrays and indexed writes

### Fixed

- PD180 porch timing corrected from 2.0ms to 2.08ms (matching PD120 and spec)
- VIS detector now performs even-parity single-bit error correction before rejecting ambiguous codes
- VIS detector retries with shifted analysis windows (±5, ±3, ±1 steps) for improved robustness

### Added

- `PDModeShared` — shared PD mode logic (`decodeComponentTimeBased`, `frequencyToValue`, `ycbcrToRGB`) eliminating duplication across PD120, PD180, and Robot36 modes
- `DecodingOptions.skipSecondsForVIS` — configurable VIS search start offset (default 3.0s, range 0–30s)
- Signal search retry-from-zero fallback in `findSignalStartWithConfidence()` when initial skip-based search finds insufficient valid frames
- 33 new unit tests: Goertzel/ToneDetector/FrequencyTracker (9), FMDemodulator (8), VISDetector (6), SignalSearch integration (4), Robot36 expanded (6)

### Changed

- PD120Mode, PD180Mode, and Robot36Mode refactored to delegate shared DSP math to `PDModeShared`
- Robot36Mode retains thin internal wrappers for test API compatibility

## [0.6.0] — 2026-02-08

### Added

- Robot36 SSTV mode support with comprehensive tests and sample files
- `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md`, and `SECURITY.md`
- GitHub Actions CI workflow (build + test on macOS)
- Issue templates (bug report, feature request) and PR template
- Git LFS tracking for WAV sample files
- `samples/README.md` with source attribution for all test recordings
- `audio/README.md` clarifying ad-hoc test files vs samples

### Fixed

- Decoder regression: support forced mode and partial decodes
- Batch mode demodulation: create image buffer in `init(mode:sampleRate:)` constructor

### Changed

- Moved internal development docs to `docs/internal/`
- Rewrote `docs/NEXT-STEPS.md` as a public-facing roadmap
- Moved Python analysis scripts to `scripts/` directory
- Refactored Python scripts to use relative paths instead of absolute paths
- Updated `README.md` project layout to reflect current structure

## [0.5.0] — 2025-12-27

### Changed

- Extracted `SSTVDecoderCore` streaming decoder, decoupled from CLI
- Refactored CLI to use `SSTVDecoderCore` instead of batch `SSTVDecoder`

## [0.3.0] — 2025-12-27

### Added

- Comprehensive tests for `DiagnosticInfo`, `DecoderState`, and `ModeParameters`
- New test WAV files (`test3.wav`, `test4.wav`)

### Fixed

- `--help` flag being treated as a filename
- Floating-point comparison in tests

### Changed

- Refactored SSTV-MEL into UI-ready decoder engine
- Improved `toRGBA8` memory efficiency
- Documented existential type performance considerations

## [0.2.0] — 2025-12-27

### Added

- `SSTVDecoderCore` streaming decoder for UI integration

### Changed

- Updated README to match repository structure

## [0.1.0] — 2025-12-27

### Added

- Library-first architecture: `SSTVCore` library target + `sstv` CLI executable
- PD120 SSTV mode with full decoding pipeline
- PD180 SSTV mode with ADR-001 compliant quadrature FM demodulation
- `DecoderDelegate` protocol for event-driven UI integration
- Progress callback support for decode operations
- `ImageWriter.encode()` method for in-memory image generation
- WAV file reader with mono/stereo support
- FM demodulator with vDSP-optimised FIR filter
- Goertzel frequency detection for VIS header and sync pulses
- Golden-file test infrastructure with SSIM image comparison
- Automated comparison scripts (Python) for decode quality analysis

[Unreleased]: https://github.com/kevinnz/SSTV-MEL/compare/v0.7.0...HEAD
[0.7.0]: https://github.com/kevinnz/SSTV-MEL/compare/v0.6.0...v0.7.0
[0.6.0]: https://github.com/kevinnz/SSTV-MEL/compare/v0.5.0...v0.6.0
[0.5.0]: https://github.com/kevinnz/SSTV-MEL/compare/v0.3.0...v0.5.0
[0.3.0]: https://github.com/kevinnz/SSTV-MEL/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/kevinnz/SSTV-MEL/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/kevinnz/SSTV-MEL/releases/tag/v0.1.0
