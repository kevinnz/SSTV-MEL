# Copilot Instructions: Refactor SSTV-MEL into a UI-Ready Decoder Engine

## Role

You are acting as a **senior DSP + systems engineer** refactoring an existing SSTV decoder (SSTV-MEL) so it can be embedded inside a **native macOS UI application**.

This repository is NOT being turned into an app.  
It is being refactored into a **decoder engine**.

---

## Primary Goal

Transform the existing codebase into a **headless, reusable SSTV decoder core** that:

- Consumes audio samples incrementally
- Emits progressive decode events
- Has a clear lifecycle and reset semantics
- Is independent of file I/O and UI
- Can be safely wrapped by Swift later

---

## Absolute Constraints (Do Not Violate)

- Do NOT change SSTV decoding algorithms unless required for correctness
- Do NOT introduce UI, macOS, or Swift-specific code
- Do NOT optimize performance prematurely
- Do NOT rewrite everything at once
- Do NOT use global or static mutable state

Correctness > cleanliness > performance

---

## Target Decoder Shape (Conceptual)
```
External Audio Source (WAV or Live)
↓
Sample Provider
↓
SSTVDecoderCore
↓
Events (callbacks / observer)
↓
External Image Consumer (UI)
```


The decoder must not:
- Load files
- Manage threads
- Block execution
- Own the application loop

---

## Refactor Order (Mandatory)

Perform the following steps **in order**.  
Do NOT skip ahead.

---

### Step 1: Extract Decoder Core

**Goal:** Create a single decoder object that owns all decode state.

Actions:
- Identify all decode logic
- Move it into a new `SSTVDecoderCore` struct/class
- Add:
  - `init(...)`
  - `reset()`
- Ensure reset clears all state completely

Do not change behavior yet.

---

### Step 2: Remove WAV File Ownership

**Goal:** Decoder must consume samples, not files.

Actions:
- Remove WAV parsing from the decoder
- Decoder must accept raw audio samples only
- Introduce:
  - `processSamples(float[] samples)`

WAV parsing must live outside the decoder or be removed.

---

### Step 3: Make Decoder State Explicit

**Goal:** Replace implicit phase transitions with a named state machine.

Actions:
- Introduce an enum:
  - `Idle`
  - `SearchingForSync`
  - `LockedToSync`
  - `DecodingLine`
  - `ImageComplete`
  - `SyncLost`
- Update decoder state in one place only
- Never infer state indirectly

This state will later drive UI status.

---

### Step 4: Progressive Image Buffer

**Goal:** Support line-by-line rendering.

Actions:
- Introduce an `ImageBuffer` abstraction
- Allocate buffer at decode start
- Write pixels incrementally per line
- Allow read access at any time

Partial images must be valid.

---

### Step 5: Event Emission Layer

**Goal:** Allow UI to observe decode progress.

Actions:
- Add callbacks / delegates / observer hooks for:
  - Sync locked (with confidence)
  - Sync lost
  - Line decoded (line index)
  - Image progress (0–1)
  - Image complete
- Emit events immediately when they occur
- Do not batch or delay events

No logging-only feedback.

---

### Step 6: Externalise Parameters

**Goal:** Allow controlled UI interaction.

Actions:
- Group mode-specific constants into parameter structs:
  - `PD120Parameters`
  - `PD180Parameters`
- Allow parameters to be injected at init or reset
- Do not allow mid-line mutation

---

### Step 7: Lifecycle Safety

**Goal:** Make decoder robust for UI use.

Actions:
- Ensure:
  - Reset is idempotent
  - Decoder can be reused
  - One instance == one decode session
- Remove any hidden static state

Decoder must be safe to stop and restart.

---

### Step 8: Replace Logging with Diagnostics

**Goal:** Prepare for UI-driven feedback.

Actions:
- Remove or reduce `printf`-style logging
- Replace with structured status reporting
- Leave optional debug hooks for development

UI decides what the user sees.

---

## Validation Checklist

The refactor is complete when:

- PD120 and PD180 decode correctly
- Decoder accepts samples in small chunks (e.g. 256–1024)
- Image appears progressively during decode
- Decoder can be reset and reused without artifacts
- No file I/O exists inside the decoder core

---

## Documentation Requirements

- Comment each major refactor step
- Explain:
  - Decoder lifecycle
  - State transitions
  - Event emission points
- Assume the next engineer is not a DSP expert

---

## Tone & Style

- Be explicit
- Prefer readable state machines
- Avoid “magic” constants
- Write maintainable systems code, not demos

---

## Final Instruction

Work incrementally.  
After each step, ensure behavior is unchanged before proceeding.

This decoder will become the foundation of a production macOS application.