# Security Policy

## Scope

SSTV-MEL is an offline SSTV audio decoder library and CLI tool. It processes WAV audio files and produces image output. It does not handle network connections, authentication, user credentials, or sensitive data.

The primary security concern is **malformed input handling** — ensuring the decoder does not crash, hang, or consume excessive resources when processing corrupted or adversarial WAV files.

## Supported Versions

| Version | Supported          |
|---------|--------------------|
| Latest  | :white_check_mark: |

Only the latest version on the `main` branch is actively maintained.

## Reporting a Vulnerability

If you discover a security issue in SSTV-MEL, please report it responsibly:

1. **Preferred:** Use [GitHub Security Advisories](https://github.com/kevinnz/SSTV-MEL/security/advisories/new) to report privately
2. **Alternative:** Open a [GitHub Issue](https://github.com/kevinnz/SSTV-MEL/issues) if the issue is not sensitive

Please include:
- A description of the issue and its potential impact
- Steps to reproduce (ideally with a sample WAV file)
- The version or commit you tested against

## Response

- Reports will be acknowledged within 7 days
- Fixes for confirmed vulnerabilities will be prioritised and released as soon as practical
- Credit will be given to reporters unless they prefer to remain anonymous
