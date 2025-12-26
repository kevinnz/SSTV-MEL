# SSTV-MEL Next Steps

This document tracks the identified improvements and fixes for the SSTV decoder.

## PD120 Decoding Issues

### 1. Fix VIS code detection for PD120
- **Status:** Not started
- **Priority:** High
- **Description:** VIS code 0x5F is registered in `VISDetector.swift` but is not being detected in PD120 audio files, causing the decoder to default to PD180
- **Workaround:** Use `--mode PD120` flag to force mode

### 2. Investigate ~68-pixel horizontal timing offset
- **Status:** Not started
- **Priority:** Medium
- **Description:** There's approximately 13ms timing error causing horizontal misalignment with reference images
- **Possible causes:**
  - Sync detection finding middle of sync pulse instead of start
  - Missing gaps/blanks between components
  - Different timing assumptions than the reference decoder

### 3. Verify PD120 component order
- **Status:** Not started
- **Priority:** Medium
- **Description:** QSSTV shows Y_odd → Cr → Cb → Y_even order. Need to confirm if line placement in image buffer is correct

### 4. Re-generate reference images
- **Status:** Not started
- **Priority:** Low
- **Description:** Consider re-generating expected reference images using this decoder for accurate comparison testing

## Branch Merges

### 5. ~~Update README to include PD180~~
- **Status:** ✅ Completed
- **Description:** GitHub issue #1 - PD180 was missing from README. Now resolved.

### 6. Merge PD180 fixes from `fix/pd180-decode-quality` branch
- **Status:** Not started
- **Priority:** High
- **Description:** Previous session achieved 0.969 correlation and 0-pixel horizontal shift on PD180. Changes include:
  - Quadrature FM demodulation (ADR-001 compliant)
  - FIR low-pass filtering
  - Time-based decoding with sub-sample precision

### 7. Merge PD120 fixes from `test/pd120-decoding` branch
- **Status:** Not started
- **Priority:** High
- **Description:** Time-based decoding algorithm and vDSP inout parameter fix. Changes include:
  - Fixed `let omega` → `var omega` for vDSP_vrampD inout parameter
  - Updated decodeFrame to use time-based algorithm with linear interpolation

## Code Quality

### 8. Run golden file tests
- **Status:** Not started
- **Priority:** Medium
- **Description:** Run `GoldenFileTests.swift` to validate decoder against expected outputs

### 9. Update PD120-Implementation.md documentation
- **Status:** Not started
- **Priority:** Low
- **Description:** Current documentation shows:
  - Outdated VIS code (0x63 instead of correct 0x5F)
  - Single-line structure instead of 2-lines-per-frame
  - Needs update to reflect actual implementation

---

*Last updated: 26 December 2025*
