---
description: "Testing conventions and rules for SSTV-MEL"
applyTo: "Tests/**"
---

# Testing Instructions

## Framework

- XCTest only

## Test Types

- **Unit tests** for DSP primitives (tone detection, Goertzel, windowing)
- **Unit tests** for VIS code decoding
- **Integration tests** for full decode pipeline
- **Golden-file tests** for image output quality

## Rules

- Tests must be deterministic
- No reliance on wall-clock time
- Sample WAV files live in `samples/` (stored in Git LFS)
- Do not generate placeholder assertions

## Image Comparison

- Golden-file tests compare decoded images against reference files using **PSNR** (Peak Signal-to-Noise Ratio) and **SSIM** (Structural Similarity Index)
- Use `ImageComparison.compare()` which returns `peakSignalToNoiseRatio` and `structuralSimilarity` scores
- Thresholds are configured per test (typically ~4–8 dB minimum PSNR)
- Document the expected output source (QSSTV, MMSSTV, etc.)

## DSP Tests

- Test with synthetic sine waves at known frequencies and amplitudes
- Verify deterministic results across runs

Tests are first-class citizens. Every new feature or mode should include corresponding tests.
