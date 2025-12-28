# ADR: Add ROBOT36 SSTV Decoding

## Status
Accepted

## Context

SSTV-MEL currently supports PD120 and PD180 SSTV modes.
ROBOT36 is widely used for:
- ISS SSTV transmissions
- Amateur satellite SSTV
- VHF/UHF SSTV events

ROBOT36 must be supported using the existing decoder architecture without architectural changes.

## Decision

We will implement ROBOT36 as a new `SSTVMode` conforming type:
- `Robot36Mode`

ROBOT36 decoding will:
- Use existing frequency demodulation output
- Decode two image lines per logical frame
- Write output into `ImageBuffer` line-by-line
- Support both offline WAV decoding and real-time streaming

## Technical constraints

- VIS code: `0x08`
- Image size: `320 x 240`
- Color space: Y + (R-Y) + (B-Y)
- Chroma is shared across two lines (4:2:0)

## Consequences

- Decoder core logic remains unchanged
- Mode detection uses existing VIS detection
- UI and file export require no changes
- ROBOT36 decoding logic is isolated and testable
