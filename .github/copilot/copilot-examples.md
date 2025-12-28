# SSTV Mode Implementation Examples

## Reference implementations

Use these files as templates:
- `PD120Mode.swift`
- `PD180Mode.swift`

## Patterns to follow

- Explicit timing constants
- Frame-based decoding
- Shared chroma across multiple lines
- No DSP inside mode
- All math operates on normalized Double values

## Anti-patterns

- Hard-coded sample counts
- Integer math for timing
- Reading raw audio samples
- Accessing ImageBuffer directly
