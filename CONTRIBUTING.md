# Contributing to SSTV-MEL

Thank you for considering contributing to SSTV-MEL! This guide covers everything you need to get started.

## Prerequisites

- **macOS 13+**
- **Swift 5.9+** (included with Xcode 15+ or standalone Swift toolchain)
- **Git LFS** — sample WAV files are stored with [Git LFS](https://git-lfs.github.com/). Install it before cloning:
  ```bash
  brew install git-lfs
  git lfs install
  ```

## Building

No Xcode project is required — the project uses Swift Package Manager:

```bash
# Clone (Git LFS will automatically download WAV files)
git clone https://github.com/kevinnz/SSTV-MEL.git
cd SSTV-MEL

# Build
swift build

# Run the CLI
swift run sstv samples/PD120/Space_Comms_-_2017-07-23\ _-_0246_UTC_-_ARISS_20_Year_-_image_1.wav
```

## Testing

Tests are a first-class concern:

```bash
swift test
```

The test suite includes:
- Unit tests for DSP primitives, mode parameters, and state machine
- Full decode integration tests
- Golden-file image comparisons (decoded output vs reference images in `expected/`)

When adding new functionality, include corresponding tests. For new SSTV modes, add both unit tests for mode constants and golden-file integration tests with sample recordings.

## Code Style

This project follows specific Swift conventions documented in [`.github/copilot/`](.github/copilot/):

- **Swift 5.9+**, targeting macOS 13+ / iOS 16+
- Prefer structs over classes
- Prefer immutability
- No force unwraps, no singletons, no magic numbers
- Use `throws` and explicit error enums, not `fatalError`
- Public types and functions must have doc comments
- DSP functions must include units in comments (Hz, ms, samples)
- Types: `PascalCase`. Functions and variables: `camelCase`
- Avoid abbreviations unless domain-standard (FFT, VIS, SSTV)

## Architecture Rules

These constraints are critical — please follow them carefully:

- **`SSTVDecoderCore`** is the single owner of decoding state
- **SSTV modes** (`Sources/SSTVCore/Modes/`) are isolated, stateless types conforming to `SSTVMode`. They must not own audio buffers, perform DSP, or access UI/file I/O
- **DSP code** is mode-agnostic — modes only interpret frequency-vs-time data
- **Image output** goes through `ImageBuffer` (line-based, incremental writes)
- **Timing** is time-based, not sample-count-based — use fractional sample interpolation
- **Decoder core** is single-threaded — no locks inside decoding logic
- All decoding must be **fully native Swift** — no C, C++, Python, or external DSP libraries

## Adding a New SSTV Mode

1. Create a new type in `Sources/SSTVCore/Modes/` (see `PD120Mode.swift` or `Robot36Mode.swift` as reference implementations)
2. Use explicit named constants for all timing values
3. Match published SSTV specifications exactly
4. Include inline comments referencing spec behaviour
5. Add unit tests in `Tests/sstvTests/` for mode constants and synthetic data
6. Add golden-file integration tests with real sample recordings if available

## Submitting Changes

1. **Fork** the repository
2. **Create a branch** from `main` for your change
3. **Make your changes** following the style and architecture guidelines above
4. **Run the tests** (`swift test`) and ensure they pass
5. **Open a pull request** against `main` with a clear description of what you changed and why

### What Makes a Good PR

- Focused on a single change (avoid bundling unrelated modifications)
- Tests included for new functionality
- Follows existing code patterns and architectural boundaries
- Doc comments on public API additions
- Clear commit messages

## Reporting Issues

When filing a bug report, please include:
- macOS version and Swift version (`swift --version`)
- The WAV file that produces incorrect output (or a description of it)
- Expected vs actual output
- CLI command used

## AI Coding Assistants

This project includes [GitHub Copilot custom instructions](.github/copilot/) that enforce architectural and DSP constraints. If you're using Copilot or another AI assistant, these instructions help prevent subtle breakage. Please don't bypass them.

## Questions?

Open an issue if something is unclear — we're happy to help.
