# PD120 Line Decoding Implementation

This document describes the PD120 line decoding implementation for the SSTV-MEL decoder.

## Overview

The implementation consists of three main components:

1. **ImageBuffer** ([Image/ImageBuffer.swift](Sources/sstv/Image/ImageBuffer.swift)) - A simple buffer for storing decoded image data
2. **SSTVMode Protocol** ([SSTV/SSTVMode.swift](Sources/sstv/SSTV/SSTVMode.swift)) - Interface for SSTV mode implementations
3. **PD120Mode** ([Modes/PD120Mode.swift](Sources/sstv/Modes/PD120Mode.swift)) - Complete PD120 implementation with line decoding

## PD120 Mode Characteristics

- **Resolution**: 640 × 496 pixels
- **Color Space**: YCbCr
- **VIS Code**: 0x63 (99 decimal)
- **Line Duration**: 126.432 ms
- **Frequency Range**: 1500 Hz (black) to 2300 Hz (white)

## Line Structure

Each PD120 line contains:

1. **Sync Pulse** (20 ms @ 1200 Hz) - Line synchronization
2. **Porch** (2.08 ms) - Timing buffer
3. **Y Component** (66 ms) - Luminance (640 pixels)
4. **Cb Component** (66 ms) - Blue chrominance (640 pixels)
5. **Cr Component** (66 ms) - Red chrominance (640 pixels)

## Implementation Details

### Decoding Process

The `decodeLine()` function performs the following steps:

1. **Calculate component timing** - Convert millisecond durations to sample counts
2. **Extract components** - Decode Y, Cb, and Cr from frequency data
3. **Convert color space** - Transform YCbCr to RGB using ITU-R BT.601
4. **Return pixel array** - Output RGB triplets for one complete line

### Frequency Mapping

Frequencies are linearly mapped to normalized values (0.0...1.0):

```
frequency → (frequency - 1500) / 800
```

- 1500 Hz → 0.0 (black)
- 1900 Hz → 0.5 (mid-gray)
- 2300 Hz → 1.0 (white)

### YCbCr to RGB Conversion

Uses ITU-R BT.601 conversion matrix:

```
R = Y + 1.402 * (Cr - 0.5)
G = Y - 0.344136 * (Cb - 0.5) - 0.714136 * (Cr - 0.5)
B = Y + 1.772 * (Cb - 0.5)
```

All values are clamped to [0.0, 1.0].

## Usage Example

```swift
let mode = PD120Mode()

// Assume frequencies contains detected frequency values for one line
// aligned to line start, with length matching line duration
let pixels = mode.decodeLine(
    frequencies: frequencies,
    sampleRate: 48000.0,
    lineIndex: 0
)

// pixels now contains 640 * 3 = 1920 values (RGB triplets)
// Store in ImageBuffer
var buffer = ImageBuffer(width: mode.width, height: mode.height)
buffer.setRow(y: 0, rowPixels: pixels)
```

## Design Principles

Following the Copilot instructions in `.github/copilot/`:

### ✅ What This Implementation Does

- Defines PD120 timing constants with clear documentation
- Maps tone frequencies to pixel intensities
- Decodes one complete line into RGB pixel data
- Uses named constants (no magic numbers)
- Includes comprehensive unit tests
- Maintains clear separation from DSP layer

### ❌ What This Implementation Does NOT Do

- DSP math (Goertzel, FFT, filtering) - handled by DSP layer
- Direct audio buffer access - receives pre-processed frequency data
- PNG file writing - handled by image output layer
- CLI argument parsing - handled by CLI layer
- Sync detection - handled by protocol layer

## Testing

Tests are in [Tests/sstvTests/PD120ModeTests.swift](Tests/sstvTests/PD120ModeTests.swift):

- `testPD120ModeConstants` - Verify all timing and frequency constants
- `testDecodeLineWithSyntheticData` - Test with mid-gray synthetic signal
- `testDecodeLineWithBlackAndWhite` - Test luminance handling
- `testImageBufferIntegration` - Verify buffer compatibility

Run tests:

```bash
swift test
```

## Assumptions

This implementation assumes:

1. **Input is pre-processed** - Frequency detection has already occurred
2. **Time alignment is handled** - Input frequencies are aligned to line start
3. **Sample rate is known** - Must be provided to calculate component boundaries
4. **No sync detection** - Sync pulses are ignored; alignment is upstream responsibility

## Missing Stubs

The following components are referenced but not yet implemented:

- **DSP layer** - Goertzel tone detection, frequency estimation
- **Audio layer** - WAV parsing, sample rate conversion
- **Protocol layer** - VIS decoding, sync detection, line alignment
- **PNG writer** - Image buffer serialization to PNG format
- **CLI** - Command-line interface and file I/O

These will be implemented in subsequent stages following the same architectural principles.

## Future Enhancements

Potential improvements (not in current scope):

- Adaptive frequency range calibration
- Improved noise handling in frequency-to-value mapping
- Color space conversion optimization
- Support for alternative YCbCr standards
