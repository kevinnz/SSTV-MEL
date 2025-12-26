# ADR-001: SSTV PD120/PD180 Decoding Algorithm Selection

## Status
Accepted

## Date
2025-12-26

## Context

This project aims to build a **native macOS application (Swift)** for decoding SSTV (Slow-Scan Television) transmissions, with an initial focus on **ISS SSTV events**. The primary target modes are **PD120** and **PD180**, which transmit high-resolution (640×496) color images.

Key constraints and priorities:

- **Primary use case:** ISS SSTV (PD120, PD180)
- **Processing model:** Offline decoding first, real-time decoding later
- **Platform:** macOS on Apple Silicon (M3 MacBook Air)
- **Language:** Swift (native preferred)
- **Quality priorities:**
  1. Image quality
  2. Code simplicity / maintainability
  3. Performance

The decoder must correctly handle:

- FM-based SSTV tone demodulation
- Long sync pulses and VIS codes
- Slant and timing correction
- PD-mode-specific line pairing and color decoding

Multiple demodulation approaches were evaluated, including zero-crossing detection, FFT-based analysis, PLL-style demodulation, and advanced recursive/Kalman techniques.

## Decision

We will implement **Quadrature FM Demodulation with FIR filtering (PLL-style / phase-difference method)** as the **primary SSTV decoding algorithm** for PD120 and PD180.

This approach will be implemented **natively in Swift**, leveraging the **Accelerate (vDSP)** framework for DSP primitives.

The decoder will be designed as:

1. **Offline-first** (entire audio file available)
2. **Streaming-capable** (architecture allows real-time extension)

## Rationale

### Why Quadrature FM Demodulation

Quadrature FM demodulation provides the best balance between quality, robustness, and implementation complexity:

- Accurately tracks instantaneous frequency (pixel brightness)
- Naturally rejects amplitude noise
- Well-suited to narrowband SSTV signals
- Proven in mature decoders (PLL / quadrature FM demod modes)
- Deterministic behavior, easy to test and debug

Unlike zero-crossing detection, this method is highly resistant to noise and jitter. Compared to FFT-based approaches, it requires less code, less state, and fewer tuning parameters while still producing high-quality images.

### Why Not FFT-First

FFT-based decoding (spectrogram-style):

- Can achieve excellent results offline
- Enables advanced slant correction techniques
- Is significantly more complex to implement and tune

FFT-based demodulation is therefore deferred as a **potential enhancement**, not the baseline algorithm.

### Why Not Zero-Crossing

Zero-crossing methods are:

- Highly noise-sensitive
- Historically brittle
- Inferior in image quality

They are not suitable for a modern quality-focused decoder.

### Why Not Kalman / Advanced Filters

While theoretically attractive, Kalman or advanced recursive demodulators:

- Add significant complexity
- Are difficult to tune and debug
- Provide diminishing returns over a well-designed PLL

They are not justified for the current scope.

## Technical Outline

### DSP Pipeline

1. Input audio at 48 kHz (preferred)
2. Quadrature mixing to I/Q baseband
3. FIR low-pass filtering (linear phase)
4. Phase-difference FM demodulation
5. Optional decimation
6. Frequency-to-pixel mapping

### PD Mode Handling

- Decode VIS header to confirm PD120 / PD180
- Detect long sync pulses for line alignment
- Parse Y0, R–Y, B–Y, Y1 segments
- Output two image lines per PD line

### Timing & Slant Correction

- Measure sync timing across entire file
- Compute global timing drift
- Apply resampling or timing correction
- Offline correction preferred in Phase 1

## Consequences

### Positive

- High-quality images under real-world conditions
- Fully native Swift implementation
- Efficient on Apple Silicon
- Clear path to real-time decoding
- Well-understood DSP techniques

### Negative

- Requires careful FIR filter design
- More complex than naive zero-crossing methods
- Some advanced corrections (e.g. adaptive noise handling) deferred

## Alternatives Considered

| Option | Rejected Because |
|------|------------------|
| Zero-crossing demodulation | Poor noise performance |
| FFT-only demodulation | Higher complexity for baseline |
| Kalman filter | Overkill for scope |
| External C/C++ libraries | Native Swift is sufficient |

## Future Work

- Optional FFT-based sync refinement
- Adaptive filtering based on SNR
- Real-time streaming mode
- GPU acceleration (unlikely to be necessary)
- Additional SSTV modes (Robot, Martin, Scottie)

## References

- PD mode specifications (G4IJE)
- MMSSTV documentation
- QSSTV source code
- slowrx (Windytan)
- AMSAT / ARISS SSTV technical notes

---

**Decision Owner:** Project maintainer

**Decision Scope:** SSTV decoder core demodulation algorithm