# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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

[Unreleased]: https://github.com/kevinnz/SSTV-MEL/compare/v0.6.0...HEAD
[0.6.0]: https://github.com/kevinnz/SSTV-MEL/compare/v0.5.0...v0.6.0
[0.5.0]: https://github.com/kevinnz/SSTV-MEL/compare/v0.3.0...v0.5.0
[0.3.0]: https://github.com/kevinnz/SSTV-MEL/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/kevinnz/SSTV-MEL/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/kevinnz/SSTV-MEL/releases/tag/v0.1.0
