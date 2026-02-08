# SSTV-MEL — Next Steps

Known improvements and future work for the SSTV decoder. For the full roadmap, see the [README](../README.md#-roadmap).

## Decoding Quality

- **PD120 VIS detection** — VIS code 0x5F is registered but not always detected; some PD120 files default to PD180. Workaround: use `--mode PD120`.
- **PD120 horizontal alignment** — Approximately 13ms timing error causes ~68-pixel horizontal offset with reference images. May relate to sync pulse edge detection or missing gap/blank intervals.
- **PD120 component order** — Verify Y_odd → Cr → Cb → Y_even ordering matches QSSTV output.
- **Reference image regeneration** — Consider regenerating `expected/` reference images from a known-good decoder for more accurate golden-file testing.

## New Modes

- **Robot72** — Next Robot-family mode to implement (see `Robot36Mode.swift` as reference)
- **PD50, PD160, PD240** — Additional PD modes following the same pattern as `PD120Mode.swift` / `PD180Mode.swift`

## Documentation

- **PD120-Implementation.md** — Contains outdated VIS code (0x63 vs correct 0x5F) and single-line structure instead of 2-lines-per-frame. Needs update to match current implementation.

## Future

- Shared decoder package for macOS/iOS UI
- Optional live audio input
- Real-time waterfall display

---

Contributions welcome — see [CONTRIBUTING.md](../CONTRIBUTING.md) for guidelines.
