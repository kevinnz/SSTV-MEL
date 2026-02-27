---
description: "Diagnose SSTV decode issues and quality problems"
---

# Debug SSTV Decode

Help me diagnose a decoding issue with SSTV-MEL. Walk through these diagnostic steps:

## 1. Check the input WAV file

Run `sstv info <file> --json` to inspect:
- Sample rate (expected: 44100 Hz)
- Channel count
- Duration
- Whether a VIS code was detected
- Which SSTV mode was identified

## 2. Verify VIS detection

If VIS detection failed (exit code 20):
- Check if the audio contains a valid SSTV signal
- Try forcing a mode with `--mode` flag
- Check if the audio is too quiet or has excessive noise

## 3. Check sync detection

If sync was not found (exit code 21) or lost (exit code 22):
- Use `--verbose` to see diagnostic output from the decoder
- Check if `--phase` offset adjustment helps
- Try `--skew` correction if lines appear slanted

## 4. Compare output quality

If the image decodes but looks wrong:
- Compare against a reference decode from QSSTV or MMSSTV
- Use PSNR/SSIM comparison via the test infrastructure
- Check if `--phase` or `--skew` adjustments improve the result

## 5. Useful commands

```bash
# Quick inspection
sstv info input.wav --json

# Verbose decode with diagnostics
sstv decode input.wav output.png --verbose

# Force a specific mode
sstv decode input.wav output.png --mode PD120

# Adjust phase and skew
sstv decode input.wav output.png --phase 0.5 --skew 0.01
```
