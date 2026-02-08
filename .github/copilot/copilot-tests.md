# Copilot Instructions — Testing

## Framework
- XCTest only

## Test Types
- Unit tests for DSP primitives
- Unit tests for VIS decoding
- Integration tests for full decode
- Golden-file comparison for images

## Rules
- Tests must be deterministic
- No reliance on wall-clock time
- Sample files live in `samples/`

## Image Tests
- Compare hashes, not pixel-by-pixel loops
- Document expected output source (QSSTV, MMSSTV, etc.)

Tests are first-class citizens.
Do not generate placeholder assertions.
