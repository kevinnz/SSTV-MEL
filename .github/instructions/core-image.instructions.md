---
description: "Image buffer and output rules for SSTV-MEL"
applyTo: "Sources/SSTVCore/Image/**"
---

# Image Output Instructions

## Scope

Image code handles:
- Pixel buffers
- Color space conversion
- PNG and JPEG encoding

It must NOT:
- Know about SSTV timing
- Access audio data
- Perform DSP

## Rules

- `ImageBuffer` is a pure data structure
- Color conversion must be isolated
- `ImageWriter` is the single component that handles image encoding (PNG and JPEG)
- Color values are normalized `Double` values in the range `0.0 ... 1.0`
- Image writes must be line-based — modes produce pixel arrays, ImageBuffer owns pixel memory

## Testing

- Image buffers should be comparable
- Image output is verified via PSNR and SSIM metrics against golden reference files

Avoid platform-specific APIs outside the writer.
