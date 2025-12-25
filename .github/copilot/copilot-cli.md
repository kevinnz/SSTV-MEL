# Copilot Instructions — CLI Behavior

## CLI Responsibilities
- Parse arguments
- Validate input paths
- Invoke decoder
- Write output
- Return meaningful exit codes

## Rules
- No decoding logic in CLI
- Errors must be user-readable
- Exit codes must be documented

## UX Expectations
- Fail fast on invalid input
- Quiet by default
- Verbose mode must be explicit
