## What

Brief description of what this PR does.

## Why

Motivation or issue reference (e.g., Fixes #123).

## How

Key implementation details — what approach was taken and why.

## Testing

- [ ] `swift test` passes
- [ ] New tests added for new functionality
- [ ] Golden-file comparisons verified (if decoder output changed)

## Checklist

- [ ] Follows code style guidelines in `CONTRIBUTING.md`
- [ ] Public API has doc comments
- [ ] No force unwraps or magic numbers introduced
- [ ] DSP code is mode-agnostic (modes only interpret frequency data)
- [ ] Timing uses fractional sample interpolation (not integer sample counts)
