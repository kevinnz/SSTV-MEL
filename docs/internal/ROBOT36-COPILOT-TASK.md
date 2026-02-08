# Task: Implement ROBOT36 SSTV Mode

## Objective

Add full ROBOT36 SSTV decoding support to SSTV-MEL.

## Requirements

- Implement `Robot36Mode` conforming to `SSTVMode`
- Place implementation in `Sources/SSTVCore/Modes/Robot36Mode.swift`
- Use time-based decoding (not sample-count-based)
- Decode two image lines per frame
- Write decoded output into `ImageBuffer`

## Must NOT do

- Do not modify DSP or audio demodulation code
- Do not modify UI code
- Do not introduce external libraries
- Do not refactor decoder core unless strictly required

## Implementation steps

1. Define all timing constants explicitly
2. Implement frame-based decoding:
   - Even line: Y + R-Y
   - Odd line: Y + B-Y
3. Sample frequency data using interpolation
4. Convert YCbCr to RGB
5. Return two RGB pixel rows per frame
6. Ensure VIS code 0x08 maps to Robot36Mode

## Success criteria

- Robot36 WAV files decode correctly
- Image renders progressively line-by-line
- Colors are stable and aligned
- Decoder works for both live audio and file-based decoding
- No changes to existing PD120/PD180 functionality