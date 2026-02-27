---
description: "SSTV mode implementation rules and patterns"
applyTo: "Sources/SSTVCore/Modes/**"
---

# SSTV Mode Instructions

## Scope

SSTV mode implementations define:
- Image width and height
- Line timing
- Frequency ranges
- Color encoding order

They must NOT:
- Perform DSP directly
- Read audio buffers
- Write image files

## Design Rules

- Each mode is its own file
- Shared timing constants go in `ModeTimings`
- Use descriptive names for timing values
- Modes should read like specifications, not algorithms

## Responsibilities

- Map tone frequency → pixel intensity
- Define per-line structure
- Specify VIS code

## Reference Implementations

Use these files as templates when adding new modes:
- `PD120Mode.swift`
- `PD180Mode.swift`

## Patterns to Follow

- Explicit timing constants
- Frame-based decoding
- Shared chroma across multiple lines
- No DSP inside mode
- All math operates on normalized Double values

## Anti-Patterns

- Copy-pasting logic between modes
- Hardcoding sample counts without explanation
- Mixing DSP math with protocol logic
- Integer math for timing
- Reading raw audio samples
- Accessing ImageBuffer directly
