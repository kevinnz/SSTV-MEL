---
description: "CLI behavior and argument parsing rules for the sstv command"
applyTo: "Sources/sstv/**"
---

# CLI Instructions

## Architecture

The CLI uses [swift-argument-parser](https://github.com/apple/swift-argument-parser) with:
- `SSTVCommand` as the `@main` root command
- `Decode` as the default subcommand (backward compatible: `sstv input.wav` works)
- `Info` subcommand for WAV inspection without decoding

## Responsibilities

- Parse and validate arguments
- Read input (file path or stdin via `-`)
- Invoke `SSTVCore` decoder
- Format output (human text to stderr, JSON to stdout)
- Return granular exit codes

## Rules

- **No decoding logic in CLI** — all decode work delegates to `SSTVCore`
- All human-readable output (progress, status, errors) goes to **stderr**
- **stdout** is reserved for `--json` structured output only
- Errors must be user-readable with actionable messages
- Fail fast on invalid input

## Output Modes

- Default: human-friendly text on stderr, image written to file
- `--json`: structured JSON on stdout, suppressess all human text
- `--quiet`: suppresses progress/decorative output
- `--verbose`: enables diagnostic output from decoder delegate

## Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | General/unknown error |
| 2 | Invalid arguments (ArgumentParser) |
| 10 | Input file not found |
| 11 | Invalid WAV format |
| 20 | VIS detection failed |
| 21 | Sync not found |
| 22 | Sync lost (partial decode) |
| 30 | Output write failed |

## stdin Support

When input is `-`, WAV data is read from stdin into a temp file, then decoded. This enables piping: `cat input.wav | sstv decode - output.png`
