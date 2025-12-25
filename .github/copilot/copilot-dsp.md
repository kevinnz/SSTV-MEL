# Copilot Instructions — DSP Layer

## Scope
DSP code handles:
- Tone detection
- Energy measurement
- Windowing
- Filtering
- Timing alignment

It must NOT:
- Know about SSTV modes
- Handle image dimensions
- Perform color conversion

## Algorithms
- Prefer Goertzel over FFT unless otherwise specified
- Windowing must be explicit and named
- Sampling rate assumptions must be documented

## Precision
- Use Double unless Float is explicitly required
- Avoid premature optimisation
- Deterministic results are more important than speed

## Testing
DSP functions must be testable with:
- Synthetic sine waves
- Known frequencies
- Known amplitudes

Include comments describing:
- Expected input
- Expected output
- Mathematical basis (briefly)

Never invent signal-processing shortcuts.
If unsure, ask for clarification instead of guessing.
