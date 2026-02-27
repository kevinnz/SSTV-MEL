---
description: "Guided workflow for implementing a new SSTV mode"
---

# Add a New SSTV Mode

I want to add a new SSTV mode to SSTV-MEL. Guide me through the implementation step by step.

## Steps

1. **Create the mode file** in `Sources/SSTVCore/Modes/` following the pattern in `PD120Mode.swift` and `PD180Mode.swift`
2. **Define all timing constants** — use explicit named constants matching the published SSTV specification. Include inline comments referencing the spec.
3. **Implement the `SSTVMode` protocol** — define image dimensions, line timing, frequency ranges, color encoding order, and VIS code
4. **Register the mode** in `SSTVModeSelection` / `ModeParameters.swift` with its VIS code
5. **Add the mode to the CLI** — update the `SSTVMode` enum in `DecodeCommand.swift` so it's available via `--mode`
6. **Create tests**:
   - Unit test for mode timing constants
   - If a sample WAV is available, add a golden-file decode test using PSNR/SSIM comparison
7. **Update documentation** — add the mode to README.md supported modes list

## Key Rules

- Modes are **stateless** — they define timing and structure, not DSP
- All math uses **normalized Double values** (0.0–1.0)
- Use **time-based** decoding with fractional sample interpolation
- Do NOT hardcode sample counts
- Do NOT copy-paste from other modes — share common logic via `ModeTimings`
