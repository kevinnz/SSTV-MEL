# Copilot Instructions — Image Output

## Scope
Image code handles:
- Pixel buffers
- Color space conversion
- PNG encoding

It must NOT:
- Know about SSTV timing
- Access audio data
- Perform DSP

## Rules
- ImageBuffer is a pure data structure
- Color conversion must be isolated
- PNGWriter is the only PNG-aware component

## Testing
- Image buffers should be comparable
- PNG output should be verifiable via hash

Avoid platform-specific APIs outside the writer.
