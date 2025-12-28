# SSTV-MEL – Copilot Instructions

You are working in the SSTV-MEL codebase, a native Swift macOS application for decoding SSTV (Slow Scan Television).

## High-level rules

- This project prioritizes **correct SSTV decoding over performance**
- Prefer **clarity and correctness** over clever optimizations
- All decoding must be **fully native Swift**
- Do NOT introduce C, C++, Python, or external DSP libraries
- Do NOT refactor unrelated code
- Follow existing architectural patterns exactly

## Architecture constraints

- `SSTVDecoderCore` is the single owner of decoding state
- SSTV modes are implemented as isolated, stateless types conforming to `SSTVMode`
- Modes must not:
  - Own audio buffers
  - Perform DSP (FFT, Goertzel, etc.)
  - Access UI or file I/O
- Modes only interpret **frequency-vs-time data** provided by the decoder core

## Image handling

- Decoded output must be written incrementally into `ImageBuffer`
- ImageBuffer writes must be line-based
- ImageBuffer owns pixel memory; modes only produce pixel arrays
- Color values are normalized `Double` values in the range `0.0 ... 1.0`

## Timing model

- SSTV decoding is **time-based**, not sample-count-based
- All pixel extraction must use **fractional sample interpolation**
- Never assume integer samples-per-pixel

## Threading

- Decoder core is single-threaded
- Do not introduce locks inside decoding logic
- Real-time safety is handled outside the decoder

## New mode implementation rules

When adding a new SSTV mode:
- Create a new type in `Sources/SSTVCore/Modes/`
- Use explicit constants for all timing values
- Match published SSTV specifications exactly
- Include clear inline comments referencing the spec behavior
