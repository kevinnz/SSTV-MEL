# Copilot Refactor Prompt: SSTV Decoder Core for macOS UI

You are refactoring an existing SSTV decoder codebase (SSTV-MEL) so it can be used as the **decoder engine** for a native macOS application written in Swift.

This is NOT a UI task.  
This is a **decoder architecture refactor**.

---

## Objectives

Refactor the decoder so that it:

1. Can be driven incrementally (streaming samples)
2. Emits progressive decode events (line-by-line)
3. Has a clear lifecycle (init → decode → reset)
4. Is independent of any UI, file I/O, or platform concerns
5. Supports PD120 and PD180 explicitly
6. Can be wrapped cleanly by Swift later

---

## Non-Goals

- Do NOT implement UI code
- Do NOT add macOS-specific APIs
- Do NOT optimize DSP math unless required
- Do NOT change decoding algorithms unless broken

Preserve correctness over performance.

---

## Target Architecture

Refactor toward this conceptual model:

Audio Source (WAV or Live)
↓
Sample Provider (pull or push)
↓
SSTVDecoderCore
↓
Decoder Events (callbacks / observer)
↓
Image Buffer (incremental)

---
## Decoder Responsibilities

The decoder must NOT:
- Load entire WAV files internally
- Own the event loop
- Write files
- Block the calling thread

---

## Required Decoder API (Conceptual)

Introduce a single decoder object with the following responsibilities:

### Decoder Lifecycle

- `init(mode: SSTVModeDecoder, sampleRate: Double)`
- `reset()`
- `setMode(_:)`
- `processSamples(_ samples: [Float])`

### Decode Events (Callbacks or Delegates)

Emit events for:

- `didLockSync(confidence: Float)`
- `didLoseSync()`
- `didDecodeLine(lineNumber: Int)`
- `didUpdateImage(progress: Float)`
- `didCompleteImage()`

Events must be emitted as soon as information is available.

---

## Image Handling Requirements

- Decoder writes into an image buffer incrementally
- Image buffer must be readable at any time
- Partial images must be valid
- No UI concepts inside the decoder

---

## WAV Handling

If the current code:
- Reads WAV files directly
- Assumes batch processing

Refactor so:
- WAV parsing is isolated or removed
- Decoder only consumes raw sample arrays
- Sample source is external

---

## State Management

Make decoder state explicit:

- Sync state
- Current line
- Mode parameters
- Timing offsets

Avoid:
- Global variables
- Implicit static state
- Hidden control flow

---

## Error Handling

Replace silent failure with explicit state transitions:
- Sync lost
- Invalid mode
- End-of-stream

No exceptions for normal decode flow.

---

## Output Expectations

Produce:
1. A refactored decoder core with a clean API
2. Clear separation between DSP logic and orchestration
3. Comments explaining:
   - Decoder lifecycle
   - Event emission points
   - Assumptions made by the decoder

---

## Validation Criteria

The refactored decoder must:
- Decode PD120 and PD180 correctly from WAV samples
- Support progressive rendering
- Be usable from a Swift wrapper without modification
- Be deterministic and resettable

---

## Tone & Style

- Favor clarity over cleverness
- Prefer explicit state machines
- Avoid “magic” constants without explanation
- Write code as if someone else must maintain it in 6 months

---

## Final Instruction

Refactor incrementally.  
Do NOT attempt a full rewrite in one step.

Explain each major refactor decision inline using comments.













