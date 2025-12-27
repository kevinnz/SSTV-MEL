
The **decoder-core** must be usable independently of the CLI.

---

## Absolute Constraints

- Do NOT change decoding algorithms unless required for correctness
- Do NOT introduce UI, macOS, Swift, or platform APIs
- Do NOT remove CLI functionality
- Do NOT rely on global or static mutable state
- Do NOT assume batch-only decoding

Correctness > architecture > performance

---

## Step-by-Step Refactor Plan (Follow in Order)

---

### STEP 1: Identify and Extract the Decoder Core

**Goal:** Isolate all SSTV decoding logic into a single reusable core.

Actions:
- Locate all DSP, sync, timing, and image-generation code
- Move this code into a new module: `decoder-core`
- Create a single owning type:
  - `SSTVDecoderCore`
- Add:
  - `init(mode, sampleRate, parameters)`
  - `reset()`

At this stage, behavior must remain identical.

---

### STEP 2: Remove File Ownership from the Decoder

**Goal:** Decoder must not know about files.

Actions:
- Remove all WAV parsing from decoder-core
- Decoder must accept raw audio samples only:
  - `processSamples(float[] samples)`
- WAV reading logic must move to the CLI layer

Decoder-core must not:
- Open files
- Seek
- Rewind
- Allocate full-file buffers

---

### STEP 3: Introduce an Explicit Decoder State Machine

**Goal:** Make implicit phases explicit and observable.

Actions:
- Introduce an enum `DecoderState` with at least:
  - Idle
  - SearchingForSync
  - SyncLocked
  - DecodingLine
  - ImageComplete
  - SyncLost
- Update state transitions in one place only
- Remove any indirect state inference

This state machine will later drive UI behavior.

---

### STEP 4: Implement Progressive Image Output

**Goal:** Support partial and real-time rendering.

Actions:
- Introduce an `ImageBuffer` abstraction:
  - Allocated when decode begins
  - Fixed dimensions per SSTV mode
- Decoder writes one line at a time
- ImageBuffer must be readable at any point
- Partial images must be valid

The CLI should still output a full image at completion.

---

### STEP 5: Add a Decoder Event Interface

**Goal:** Allow external consumers (CLI, UI) to observe progress.

Actions:
- Add callback / observer hooks for:
  - Sync locked (with confidence metric)
  - Sync lost
  - Line decoded (line index)
  - Image progress (0.0–1.0)
  - Image complete
- Emit events immediately when state changes
- Do not buffer or batch events

The decoder must not print status messages directly.

---

### STEP 6: Externalise Mode Parameters

**Goal:** Make PD120 / PD180 configurable but safe.

Actions:
- Group mode constants into parameter structs:
  - `PD120Parameters`
  - `PD180Parameters`
- Allow parameter selection at init or reset
- Disallow mid-line parameter mutation

No hard-coded magic numbers without documentation.

---

### STEP 7: Refactor the CLI to Use the Decoder Core

**Goal:** Prove the core is reusable.

Actions:
- CLI must:
  - Read WAV files
  - Feed samples incrementally into decoder-core
  - Subscribe to decoder events
- CLI output must match current behavior exactly
- Remove duplicate decode logic from CLI

CLI becomes a thin orchestration layer.

---

### STEP 8: Lifecycle, Reset, and Safety

**Goal:** Make decoder robust for long-lived apps.

Actions:
- Ensure:
  - `reset()` clears all state
  - Decoder instance can be reused
  - No static or global state remains
- One decoder instance = one decode session

Assume the decoder may be stopped and restarted at any time.

---

### STEP 9: Replace Logging with Structured Diagnostics

**Goal:** Prepare for UI integration.

Actions:
- Remove `printf`-style logging from decoder-core
- Replace with:
  - State changes
  - Events
  - Optional debug hooks
- CLI decides what to print

Decoder-core never talks to users directly.

---

## Validation Criteria (Must Pass)

- PD120 and PD180 decode correctly
- CLI output matches pre-refactor output
- Decoder supports incremental sample input (e.g. 256–1024 samples)
- Partial images are valid during decode
- Decoder can be reset and reused safely
- No file I/O exists in decoder-core

---

## Documentation Requirements

- Comment major refactor steps
- Document:
  - Decoder lifecycle
  - State transitions
  - Event semantics
- Assume future maintainers are not DSP experts

---

## Final Instruction

Refactor incrementally.  
After each step, confirm output correctness before continuing.

This decoder core will be used by a production macOS UI application.
