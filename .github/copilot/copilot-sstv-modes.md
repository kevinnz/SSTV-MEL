# Copilot Instructions — SSTV Modes

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

## Example Responsibilities
- Map tone frequency → pixel intensity
- Define per-line structure
- Specify VIS code

## Anti-Patterns
- Copy-pasting logic between modes
- Hardcoding sample counts without explanation
- Mixing DSP math with protocol logic

Modes should read like specifications, not algorithms.
