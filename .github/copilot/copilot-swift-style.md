# Copilot Instructions — Swift Style Guide

## Language Version
- Swift 5.9+
- macOS 13+

## Style Rules
- Prefer structs over classes
- Prefer immutability
- No singletons
- No force unwraps
- No magic numbers (use named constants)

## Error Handling
- Use `throws`, not fatalError
- Define explicit error enums
- Errors must include context

## Naming
- Types: PascalCase
- Functions & vars: camelCase
- Protocols describe capability (e.g. `SSTVMode`)
- Avoid abbreviations unless domain-standard (FFT, VIS)

## Documentation
- Public types and functions must have doc comments
- DSP functions must include units (Hz, ms, samples)

## Performance
- Avoid unnecessary allocations in inner DSP loops
- Prefer preallocated buffers
- Clarity > micro-optimisation unless profiling data exists
