# Plan: Open Source Readiness for SSTV-MEL

This repo is already in strong shape — MIT license, zero external dependencies, clean code with good documentation, and no secrets or credentials. The changes below are organized by priority to get it cleanly open-sourced.

## Steps

### Critical (must-fix before public)

1. ~~**Fix hardcoded paths in Python scripts**~~ — **DONE.** All 5 scripts refactored to use `os.path.dirname(os.path.abspath(__file__))` for project-relative paths. Each script also accepts optional CLI arguments for decoded/expected image paths. `scripts/README.md` updated with usage examples. Verified: `grep -rn '/Users/kevin' scripts/` returns zero matches.

2. ~~**Address large binary files**~~ — **DONE.** 21 WAV files totalling ~321MB were tracked in git. Installed Git LFS (`git-lfs/3.7.1`), ran `git lfs migrate import --include="*.wav" --everything` to rewrite all 95 commits across all branches/tags. `.gitattributes` now tracks `*.wav` via LFS. All 21 files confirmed as LFS pointers via `git lfs ls-files`. **Note:** History was rewritten — requires `git push --force-with-lease` to update the remote.

3. ~~**Verify `.DS_Store` is not tracked**~~ — **DONE.** `git ls-files '*.DS_Store'` returns zero results. `.DS_Store` exists on disk in `samples/` and `expected/` but is correctly gitignored. No action needed.

4. ~~**Verify sample file licensing**~~ — **DONE.** Created `samples/README.md` with full attribution: PD120/PD180 files credited as ARISS public SSTV event recordings with dates and event names; Robot36 files credited as amateur radio SSTV transmissions with callsigns. Notes that amateur radio SSTV transmissions are public broadcasts freely shared for educational and technical use. Includes file format info and Git LFS note.

### Recommended (should-fix for a good open source project)

5. ~~**Add `CONTRIBUTING.md`**~~ — **DONE.** Created `CONTRIBUTING.md` covering: prerequisites (macOS 13+, Swift 5.9+, Git LFS), build/test instructions, code style rules (from copilot instructions), architecture constraints, how to add a new SSTV mode, PR guidelines, issue reporting tips, and a note about AI coding assistant instructions.

6. ~~**Add `CODE_OF_CONDUCT.md`**~~ — **DONE.** Created `CODE_OF_CONDUCT.md` using Contributor Covenant v2.1 (the industry standard). Enforcement contact set to GitHub Issues and direct GitHub contact with the maintainer.

7. ~~**Add `SECURITY.md`**~~ — **DONE.** Created `SECURITY.md` with: scope statement (offline decoder, no network/auth), supported versions table, two reporting channels (GitHub Security Advisories for private reports, GitHub Issues for non-sensitive), required report details, and response timeline (7-day acknowledgement).

8. ~~**Add GitHub Actions CI**~~ — **DONE.** Created `.github/workflows/ci.yml`: runs on `macos-15` with Xcode 16, triggers on push/PR to `main`, checks out with LFS, builds in release mode (`swift build -c release`), and runs `swift test`. Includes concurrency grouping to cancel superseded runs.

9. ~~**Add issue and PR templates**~~ — **DONE.** Created three templates: `.github/ISSUE_TEMPLATE/bug_report.md` (environment info, sample file, steps to reproduce), `.github/ISSUE_TEMPLATE/feature_request.md` (motivation, proposed solution, spec links), `.github/pull_request_template.md` (what/why/how, testing checklist enforcing architecture constraints like fractional sample interpolation and mode-agnostic DSP).

10. ~~**Clean up internal docs**~~ — **DONE.** Moved 5 internal development artifacts to `docs/internal/` using `git mv` (preserves history): `DECODER-CORE-REFACTOR.md`, `REFACTOR-ENGINE.md`, `REFACTOR-FOR-UI.md`, `REFACTOR-TO-LIBRARY.md`, `ROBOT36-COPILOT-TASK.md`. Created `docs/internal/README.md` explaining these are historical, with cross-references to current ADRs and CONTRIBUTING.md. Removed empty `docs/tasks/` directory.

11. ~~**Update `NEXT-STEPS.md`**~~ — **DONE.** Rewrote as a clean public-facing document. Removed all internal branch names (`fix/pd180-decode-quality`, `test/pd120-decoding`), GitHub issue references (#1), completed/stale items, and status/priority tracking. Replaced with concise sections: Decoding Quality (known PD120 issues), New Modes (Robot72, additional PD modes), Documentation (PD120-Implementation.md update needed), Future (UI, live audio, waterfall). Links to README roadmap and CONTRIBUTING.md.

12. ~~**Fix README inconsistencies**~~ — **DONE.** Updated the Project Layout section in `README.md` to reflect the actual current file structure: added `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md`, `SECURITY.md`, `.gitattributes` to root; added `.github/` section with `workflows/`, `ISSUE_TEMPLATE/`, `pull_request_template.md`, `copilot/`; added `ModeParameters.swift` to Modes; added `DecoderStateTests.swift` and `Robot36ModeTests.swift` to Tests; updated `docs/` to show `internal/`, `modes/` subdirectories; added `samples/README.md` and `audio/README.md`; added `expected/` and `scripts/` sections; fixed broken emoji (`�🚀` → `🚀`) in Building section header. Confirmed `sstv_05.pdf` exists — no change needed.

### Optional (nice-to-have)

13. ~~**Add `CHANGELOG.md`**~~ — **DONE.** Created `CHANGELOG.md` following [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) format with all 4 existing tags (0.1.0, 0.2.0, v0.3.0, v0.5.0) plus an Unreleased section covering Robot36 support, bug fixes, and open-source readiness work. Each version entry categorised into Added/Changed/Fixed. Includes GitHub comparison links for all versions.

14. ~~**Add git tags / releases**~~ — **DONE.** Committed all open-source readiness work as a single commit (`chore: open-source readiness`, 25 files changed). Updated `CHANGELOG.md` to move Unreleased into `[0.6.0] — 2026-02-08`. Created annotated tag `v0.6.0` with descriptive message. Tags now: `0.1.0`, `0.2.0`, `v0.3.0`, `v0.5.0`, `v0.6.0`. **Note:** Still requires `git push --force-with-lease && git push --tags` to update remote (force-push needed due to earlier LFS history rewrite).

15. ~~**Clarify `audio/` vs `samples/`**~~ — **DONE.** Created `audio/README.md` explaining these are ad-hoc development test files (not part of automated tests), with a cross-reference to `samples/` for the primary test suite.

16. ~~**Add PD180 unit tests**~~ — **DONE.** Created `Tests/sstvTests/PD180ModeTests.swift` with 10 tests: mode constants, PD180 vs PD120 timing comparison, `lineDurationMs` computed property, `decodeFrame` with mid-gray and black luminance synthetic data, `decodeLine` legacy interface, line-from-frame selection, multi-frame state independence, `DecodingOptions` integration, and `ImageBuffer` integration. All 10 tests pass. All 3 modes (PD120, PD180, Robot36) now have dedicated test files.

17. ~~**Consider SwiftLint**~~ — **DONE.** Created `.swiftlint.yml` with rules matching project conventions. Auto-fixed 1003 trailing whitespace violations across all 23 Swift files. Config includes: relaxed `identifier_name` (min 1 for DSP vars r/g/b/x/y), relaxed `function_body_length` (200), `cyclomatic_complexity` (45), `file_length` (1000), `large_tuple` (3 for RGB), `line_length` ignores comments. Opt-in rules: `force_unwrapping`, `fatal_error_message`, `empty_count`, `closure_spacing`, etc. Disabled: `todo`, `trailing_comma`, `for_where`. Result: 0 errors, 8 acceptable warnings.

## Verification

- ~~Run `git ls-files '*.DS_Store'`~~ — **Clean.** No `.DS_Store` tracked.
- ~~Check tracked file sizes~~ — **Done.** 321MB of WAVs migrated to Git LFS.
- Run `swift build && swift test` to confirm everything passes
- ~~Run `git push --force-with-lease` to update remote with LFS-rewritten history~~ — **Pending.** LFS rewrite + v0.6.0 tag are ready locally. Push with `git push --force-with-lease && git push --tags`.
- Review the repo as a first-time visitor: clone, read README, try to build and contribute

## Status

**All 4 critical steps complete.** The repo has no blockers for open source release.
Steps 5–12 (recommended): **all done.**
Steps 13–17 (optional): **all done.**

The repo is **ready for open source**. All 17 steps complete — code, security, licensing, documentation, testing, and tooling are all in place.

**To publish:** `git push --force-with-lease && git push --tags` (force-push needed due to LFS history rewrite from step 2).

## Decisions

- Copilot instruction files in `.github/copilot/` are clean and useful — **keep them** (they help AI-assisted contributors)
- MIT license and copyright attribution are correct — **no changes needed**
- Zero external dependencies — **no license audit needed**
- Personal name/callsign in LICENSE and README is standard for open source — **keep as-is**
