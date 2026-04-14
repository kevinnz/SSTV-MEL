# SSTV-MEL Decode Improvement Plan

## Problem Statement

The SSTV-MEL decoder has several performance bottlenecks, decode quality issues, and test gaps identified through codebase analysis cross-referenced with SSTV format research. The most critical issue is O(n²) redundant FM demodulation in the streaming decoder path.

**Baseline**: 139 tests passing, ~342s total test time (golden files dominate). Branch: `decode-improvement`. Current version: v0.6.0.

## Approach

Four parallel workstreams, with a final sequential step for version bump and PR.

---

## Workstream A: Performance Improvements

**Goal**: Fix critical O(n²) FM demodulation bug and reduce memory allocations.

### A1. Fix Redundant FM Demodulation (Critical)

**File**: `Sources/SSTVCore/SSTV/SSTVDecoderCore.swift` (lines 559-565)

**Bug**: `processFrameDecoding()` re-demodulates the ENTIRE sample buffer every time new samples arrive if `sampleBuffer.count > frequencies.count`. This is O(n²) — a 90-second file at 44.1kHz means re-demodulating ~4M samples repeatedly.

**Fix**: Track the last demodulated sample index. Only demodulate NEW samples incrementally and append to the existing `frequencies` array. The `FMFrequencyTracker` already maintains filter state, so incremental demodulation is correct.

```
// Before (O(n²)):
if sampleBuffer.count > frequencies.count {
    let samples = sampleBuffer.map { Double($0) }
    frequencies = tracker.track(samples: samples)  // re-demod ALL
}

// After (O(n)):
if sampleBuffer.count > lastDemodulatedIndex {
    let newSamples = Array(sampleBuffer[lastDemodulatedIndex...]).map { Double($0) }
    let newFreqs = tracker.track(samples: newSamples)
    frequencies.append(contentsOf: newFreqs)
    lastDemodulatedIndex = sampleBuffer.count
}
```

**Note**: Must verify FMFrequencyTracker maintains internal state between calls (filter memory). If it resets state, need to also fix the tracker to support incremental operation.

### A2. Eliminate Redundant Float→Double Buffer Copies

**Files**: `SSTVDecoderCore.swift` lines 459, 519

Both `processVISDetection()` and `processSignalSearch()` do `sampleBuffer.map { Double($0) }` — a full copy of the entire buffer. Since the FM tracker already needs Double input, consider storing samples as Double from the start, or at minimum avoid re-copying the same prefix.

**Fix options** (choose one):
1. Change `sampleBuffer` from `[Float]` to `[Double]` — simplest, but slightly more memory
2. Keep Float storage but only convert new samples when needed

Option 1 is preferred — Double is used everywhere downstream and the ~2× memory for the sample buffer is negligible compared to the frequencies array which is already Double.

### A3. Optimize ImageBuffer Bulk Operations

**File**: `Sources/SSTVCore/Image/ImageBuffer.swift`

- `setRow()` uses element-by-element copy — replace with `replaceSubrange` or `withUnsafeMutableBufferPointer` for bulk memory copy
- `toRGBA8()` and `toRGB8()` append element-by-element — pre-allocate with `reserveCapacity` or use `UnsafeMutableBufferPointer`

These are inner-loop operations called for every decoded line (496 lines × 640 pixels × 3 channels).

---

## Workstream B: Decode Quality Improvements

**Goal**: Fix timing discrepancies, deduplicate mode logic, improve VIS robustness.

### B1. Extract Shared PD Mode Decode Logic

**Files**: `PD120Mode.swift`, `PD180Mode.swift`, `Robot36Mode.swift`

PD120 and PD180 have ~200 lines of identical code:
- `decodeComponentTimeBased()` — identical implementation
- `frequencyToValue()` — identical implementation  
- `ycbcrToRGB()` — identical implementation (also duplicated in Robot36 with different visibility)

**Fix**: Create `Sources/SSTVCore/Modes/PDModeShared.swift` with shared implementations as free functions or a protocol extension. Modes call shared logic with their mode-specific timing parameters.

This reduces maintenance burden and ensures bug fixes apply to all modes simultaneously.

### B2. Fix PD180 Porch Timing

**File**: `Sources/SSTVCore/Modes/PD180Mode.swift` line 56

PD180 uses `porchMs = 2.0` but:
- PD120 uses `porchMs = 2.08` (correct per spec)
- Research document specifies 2.08ms for all PD modes
- This 0.08ms error accumulates across 248 frames (19.84ms total drift ≈ 3.5 pixels at PD180 scan rate)

**Fix**: Change `porchMs` from `2.0` to `2.08` in PD180Mode.

### B3. Improve VIS Detection Robustness

**File**: `Sources/SSTVCore/SSTV/VISDetector.swift`

Current issues:
- Single ambiguous bit fails entire detection → returns nil → defaults to PD120
- No error correction or multi-attempt strategy
- Parity bit is checked but not used for single-bit error correction

**Fix**: 
1. Use parity bit to correct single-bit errors (the VIS code has an even parity bit — if one data bit is ambiguous, the parity constraint resolves it)
2. If detection confidence is low, try a second pass with slightly shifted window
3. Track confidence score and report via delegate

### B4. Improve Signal Search Flexibility

**File**: `Sources/SSTVCore/SSTV/SSTVDecoderCore.swift` line 161

The hardcoded `skipSecondsForVIS = 3.0` fails for files with late VIS codes. The signal search starts at sample index `3.0 * sampleRate`, missing any signal content before that point isn't the issue — the issue is if VIS ends later than 3s, the skip is fine. But if the signal starts very close to the beginning (less than 3s of audio before VIS), the sync search wastes time.

**Fix**: Make `skipSecondsForVIS` configurable via `DecodingOptions` with a sensible default. Also add a fallback: if no signal is found after the skip point, retry from sample 0.

---

## Workstream C: New Tests

**Goal**: Fill critical test coverage gaps for DSP primitives, VIS detection, and signal search.

### C1. Goertzel Algorithm Tests

**File**: New `Tests/sstvTests/GoertzelTests.swift`

Test with synthetic sine waves:
- Single frequency detection at known Hz values (1200, 1500, 1900, 2300 Hz)
- Energy measurement accuracy
- Frequency discrimination (detect 1200 Hz, reject 1300 Hz)
- Edge cases: zero signal, DC offset, very short windows
- Parabolic interpolation accuracy

### C2. FM Demodulator Tests

**File**: New `Tests/sstvTests/FMDemodulatorTests.swift`

- Constant frequency → constant output
- Linear chirp → linear output
- Known FM-modulated signal → correct frequency recovery
- Sample rate independence
- Filter settling time behavior

### C3. VIS Detection Tests

**File**: New `Tests/sstvTests/VISDetectorTests.swift`

- Synthetic VIS code for PD120 (0x5F), PD180 (0x60), Robot36 (0x08)
- Correct leader tone detection (1900 Hz)
- Correct start bit detection (1200 Hz)
- Bit decoding accuracy (1100 Hz = 0, 1300 Hz = 1)
- Parity validation
- Unknown VIS code handling
- Noisy signal tolerance (if B3 improvements are applied)

### C4. Signal Search Tests

**File**: New `Tests/sstvTests/SignalSearchTests.swift`

- Synthetic sync pulse pattern at known position → correct detection
- Multiple signal detection (pick strongest)
- No signal → graceful failure with zero confidence
- Signal at beginning of file (edge case for skip logic)

### C5. Expanded Robot36 Tests

**File**: Extend `Tests/sstvTests/Robot36ModeTests.swift`

- Frame decode with synthetic frequency data
- Alternating Cr/Cb chroma line handling
- Separator frequency detection (1500 Hz vs 2300 Hz for even/odd)

---

## Workstream D: Version Bump & PR (Sequential, depends on A+B+C)

### D1. Update Version Number

- `CHANGELOG.md`: Add v0.7.0 section with all improvements
- Any version constants in source code

### D2. Create Pull Request

- Commit all changes with descriptive messages
- Create PR with summary of improvements, before/after metrics
- Reference this plan in PR description

---

## Dependency Graph

```
A1 (FM demod fix)     ──┐
A2 (Float→Double)     ──┤
A3 (ImageBuffer opt)  ──┤
B1 (Shared PD logic)  ──┤
B2 (PD180 timing)     ──┼──→ D1 (Version) → D2 (PR)
B3 (VIS robustness)   ──┤
B4 (Signal search)    ──┤
C1 (Goertzel tests)   ──┤
C2 (FM demod tests)   ──┤
C3 (VIS tests)        ──┤
C4 (Signal tests)     ──┤
C5 (Robot36 tests)    ──┘
```

A1-A3, B1-B4, C1-C5 are all parallelizable. D1-D2 run after all others complete.

## Parallel Agent Assignment

- **Agent 1 (Performance)**: A1, A2, A3
- **Agent 2 (Decode Quality)**: B1, B2, B3, B4
- **Agent 3 (Tests)**: C1, C2, C3, C4, C5
- **Agent 4 (Finalize)**: D1, D2 (after agents 1-3 complete)

## Risk Notes

- **A1** requires verifying FMFrequencyTracker supports incremental operation. If not, the tracker itself needs modification.
- **B1** (shared logic extraction) touches the same files as **B2** (PD180 timing). Agent 2 should do B1 first, then B2.
- **B3** (VIS robustness) may affect **C3** (VIS tests). Agent 3 should write tests for current behavior first, then update after B3 lands.
- Golden file test thresholds may need adjustment after B2 timing fix — PD180 images should improve.
