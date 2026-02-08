# Internal Development Documents

These documents are **historical development artifacts** from the initial implementation of SSTV-MEL. They record AI-assisted refactoring plans and task prompts used during the project's development.

They are preserved here for reference but are **not maintained** and may not reflect the current codebase. For up-to-date architecture information, see:

- [ADR: PD120/PD180 Decoding Algorithm](../adr/adr_001_sstv_pd_120_pd_180_decoding_algorithm.md)
- [ADR: Robot36 Decoder](../adr/ADR-ROBOT36-DECODER.md)
- [CONTRIBUTING.md](../../CONTRIBUTING.md) — architecture rules and code style

## Contents

| File | Description |
|------|-------------|
| `DECODER-CORE-REFACTOR.md` | Plan for refactoring the decoder core state machine |
| `REFACTOR-ENGINE.md` | Plan for separating the decoding engine from mode logic |
| `REFACTOR-FOR-UI.md` | Plan for making the library UI-friendly (delegate callbacks) |
| `REFACTOR-TO-LIBRARY.md` | Plan for extracting SSTVCore as a reusable library |
| `ROBOT36-COPILOT-TASK.md` | AI task prompt for implementing Robot36 mode support |
